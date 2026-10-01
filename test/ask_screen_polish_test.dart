import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/ask_conversation.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/features/collections/collections_provider.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/core/providers/usage_providers.dart';
import 'package:glimpse/core/providers/user_display_name_provider.dart';
import 'package:glimpse/core/services/usage_limits.dart';
import 'package:glimpse/features/ask/ask_empty_suggestions_provider.dart';
import 'package:glimpse/features/ask/ask_provider.dart';
import 'package:glimpse/features/ask/ask_screen.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the screen to test/goldens_scratch when run with
/// `--dart-define=ASK_PREVIEW=true --update-goldens` (design review only).
const _preview = bool.fromEnvironment('ASK_PREVIEW');
const _boundary = ValueKey('ask-boundary');

class _Database extends Fake implements IsarService {
  final added = <int, List<int>>{};

  @override
  Future<List<SavedUrl>> getAllUrls() async => const [];

  @override
  Future<void> addUrlsToCollection({
    required int collectionId,
    required List<int> urlIds,
  }) async => added[collectionId] = urlIds;
}

AskConversation _chat(String key, String title, DateTime at) =>
    AskConversation()
      ..key = key
      ..title = title
      ..createdAt = at
      ..updatedAt = at
      ..messagesJson = '[]';

UserCollection _collection(int id, String name, List<int> urlIds) =>
    UserCollection()
      ..id = id
      ..name = name
      ..emoji = ''
      ..createdAt = DateTime(2026, 9)
      ..urlIds = urlIds;

class _FakeAsk extends StateNotifier<AskState> implements AskNotifier {
  _FakeAsk(super.state);

  int stops = 0;
  int retries = 0;
  final edits = <(String, String)>[];
  final deleted = <String>[];
  final restored = <String>[];
  List<AskConversation> history = const [];

  @override
  void editAndResend(String id, String question) => edits.add((id, question));

  @override
  Future<List<AskConversation>> conversations() async => history;

  @override
  String? get conversationKey => history.firstOrNull?.key;

  @override
  Future<void> deleteConversation(AskConversation chat) async =>
      deleted.add(chat.key);

  @override
  Future<void> restoreConversation(AskConversation chat) async =>
      restored.add(chat.key);

  @override
  Future<void> get ready => Future.value();

  @override
  String? get focusedUrl => null;

  @override
  void stop() => stops++;

  @override
  void retryLast() => retries++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

SavedUrl _save(int id, String title, String url) => SavedUrl()
  ..id = id
  ..rawUrl = url
  ..domain = Uri.parse(url).host
  ..title = title
  ..description = ''
  ..summary =
      'An animated short about kindness and friendship, shared by a '
      'cinema recommendations account.'
  ..savedAt = DateTime(2026, 9, 20);

/// A small library: a fresh save, a busy topic, a week of saves and an old
/// one worth revisiting.
List<SavedUrl> _library() {
  SavedUrl at(int id, String title, String category, DateTime when) =>
      _save(id, title, 'https://example.com/$id')
        ..category = category
        ..categories = [category]
        ..tags = const []
        ..savedAt = when;
  final now = DateTime(2026, 10, 1, 9);
  return [
    at(1, 'The quiet power of slow mornings', 'Productivity', now),
    at(
      2,
      'Deep work, revisited',
      'Productivity',
      now.subtract(const Duration(days: 1)),
    ),
    at(
      3,
      'Time blocking for creatives',
      'Productivity',
      now.subtract(const Duration(days: 2)),
    ),
    at(4, 'Instagram', 'Instagram', now.subtract(const Duration(days: 3))),
    at(
      5,
      'Ghibli backgrounds, frame by frame',
      'Animation',
      now.subtract(const Duration(days: 9)),
    ),
    at(
      6,
      'How Pixar writes a story',
      'Animation',
      now.subtract(const Duration(days: 12)),
    ),
    at(
      7,
      'Why hand-drawn still wins',
      'Animation',
      now.subtract(const Duration(days: 20)),
    ),
    at(
      8,
      'A field guide to Lisbon’s miradouros',
      'Travel',
      now.subtract(const Duration(days: 75)),
    ),
  ];
}

List<ChatMessage> _conversation() {
  final film = _save(
    1,
    'The Boy, the Mole, the Fox and the Horse',
    'https://www.instagram.com/p/abc',
  );
  final review = _save(
    2,
    'Why hand-drawn animation still wins',
    'https://www.youtube.com/watch?v=1',
  );
  return [
    ChatMessage(
      id: 'q',
      text: 'Explain It’s Just Cinema on Instagram',
      isUser: true,
    ),
    ChatMessage(
      id: 'a',
      text:
          'You saved a post from the Instagram account "It’s Just Cinema" '
          'which highlights the animated short film *The Boy, the Mole, the '
          'Fox and the Horse*, directed by Peter Baynton and Charlie Mackesy '
          '[1]. The account serves as a hub for cinema recommendations [2].',
      isUser: false,
      sources: [film, review],
      sections: [
        ChatMessageSection(
          heading: film.title,
          summary: film.summary!,
          source: film,
          citationIndex: 1,
        ),
        ChatMessageSection(
          heading: review.title,
          summary: review.summary!,
          source: review,
          citationIndex: 2,
        ),
      ],
      action: ChatAction.saveToCollection,
      canSaveAsNote: true,
      followUpSuggestions: const [
        'What other animated films have been recommended in my library?',
        'Are there other accounts that focus on movie recommendations?',
      ],
    ),
  ];
}

/// Timers start entrances on one frame and their tickers on the next, so a
/// few frames pass before anything has landed.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeAsk> pumpAsk(
    WidgetTester tester, {
    required AskState state,
    ThemeMode mode = ThemeMode.dark,
    List<AskConversation> history = const [],
    List<UserCollection> collections = const [],
    _Database? database,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final ask = _FakeAsk(state)..history = history;
    const seed = Color(0xFF6750A4);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          askProvider.overrideWith((ref) => ask),
          isarServiceProvider.overrideWithValue(database ?? _Database()),
          collectionsListProvider.overrideWith((ref) async => collections),
          urlStreamProvider.overrideWith((ref) => Stream.value(_library())),
          userDisplayNameProvider.overrideWith((ref) async => 'Yash'),
          askEmptySuggestionsProvider.overrideWith(
            (ref) async => buildAskSuggestions(
              _library(),
              lookupAppLocalizations(const Locale('en')),
              now: DateTime(2026, 10, 1, 9),
            ),
          ),
          remainingUsageProvider.overrideWith((ref, feature) async => 9999),
          nearLimitProvider.overrideWith((ref, feature) async => false),
        ],
        child: RepaintBoundary(
          key: _boundary,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const AskScreen(),
                ),
              ],
            ),
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme(seed),
            darkTheme: AppTheme.darkTheme(seed),
            themeMode: mode,
          ),
        ),
      ),
    );
    await settle(tester);
    return ask;
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!_preview) return;
    await expectLater(
      find.byKey(_boundary),
      matchesGoldenFile('goldens_scratch/$name.png'),
    );
  }

  testWidgets('an answer reads as text with quiet actions and sources', (
    tester,
  ) async {
    final ask = await pumpAsk(
      tester,
      state: AskState(messages: _conversation()),
    );
    await preview(tester, 'ask_answer');

    // Emphasis renders as italics, never as stray asterisks.
    expect(find.textContaining('*', findRichText: true), findsNothing);

    // No standing Retry: regenerating lives under the latest answer.
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.byTooltip('Regenerate'));
    expect(ask.retries, 1);

    // Sources stay folded into one pill until asked for.
    expect(find.text('Why hand-drawn animation still wins'), findsNothing);
    await tester.tap(find.text('2 sources'));
    await settle(tester);
    expect(find.text('Why hand-drawn animation still wins'), findsOneWidget);
    await preview(tester, 'ask_sources_open');

    expect(find.text('Save to a collection'), findsOneWidget);
    expect(
      find.text(
        'What other animated films have been recommended in my library?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('while answering, the send button stops it', (tester) async {
    final ask = await pumpAsk(
      tester,
      state: AskState(messages: [_conversation().first], isLoading: true),
    );
    await preview(tester, 'ask_thinking');
    expect(find.text('Looking through your saves…'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop'));
    expect(ask.stops, 1);
  });

  testWidgets('an empty chat greets with prompts to try', (tester) async {
    await pumpAsk(tester, state: const AskState());
    await preview(tester, 'ask_empty');
    expect(find.text('Ask anything across your 8 saves'), findsOneWidget);
    expect(find.text('Get the big idea'), findsOneWidget);
    // The card shows the whole title; the composer gets the whole question.
    await tester.tap(find.text('The quiet power of slow mornings'));
    await settle(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.controller!.text,
      'What’s the big idea in The quiet power of slow mornings?',
    );
    expect(UsageLimits.planAllowance(UsageFeature.ask), 30);
  });

  testWidgets('light theme preview', skip: !_preview, (tester) async {
    await pumpAsk(
      tester,
      state: AskState(messages: _conversation()),
      mode: ThemeMode.light,
    );
    await tester.tap(find.text('2 sources'));
    await settle(tester);
    await preview(tester, 'ask_light');
  });

  testWidgets('holding a question edits it in the message box', (tester) async {
    final ask = await pumpAsk(
      tester,
      state: AskState(messages: _conversation()),
    );
    final question = find.text('Explain It’s Just Cinema on Instagram');
    await tester.longPress(question);
    await settle(tester);
    await preview(tester, 'ask_hold_menu');
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Ask again'), findsOneWidget);

    await tester.tap(find.text('Edit message'));
    await settle(tester);
    // No dialog: the question is back in the composer, marked as an edit.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Editing your question'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Explain It’s Just Cinema on Instagram');
    await preview(tester, 'ask_editing');

    await tester.enterText(find.byType(TextField), 'Explain It’s Just Cinema');
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    expect(ask.edits, [('q', 'Explain It’s Just Cinema')]);
    expect(find.text('Editing your question'), findsNothing);
  });

  testWidgets('history groups chats and deleting leaves an undo', (
    tester,
  ) async {
    final now = DateTime.now();
    final ask = await pumpAsk(
      tester,
      state: AskState(messages: _conversation()),
      history: [
        _chat('a', 'Explain It’s Just Cinema on Instagram', now),
        _chat(
          'b',
          'Plan a weekend in Lisbon',
          now.subtract(const Duration(days: 1)),
        ),
        _chat(
          'c',
          'Books about memory',
          now.subtract(const Duration(days: 40)),
        ),
      ],
    );
    await tester.tap(find.byTooltip('Recent chats'));
    await settle(tester);
    await preview(tester, 'ask_history');
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Open now'), findsOneWidget);

    await tester.tap(find.byTooltip('More').at(1));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(ask.deleted, ['b']);
    expect(find.text('Chat deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(ask.restored, ['b']);
    expect(find.text('Plan a weekend in Lisbon'), findsOneWidget);
  });

  testWidgets('save to collection marks where these saves already are', (
    tester,
  ) async {
    final database = _Database();
    await pumpAsk(
      tester,
      state: AskState(messages: _conversation()),
      database: database,
      collections: [
        _collection(7, 'Animation', [1, 2]),
        _collection(8, 'Films to watch', [1]),
        _collection(9, 'Weekend reads', []),
      ],
    );
    await tester.tap(find.text('Save to a collection'));
    await settle(tester);
    await preview(tester, 'ask_collection_sheet');
    expect(find.text('Already here'), findsOneWidget);
    expect(find.text('1 already here'), findsOneWidget);

    await tester.tap(find.text('Weekend reads'));
    await settle(tester);
    expect(database.added[9], [1, 2]);
    expect(find.text('Added 2 saves to Weekend reads'), findsOneWidget);
  });

  group('new-chat suggestions', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final now = DateTime(2026, 10, 1, 9);

    test('draw on the library, never on platforms', () {
      final picks = buildAskSuggestions(_library(), l, now: now);
      expect(picks.map((p) => p.headline), [
        'Get the big idea',
        'Catch up on Productivity',
        'This week’s saves',
        'Revisit an old save',
      ]);
      expect(picks.map((p) => p.promptText), [
        'What’s the big idea in The quiet power of slow mornings?',
        'What have I learned about Productivity?',
        'What did I save this week?',
        'Remind me what A field guide to Lisbon’s miradouros was about',
      ]);
      expect(picks.first.display, 'The quiet power of slow mornings');
      expect(picks.any((p) => p.promptText.contains('Instagram')), isFalse);
    });

    test('an empty library asks how to start', () {
      final picks = buildAskSuggestions(const [], l, now: now);
      expect(picks.single.promptText, 'How do I save a link?');
    });

    test('titles drop site suffixes and skip one-word stand-ins', () {
      expect(cleanSuggestionTitle('Deep work | Medium'), 'Deep work');
      expect(cleanSuggestionTitle('https://example.com/a'), isNull);
      expect(cleanSuggestionTitle('@someone'), isNull);
      // A category standing in for a missing title.
      expect(cleanSuggestionTitle('Spirituality'), isNull);
    });
  });
}
