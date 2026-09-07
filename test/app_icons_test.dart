import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import 'package:glimpse/shared/widgets/app_asset_icon.dart';
import 'package:glimpse/core/constants/app_assets.dart';
import 'package:glimpse/shared/widgets/app_expansion_chevron.dart';
import 'package:glimpse/shared/widgets/notifications/notification_type_style.dart';

void main() {
  test('digest emphasis is independent of the chosen glyph', () {
    final colors = ColorScheme.fromSeed(seedColor: Colors.blue);
    final digest = NotificationTypeStyle.forHistoryType('digest', colors);
    final collector = NotificationTypeStyle.forHistoryType('collector', colors);
    expect(digest.icon, collector.icon);
    expect(digest.isDigestHighlight, isTrue);
    expect(collector.isDigestHighlight, isFalse);
  });

  testWidgets('expansion chevron follows initial and programmatic state', (
    tester,
  ) async {
    final controller = ExpansibleController()..expand();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpansionTile(
            controller: controller,
            title: const Text('Sources'),
            trailing: const AppExpansionChevron(),
            children: const [Text('Saved source')],
          ),
        ),
      ),
    );
    final rotation = find.descendant(
      of: find.byType(AppExpansionChevron),
      matching: find.byType(AnimatedRotation),
    );
    expect(tester.widget<AnimatedRotation>(rotation).turns, 0.5);
    controller.collapse();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedRotation>(rotation).turns, 0);
    await tester.tap(find.text('Sources'));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedRotation>(rotation).turns, 0.5);
    expect(find.byIcon(AppIcons.chevronDown), findsOneWidget);
  });

  test('primary destinations have distinct semantic icons', () {
    final destinations = <IconData>{
      AppIcons.home,
      AppIcons.collections,
      AppIcons.interests,
      AppIcons.search,
    };

    expect(destinations, hasLength(4));
  });

  testWidgets('selected navigation icon uses the matching fill variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            AppIcon(AppIcons.collections, key: ValueKey('inactive')),
            AppIcon(
              AppIcons.collections,
              key: ValueKey('selected'),
              selected: true,
            ),
          ],
        ),
      ),
    );

    final inactive = tester.widget<AppAssetIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('inactive')),
        matching: find.byType(AppAssetIcon),
      ),
    );
    final selected = tester.widget<AppAssetIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('selected')),
        matching: find.byType(AppAssetIcon),
      ),
    );
    expect(inactive.asset, AppAssets.collectionsIcon);
    expect(selected.asset, AppAssets.collectionsSelectedIcon);
  });

  testWidgets('filled icon uses the matching fill variant', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppIcon(AppIcons.privacy, key: ValueKey('filled'), filled: true),
      ),
    );

    final filled = tester.widget<AppAssetIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('filled')),
        matching: find.byType(AppAssetIcon),
      ),
    );

    expect(filled.asset, 'assets/icons/iconly-shield-done-selected.svg');
  });

  testWidgets('saved tokens preserve fill without a selected flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppIcon(AppIcons.bookmarkSaved)),
    );
    expect(
      tester.widget<AppAssetIcon>(find.byType(AppAssetIcon)).asset,
      'assets/icons/iconly-bookmark-selected.svg',
    );
  });

  testWidgets('filled collection action uses the matching stacked-card asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppIcon(AppIcons.addToCollection, filled: true)),
    );
    expect(
      tester.widget<AppAssetIcon>(find.byType(AppAssetIcon)).asset,
      AppAssets.addToCollectionFilledIcon,
    );
  });

  testWidgets('add link does not replace ordinary link metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [AppIcon(AppIcons.addLink), AppIcon(AppIcons.link)],
        ),
      ),
    );
    expect(find.byIcon(AppIcons.link), findsOneWidget);
    expect(
      tester.widget<AppAssetIcon>(find.byType(AppAssetIcon)).asset,
      AppAssets.addLinkIcon,
    );
  });

  test('language setting uses the Phosphor icon family', () {
    expect(AppIcons.language.fontFamily, 'PhosphorBold');
    expect(
      AppIcons.filledVariant(AppIcons.language).fontFamily,
      'PhosphorFill',
    );
  });
}
