import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A vibrator primitive (Android's `VibrationEffect.Composition` ids).
enum HapticPrimitive {
  /// A crisp, bright click.
  click(1),

  /// A deep, heavy knock: something landing.
  thud(2),

  /// A short whirl.
  spin(3),

  /// A fast swell.
  quickRise(4),

  /// A gentle swell: something lifting into place.
  slowRise(5),

  /// A fast fade: something leaving.
  quickFall(6),

  /// A light, sharp tick.
  tick(7),

  /// A soft, low tick: a notch felt more than heard.
  lowTick(8);

  const HapticPrimitive(this.id);
  final int id;
}

/// What a phone plays when it can't compose a pattern's primitives.
enum HapticFallback {
  tick(HapticFeedback.selectionClick),
  click(HapticFeedback.lightImpact),
  double(HapticFeedback.mediumImpact),
  heavy(HapticFeedback.heavyImpact);

  const HapticFallback(this.framework);
  final Future<void> Function() framework;
}

class HapticStep {
  const HapticStep(this.primitive, this.scale, [this.delayMs = 0]);
  final HapticPrimitive primitive;

  /// 0..1 strength of this primitive.
  final double scale;

  /// Pause before this primitive starts, after the previous one.
  final int delayMs;
}

/// A named haptic: primitives played as one composition, plus the effect a
/// phone without them falls back to.
class HapticPattern {
  const HapticPattern(this.name, this.steps, {required this.fallback});
  final String name;
  final List<HapticStep> steps;
  final HapticFallback fallback;
}

/// Glimpse's haptic vocabulary. Name the moment, not the motor: callers pick
/// a pattern and the Android side (`HapticsBridge.kt`) plays it as richly as
/// the phone allows — composed primitives, then predefined effects, then view
/// haptics. Elsewhere, or when the bridge is missing, it falls back to
/// Flutter's [HapticFeedback]. It honours the system touch-feedback switch
/// and never throws.
abstract final class AppHaptics {
  static const _channel = MethodChannel('com.shinrinyoku.glimpse/haptics');

  static bool get _bridge =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The lightest detent: a selection, a rung in a list.
  static const tick = HapticPattern('tick', [
    HapticStep(HapticPrimitive.tick, .5),
  ], fallback: HapticFallback.tick);

  /// A notch you feel more than hear: a page settling into place.
  static const detent = HapticPattern('detent', [
    HapticStep(HapticPrimitive.lowTick, .8),
  ], fallback: HapticFallback.tick);

  /// A fingertip landing on something, before anything has happened.
  static const press = HapticPattern('press', [
    HapticStep(HapticPrimitive.tick, .75),
  ], fallback: HapticFallback.tick);

  /// A firm, clean click for an action that happened.
  static const tap = HapticPattern('tap', [
    HapticStep(HapticPrimitive.click, .7),
  ], fallback: HapticFallback.click);

  /// A long press: something picked up, ready to move or choose.
  static const hold = HapticPattern('hold', [
    HapticStep(HapticPrimitive.quickRise, .45),
    HapticStep(HapticPrimitive.click, .75, 10),
  ], fallback: HapticFallback.heavy);

  /// Something physical settling: a cover, a card, a pin.
  static const land = HapticPattern('land', [
    HapticStep(HapticPrimitive.thud, .5),
  ], fallback: HapticFallback.click);

  /// A surface lifting in: a sheet rising, a panel opening.
  static const swell = HapticPattern('swell', [
    HapticStep(HapticPrimitive.slowRise, .35),
  ], fallback: HapticFallback.tick);

  /// A surface falling away: a sheet dismissed.
  static const drop = HapticPattern('drop', [
    HapticStep(HapticPrimitive.quickFall, .45),
  ], fallback: HapticFallback.tick);

  /// One key of typing: barely there.
  static const key = HapticPattern('key', [
    HapticStep(HapticPrimitive.lowTick, .35),
  ], fallback: HapticFallback.tick);

  /// Work in progress: three soft pulses, fading.
  static const pulse = HapticPattern('pulse', [
    HapticStep(HapticPrimitive.lowTick, .55),
    HapticStep(HapticPrimitive.lowTick, .4, 120),
    HapticStep(HapticPrimitive.lowTick, .25, 120),
  ], fallback: HapticFallback.tick);

  /// Something landed safely: a swell into a bright click, then a sparkle.
  static const success = HapticPattern('success', [
    HapticStep(HapticPrimitive.quickRise, .3),
    HapticStep(HapticPrimitive.click, .85, 20),
    HapticStep(HapticPrimitive.tick, .35, 80),
  ], fallback: HapticFallback.double);

  /// A small celebration: a whirl, then two bright sparks.
  static const delight = HapticPattern('delight', [
    HapticStep(HapticPrimitive.spin, .5),
    HapticStep(HapticPrimitive.tick, .5, 60),
    HapticStep(HapticPrimitive.tick, .35, 60),
  ], fallback: HapticFallback.double);

  /// Committing to a big step: a big button pressed all the way down.
  static const confirm = HapticPattern('confirm', [
    HapticStep(HapticPrimitive.slowRise, .5),
    HapticStep(HapticPrimitive.click, 1),
    HapticStep(HapticPrimitive.thud, .35, 40),
  ], fallback: HapticFallback.heavy);

  /// Every pattern, for the developer haptics lab.
  static const all = [
    tick,
    detent,
    press,
    tap,
    hold,
    land,
    swell,
    drop,
    key,
    pulse,
    success,
    delight,
    confirm,
  ];

  /// Plays [pattern], with every primitive scaled by [intensity] (0..1).
  static Future<void> play(
    HapticPattern pattern, {
    double intensity = 1,
  }) async {
    final scale = intensity.clamp(0.0, 1.0);
    if (_bridge) {
      try {
        await _channel.invokeMethod<void>('compose', {
          'name': pattern.name,
          'steps': [
            for (final step in pattern.steps)
              [
                step.primitive.id,
                (step.scale * scale).clamp(0.0, 1.0),
                step.delayMs,
              ],
          ],
          'fallback': pattern.fallback.name,
        });
        return;
      } on MissingPluginException {
        // No bridge in this engine (tests, add-to-app): framework haptic.
      } on PlatformException {
        // Fall through to the framework haptic.
      }
    }
    try {
      await pattern.fallback.framework();
    } catch (_) {
      // Haptics are decoration; never let them fail an interaction.
    }
  }
}
