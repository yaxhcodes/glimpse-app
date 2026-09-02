package com.shinrinyoku.glimpse

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.TextureView
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.ScrollView
import io.flutter.embedding.android.FlutterImageView
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
    private val locationInWindow = IntArray(2)
    private var statusBarInset = 0
    private var viewportTopInset = 0
    private var viewportBottomInset = 0
    private var focusGeneration = 0
    private var onProxySessionPreparing: (((Boolean) -> Unit) -> Unit)? = null

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
        if (scrollProxy.isLongshotSessionActive) return
        updateProxyInsets()
        scrollProxy.updateMetrics(value)
    }

    fun currentScrollCaptureBounds(): Rect {
        return scrollProxy.currentScrollCaptureBounds() ?: Rect()
    }

    fun currentRootScrollCaptureBounds(): Rect {
        if (!isAttachedToWindow || width <= 0 || height <= 0) return Rect()
        val bounds = scrollProxy.currentScrollCaptureBoundsInWindow() ?: return Rect()
        getLocationInWindow(locationInWindow)
        bounds.offset(-locationInWindow[0], -locationInWindow[1])
        return if (bounds.intersect(0, 0, width, height)) bounds else Rect()
    }

    fun preferredScrollCaptureTarget(): View = scrollProxy

    private fun preferredRenderSource(): View? {
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            if (child === scrollProxy) continue
            findFlutterRenderView(child)?.let { return it }
        }
        return null
    }

    private fun updateImageMirror() {
        val source = preferredRenderSource()
        val bounds = scrollProxy.currentScrollCaptureBoundsInWindow()
        if (source == null || bounds == null) {
            scrollProxy.updateImageMirror(null, null)
            return
        }
        source.getLocationInWindow(locationInWindow)
        bounds.offset(-locationInWindow[0], -locationInWindow[1])
        if (!bounds.intersect(0, 0, source.width, source.height)) {
            scrollProxy.updateImageMirror(null, null)
            return
        }
        scrollProxy.updateImageMirror(source, bounds)
    }

    fun setOnProxyScrollRequested(
        listener: ((Double, (Boolean) -> Unit) -> Unit)?,
    ) {
        scrollProxy.onScrollRequested = listener
    }

    fun setOnProxySessionPreparing(
        listener: (((Boolean) -> Unit) -> Unit)?,
    ) {
        onProxySessionPreparing = listener
    }

    fun setOnProxySessionEnded(listener: (() -> Unit)?) {
        scrollProxy.onSessionEnded = listener
    }

    fun resetProxySession() {
        scrollProxy.resetLongshotSession()
    }

    override fun onWindowFocusChanged(hasWindowFocus: Boolean) {
        super.onWindowFocusChanged(hasWindowFocus)
        val generation = ++focusGeneration
        if (hasWindowFocus) {
            scrollProxy.finishLongshotSession()
            updateProxyInsets()
            return
        }

        // Navigation can leave the proxy holding the previous route's cached
        // range. Refresh it after the screenshot overlay takes focus but before
        // OPlus probes the native ScrollView.
        val prepare = onProxySessionPreparing
        if (prepare == null) {
            beginPreparedLongshotSession(generation)
            return
        }
        prepare { didPrepare ->
            post {
                if (!didPrepare) return@post
                beginPreparedLongshotSession(generation)
            }
        }
    }

    private fun beginPreparedLongshotSession(generation: Int) {
        if (generation != focusGeneration || hasWindowFocus()) return
        scrollProxy.beginPotentialLongshotSession()
        updateImageMirror()
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
        if (scrollProxy.isLongshotSessionActive) return
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

    private fun findFlutterRenderView(view: View): View? {
        if (view is FlutterImageView || view is TextureView) return view
        if (view !is ViewGroup) return null
        for (index in 0 until view.childCount) {
            findFlutterRenderView(view.getChildAt(index))?.let { return it }
        }
        return null
    }

    private companion object {
        const val TAG = "GlimpseScrollCapture"
    }

    data class VerticalScrollMetrics(
        val minimumOffset: Double,
        val maximumOffset: Double,
        val offset: Double,
        val viewportDimension: Double,
        val viewportTopInset: Double,
        val viewportBottomInset: Double,
        val scrollBounds: Rect,
    )
}

/**
 * Native scroll target for OEM screenshot tools that ignore Android's public
 * window callback. It delegates programmatic scrolling to Dart and mirrors the
 * resulting Flutter surface only while the OEM capture session is active.
 */
private class ScrollCaptureProxyView(context: Context) : ScrollView(context) {
    private val extentView = ScrollCaptureImageMirrorView(context)
    private val locationInWindow = IntArray(2)
    private var metrics: ScrollCaptureRootLayout.VerticalScrollMetrics? = null
    private var isSynchronizing = false
    private var viewportTopInset = 0
    private var viewportBottomInset = 0
    private var acceptsLongshotGestures = false
    private var scrollRequestInFlight = false
    private var queuedScrollY: Int? = null
    private var scrollDispatchScheduled = false
    private var sessionGeneration = 0
    private val dispatchQueuedOnAnimation = Runnable {
        scrollDispatchScheduled = false
        dispatchQueuedScrollRequest()
    }
    private val stopAcceptingLongshotGestures = Runnable {
        finishLongshotSession()
    }

    var onScrollRequested: ((Double, (Boolean) -> Unit) -> Unit)? = null
    var onSessionEnded: (() -> Unit)? = null
    val isLongshotSessionActive: Boolean
        get() = acceptsLongshotGestures

    init {
        isFillViewport = true
        isVerticalScrollBarEnabled = false
        overScrollMode = View.OVER_SCROLL_NEVER
        isClickable = false
        isFocusable = false
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
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
        // Native ScrollView geometry must remain stable while OPlus is
        // stitching. Capture-only Flutter rebuilds can otherwise resize a
        // short route all the way to its end during the first gesture.
        if (acceptsLongshotGestures) return
        metrics = value
        updateExtent()

        // OPlus tests the target with a one-pixel scroll before beginning its
        // longshot gesture sequence. A Flutter rebuild can publish the old
        // offset during that probe; snapping the proxy back here makes OPlus
        // conclude that the page is already at its end.
        val targetOffset = value?.let {
            ceil(it.offset - it.minimumOffset)
                .coerceIn(0.0, Int.MAX_VALUE.toDouble())
                .toInt()
        } ?: 0
        if (scrollY == targetOffset) return
        isSynchronizing = true
        scrollTo(0, targetOffset)
        isSynchronizing = false
    }

    fun currentScrollCaptureBounds(): Rect? {
        val bounds = currentScrollCaptureBoundsInWindow() ?: return null
        getLocationInWindow(locationInWindow)
        bounds.offset(-locationInWindow[0], -locationInWindow[1])
        return if (bounds.intersect(0, 0, width, height)) bounds else null
    }

    fun currentScrollCaptureBoundsInWindow(): Rect? {
        val value = metrics ?: return null
        if (!isAttachedToWindow ||
            width <= 0 ||
            height <= 0 ||
            value.maximumOffset <= value.minimumOffset
        ) {
            return null
        }
        getLocationInWindow(locationInWindow)
        val viewportBounds = Rect(
            locationInWindow[0],
            locationInWindow[1],
            locationInWindow[0] + width,
            locationInWindow[1] + height,
        )
        val bounds = Rect(value.scrollBounds)
        return if (bounds.intersect(viewportBounds)) bounds else null
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

    fun beginPotentialLongshotSession() {
        removeCallbacks(stopAcceptingLongshotGestures)
        acceptsLongshotGestures = true
    }

    fun resetLongshotSession() {
        removeCallbacks(stopAcceptingLongshotGestures)
        removeCallbacks(dispatchQueuedOnAnimation)
        acceptsLongshotGestures = false
        scrollDispatchScheduled = false
        sessionGeneration += 1
        scrollRequestInFlight = false
        queuedScrollY = null
        extentView.updateMirror(null, null, 0)
    }

    fun updateImageMirror(source: View?, sourceBounds: Rect?) {
        extentView.updateMirror(source, sourceBounds, scrollY)
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
            !scrollRequestInFlight &&
                queuedScrollY == null &&
                abs(top - oldTop) <= INITIAL_PROBE_DISTANCE_PX
        acceptsLongshotGestures = true
        removeCallbacks(stopAcceptingLongshotGestures)
        postDelayed(stopAcceptingLongshotGestures, LONGSHOT_GESTURE_TIMEOUT_MS)
        if (isInitialProbe) return
        // OPlus reads ScrollView.scrollY synchronously after requesting a
        // rectangle. Keep the native offset in place so it observes the real
        // delta; its configured capture delay gives Flutter time to paint the
        // matching frame before the screenshot is sampled.
        val target = top.coerceIn(0, maximumScrollY())
        queuedScrollY = target
        scheduleQueuedScrollRequest()
    }

    private fun scheduleQueuedScrollRequest() {
        if (scrollRequestInFlight || scrollDispatchScheduled || queuedScrollY == null) return
        scrollDispatchScheduled = true
        postOnAnimation(dispatchQueuedOnAnimation)
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
        listener(current.minimumOffset + target) { didAccept ->
            post {
                if (requestGeneration != sessionGeneration) return@post
                completeScrollRequest(
                    target = target,
                    requestGeneration = requestGeneration,
                    didAccept = didAccept,
                )
            }
        }
    }

    private fun completeScrollRequest(
        target: Int,
        requestGeneration: Int,
        didAccept: Boolean,
    ) {
        if (requestGeneration != sessionGeneration) return
        if (didAccept) {
            val newerTarget = queuedScrollY
            if (newerTarget != null && newerTarget != target) {
                queuedScrollY = null
                dispatchScrollRequest(newerTarget)
                return
            }
            if (newerTarget == target) {
                queuedScrollY = null
            }
            extentView.presentFlutterFrame(target) {
                post {
                    if (requestGeneration != sessionGeneration) return@post
                    scrollRequestInFlight = false
                    scheduleQueuedScrollRequest()
                }
            }
            return
        }
        queuedScrollY = null
        scrollRequestInFlight = false
        scheduleQueuedScrollRequest()
    }

    private fun maximumScrollY(): Int {
        return (extentView.height - height).coerceAtLeast(0)
    }

    private companion object {
        const val INITIAL_PROBE_DISTANCE_PX = 1
        const val LONGSHOT_GESTURE_TIMEOUT_MS = 2_000L
        const val TAG = "GlimpseScrollCapture"
    }
}

private class ScrollCaptureImageMirrorView(context: Context) : View(context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private var imageSource: View? = null
    private var imageSourceBounds: Rect? = null
    private var displayedBitmap: Bitmap? = null
    private var displayedSourceBounds: Rect? = null
    private var reusableBitmap: Bitmap? = null
    private var mirrorTop = 0
    private var captureGeneration = 0

    init {
        setWillNotDraw(false)
    }

    fun updateMirror(source: View?, sourceBounds: Rect?, top: Int) {
        captureGeneration += 1
        imageSource = source
        imageSourceBounds = sourceBounds?.let(::Rect)
        mirrorTop = top
        if (source == null || sourceBounds == null) {
            displayedBitmap?.recycle()
            displayedBitmap = null
            displayedSourceBounds = null
            reusableBitmap?.recycle()
            reusableBitmap = null
            invalidate()
            return
        }
        snapshotFlutterFrame(top, null)
    }

    fun presentFlutterFrame(target: Int, onComplete: (Boolean) -> Unit) {
        snapshotFlutterFrame(target, onComplete)
    }

    private fun snapshotFlutterFrame(
        target: Int,
        onComplete: ((Boolean) -> Unit)?,
    ) {
        val source = imageSource
        val bounds = imageSourceBounds
        if (source == null ||
            bounds == null ||
            bounds.isEmpty ||
            source.width <= 0 ||
            source.height <= 0
        ) {
            onComplete?.invoke(false)
            return
        }

        val generation = ++captureGeneration
        if (source is TextureView) {
            snapshotTextureView(source, bounds, target, generation, onComplete)
            return
        }
        if (source !is FlutterImageView || !source.surface.isValid) {
            onComplete?.invoke(false)
            return
        }

        val bitmap = obtainBitmap(source.width, source.height)
        try {
            PixelCopy.request(
                source.surface,
                Rect(0, 0, source.width, source.height),
                bitmap,
                { result ->
                    if (generation != captureGeneration || source !== imageSource) {
                        bitmap.recycle()
                        onComplete?.invoke(false)
                        return@request
                    }
                    if (result != PixelCopy.SUCCESS) {
                        Log.w(TAG, "Flutter surface snapshot failed: $result")
                        recycleForReuse(bitmap)
                        onComplete?.invoke(false)
                        return@request
                    }

                    presentBitmap(bitmap, bounds, target)
                    onComplete?.invoke(true)
                },
                mainHandler,
            )
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not snapshot Flutter surface", error)
            recycleForReuse(bitmap)
            onComplete?.invoke(false)
        }
    }

    private fun snapshotTextureView(
        source: TextureView,
        bounds: Rect,
        target: Int,
        generation: Int,
        onComplete: ((Boolean) -> Unit)?,
    ) {
        val bitmap = obtainBitmap(source.width, source.height)
        val captured = try {
            source.getBitmap(bitmap)
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not snapshot Flutter texture", error)
            null
        }
        if (generation != captureGeneration || source !== imageSource) {
            bitmap.recycle()
            onComplete?.invoke(false)
            return
        }
        if (captured == null) {
            recycleForReuse(bitmap)
            onComplete?.invoke(false)
            return
        }

        presentBitmap(captured, bounds, target)
        onComplete?.invoke(true)
    }

    private fun presentBitmap(bitmap: Bitmap, bounds: Rect, target: Int) {
        val previous = displayedBitmap
        displayedBitmap = bitmap
        displayedSourceBounds = Rect(bounds)
        mirrorTop = target
        recycleForReuse(previous)
        invalidate()
    }

    private fun obtainBitmap(width: Int, height: Int): Bitmap {
        val reusable = reusableBitmap
        if (reusable != null &&
            !reusable.isRecycled &&
            reusable.width == width &&
            reusable.height == height
        ) {
            reusableBitmap = null
            return reusable
        }
        reusable?.recycle()
        reusableBitmap = null
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    }

    private fun recycleForReuse(bitmap: Bitmap?) {
        if (bitmap == null || bitmap.isRecycled) return
        reusableBitmap?.recycle()
        reusableBitmap = bitmap
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val bitmap = displayedBitmap ?: return
        val bounds = displayedSourceBounds ?: return
        val checkpoint = canvas.save()
        canvas.clipRect(0, mirrorTop, bounds.width(), mirrorTop + bounds.height())
        canvas.translate(-bounds.left.toFloat(), mirrorTop.toFloat() - bounds.top)
        canvas.drawBitmap(bitmap, 0f, 0f, bitmapPaint)
        canvas.restoreToCount(checkpoint)
    }

    private companion object {
        const val TAG = "GlimpseScrollCapture"
    }
}
