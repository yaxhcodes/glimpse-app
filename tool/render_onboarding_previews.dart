import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glimpse/features/onboarding/onboarding_scenes.dart';
import 'package:glimpse/features/onboarding/onboarding_theme.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:glimpse/l10n/l10n.dart';

// Regenerate with: flutter test tool/render_onboarding_previews.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader('NotoSansJP')..addFont(
          File(
            'tool/fonts/NotoSansJP-Onboarding.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    for (final entry in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/phosphor_flutter/PhosphorBold':
          'packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf',
      'packages/phosphor_flutter/PhosphorFill':
          'packages/phosphor_flutter/lib/fonts/Phosphor-Fill.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  for (final locale in ['en', 'de', 'es', 'fr', 'pt', 'ja']) {
    for (final dark in [false, true]) {
      for (var chapter = 4; chapter <= 5; chapter++) {
        final parts = switch (chapter) {
          2 => [1, 2, 3],
          3 => [1, 2, 3, 4],
          5 => [1, 2],
          _ => [0],
        };
        for (final part in parts) {
          testWidgets('capture $locale $dark $chapter $part', (tester) async {
            tester.view.physicalSize = Size(chapter == 1 ? 440 : 372, 2400);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: OnboardingTheme.from(
                  dark
                      ? AppTheme.darkTheme(Colors.green)
                      : AppTheme.lightTheme(Colors.green),
                ),
                builder: (context, child) {
                  final theme = Theme.of(context);
                  return Theme(
                    data: theme.copyWith(
                      textTheme: theme.textTheme.apply(
                        fontFamilyFallback: const ['NotoSansJP'],
                      ),
                    ),
                    child: child!,
                  );
                },
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(
                      key: key,
                      child: OnboardingProductPreview(
                        chapter: chapter,
                        part: part,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.runAsync(() async {
              await GoogleFonts.pendingFonts();
              // Warm every image used by real product components before capture.
              for (final image in tester.widgetList<Image>(
                find.byType(Image),
              )) {
                await precacheImage(
                  image.image,
                  tester.element(find.byType(Scaffold)),
                );
              }
            });
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final frame = await boundary.toImage(pixelRatio: 2);
              try {
                final bytes = (await frame.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                final file = File(
                  '.dart_tool/onboarding/previews/${locale}_${dark ? 'dark' : 'light'}_${chapter}_$part.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes.buffer.asUint8List());
              } finally {
                frame.dispose();
              }
            });
          });
        }
      }
    }
  }
}
