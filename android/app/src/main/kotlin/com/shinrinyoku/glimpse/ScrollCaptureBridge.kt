package com.shinrinyoku.glimpse

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.Rect
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.view.ScrollCaptureCallback
import android.view.ScrollCaptureSession
import android.view.Surface
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.function.Consumer

/**
 * Android 12+ scrolling-screenshot support for Flutter content.
 *
 * Flutter renders its widget tree into a single Android view, so Android cannot
 * discover Dart [Scrollable] widgets on its own. The Dart coordinator reports
 * the active viewport and performs requested scrolls; this callback copies the
 * resulting composed window pixels into Android's scroll-capture surface.
 */
class ScrollCaptureBridge(
    private val activity: FlutterFragmentActivity,
    messenger: BinaryMessenger,
    rootLayout: ScrollCaptureRootLayout?,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var rootLayout: ScrollCaptureRootLayout? = null
    private var isRegistered = false

    init {
        attachRootLayout(rootLayout)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateViewMetrics" -> {
                    rootLayout?.updateVerticalScrollMetrics(
                        call.arguments.asVerticalScrollMetrics(),
                    )
                    result.success(null)
                }
                "resetProxy" -> {
                    rootLayout?.resetProxySession()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun attachRootLayout(layout: ScrollCaptureRootLayout?) {
        if (rootLayout === layout) return
        rootLayout?.setOnProxyScrollRequested(null)
        rootLayout?.setOnProxySessionEnded(null)
        rootLayout = layout
        layout?.setOnProxyScrollRequested { offset, onComplete ->
            channel.invokeMethod("proxyScrollTo", offset, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    onComplete(result == true)
                }

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "Proxy scroll failed: $code $message")
                    onComplete(false)
                }

                override fun notImplemented() = onComplete(false)
            })
        }
        layout?.setOnProxySessionEnded {
            channel.invokeMethod("proxyScrollEnd", null, object : MethodChannel.Result {
                override fun success(result: Any?) = Unit

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "Proxy cleanup failed: $code $message")
                }

                override fun notImplemented() = Unit
            })
        }
    }

    private val callback = object : ScrollCaptureCallback {
        override fun onScrollCaptureSearch(
            signal: CancellationSignal,
            onReady: Consumer<Rect>,
        ) {
            if (signal.isCanceled) return
            channel.invokeMethod("getMetrics", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (signal.isCanceled) return
                    val scrollBounds = result.asRect() ?: Rect()
                    activity.window.decorView.let { decorView ->
                        scrollBounds.intersect(0, 0, decorView.width, decorView.height)
                    }
                    onReady.accept(scrollBounds)
                }

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "Scroll capture search failed: $code $message")
                    if (!signal.isCanceled) onReady.accept(Rect())
                }

                override fun notImplemented() {
                    if (!signal.isCanceled) onReady.accept(Rect())
                }
            })
        }

        override fun onScrollCaptureStart(
            session: ScrollCaptureSession,
            signal: CancellationSignal,
            onReady: Runnable,
        ) {
            if (signal.isCanceled) return
            channel.invokeMethod("start", null, readyResult(signal, onReady))
        }

        override fun onScrollCaptureImageRequest(
            session: ScrollCaptureSession,
            signal: CancellationSignal,
            captureArea: Rect,
            onComplete: Consumer<Rect>,
        ) {
            if (signal.isCanceled) return
            val arguments = mapOf(
                "left" to captureArea.left,
                "top" to captureArea.top,
                "right" to captureArea.right,
                "bottom" to captureArea.bottom,
            )
            channel.invokeMethod("capture", arguments, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (signal.isCanceled) return
                    val map = result as? Map<*, *>
                    val availableArea = result.asRect()
                    val scrollDelta = (map?.get("scrollDelta") as? Number)?.toInt()
                    if (availableArea == null ||
                        scrollDelta == null ||
                        availableArea.isEmpty
                    ) {
                        onComplete.accept(Rect())
                        return
                    }
                    activity.window.decorView.postOnAnimationDelayed(
                        {
                            if (signal.isCanceled) return@postOnAnimationDelayed
                            copyVisibleRegion(
                                session = session,
                                availableArea = availableArea,
                                scrollDelta = scrollDelta,
                                signal = signal,
                                onComplete = onComplete,
                            )
                        },
                        POST_SCROLL_CAPTURE_DELAY_MS,
                    )
                }

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "Scroll capture request failed: $code $message")
                    if (!signal.isCanceled) onComplete.accept(Rect())
                }

                override fun notImplemented() {
                    if (!signal.isCanceled) onComplete.accept(Rect())
                }
            })
        }

        override fun onScrollCaptureEnd(onReady: Runnable) {
            channel.invokeMethod("end", null, object : MethodChannel.Result {
                override fun success(result: Any?) = onReady.run()

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "Scroll capture cleanup failed: $code $message")
                    onReady.run()
                }

                override fun notImplemented() = onReady.run()
            })
        }
    }

    fun registerWhenReady() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || isRegistered) return
        activity.window.decorView.post {
            if (isRegistered || !activity.window.decorView.isAttachedToWindow) {
                return@post
            }
            activity.window.registerScrollCaptureCallback(callback)
            isRegistered = true
        }
    }

    fun dispose() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && isRegistered) {
            try {
                activity.window.unregisterScrollCaptureCallback(callback)
            } catch (error: IllegalStateException) {
                Log.w(TAG, "Could not unregister scroll capture callback", error)
            }
        }
        channel.setMethodCallHandler(null)
        rootLayout?.updateVerticalScrollMetrics(null)
        attachRootLayout(null)
        isRegistered = false
    }

    private fun readyResult(
        signal: CancellationSignal,
        onReady: Runnable,
    ): MethodChannel.Result {
        return object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (!signal.isCanceled) onReady.run()
            }

            override fun error(code: String, message: String?, details: Any?) {
                Log.w(TAG, "Scroll capture start failed: $code $message")
                if (!signal.isCanceled) onReady.run()
            }

            override fun notImplemented() {
                if (!signal.isCanceled) onReady.run()
            }
        }
    }

    private fun copyVisibleRegion(
        session: ScrollCaptureSession,
        availableArea: Rect,
        scrollDelta: Int,
        signal: CancellationSignal,
        onComplete: Consumer<Rect>,
    ) {
        val position = session.positionInWindow
        val sourceArea = Rect(availableArea).apply {
            offset(0, -scrollDelta)
            offset(position.x, position.y)
        }
        if (sourceArea.isEmpty) {
            onComplete.accept(Rect())
            return
        }

        val bitmap = try {
            Bitmap.createBitmap(
                sourceArea.width(),
                sourceArea.height(),
                Bitmap.Config.ARGB_8888,
            )
        } catch (error: IllegalArgumentException) {
            Log.w(TAG, "Invalid scroll capture source $sourceArea", error)
            onComplete.accept(Rect())
            return
        }

        try {
            PixelCopy.request(
                activity.window,
                sourceArea,
                bitmap,
                { result ->
                    if (signal.isCanceled) {
                        bitmap.recycle()
                        return@request
                    }
                    if (result != PixelCopy.SUCCESS) {
                        Log.w(TAG, "PixelCopy failed during scroll capture: $result")
                        bitmap.recycle()
                        onComplete.accept(Rect())
                        return@request
                    }

                    val rendered = renderToSurface(session.surface, bitmap)
                    bitmap.recycle()
                    onComplete.accept(if (rendered) Rect(availableArea) else Rect())
                },
                mainHandler,
            )
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not start PixelCopy for $sourceArea", error)
            bitmap.recycle()
            onComplete.accept(Rect())
        }
    }

    private fun renderToSurface(surface: Surface, bitmap: Bitmap): Boolean {
        var canvas: android.graphics.Canvas? = null
        var rendered = false
        try {
            canvas = surface.lockHardwareCanvas()
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            canvas.drawBitmap(bitmap, 0f, 0f, Paint(Paint.FILTER_BITMAP_FLAG))
            rendered = true
        } catch (error: Throwable) {
            Log.w(TAG, "Could not render scroll capture buffer", error)
        } finally {
            if (canvas != null) {
                try {
                    surface.unlockCanvasAndPost(canvas)
                } catch (error: Throwable) {
                    rendered = false
                    Log.w(TAG, "Could not post scroll capture buffer", error)
                }
            }
        }
        return rendered
    }

    private fun Any?.asRect(): Rect? {
        val map = this as? Map<*, *> ?: return null
        val left = (map["left"] as? Number)?.toInt() ?: return null
        val top = (map["top"] as? Number)?.toInt() ?: return null
        val right = (map["right"] as? Number)?.toInt() ?: return null
        val bottom = (map["bottom"] as? Number)?.toInt() ?: return null
        return Rect(left, top, right, bottom)
    }

    private fun Any?.asVerticalScrollMetrics(): ScrollCaptureRootLayout.VerticalScrollMetrics? {
        val map = this as? Map<*, *> ?: return null
        val minimumOffset = (map["minimumOffset"] as? Number)?.toDouble() ?: return null
        val maximumOffset = (map["maximumOffset"] as? Number)?.toDouble() ?: return null
        val offset = (map["offset"] as? Number)?.toDouble() ?: return null
        val viewportDimension =
            (map["viewportDimension"] as? Number)?.toDouble() ?: return null
        val viewportTopInset =
            (map["viewportTopInset"] as? Number)?.toDouble() ?: 0.0
        val viewportBottomInset =
            (map["viewportBottomInset"] as? Number)?.toDouble() ?: 0.0
        if (maximumOffset <= minimumOffset || viewportDimension <= 0.0) return null
        return ScrollCaptureRootLayout.VerticalScrollMetrics(
            minimumOffset = minimumOffset,
            maximumOffset = maximumOffset,
            offset = offset.coerceIn(minimumOffset, maximumOffset),
            viewportDimension = viewportDimension,
            viewportTopInset = viewportTopInset.coerceAtLeast(0.0),
            viewportBottomInset = viewportBottomInset.coerceAtLeast(0.0),
        )
    }

    private companion object {
        const val CHANNEL_NAME = "com.shinrinyoku.glimpse/scroll_capture"
        const val TAG = "GlimpseScrollCapture"
        const val POST_SCROLL_CAPTURE_DELAY_MS = 60L
    }
}
