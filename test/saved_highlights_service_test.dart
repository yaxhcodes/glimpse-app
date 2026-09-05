import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/saved_highlights_service.dart';
import 'package:glimpse/features/url_detail/reader_selectable_text.dart';
import 'package:glimpse/l10n/l10n.dart';

void main() {
  group('SavedHighlightsCodec', () {
    test('anchors a whitespace-normalized selection to the source text', () {
      final highlight = SavedHighlightsCodec.create(
        id: 'highlight-1',
        sectionKey: 'brief',
        sourceText: 'A calm reader\nkeeps the important context together.',
        selectedText: 'reader keeps the important context',
        createdAt: DateTime.utc(2026, 9, 5),
      );

      expect(highlight, isNotNull);
      expect(highlight!.quote, 'reader\nkeeps the important context');
      expect(highlight.prefix, 'A calm ');
      expect(highlight.suffix, ' together.');
    });

    test('uses surrounding context to resolve repeated text', () {
      final highlight = SavedTextHighlight(
        id: 'highlight-2',
        sectionKey: 'explanation:0:point:0',
        quote: 'the idea',
        prefix: 'first, ',
        suffix: ' becomes useful',
        createdAt: DateTime.utc(2026, 9, 5),
      );

      final ranges = SavedHighlightsCodec.rangesFor(
        sectionKey: highlight.sectionKey,
        sourceText:
            'Notice the idea briefly; first, the idea becomes useful later.',
        highlights: [highlight],
      );

      expect(ranges, hasLength(1));
      expect(ranges.single.start, 32);
    });

    test('ignores malformed and oversized persisted entries', () {
      expect(SavedHighlightsCodec.decode('not json'), isEmpty);
      expect(
        SavedHighlightsCodec.decode(
          '[{"id":"1","section_key":"brief","quote":"",'
          '"created_at":"2026-09-05T00:00:00.000Z"}]',
        ),
        isEmpty,
      );
      expect(
        SavedHighlightsCodec.selectionRange(
          'short source',
          List.filled(SavedHighlightsCodec.maxQuoteLength + 1, 'x').join(),
        ),
        isNull,
      );
    });
  });

  group('SavedHighlightsService', () {
    test('repeated words preserve the selected occurrence', () async {
      final url = _savedUrl();
      final service = SavedHighlightsService(_MemoryIsarService(url));
      const text = 'Keep this idea. Revisit this idea.';
      final result = await service.add(
        urlId: url.id,
        sectionKey: 'brief',
        sourceText: text,
        selectedText: 'idea',
        selectionStart: text.lastIndexOf('idea'),
      );
      final ranges = SavedHighlightsCodec.rangesFor(
        sectionKey: 'brief',
        sourceText: text,
        highlights: result!.highlights,
      );
      expect(ranges.single.start, text.lastIndexOf('idea'));
      expect(
        SavedHighlightsCodec.intersectingHighlight(
          sectionKey: 'brief',
          sourceText: text,
          selectedText: 'idea',
          selectionStart: text.indexOf('idea'),
          highlights: result.highlights,
        ),
        isNull,
      );
    });
    test('adds, deduplicates, and removes a persisted highlight', () async {
      final url = _savedUrl();
      final service = SavedHighlightsService(_MemoryIsarService(url));

      final added = await service.add(
        urlId: url.id,
        sectionKey: 'brief',
        sourceText: 'A complete sentence worth keeping.',
        selectedText: 'sentence worth keeping',
      );
      final duplicate = await service.add(
        urlId: url.id,
        sectionKey: 'brief',
        sourceText: 'A complete sentence worth keeping.',
        selectedText: 'sentence worth keeping',
      );

      expect(added?.changed, isTrue);
      expect(SavedHighlightsCodec.decode(url.highlightsJson), hasLength(1));
      expect(duplicate?.changed, isFalse);

      final removed = await service.remove(
        urlId: url.id,
        highlightId: added!.highlight!.id,
      );

      expect(removed?.changed, isTrue);
      expect(url.highlightsJson, isNull);
    });
  });

  testWidgets('reader text is selectable and paints saved highlights', (
    tester,
  ) async {
    final highlight = SavedHighlightsCodec.create(
      id: 'highlight-1',
      sectionKey: 'brief',
      sourceText: 'A sentence worth keeping.',
      selectedText: 'worth keeping',
      createdAt: DateTime.utc(2026, 9, 5),
    )!;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReaderSelectableText(
            text: 'A sentence worth keeping.',
            sectionKey: 'brief',
            highlights: [highlight],
            onAddHighlight: (_, _) async {},
            onRemoveHighlight: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    final textWidget = tester.widget<Text>(
      find.descendant(
        of: find.byType(ReaderSelectableText),
        matching: find.byType(Text),
      ),
    );
    final root = textWidget.textSpan! as TextSpan;
    final highlighted = root.children!.whereType<TextSpan>().singleWhere(
      (span) => span.text == 'worth keeping',
    );
    expect(highlighted.style?.backgroundColor, isNotNull);
  });

  testWidgets('reader selection offers the highlight action', (tester) async {
    String? addedText;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: ReaderSelectableText(
              text: 'A sentence worth keeping.',
              sectionKey: 'brief',
              highlights: const [],
              onAddHighlight: (text, _) async => addedText = text,
              onRemoveHighlight: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.longPress(find.text('A sentence worth keeping.'));
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Highlight'), findsOneWidget);
    await tester.tap(find.text('Highlight'));
    await tester.pump();
    expect(addedText, isNotNull);
    expect(addedText, isNotEmpty);
  });

  testWidgets('reader copies the selected text to the clipboard', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: ReaderSelectableText(
              text: 'Singapore',
              sectionKey: 'brief',
              highlights: const [],
              onAddHighlight: (_, _) async {},
              onRemoveHighlight: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Singapore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copiedText, 'Singapore');
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('selecting highlighted text offers removal', (tester) async {
    final highlight = SavedHighlightsCodec.create(
      id: 'highlight-1',
      sectionKey: 'brief',
      sourceText: 'A sentence worth keeping.',
      selectedText: 'worth keeping',
      createdAt: DateTime.utc(2026, 9, 5),
    )!;
    SavedTextHighlight? removedHighlight;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: ReaderSelectableText(
              text: 'A sentence worth keeping.',
              sectionKey: 'brief',
              highlights: [highlight],
              onAddHighlight: (_, _) async {},
              onRemoveHighlight: (value) async => removedHighlight = value,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.longPress(find.text('A sentence worth keeping.'));
    await tester.pumpAndSettle();

    expect(find.text('Remove highlight'), findsOneWidget);
    await tester.tap(find.text('Remove highlight'));
    await tester.pump();
    expect(removedHighlight?.id, highlight.id);
  });
}

SavedUrl _savedUrl() => SavedUrl()
  ..id = 42
  ..rawUrl = 'https://example.com/reader'
  ..domain = 'example.com'
  ..title = 'Reader'
  ..description = ''
  ..category = 'Other'
  ..categoryEmoji = '🔖'
  ..savedAt = DateTime.utc(2026, 9, 5);

class _MemoryIsarService implements IsarService {
  _MemoryIsarService(this.url);

  final SavedUrl url;

  @override
  Future<bool> mutateUrl(int id, void Function(SavedUrl url) mutate) async {
    if (id != url.id) return false;
    mutate(url);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected database call: ${invocation.memberName}',
    );
  }
}
