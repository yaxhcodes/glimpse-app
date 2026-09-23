package com.shinrinyoku.glimpse

import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.FlutterEngine
import android.os.Handler
import android.os.Looper

/** A transient share destination that leaves the sending app visible. */
class ShareActivity : MainActivity() {
    private val pendingEnrichment = mutableSetOf<String>()
    private val cleanupHandler = Handler(Looper.getMainLooper())
    private var captureEngine: FlutterEngine? = null
    private var detached = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureEngine = flutterEngine
    }

    override fun createFlutterFragment(): FlutterFragment =
        FlutterFragment.NewEngineFragmentBuilder(ShareCaptureFragment::class.java)
            .initialRoute("/share")
            .dartEntrypoint(getDartEntrypointFunctionName())
            .appBundlePath(getAppBundlePath())
            .flutterShellArgs(FlutterShellArgs.fromIntent(intent))
            .renderMode(RenderMode.texture)
            .transparencyMode(TransparencyMode.transparent)
            .shouldAutomaticallyHandleOnBackPressed(true)
            .build()

    fun trackEnrichmentStart(processingId: String) {
        pendingEnrichment.add(processingId)
    }

    fun trackEnrichmentFinish(processingId: String) {
        pendingEnrichment.remove(processingId)
        if (detached && pendingEnrichment.isEmpty()) {
            cleanupHandler.removeCallbacksAndMessages(null)
            cleanupHandler.post { releaseCaptureEngine() }
        }
    }

    override fun onDestroy() {
        val retain = pendingEnrichment.isNotEmpty()
        detached = true
        super.onDestroy()
        if (retain) {
            cleanupHandler.postDelayed({ releaseCaptureEngine() }, 10 * 60 * 1000L)
        } else {
            cleanupHandler.post { releaseCaptureEngine() }
        }
    }

    private fun releaseCaptureEngine() {
        cleanupHandler.removeCallbacksAndMessages(null)
        captureEngine?.destroy()
        captureEngine = null
        pendingEnrichment.clear()
    }

    override fun getInitialRoute(): String = "/share"
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent
    override fun getRenderMode(): RenderMode = RenderMode.texture
}

/** Engine ownership stays with ShareActivity until its capture work settles. */
class ShareCaptureFragment : FlutterFragment() {
    override fun shouldDestroyEngineWithHost(): Boolean = false
}
