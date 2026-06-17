# Android 17 (API 37) readiness

_Last reviewed: 2026-06-17_

Android 17 shipped ~June 2026 as **API level 37**. Its headline is **Material 3
Expressive** (spring-based motion, a 35-shape morphing library, ~15 new/refreshed
components, richer dynamic color, background blur), plus a **mandatory
large-screen adaptive-layout** change for apps that target 37.

## The stack constraint that shapes everything

Glimpse is a **Flutter** app. Material 3 Expressive is a *native* Android
(Compose / Views) design system — Flutter renders its own widgets and does **not**
inherit it. Stable Flutter ships baseline M3 only; the Expressive variant is not
available yet. So we cannot "switch on" the Android 17 look. We adopt its *feel*
by hand, using the primitives Flutter does provide, and track the Flutter
framework for first-class Expressive support.

`targetSdk` / `compileSdk` are also Flutter-managed (`flutter.targetSdkVersion` in
[`android/app/build.gradle.kts`](../android/app/build.gradle.kts)) — they move
when we upgrade the Flutter SDK, not by hand-editing.

## Compliance status

| Behavior change (apps targeting API 37)            | Status | Notes |
|----------------------------------------------------|--------|-------|
| Large-screen orientation/resizability opt-out removed | ✅ Already compliant | No `screenOrientation` lock, no `resizeableActivity="false"`, no `setPreferredOrientations` anywhere. |
| Edge-to-edge enforced                              | ✅ Handled | `AppTheme` sets transparent system bars via `systemOverlayStyle`; Flutter draws edge-to-edge. Re-verify on a foldable. |
| Predictive back gesture                            | ✅ Enabled | `enableOnBackInvokedCallback=true` + `PredictiveBackPageTransitionsBuilder`; all back-intercepting screens use `PopScope`. |
| Implicit URI grants removed (lands Android **18**) | ⏳ Track only | Affects the *sender* path (`share_plus`). Plugin-managed; no action until we target 38. |
| Cleartext traffic deprecation                      | ✅ N/A | HTTPS only. |
| Background audio hardening                         | ✅ N/A | App plays no audio. |
| SMS OTP delays                                     | ✅ N/A | No SMS use. |

## What we shipped for the Android 17 "feel" (Flutter-side)

- **Predictive back** — manifest opt-in + `PredictiveBackPageTransitionsBuilder`
  in [`app_theme.dart`](../lib/shared/theme/app_theme.dart). Gives the OS-driven
  back-preview animation on Android 14+, falls back to zoom on older releases.
- **Expressive motion tokens** — [`app_motion.dart`](../lib/shared/theme/app_motion.dart):
  emphasized easing + tuned spring descriptions in one place.
- **Springy touch response** — [`expressive_tap_scale.dart`](../lib/shared/widgets/expressive_tap_scale.dart),
  a `Listener`-based press-scale (doesn't steal ripples/taps), first adopted on
  the URL card.
- **Morphing loading indicator** — [`expressive_loading_indicator.dart`](../lib/shared/widgets/expressive_loading_indicator.dart),
  a filled shape that morphs between 4- and 7-lobe forms while rotating; wired
  into the shared [`LoadingIndicator`](../lib/shared/widgets/loading_indicator.dart)
  so it appears everywhere that widget is used.
- **Shape-morphing FAB** — [`expressive_fab.dart`](../lib/shared/widgets/expressive_fab.dart),
  the "Ask Glimpse" extended FAB springs its scale and morphs its corner radius
  tighter on press, settling back with overshoot. Wraps the real
  `FloatingActionButton.extended`, so theme/elevation/semantics are unchanged.

**Nav-bar indicator shape-morph — deferred (Flutter limitation).** Flutter's
`NavigationBar` animates the selected indicator's *position and fade*, not its
*shape*; a per-selection shape morph would require a custom navigation bar,
which isn't worth the risk for this slice. The indicator stays a `StadiumBorder`
(already the correct M3 Expressive pill). A lighter alternative — spring-popping
the destination icon on selection — is listed below.

## Targeting API 37 — when and how

**Not yet required.** Google Play's floor is API 35 (since Aug 2025); the API 37
requirement is expected ~2027. Forcing `targetSdk 37` now risks breaking the
minified release build for no compliance benefit.

When required:
1. Upgrade the Flutter SDK to a version whose embedded toolchain supports API 37
   (raises `flutter.compileSdkVersion` / `targetSdkVersion`).
2. `flutter pub upgrade`; re-validate plugins (`receive_sharing_intent`,
   `share_plus`, `flutter_local_notifications`, `workmanager`, `isar`).
3. Build the **release** flavor (minify + resource shrink are on) and smoke-test:
   share-to-save, backup open-with, notifications, predictive back.
4. Verify large-screen/foldable layouts (orientation opt-out is gone at 37).

## Next slices (Expressive design, not yet done)

- Roll the spring tap-scale out to remaining tappable cards/list rows
  (search results, collections, notifications, mindmap cluster cards).
- Spring-pop the nav destination icons on selection (lighter-weight than a
  custom indicator shape).
- Audit dynamic-color tonal usage against the Expressive palette guidance.
