import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/providers/swipe_preferences_provider.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

void main() {
  test('gesture actions provide filled variants for settings', () {
    expect(SwipeActionType.delete.icon, AppIcons.clearData);
    expect(SwipeActionType.share.icon, AppIcons.share);
    for (final action in SwipeActionType.values) {
      expect(action.icon.fontFamily, 'PhosphorBold');
      expect(action.filledIcon.fontFamily, 'PhosphorFill');
    }
  });
}
