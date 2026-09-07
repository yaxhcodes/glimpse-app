import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/premium_design_system.dart';
import 'package:glimpse/shared/widgets/topic_emblem.dart';
import 'package:glimpse/shared/theme/topic_visual.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

void main() {
  testWidgets('Details bookmark stays 22 px inside its 44 px badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              key: ValueKey('mention-badge'),
              dimension: 44,
              child: AppIcon(AppIcons.bookmark, size: 22, filled: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.byKey(const ValueKey('mention-badge'));
    final drawing = find.byType(SvgPicture);
    expect(tester.getSize(badge), const Size.square(44));
    expect(tester.getSize(drawing), const Size.square(22));
    expect(tester.getCenter(drawing), tester.getCenter(badge));
  });

  testWidgets('search glyph stays 20 px inside the larger prefix slot', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PremiumSearchBar(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    final slot = find.byWidget(field.decoration!.prefixIcon!);
    final drawing = find.descendant(
      of: slot,
      matching: find.byType(SvgPicture),
    );
    expect(tester.getSize(slot).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(drawing), const Size.square(20));
    expect(tester.getCenter(drawing), tester.getCenter(slot));
  });

  for (final size in [40.0, 48.0]) {
    testWidgets('heart stays inside its $size px topic emblem', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TopicEmblem(
                visual: TopicVisual.forCategory('wellness'),
                size: size,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emblem = find.byType(TopicEmblem);
      final drawing = find.descendant(
        of: emblem,
        matching: find.byType(SvgPicture),
      );
      expect(tester.getSize(emblem), Size.square(size));
      expect(tester.getSize(drawing), Size.square(size * .48));
      expect(tester.getCenter(drawing), tester.getCenter(emblem));
    });
  }
}
