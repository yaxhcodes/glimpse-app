import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/settings/settings_components.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    for (final (family, asset) in [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ]) {
      await (FontLoader('packages/phosphor_flutter/$family')..addFont(
            rootBundle.load('packages/phosphor_flutter/lib/fonts/$asset'),
          ))
          .load();
    }
  });

  for (final dark in [false, true]) {
    testWidgets('Glimpse icon system ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const seed = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme(seed) : AppTheme.lightTheme(seed),
          home: Builder(
            builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return RepaintBoundary(
                key: const ValueKey('iconography'),
                child: Scaffold(
                  appBar: AppBar(
                    leading: const BackButton(),
                    title: const Text('Glimpse'),
                    actions: [
                      IconButton(
                        onPressed: () {},
                        icon: const AppIcon(AppIcons.addLink),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const AppIcon(AppIcons.notifications),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const AppIcon(AppIcons.more),
                      ),
                    ],
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Glimpse iconography',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        for (final (icon, title, color) in [
                          (
                            AppIcons.appearance,
                            'Appearance',
                            SettingsAccents.violet,
                          ),
                          (AppIcons.language, 'Language', SettingsAccents.blue),
                          (AppIcons.privacy, 'Privacy', SettingsAccents.green),
                          (
                            AppIcons.backup,
                            'Backup & restore',
                            SettingsAccents.amber,
                          ),
                        ])
                          SettingsTile(
                            icon: icon,
                            iconColor: color,
                            title: title,
                            onTap: () {},
                          ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final icon in [
                              AppIcons.copy,
                              AppIcons.share,
                              AppIcons.externalLink,
                              AppIcons.pin,
                              AppIcons.clearData,
                            ])
                              IconButton(
                                onPressed: () {},
                                icon: AppIcon(icon, size: 22),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            for (final (icon, label) in [
                              (AppIcons.bookOpen, 'Books'),
                              (AppIcons.movie, 'Movies'),
                              (AppIcons.music, 'Music'),
                              (AppIcons.place, 'Places'),
                            ])
                              Expanded(
                                child: Column(
                                  children: [
                                    AppIcon(icon, size: 24),
                                    const SizedBox(height: 8),
                                    Text(label),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            AppIcon(
                              AppIcons.clock,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Saved yesterday',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Spacer(),
                            AppIcon(AppIcons.pin, size: 18, selected: true),
                            const SizedBox(width: 8),
                            const Text('Pinned'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: 1,
                    destinations: [
                      for (final (icon, label) in [
                        (AppIcons.home, 'Home'),
                        (AppIcons.collections, 'Collections'),
                        (AppIcons.interests, 'Interests'),
                        (AppIcons.search, 'Search'),
                      ])
                        NavigationDestination(
                          icon: AppIcon(icon),
                          selectedIcon: AppIcon(icon, selected: true),
                          label: label,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(AppIcons.arrowBack), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('iconography')),
        matchesGoldenFile('goldens/iconography_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}
