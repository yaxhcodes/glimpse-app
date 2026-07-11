import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/category_chip.dart';
import 'package:glimpse/shared/widgets/creator_profile_link.dart';
import 'package:glimpse/shared/widgets/metadata_pill.dart';
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

  testWidgets('creator links expose a 48dp semantic link target', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const CreatorProfileLink(
          username: 'glimpse',
          platform: 'Instagram',
          compact: true,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CreatorProfileLink)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(CreatorProfileLink)).width,
      lessThan(200),
    );
    final semantics = tester
        .getSemantics(find.byType(CreatorProfileLink))
        .getSemanticsData();
    expect(semantics.flagsCollection.isLink, isTrue);
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

  testWidgets('social metrics and author remain on one compact row', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const SizedBox(
          width: 360,
          child: Row(
            children: [
              MetadataPill(value: '499K', icon: Icons.favorite_border_rounded),
              SizedBox(width: 8),
              MetadataPill(
                value: '7.7K',
                icon: Icons.chat_bubble_outline_rounded,
              ),
              SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: CreatorProfileLink(
                  username: 'rasikanandaswami',
                  platform: 'Instagram',
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final likes = tester.getCenter(find.text('499K'));
    final comments = tester.getCenter(find.text('7.7K'));
    final author = tester.getCenter(find.text('rasikanandaswami'));

    expect(comments.dy, likes.dy);
    expect(author.dy, likes.dy);
  });
}
