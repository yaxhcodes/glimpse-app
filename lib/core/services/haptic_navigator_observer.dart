import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'app_haptics.dart';

/// Every page a person opens by touch is felt as a [AppHaptics.tap]: cards,
/// rows, chevrons and tiles across the app get feedback without each one
/// having to ask for it.
///
/// Only pushes of full pages count — not dialogs or sheets, not pops — and
/// only when a finger went down within [_touchWindow], so navigation driven
/// by code (deep links, shortcuts, redirects) stays silent. If the widget
/// already played its own haptic, this one stays quiet.
class HapticNavigatorObserver extends NavigatorObserver {
  HapticNavigatorObserver() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  /// Tap handlers run before global pointer routes see the finger lift, so
  /// "caused by a touch" is measured from the finger going down.
  static const _touchWindow = Duration(milliseconds: 1000);
  static const _alreadyFelt = Duration(milliseconds: 250);

  DateTime? _lastDown;

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _lastDown = DateTime.now();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute || previousRoute == null) return;
    final down = _lastDown;
    if (down == null || DateTime.now().difference(down) > _touchWindow) return;
    if (AppHaptics.playedWithin(_alreadyFelt)) return;
    AppHaptics.play(AppHaptics.tap);
  }
}
