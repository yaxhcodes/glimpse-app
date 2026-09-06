import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/url_detail/reader_ask_actions.dart';
import 'package:glimpse/l10n/generated/app_localizations.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    for (final brightness in Brightness.values) {
      testWidgets('Ask actions wrap at 2x text in $locale $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var opens = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ReaderAskActions(onOpen: () => opens++),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(opens, 0);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ReaderAskActions)),
        );
        expect(find.text(l10n.readerAskAbout), findsOneWidget);
        expect(find.byType(ActionChip), findsNothing);
        await tester.tap(find.byType(TextButton));
        expect(opens, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
