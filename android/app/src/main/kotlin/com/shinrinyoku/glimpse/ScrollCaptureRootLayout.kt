package com.shinrinyoku.glimpse

import android.content.Context
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.MotionEvent
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.ScrollView
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max

/**
 * Exposes Flutter's active vertical scroll range to Android view inspectors.
 *
 * Flutter's widget tree is rendered inside one native view, so OEM screenshot
 * tools cannot otherwise tell whether the current route can keep scrolling.
 * The values are supplied by [ScrollCaptureBridge] and are only metadata; Dart
 * remains responsible for moving and rendering the actual scrollable.
 */
class ScrollCaptureRootLayout(context: Context) : FrameLayout(context) {
    private val scrollProxy = ScrollCaptureProxyView(context)
    private var statusBarInset = 0
    private var viewportTopInset = 0
    private var viewportBottomInset = 0

    init {
        addView(
            scrollProxy,
            LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    override fun onViewAdded(child: View) {
        super.onViewAdded(child)
        if (child !== scrollProxy) {
            // OEM longshot implementations only consider an unobscured native
            // scroll target. Keep the transparent proxy above Flutter's
            // SurfaceView while allowing every touch to fall through.
            bringChildToFront(scrollProxy)
        }
    }

    fun updateVerticalScrollMetrics(value: VerticalScrollMetrics?) {
        viewportTopInset = ceil(value?.viewportTopInset ?: 0.0).toInt()
        viewportBottomInset = ceil(value?.viewportBottomInset ?: 0.0).toInt()
        updateProxyInsets()
        scrollProxy.updateMetrics(value)
    }

    fun setOnProxyScrollRequested(
        listener: ((Double, (Boolean) -> Unit) -> Unit)?,
    ) {
        scrollProxy.onScrollRequested = listener
    }

    fun setOnProxySessionEnded(listener: (() -> Unit)?) {
        scrollProxy.onSessionEnded = listener
    }

    fun resetProxySession() {
        scrollProxy.resetLongshotSession()
    }

    override fun onWindowFocusChanged(hasWindowFocus: Boolean) {
        super.onWindowFocusChanged(hasWindowFocus)
        if (hasWindowFocus) {
            scrollProxy.finishLongshotSession()
        }
    }

    override fun onApplyWindowInsets(insets: WindowInsets): WindowInsets {
        statusBarInset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            insets.getInsets(WindowInsets.Type.statusBars()).top
        } else {
            @Suppress("DEPRECATION")
            insets.systemWindowInsetTop
        }
        updateProxyInsets()
        return super.onApplyWindowInsets(insets)
    }

    private fun updateProxyInsets() {
        val layoutParams = scrollProxy.layoutParams as LayoutParams
        val effectiveTopInset = max(statusBarInset, viewportTopInset)
        if (layoutParams.topMargin == effectiveTopInset &&
            layoutParams.bottomMargin == viewportBottomInset
        ) {
            return
        }
        layoutParams.topMargin = effectiveTopInset
        layoutParams.bottomMargin = viewportBottomInset
        scrollProxy.layoutParams = layoutParams
        scrollProxy.updateViewportInsets(effectiveTopInset, viewportBottomInset)
    }

    data class VerticalScrollMetrics(
        val minimumOffset: Double,
        val maximumOffset: Double,
        val offset: Double,
        val viewportDimension: Double,
        val viewportTopInset: Double,
        val viewportBottomInset: Double,
    )
}

/**
 * Native scroll target for OEM screenshot tools that ignore Android's public
 * window callback. It lives behind Flutter and delegates every programmatic
 * scroll to Dart; it never paints or handles normal app gestures.
 */
private class ScrollCaptureProxyView(context: Context) : ScrollView(context) {
    private val extentView = View(context)
    private var metrics: ScrollCaptureRootLayout.VerticalScrollMetrics? = null
    private var isSynchronizing = false
    private var viewportTopInset = 0
    private var viewportBottomInset = 0
    private var acceptsLongshotGestures = false
    private var requestedScrollY = 0
    private var scrollRequestInFlight = false
    private var queuedScrollY: Int? = null
    private var sessionGeneration = 0
    private val stopAcceptingLongshotGestures = Runnable {
        finishLongshotSession()
    }

    var onScrollRequested: ((Double, (Boolean) -> Unit) -> Unit)? = null
    var onSessionEnded: (() -> Unit)? = null

    init {
        isFillViewport = true
        isVerticalScrollBarEnabled = false
        overScrollMode = View.OVER_SCROLL_NEVER
        isClickable = false
        isFocusable = false
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The window callback is the single authoritative Android 12+
            // target. Keep this proxy available only to legacy OEM longshot
            // discovery so the system cannot alternate between two targets.
            scrollCaptureHint = View.SCROLL_CAPTURE_HINT_EXCLUDE
        }
        addView(
            extentView,
            LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    override fun onInterceptTouchEvent(event: MotionEvent): Boolean {
        return acceptsLongshotGestures && super.onInterceptTouchEvent(event)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        return acceptsLongshotGestures && super.onTouchEvent(event)
    }

    fun updateMetrics(value: ScrollCaptureRootLayout.VerticalScrollMetrics?) {
        metrics = value
        updateExtent()

        // OPlus tests the target with a one-pixel scroll before beginning its
        // longshot gesture sequence. A Flutter rebuild can publish the old
        // offset during that probe; snapping the proxy back here makes OPlus
        // conclude that the page is already at its end.
        if (acceptsLongshotGestures) return

        val targetOffset = value?.let {
            ceil(it.offset - it.minimumOffset)
                .coerceIn(0.0, Int.MAX_VALUE.toDouble())
                .toInt()
        } ?: 0
        if (scrollY == targetOffset) return
        isSynchronizing = true
        scrollTo(0, targetOffset)
        isSynchronizing = false
        requestedScrollY = targetOffset
    }

    fun updateViewportInsets(top: Int, bottom: Int) {
        if (viewportTopInset == top && viewportBottomInset == bottom) return
        viewportTopInset = top
        viewportBottomInset = bottom
        updateExtent()
    }

    fun finishLongshotSession() {
        val hadActiveSession = acceptsLongshotGestures ||
            scrollRequestInFlight ||
            queuedScrollY != null
        if (!hadActiveSession) return

        resetLongshotSession()
        onSessionEnded?.invoke()
    }

    fun resetLongshotSession() {
        removeCallbacks(stopAcceptingLongshotGestures)
        acceptsLongshotGestures = false
        sessionGeneration += 1
        scrollRequestInFlight = false
        queuedScrollY = null
        requestedScrollY = scrollY
    }

    private fun updateExtent() {
        val value = metrics
        val contentHeight = value?.let {
            val nativeViewport = if (height > 0) {
                height.toDouble()
            } else {
                (it.viewportDimension - viewportTopInset - viewportBottomInset)
                    .coerceAtLeast(1.0)
            }
            ceil(it.maximumOffset - it.minimumOffset + nativeViewport)
                .coerceIn(1.0, Int.MAX_VALUE.toDouble())
                .toInt()
        } ?: 1
        val layoutParams = extentView.layoutParams
        if (layoutParams.height != contentHeight) {
            layoutParams.height = contentHeight
            extentView.layoutParams = layoutParams
            extentView.minimumHeight = contentHeight
            requestLayout()
        }
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        super.onSizeChanged(width, height, oldWidth, oldHeight)
        if (height != oldHeight) updateExtent()
    }

    override fun onScrollChanged(left: Int, top: Int, oldLeft: Int, oldTop: Int) {
        super.onScrollChanged(left, top, oldLeft, oldTop)
        if (isSynchronizing || top == oldTop) return
        // OPlus probes a native target with a one-pixel programmatic scroll
        // immediately before sending the gestures used for longshot capture.
        // Flutter-driven metric synchronization is excluded above, so normal
        // app touches continue to fall through to Flutter.
        val isInitialProbe =
            !acceptsLongshotGestures && abs(top - oldTop) <= INITIAL_PROBE_DISTANCE_PX
        acceptsLongshotGestures = true
        removeCallbacks(stopAcceptingLongshotGestures)
        postDelayed(stopAcceptingLongshotGestures, LONGSHOT_GESTURE_TIMEOUT_MS)
        if (isInitialProbe) {
            requestedScrollY = top
            dispatchScrollRequest(top)
            return
        }

        val target = (requestedScrollY + top - oldTop).coerceIn(
            0,
            maximumScrollY(),
        )
        requestedScrollY = target
        queuedScrollY = target
        isSynchronizing = true
        scrollTo(0, oldTop)
        isSynchronizing = false
        dispatchQueuedScrollRequest()
    }

    private fun dispatchQueuedScrollRequest() {
        if (scrollRequestInFlight) return
        val target = queuedScrollY ?: return
        queuedScrollY = null
        dispatchScrollRequest(target)
    }

    private fun dispatchScrollRequest(target: Int) {
        val current = metrics ?: return
        val listener = onScrollRequested ?: return
        val requestGeneration = sessionGeneration
        scrollRequestInFlight = true
        listener(current.minimumOffset + target) { didPaint ->
            post {
                if (requestGeneration != sessionGeneration) return@post
                if (didPaint) {
                    postOnAnimationDelayed(
                        {
                            completeScrollRequest(
                                target = target,
                                requestGeneration = requestGeneration,
                                didPaint = true,
                            )
                        },
                        POST_SCROLL_CAPTURE_DELAY_MS,
                    )
                } else {
                    completeScrollRequest(
                        target = target,
                        requestGeneration = requestGeneration,
                        didPaint = false,
                    )
                }
            }
        }
    }

    private fun completeScrollRequest(
        target: Int,
        requestGeneration: Int,
        didPaint: Boolean,
    ) {
        if (requestGeneration != sessionGeneration) return
        if (didPaint) {
            isSynchronizing = true
            scrollTo(0, target.coerceIn(0, maximumScrollY()))
            isSynchronizing = false
        } else {
            requestedScrollY = scrollY
            queuedScrollY = null
        }
        scrollRequestInFlight = false
        dispatchQueuedScrollRequest()
    }

    private fun maximumScrollY(): Int {
        return (extentView.height - height).coerceAtLeast(0)
    }

    private companion object {
        const val INITIAL_PROBE_DISTANCE_PX = 1
        const val LONGSHOT_GESTURE_TIMEOUT_MS = 2_000L
        const val POST_SCROLL_CAPTURE_DELAY_MS = 60L
    }
}
