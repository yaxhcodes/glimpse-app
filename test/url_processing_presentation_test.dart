import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/l10n/generated/app_localizations.dart';
import 'package:glimpse/l10n/generated/app_localizations_de.dart';
import 'package:glimpse/l10n/generated/app_localizations_en.dart';
import 'package:glimpse/l10n/generated/app_localizations_es.dart';
import 'package:glimpse/l10n/generated/app_localizations_fr.dart';
import 'package:glimpse/l10n/generated/app_localizations_ja.dart';
import 'package:glimpse/l10n/generated/app_localizations_pt.dart';
import 'package:glimpse/shared/widgets/url_card.dart';
import 'package:glimpse/shared/widgets/url_processing_presentation.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  final english = AppLocalizationsEn();

  group('UrlProcessingPresentation', () {
    test('turns persisted stages into stable user-facing copy', () {
      final presentations =
          [
            UrlProcessingStatus.pending,
            UrlProcessingStatus.processing,
            UrlProcessingStatus.extracting,
            UrlProcessingStatus.transcriptReady,
            UrlProcessingStatus.enriching,
            UrlProcessingStatus.generatingRecommendations,
            UrlProcessingStatus.generatingEmbeddings,
            UrlProcessingStatus.retrying,
          ].map(
            (status) => UrlProcessingPresentation.fromStatus(
              status,
              sourceName: 'Instagram',
              strings: english,
            ),
          );
      final values = presentations.toList();

      expect(values[2].headline, 'Reading the reel');
      expect(values[4].headline, 'Finding what matters');
      expect(values[6].headline, 'Finishing your save');
      for (final presentation in values) {
        expect(presentation.headline.length, inInclusiveRange(16, 22));
        expect(presentation.detail.length, inInclusiveRange(30, 34));
      }
    });

    test('uses content-specific language without repeating the source', () {
      final youtube = UrlProcessingPresentation.fromStatus(
        UrlProcessingStatus.extracting,
        sourceName: 'YouTube',
        strings: english,
      );
      final web = UrlProcessingPresentation.fromStatus(
        UrlProcessingStatus.extracting,
        sourceName: 'example.com',
        strings: english,
      );

      expect(youtube.headline, 'Reading the video');
      expect(youtube.headline, isNot(contains('YouTube')));
      expect(web.headline, 'Reading the page');
    });

    test('reassures the user when processing fails', () {
      final failed = UrlProcessingPresentation.fromStatus(
        UrlProcessingStatus.failed,
        sourceName: 'Instagram',
        strings: english,
      );

      expect(failed.failed, isTrue);
      expect(failed.headline, 'Couldn\'t finish processing');
      expect(failed.detail, contains('save is safe'));
    });

    test('localizes extracting copy for every supported locale', () {
      void expectCopy(
        AppLocalizations strings,
        String headline,
        String detail,
      ) {
        final presentation = UrlProcessingPresentation.fromStatus(
          UrlProcessingStatus.extracting,
          sourceName: 'Instagram',
          strings: strings,
        );
        expect(presentation.headline, headline);
        expect(presentation.detail, detail);
      }

      expectCopy(
        AppLocalizationsEn(),
        'Reading the reel',
        'Pulling out the useful details',
      );
      expectCopy(AppLocalizationsJa(), 'リールを読み取っています', '役立つ情報を取り出しています');
      expectCopy(
        AppLocalizationsEs(),
        'Leyendo reel',
        'Extrayendo los detalles útiles',
      );
      expectCopy(
        AppLocalizationsFr(),
        'Lecture de reel',
        'Extraction des détails utiles',
      );
      expectCopy(
        AppLocalizationsPt(),
        'Lendo reel',
        'Extraindo os detalhes úteis',
      );
      expectCopy(
        AppLocalizationsDe(),
        'Reel wird gelesen',
        'Nützliche Details werden herausgearbeitet',
      );
    });
  });

  testWidgets('processing card fits phone width without repetitive copy', (
    tester,
  ) async {
    final url = _processingUrl();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
          ),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 800)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: UrlCard(savedUrl: url, tagFrequency: const {}),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Reading the reel'), findsOneWidget);
    expect(find.text('Pulling out the useful details'), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget);
    expect(find.textContaining('Enriching Instagram save'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(Shimmer), findsNWidgets(2));
    final shimmer = tester.widget<Shimmer>(find.byType(Shimmer).first);
    final gradient = shimmer.gradient as LinearGradient;
    final luminanceDifference =
        (gradient.colors[2].computeLuminance() -
                gradient.colors[0].computeLuminance())
            .abs();
    expect(shimmer.period, const Duration(milliseconds: 1800));
    expect(luminanceDifference, greaterThan(0.12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('processing card follows the active Japanese locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UrlCard(savedUrl: _processingUrl(), tagFrequency: const {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('リールを読み取っています'), findsOneWidget);
    expect(find.text('役立つ情報を取り出しています'), findsOneWidget);
    expect(find.text('Reading the reel'), findsNothing);
    expect(find.text('Pulling out the useful details'), findsNothing);
  });
}

SavedUrl _processingUrl() => SavedUrl()
  ..rawUrl = 'https://www.instagram.com/reel/example'
  ..domain = 'instagram.com'
  ..title = 'instagram.com'
  ..description = ''
  ..category = 'Social'
  ..categoryEmoji = '📱'
  ..categories = ['Social']
  ..tags = ['instagram']
  ..savedAt = DateTime.now()
  ..processingStatus = UrlProcessingStatus.extracting
  ..processingUpdatedAt = DateTime.now();
