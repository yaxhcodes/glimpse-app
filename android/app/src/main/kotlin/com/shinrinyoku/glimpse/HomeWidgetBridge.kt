package com.shinrinyoku.glimpse

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the `com.shinrinyoku.glimpse/home_widget` MethodChannel (see
 * `HomeWidgetSync` on the Dart side).
 *
 *   - `isInUse()`                → whether a Rediscover widget is placed, so
 *                                  Dart skips the ranking and picture work
 *                                  when nobody would see it.
 *   - `updateRediscover(json)`   → stores the ranked saves and re-renders.
 */
class HomeWidgetBridge(context: Context, messenger: BinaryMessenger) {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isInUse" -> result.success(RediscoverWidgetProvider.isInUse(appContext))
                "updateRediscover" -> {
                    val json = call.arguments as? String
                    if (json == null) {
                        result.error("bad_args", "missing saves", null)
                    } else {
                        HomeWidgetStore.writeSaves(appContext, json)
                        RediscoverWidgetProvider.refreshAll(appContext)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val CHANNEL = "com.shinrinyoku.glimpse/home_widget"
    }
}
