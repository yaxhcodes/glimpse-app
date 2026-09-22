package com.shinrinyoku.glimpse

import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.RenderMode

/** A transient share destination that leaves the sending app visible. */
class ShareActivity : MainActivity() {
    override fun getInitialRoute(): String = "/share"
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent
    override fun getRenderMode(): RenderMode = RenderMode.texture
}
