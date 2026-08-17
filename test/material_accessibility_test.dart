import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/url_detail/source_saved_metadata_row.dart';
import 'package:glimpse/shared/widgets/category_chip.dart';
import 'package:glimpse/shared/widgets/content_attribution_disclaimer.dart';
import 'package:glimpse/shared/widgets/creator_profile_link.dart';
import 'package:glimpse/shared/widgets/tag_group.dart';

void main() {
  Widget themed(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  testWidgets('interactive category chips expose a 48dp target', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(CategoryChip(category: 'Other', emoji: '🔖', onTap: () {})),
    );

    expect(
      tester.getSize(find.byType(CategoryChip)).height,
      greaterThanOrEqualTo(48),
    );
    final semantics = tester
        .getSemantics(find.byType(CategoryChip))
        .getSemanticsData();
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('creator links remain compact and semantic', (tester) async {
    await tester.pumpWidget(
      themed(
        const CreatorProfileLink(username: 'glimpse', platform: 'Instagram'),
      ),
    );

    expect(tester.getSize(find.byType(CreatorProfileLink)).height, 32);
    expect(
      tester.getSize(find.byType(CreatorProfileLink)).width,
      lessThan(200),
    );
    expect(find.text('by'), findsNothing);
    expect(find.text('@glimpse'), findsOneWidget);
    expect(find.text('Creator'), findsNothing);
    final handleRect = tester.getRect(find.text('@glimpse'));
    final externalIconRect = tester.getRect(
      find.byIcon(Icons.north_east_rounded),
    );
    expect(externalIconRect.left, greaterThanOrEqualTo(handleRect.right));
    expect(externalIconRect.left - handleRect.right, lessThanOrEqualTo(8));
    final linkTarget = find.descendant(
      of: find.byType(CreatorProfileLink),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(linkTarget).height, 32);
    final semantics = tester
        .getSemantics(find.byType(CreatorProfileLink))
        .getSemanticsData();
    expect(semantics.flagsCollection.isLink, isTrue);
  });

  testWidgets('exact timestamp animates while unread remains stable', (
    tester,
  ) async {
    Widget metadata(String savedLabel, {required bool exactDateVisible}) {
      return themed(
        SizedBox(
          width: 240,
          child: SourceSavedMetadataRow(
            leading: const Icon(Icons.camera_alt_outlined, size: 16),
            sourceName: 'Instagram',
            savedLabel: savedLabel,
            exactDateVisible: exactDateVisible,
            isRead: false,
            sourceColor: Colors.pink,
            onSavedLabelTap: () {},
          ),
        ),
      );
    }

    await tester.pumpWidget(metadata('22h ago', exactDateVisible: false));
    final relativeUnreadRect = tester.getRect(
      find.byKey(const ValueKey('read-state-label')),
    );

    await tester.pumpWidget(
      metadata('August 16, 2026 · 5:03 PM', exactDateVisible: true),
    );
    final transitionUnreadRect = tester.getRect(
      find.byKey(const ValueKey('read-state-label')),
    );

    expect(transitionUnreadRect, relativeUnreadRect);
    expect(
      find.descendant(
        of: find.byType(SourceSavedMetadataRow),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester.getRect(find.byKey(const ValueKey('read-state-label'))),
      relativeUnreadRect,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('read-state-label'))),
      relativeUnreadRect,
    );
    expect(find.byKey(const ValueKey('saved-timestamp-label')), findsOneWidget);
    final timestampParagraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('saved-timestamp-label')),
    );
    expect(timestampParagraph.didExceedMaxLines, isTrue);
  });

  testWidgets('creator and unread share a balanced second metadata row', (
    tester,
  ) async {
    Widget metadata(String savedLabel, {required bool exactDateVisible}) {
      return themed(
        SizedBox(
          width: 240,
          child: SourceSavedMetadataRow(
            leading: const Icon(Icons.camera_alt_outlined, size: 16),
            sourceName: 'Instagram',
            savedLabel: savedLabel,
            exactDateVisible: exactDateVisible,
            isRead: false,
            sourceColor: Colors.pink,
            creatorLink: const Text('@glimpse'),
            onSavedLabelTap: () {},
          ),
        ),
      );
    }

    await tester.pumpWidget(metadata('22h ago', exactDateVisible: false));
    final relativeUnreadRect = tester.getRect(
      find.byKey(const ValueKey('read-state-label')),
    );
    expect(
      tester.getCenter(find.text('@glimpse')).dy,
      tester.getCenter(find.text('Unread')).dy,
    );

    await tester.pumpWidget(
      metadata('August 16, 2026 · 5:03 PM', exactDateVisible: true),
    );
    final exactUnreadRect = tester.getRect(
      find.byKey(const ValueKey('read-state-label')),
    );

    expect(exactUnreadRect, relativeUnreadRect);
  });

  testWidgets('detail tags remain left-aligned and wrap inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 360,
          child: TagGroup(
            tags: const [
              'hinduism',
              'religion',
              'theology',
              'philosophy',
              'spirituality',
            ],
            onTap: (_) {},
            onLongPress: (_) {},
          ),
        ),
      ),
    );

    final first = tester.getCenter(find.text('hinduism'));
    final second = tester.getCenter(find.text('religion'));
    final wrapped = tester.getCenter(find.text('philosophy'));

    expect(second.dx, greaterThan(first.dx));
    expect(second.dy, first.dy);
    expect(first.dx, lessThan(100));
    expect(wrapped.dy, greaterThan(first.dy));
    expect(wrapped.dy - first.dy, lessThanOrEqualTo(50));
  });

  testWidgets('content disclaimer communicates accuracy and attribution', (
    tester,
  ) async {
    await tester.pumpWidget(themed(const ContentAttributionDisclaimer()));

    expect(
      find.text(ContentAttributionDisclaimer.accuracyText),
      findsOneWidget,
    );
    expect(
      find.text(ContentAttributionDisclaimer.attributionText),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    expect(
      tester
          .getTopLeft(find.text(ContentAttributionDisclaimer.accuracyText))
          .dx,
      tester
          .getTopLeft(find.text(ContentAttributionDisclaimer.attributionText))
          .dx,
    );
    final semantics = tester
        .getSemantics(find.byType(ContentAttributionDisclaimer))
        .getSemanticsData();
    expect(semantics.label, ContentAttributionDisclaimer.message);
  });
}
