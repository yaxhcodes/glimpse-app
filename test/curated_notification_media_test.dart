import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/shared/widgets/notifications/curated_notification_media.dart';

SavedUrl _savedUrl(String title) {
  return SavedUrl()
    ..rawUrl = 'https://example.com/$title'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = ''
    ..categories = const []
    ..tags = const []
    ..savedAt = DateTime(2026);
}

void main() {
  testWidgets('notification thumbnails overlap with a visible separator', (
    tester,
  ) async {
    const gapColor = Color(0xFFF4F1EC);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CuratedNotificationThumbStack(
            urls: [_savedUrl('one'), _savedUrl('two'), _savedUrl('three')],
            size: 50,
            overlap: 14,
            gapWidth: 2,
            gapColor: gapColor,
          ),
        ),
      ),
    );

    final stackFinder = find.byType(CuratedNotificationThumbStack);
    final positioned = tester.widgetList<Positioned>(
      find.descendant(of: stackFinder, matching: find.byType(Positioned)),
    );
    expect(positioned.map((tile) => tile.left), [0, 36, 72]);

    final stackBox = tester.widget<SizedBox>(
      find.descendant(of: stackFinder, matching: find.byType(SizedBox)).first,
    );
    expect(stackBox.width, 122);

    final tiles = tester.widgetList<CuratedNotificationThumbStripItem>(
      find.descendant(
        of: stackFinder,
        matching: find.byType(CuratedNotificationThumbStripItem),
      ),
    );
    expect(tiles, hasLength(3));
    expect(tiles.every((tile) => tile.overlayGapWidth == 2), isTrue);
    expect(tiles.every((tile) => tile.overlayGapColor == gapColor), isTrue);

    final foregroundBorders = tester
        .widgetList<Container>(
          find.descendant(of: stackFinder, matching: find.byType(Container)),
        )
        .map((container) => container.foregroundDecoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.border)
        .whereType<Border>()
        .toList();
    expect(foregroundBorders, hasLength(3));
    expect(foregroundBorders.every((border) => border.top.width == 2), isTrue);
    expect(
      foregroundBorders.every((border) => border.top.color == gapColor),
      isTrue,
    );
  });
}
