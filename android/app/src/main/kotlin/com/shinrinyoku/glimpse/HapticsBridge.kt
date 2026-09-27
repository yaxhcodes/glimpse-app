package com.shinrinyoku.glimpse

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.HapticFeedbackConstants
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Glimpse's haptic vocabulary, played as richly as the device allows.
 *
 * Bridges `com.shinrinyoku.glimpse/haptics` (see `AppHaptics` on the Dart
 * side, where the patterns are designed). Each pattern arrives as a list of
 * vibrator primitives and is played as one composition (Android 11+, when the
 * motor supports every primitive in it), else as its predefined fallback
 * (Android 10+), else as a view haptic constant — so every phone gets the
 * best version it can play and nothing ever throws.
 *
 * Effects follow the system "touch feedback" switch: when the user has turned
 * touch vibration off, nothing plays.
 */
class HapticsBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val vibrator: Vibrator? = defaultVibrator(activity)
    private val primitiveSupport = mutableMapOf<Int, Boolean>()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "compose" -> {
                    val steps = (call.argument<List<List<Number>>>("steps") ?: emptyList())
                        .mapNotNull { step ->
                            if (step.size < 3) null
                            else Step(step[0].toInt(), step[1].toFloat().coerceIn(0f, 1f), step[2].toInt())
                        }
                    val fallback = call.argument<String>("fallback").orEmpty()
                    try {
                        play(steps, fallback)
                    } catch (t: Throwable) {
                        android.util.Log.w("Glimpse", "haptic ${call.argument<String>("name")} failed: $t")
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** One primitive of a pattern: its id, scale 0..1, and delay before it. */
    private data class Step(val primitive: Int, val scale: Float, val delayMs: Int)

    private fun play(steps: List<Step>, fallback: String) {
        if (!touchFeedbackEnabled()) return
        val v = vibrator
        if (v != null && v.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && steps.isNotEmpty()) {
                composition(v, steps)?.let {
                    vibrate(v, it)
                    return
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                predefined(fallback)?.let {
                    vibrate(v, VibrationEffect.createPredefined(it))
                    return
                }
            }
        }
        viewFallback(fallback)
    }

    /** The pattern as one composition, or null when the motor lacks a primitive. */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun composition(v: Vibrator, steps: List<Step>): VibrationEffect? {
        if (steps.any { !supportsPrimitive(v, it.primitive) }) return null
        val composition = VibrationEffect.startComposition()
        for (step in steps) {
            composition.addPrimitive(step.primitive, step.scale, step.delayMs.coerceAtLeast(0))
        }
        return composition.compose()
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun supportsPrimitive(v: Vibrator, primitive: Int): Boolean {
        return primitiveSupport.getOrPut(primitive) {
            v.areAllPrimitivesSupported(primitive)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun predefined(fallback: String): Int? {
        return when (fallback) {
            "tick" -> VibrationEffect.EFFECT_TICK
            "click" -> VibrationEffect.EFFECT_CLICK
            "double" -> VibrationEffect.EFFECT_DOUBLE_CLICK
            "heavy" -> VibrationEffect.EFFECT_HEAVY_CLICK
            else -> null
        }
    }

    private fun viewFallback(fallback: String) {
        val constant = when (fallback) {
            "tick" -> HapticFeedbackConstants.CLOCK_TICK
            "click" -> HapticFeedbackConstants.VIRTUAL_KEY
            "double", "heavy" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    HapticFeedbackConstants.CONFIRM
                } else {
                    HapticFeedbackConstants.LONG_PRESS
                }
            else -> return
        }
        activity.window?.decorView?.performHapticFeedback(constant)
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun vibrate(v: Vibrator, effect: VibrationEffect) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Touch usage: scales with the system's touch vibration intensity.
            v.vibrate(
                effect,
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH),
            )
        } else {
            v.vibrate(
                effect,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        }
    }

    private fun touchFeedbackEnabled(): Boolean = try {
        Settings.System.getInt(
            activity.contentResolver,
            Settings.System.HAPTIC_FEEDBACK_ENABLED,
            1,
        ) != 0
    } catch (_: Throwable) {
        true
    }

    private companion object {
        const val CHANNEL = "com.shinrinyoku.glimpse/haptics"

        fun defaultVibrator(context: Context): Vibrator? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                    ?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
    }
}
