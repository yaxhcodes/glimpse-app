import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// A vibrator primitive (Android's `VibrationEffect.Composition` ids), used
/// by the [HapticEngine.composed] engine.
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

/// An Android view haptic constant, used by the [HapticEngine.system]
/// engine. Manufacturers tune each of these to their own motor.
enum SystemHaptic {
  clockTick,
  virtualKey,
  keyboardTap,
  keyboardPress,
  longPress,
  contextClick,
  textHandleMove,
  gestureStart,
  gestureEnd,
  confirm,
  reject,
}

/// How a pattern is played on Android.
enum HapticEngine {
  /// The phone's own tuned haptics (view haptic constants). The default:
  /// it feels right on every manufacturer's motor.
  system,

  /// Raw vibrator primitives. Richer on some phones (Pixel), but others
  /// report them as supported and play them too faintly to feel.
  composed,
}

/// What Flutter plays where there is no Android bridge (tests, other
/// platforms).
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

class SystemStep {
  const SystemStep(this.haptic, [this.delayMs = 0]);
  final SystemHaptic haptic;

  /// Pause before this haptic, after the previous one.
  final int delayMs;
}

/// A named haptic, written once for each engine: as tuned system haptics and
/// as vibrator primitives.
class HapticPattern {
  const HapticPattern(
    this.name, {
    required this.system,
    required this.steps,
    required this.fallback,
  });
  final String name;
  final List<SystemStep> system;
  final List<HapticStep> steps;
  final HapticFallback fallback;
}

/// Glimpse's haptic vocabulary. Name the moment, not the motor: callers pick
/// a pattern and the Android side (`HapticsBridge.kt`) plays it with the
/// current [engine]. Elsewhere, or when the bridge is missing, it falls back
/// to Flutter's [HapticFeedback]. It honours the system touch-feedback switch
/// (users who want no haptics turn them off there) and never throws.
abstract final class AppHaptics {
  static const _channel = MethodChannel('com.shinrinyoku.glimpse/haptics');

  static bool get _bridge =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Which Android engine plays patterns; switchable in the Haptics lab.
  static HapticEngine engine = HapticEngine.system;

  /// How much the person wants to feel, from Settings. Loaded at start-up.
  static HapticsLevel level = HapticsLevel.full;

  static const levelPreferenceKey = 'glimpse_haptics_level';

  static Future<void> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    level =
        HapticsLevel.values.asNameMap()[prefs.getString(levelPreferenceKey)] ??
        HapticsLevel.full;
  }

  static Future<void> setLevel(HapticsLevel value) async {
    level = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(levelPreferenceKey, value.name);
  }

  static DateTime? _lastPlayed;

  /// Whether any pattern started within [window] — so an automatic haptic
  /// (see `HapticNavigatorObserver`) doesn't double one a widget just played.
  static bool playedWithin(Duration window) {
    final last = _lastPlayed;
    return last != null && DateTime.now().difference(last) < window;
  }

  /// The lightest detent: a selection, a rung in a list.
  static const tick = HapticPattern(
    'tick',
    system: [SystemStep(SystemHaptic.clockTick)],
    steps: [HapticStep(HapticPrimitive.tick, .5)],
    fallback: HapticFallback.tick,
  );

  /// A notch: a page or tab settling into place.
  static const detent = HapticPattern(
    'detent',
    system: [SystemStep(SystemHaptic.clockTick)],
    steps: [HapticStep(HapticPrimitive.lowTick, .8)],
    fallback: HapticFallback.tick,
  );

  /// A fingertip landing on something, before anything has happened.
  static const press = HapticPattern(
    'press',
    system: [SystemStep(SystemHaptic.virtualKey)],
    steps: [HapticStep(HapticPrimitive.tick, .75)],
    fallback: HapticFallback.tick,
  );

  /// A firm, clean click for an action that happened.
  static const tap = HapticPattern(
    'tap',
    system: [SystemStep(SystemHaptic.virtualKey)],
    steps: [HapticStep(HapticPrimitive.click, .7)],
    fallback: HapticFallback.click,
  );

  /// A long press: something picked up, ready to move or choose.
  static const hold = HapticPattern(
    'hold',
    system: [SystemStep(SystemHaptic.longPress)],
    steps: [
      HapticStep(HapticPrimitive.quickRise, .45),
      HapticStep(HapticPrimitive.click, .75, 10),
    ],
    fallback: HapticFallback.heavy,
  );

  /// Something physical settling: a cover, a card, a pin.
  static const land = HapticPattern(
    'land',
    system: [SystemStep(SystemHaptic.keyboardTap)],
    steps: [HapticStep(HapticPrimitive.thud, .5)],
    fallback: HapticFallback.click,
  );

  /// A surface lifting in: a sheet rising, a panel opening.
  static const swell = HapticPattern(
    'swell',
    system: [SystemStep(SystemHaptic.gestureStart)],
    steps: [HapticStep(HapticPrimitive.slowRise, .35)],
    fallback: HapticFallback.tick,
  );

  /// A surface falling away: a sheet dismissed.
  static const drop = HapticPattern(
    'drop',
    system: [SystemStep(SystemHaptic.gestureEnd)],
    steps: [HapticStep(HapticPrimitive.quickFall, .45)],
    fallback: HapticFallback.tick,
  );

  /// One key of typing: barely there.
  static const key = HapticPattern(
    'key',
    system: [SystemStep(SystemHaptic.textHandleMove)],
    steps: [HapticStep(HapticPrimitive.lowTick, .35)],
    fallback: HapticFallback.tick,
  );

  /// Work in progress: three soft pulses.
  static const pulse = HapticPattern(
    'pulse',
    system: [
      SystemStep(SystemHaptic.textHandleMove),
      SystemStep(SystemHaptic.textHandleMove, 120),
      SystemStep(SystemHaptic.textHandleMove, 120),
    ],
    steps: [
      HapticStep(HapticPrimitive.lowTick, .55),
      HapticStep(HapticPrimitive.lowTick, .4, 120),
      HapticStep(HapticPrimitive.lowTick, .25, 120),
    ],
    fallback: HapticFallback.tick,
  );

  /// Something landed safely: a tick, then a bright confirmation.
  static const success = HapticPattern(
    'success',
    system: [
      SystemStep(SystemHaptic.clockTick),
      SystemStep(SystemHaptic.confirm, 70),
    ],
    steps: [
      HapticStep(HapticPrimitive.quickRise, .3),
      HapticStep(HapticPrimitive.click, .85, 20),
      HapticStep(HapticPrimitive.tick, .35, 80),
    ],
    fallback: HapticFallback.double,
  );

  /// A small celebration: two quick sparks, then a confirmation.
  static const delight = HapticPattern(
    'delight',
    system: [
      SystemStep(SystemHaptic.clockTick),
      SystemStep(SystemHaptic.clockTick, 60),
      SystemStep(SystemHaptic.confirm, 60),
    ],
    steps: [
      HapticStep(HapticPrimitive.spin, .5),
      HapticStep(HapticPrimitive.tick, .5, 60),
      HapticStep(HapticPrimitive.tick, .35, 60),
    ],
    fallback: HapticFallback.double,
  );

  /// Committing to a big step: a big button pressed all the way down.
  static const confirm = HapticPattern(
    'confirm',
    system: [
      SystemStep(SystemHaptic.keyboardTap),
      SystemStep(SystemHaptic.confirm, 40),
    ],
    steps: [
      HapticStep(HapticPrimitive.slowRise, .5),
      HapticStep(HapticPrimitive.click, 1),
      HapticStep(HapticPrimitive.thud, .35, 40),
    ],
    fallback: HapticFallback.heavy,
  );

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

  /// Plays [pattern]. [intensity] (0..1) scales the composed engine's
  /// primitives; system haptics can't be scaled, so a faint one (below .4)
  /// plays as the softest system haptic instead.
  static Future<void> play(
    HapticPattern pattern, {
    double intensity = 1,
  }) async {
    if (level == HapticsLevel.off) return;
    _lastPlayed = DateTime.now();
    // Subtle keeps only the lightest touch: below .4 even system haptics
    // play as the softest one.
    final scale = level == HapticsLevel.subtle
        ? (intensity * 0.35).clamp(0.0, 0.35)
        : intensity.clamp(0.0, 1.0);
    if (_bridge) {
      try {
        await _channel.invokeMethod<void>('compose', {
          'name': pattern.name,
          'engine': engine.name,
          'system': [
            for (final step in pattern.system)
              [
                scale < .4
                    ? SystemHaptic.textHandleMove.name
                    : step.haptic.name,
                step.delayMs,
              ],
          ],
          'steps': [
            for (final step in pattern.steps)
              [
                step.primitive.id,
                (step.scale * scale).clamp(0.0, 1.0),
                step.delayMs,
              ],
          ],
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

/// How strongly the app's haptics play (Settings › Personalization).
enum HapticsLevel { full, subtle, off }
