import 'package:flutter/material.dart';

/// Material 3 Expressive–inspired motion tokens.
///
/// Android 17's headline change is the Expressive motion system: spring-based,
/// with emphasized easing for spatial transitions. Stable Flutter does not ship
/// those tokens yet, so this centralizes an approximation built from the
/// emphasized curves Flutter *does* provide, plus tuned [SpringDescription]s for
/// touch response. Components reference these so the app's motion stays
/// consistent, and we can swap in first-class Expressive tokens once the
/// framework exposes them — without touching call sites.
class AppMotion {
  AppMotion._();

  // ── Durations (M3 Expressive spatial scale) ────────────────────────────────
  static const Duration short = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration long = Duration(milliseconds: 480);

  // ── Easing ─────────────────────────────────────────────────────────────────
  /// Default emphasized spatial easing (M3 standard).
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// For elements entering / settling into place (decelerating).
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// For elements accelerating off-screen.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  // ── Springs (interactive touch response) ───────────────────────────────────
  /// Bouncy press/release spring — the signature Expressive "squish & settle".
  /// Underdamped (damping < critical ≈ 37.9) so release gently overshoots.
  static const SpringDescription springExpressive = SpringDescription(
    mass: 1.0,
    stiffness: 360.0,
    damping: 18.0,
  );

  /// Near-critically-damped spring for subtle, almost overshoot-free settles.
  static const SpringDescription springSubtle = SpringDescription(
    mass: 1.0,
    stiffness: 520.0,
    damping: 44.0,
  );
}
