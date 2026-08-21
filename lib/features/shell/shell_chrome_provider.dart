import 'package:flutter_riverpod/flutter_riverpod.dart';

final shellChromeVisibilityProvider =
    NotifierProvider<ShellChromeVisibilityNotifier, bool>(
      ShellChromeVisibilityNotifier.new,
    );

class ShellChromeVisibilityNotifier extends Notifier<bool> {
  static const double hideThreshold = 28;
  static const double showThreshold = 12;

  double _accumulatedDelta = 0;

  @override
  bool build() => true;

  void handleUserScroll({required double delta, required bool isAtTop}) {
    if (isAtTop) {
      show();
      return;
    }
    if (delta == 0) return;

    if (_accumulatedDelta != 0 && _accumulatedDelta.sign != delta.sign) {
      _accumulatedDelta = 0;
    }
    _accumulatedDelta += delta;

    if (state && _accumulatedDelta >= hideThreshold) {
      state = false;
      _accumulatedDelta = 0;
    } else if (!state && _accumulatedDelta <= -showThreshold) {
      state = true;
      _accumulatedDelta = 0;
    }
  }

  void endGesture() {
    _accumulatedDelta = 0;
  }

  void show() {
    _accumulatedDelta = 0;
    if (!state) state = true;
  }
}
