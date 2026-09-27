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
 * side, where the patterns are designed). Each pattern arrives twice: as a
 * sequence of view haptic constants (the default "system" engine — every
 * manufacturer tunes these to its own motor, so they feel right everywhere)
 * and as vibrator primitives (the "composed" engine, which some phones report
 * as supported but play too faintly to feel). Nothing ever throws.
 *
 * Both follow the system "touch feedback" switch.
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
                    val system = (call.argument<List<List<Any>>>("system") ?: emptyList())
                        .mapNotNull { step ->
                            val name = step.getOrNull(0) as? String ?: return@mapNotNull null
                            name to ((step.getOrNull(1) as? Number)?.toInt() ?: 0)
                        }
                    val composed = call.argument<String>("engine") == "composed"
                    try {
                        if (composed && playComposed(steps)) {
                            // Played as primitives.
                        } else {
                            playSystem(system)
                        }
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

    /**
     * The pattern as the phone's own tuned haptics: each step is a view
     * haptic constant, which the manufacturer maps to its best waveform and
     * which already follows the system touch-feedback switch.
     */
    private fun playSystem(steps: List<Pair<String, Int>>) {
        val view = activity.window?.decorView ?: return
        var at = 0L
        for ((name, delay) in steps) {
            at += delay.coerceAtLeast(0)
            val constant = systemConstant(name) ?: continue
            if (at == 0L) {
                view.performHapticFeedback(constant)
            } else {
                view.postDelayed({ view.performHapticFeedback(constant) }, at)
            }
        }
    }

    /** Plays [steps] as vibrator primitives; false when this phone can't. */
    private fun playComposed(steps: List<Step>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || steps.isEmpty()) return false
        if (!touchFeedbackEnabled()) return true
        val v = vibrator ?: return false
        if (!v.hasVibrator()) return false
        val effect = composition(v, steps) ?: return false
        vibrate(v, effect)
        return true
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

    private fun systemConstant(name: String): Int? {
        val sdk = Build.VERSION.SDK_INT
        return when (name) {
            "clockTick" -> HapticFeedbackConstants.CLOCK_TICK
            "virtualKey" -> HapticFeedbackConstants.VIRTUAL_KEY
            "keyboardTap" -> HapticFeedbackConstants.KEYBOARD_TAP
            "longPress" -> HapticFeedbackConstants.LONG_PRESS
            "contextClick" -> HapticFeedbackConstants.CONTEXT_CLICK
            "keyboardPress" ->
                if (sdk >= Build.VERSION_CODES.O_MR1) HapticFeedbackConstants.KEYBOARD_PRESS
                else HapticFeedbackConstants.VIRTUAL_KEY
            "textHandleMove" ->
                if (sdk >= Build.VERSION_CODES.O_MR1) HapticFeedbackConstants.TEXT_HANDLE_MOVE
                else HapticFeedbackConstants.CLOCK_TICK
            "gestureStart" ->
                if (sdk >= Build.VERSION_CODES.R) HapticFeedbackConstants.GESTURE_START
                else HapticFeedbackConstants.CLOCK_TICK
            "gestureEnd" ->
                if (sdk >= Build.VERSION_CODES.R) HapticFeedbackConstants.GESTURE_END
                else HapticFeedbackConstants.CLOCK_TICK
            "confirm" ->
                if (sdk >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM
                else HapticFeedbackConstants.VIRTUAL_KEY
            "reject" ->
                if (sdk >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT
                else HapticFeedbackConstants.LONG_PRESS
            else -> null
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
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
