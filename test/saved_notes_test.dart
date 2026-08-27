import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/providers/pinned_urls_provider.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/core/services/saved_notes_codec.dart';
import 'package:glimpse/core/services/saved_notes_service.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/url_detail/url_detail_provider.dart';
import 'package:glimpse/features/url_detail/url_detail_screen.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:glimpse/shared/widgets/url_card.dart';
import 'package:glimpse/shared/widgets/lightweight_markdown_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Markdown previews remove model formatting markers', () {
    const markdown = '''### Shared Themes
Across the sources, **structured curation** matters.
* **Narrative Depth:** Build a complete understanding.''';

    expect(LightweightMarkdownText.toPlainText(markdown), '''Shared Themes
Across the sources, structured curation matters.
• Narrative Depth: Build a complete understanding.''');
  });

  group('SavedUrl note helpers', () {
    test('personal note takes preview priority over Ask notes', () {
      final url = _savedUrl()
        ..userNotes = '\n  Remember the practical example.  \nSecond line'
        ..askNotes = [_askNote(question: 'What is the key idea?')];

      expect(url.hasNotes, isTrue);
      expect(url.notePreview, 'Remember the practical example.');
      expect(url.notePreviewIsAsk, isFalse);
    });

    test('latest Ask question becomes the fallback preview', () {
      final url = _savedUrl()
        ..askNotes = [
          _askNote(
            id: 'older',
            question: 'Older question',
            createdAt: DateTime(2026, 8, 1),
          ),
          _askNote(
            id: 'newer',
            question: 'Newer question',
            createdAt: DateTime(2026, 8, 2),
          ),
        ];

      expect(url.notePreview, 'Asked: Newer question');
      expect(url.notePreviewIsAsk, isTrue);
    });
  });

  group('legacy Ask note migration', () {
    test('extracts all valid blocks and preserves the personal prefix', () {
      final url = _savedUrl()
        ..userNotes = '''Keep this for the weekend.

## Ask Glimpse
Asked: 2026-07-01 10:15
Question: What should I remember?

The first answer.

## Ask Glimpse
Asked: 2026-07-02 09:05
Question: What is the next step?

The second answer.''';

      expect(SavedNotesCodec.migrateLegacyAskNotes(url), isTrue);
      expect(url.userNotes, 'Keep this for the weekend.');
      expect(url.askNotes, hasLength(2));
      expect(url.askNotes.first.question, 'What should I remember?');
      expect(url.askNotes.last.body, 'The second answer.');
      expect(url.askNotes.last.createdAt, DateTime(2026, 7, 2, 9, 5));

      expect(SavedNotesCodec.migrateLegacyAskNotes(url), isFalse);
      expect(url.askNotes, hasLength(2));
    });

    test('leaves malformed blocks untouched', () {
      const malformed = '''Personal text

## Ask Glimpse
Asked: not-a-date
This block has no question.''';
      final url = _savedUrl()..userNotes = malformed;

      expect(SavedNotesCodec.migrateLegacyAskNotes(url), isFalse);
      expect(url.userNotes, malformed);
      expect(url.askNotes, isEmpty);
    });
  });

  group('SavedNotesService', () {
    test('personal and Ask mutations never overwrite each other', () async {
      final url = _savedUrl()
        ..id = 7
        ..userNotes = 'Original thought'
        ..askNotes = [_askNote(id: 'existing')];
      final database = _MemoryIsarService(url);
      final service = SavedNotesService(database);

      expect(await service.updatePersonalNote(7, 'Updated thought'), isTrue);
      expect(database.url.userNotes, 'Updated thought');
      expect(database.url.askNotes.single.id, 'existing');

      expect(
        await service.saveAskNote(
          urlId: 7,
          sourceMessageId: 'message-2',
          question: 'What changed?',
          body: 'The durable answer.',
        ),
        isTrue,
      );
      expect(database.url.userNotes, 'Updated thought');
      expect(database.url.askNotes, hasLength(2));

      await service.saveAskNote(
        urlId: 7,
        sourceMessageId: 'message-2',
        question: 'What changed?',
        body: 'The durable answer.',
      );
      expect(database.url.askNotes, hasLength(2));

      expect(await service.deleteAskNote(7, 'existing'), isTrue);
      expect(database.url.userNotes, 'Updated thought');
      expect(database.url.askNotes.single.sourceMessageId, 'message-2');
    });
  });

  testWidgets('UrlCard shows the preferred one-line note preview', (
    tester,
  ) async {
    final url = _savedUrl()..userNotes = 'A concise personal reminder';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: UrlCard(savedUrl: url, tagFrequency: const {}),
          ),
        ),
      ),
    );

    expect(find.text('A concise personal reminder'), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
  });

  testWidgets(
    'detail starts in read mode and edits a personal note on demand',
    (tester) async {
      final url = _savedUrl()
        ..id = 9
        ..userNotes = 'Read this as content';
      final database = _MemoryIsarService(url);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarServiceProvider.overrideWithValue(database),
            savedNotesServiceProvider.overrideWithValue(
              SavedNotesService(database),
            ),
            urlDetailProvider(9).overrideWith((ref) async => database.url),
            tagOccurrenceMapProvider.overrideWithValue(const {}),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const UrlDetailScreen(urlId: 9),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read this as content'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.ensureVisible(find.widgetWithText(TextButton, 'Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A better personal note');
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();

      expect(database.url.userNotes, 'A better personal note');
      expect(find.text('A better personal note'), findsOneWidget);
    },
  );

  testWidgets('detail keeps Ask notes distinct from the personal editor', (
    tester,
  ) async {
    final url = _savedUrl()
      ..id = 10
      ..askNotes = [
        _askNote(
          question: 'What should I carry forward?',
          body: '''### Shared Themes
Use **structured curation**.
* **Narrative Depth:** Prefer complete works.''',
        ),
      ];
    final database = _MemoryIsarService(url);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(database),
          savedNotesServiceProvider.overrideWithValue(
            SavedNotesService(database),
          ),
          urlDetailProvider(10).overrideWith((ref) async => database.url),
          tagOccurrenceMapProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const UrlDetailScreen(urlId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ask Glimpse'), findsOneWidget);
    expect(find.text('What should I carry forward?'), findsOneWidget);
    expect(find.textContaining('###'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Add your note'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('## Ask Glimpse'), findsNothing);
  });

  testWidgets('detail overflow toggles the saved item pin', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final url = _savedUrl()..id = 12;
    final database = _MemoryIsarService(url);
    final container = ProviderContainer(
      overrides: [
        isarServiceProvider.overrideWithValue(database),
        savedNotesServiceProvider.overrideWithValue(
          SavedNotesService(database),
        ),
        urlDetailProvider(12).overrideWith((ref) async => database.url),
        tagOccurrenceMapProvider.overrideWithValue(const {}),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const UrlDetailScreen(urlId: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsOneWidget);

    await tester.tap(find.text('Pin'));
    await tester.pump();
    expect(container.read(pinnedUrlsProvider), contains(12));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Unpin'), findsOneWidget);
  });

  testWidgets('detail localizes note chrome and both saved-time formats', (
    tester,
  ) async {
    final url = _savedUrl()
      ..id = 11
      ..savedAt = DateTime.now().subtract(const Duration(days: 2));
    final database = _MemoryIsarService(url);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(database),
          savedNotesServiceProvider.overrideWithValue(
            SavedNotesService(database),
          ),
          urlDetailProvider(11).overrideWith((ref) async => database.url),
          tagOccurrenceMapProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          home: const UrlDetailScreen(urlId: 11),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2日前'), findsOneWidget);
    await tester.ensureVisible(find.text('2日前'));
    await tester.tap(find.text('2日前'));
    await tester.pump();
    expect(find.textContaining('August'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'\d{4}年\d{1,2}月\d{1,2}日').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('メモを追加'));
    await tester.tap(find.text('メモを追加'));
    await tester.pump();
    expect(find.text('自分のメモ'), findsOneWidget);
    expect(find.text('完了'), findsOneWidget);
    expect(find.text('印象に残ったことは？'), findsOneWidget);
    expect(find.text('クイック追加'), findsOneWidget);
    expect(find.text('後で見返す'), findsOneWidget);
    expect(find.text('誰かと共有'), findsOneWidget);
    expect(find.text('試す価値あり'), findsOneWidget);
    expect(find.text('確認済み'), findsOneWidget);
  });
}

SavedUrl _savedUrl() => SavedUrl()
  ..id = 1
  ..rawUrl = 'https://example.com/article'
  ..domain = 'example.com'
  ..title = 'A useful article'
  ..description = 'A clear description.'
  ..category = 'Technology'
  ..categoryEmoji = '💻'
  ..categories = ['Technology']
  ..tags = <String>[]
  ..processingStatus = 'COMPLETED'
  ..savedAt = DateTime(2026, 8, 1);

SavedAskNote _askNote({
  String id = 'ask-1',
  String question = 'Why is this useful?',
  String body = 'A useful answer.',
  DateTime? createdAt,
}) => SavedAskNote()
  ..id = id
  ..question = question
  ..body = body
  ..createdAt = createdAt ?? DateTime(2026, 8, 1);

class _MemoryIsarService implements IsarService {
  _MemoryIsarService(this.url);

  SavedUrl url;

  @override
  Future<SavedUrl?> getUrlById(int id) async => id == url.id ? url : null;

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
