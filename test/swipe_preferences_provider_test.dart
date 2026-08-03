import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/providers/swipe_preferences_provider.dart';

void main() {
  test('gesture actions provide filled variants for settings', () {
    expect(SwipeActionType.delete.icon, Icons.delete_outline_rounded);
    expect(SwipeActionType.delete.filledIcon, Icons.delete_rounded);
    expect(SwipeActionType.share.icon, Icons.share_outlined);
    expect(SwipeActionType.share.filledIcon, Icons.share_rounded);
    expect(
      SwipeActionType.addToCollection.filledIcon.fontFamily,
      'PhosphorFill',
    );
  });
}
