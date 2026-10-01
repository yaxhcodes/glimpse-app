import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/core/services/reminders/reminder_times.dart';
import 'package:glimpse/features/collections/share_capture_sheet.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/reminders/coming_up_section.dart';
import 'package:glimpse/features/reminders/reminder_flow.dart';
import 'package:glimpse/shared/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boundary = ValueKey('reminders-golden');
const _seed = Color(0xFF6750A4);

class _FakeIsarService implements IsarService {
  @override
  Future<List<UserCollection>> getAllCollections() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
}

SavedUrl _save(
  int id,
  String title,
  DateTime remindAt, {
  bool ring = false,
  String? repeat,
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = id.isEven ? 'instagram.com' : 'youtube.com'
    ..title = title
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = 'O'
    ..categories = ['Other']
    ..tags = []
    ..savedAt = DateTime(2026, 9, 1)
    ..remindAt = remindAt
    ..remindRing = ring
    ..remindRepeat = repeat;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // A Tuesday morning: every quick pick is on offer.
  final now = DateTime(2026, 10, 6, 9, 10);
  setUp(() {
    reminderClock = () => now;
    // The save card reads swipe preferences and keeps an image cache.
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });
  tearDown(() => reminderClock = DateTime.now);

  setUpAll(() async {
    await initializeDateFormatting('en');
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

  Future<void> pumpAt390(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(_FakeIsarService()),
          ...overrides,
        ],
        child: RepaintBoundary(
          key: _boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(_seed),
            home: child,
          ),
        ),
      ),
    );
  }

  Future<void> expectGolden(WidgetTester tester, String path) async {
    for (final element in tester.allElements) {
      element.renderObject?.markNeedsPaint();
    }
    await tester.pump();
    await expectLater(find.byKey(_boundary), matchesGoldenFile(path));
  }

  testWidgets('the save pill offers Remind and sets the reminder', (
    tester,
  ) async {
    DateTime? remindedAt;
    late Future<ShareCaptureOutcome?> result;
    await pumpAt390(
      tester,
      Scaffold(
        backgroundColor: Colors.blueGrey.shade100,
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => result = showShareCapture(
                context,
                onCapture: (_, _) async => const ShareCaptureOutcome(
                  type: ShareCaptureOutcomeType.captured,
                  savedUrlId: 7,
                ),
                onRemind: (at) async {
                  remindedAt = at;
                  return const ShareCaptureOutcome(
                    type: ShareCaptureOutcomeType.captured,
                    savedUrlId: 7,
                  );
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remind me'), findsOneWidget);
    expect(find.text('Saved to Glimpse'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectGolden(tester, 'goldens/reminder_pill.png');

    await tester.tap(find.byTooltip('Remind me'));
    await tester.pumpAndSettle();
    expect(find.text('Remind me'), findsOneWidget);
    await expectGolden(tester, 'goldens/reminder_pill_panel.png');

    await tester.tap(find.textContaining('Tomorrow morning'));
    await tester.pumpAndSettle();
    expect(remindedAt, isNotNull);
    expect(remindedAt!.hour, 9);
    expect(find.textContaining('Reminder set'), findsOneWidget);
    expect(find.byTooltip('Remind me'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(await result, isNotNull);
  });

  testWidgets('the reminder sheet offers picks, a custom time and Ring', (
    tester,
  ) async {
    ReminderChoice? picked;
    await pumpAt390(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                picked = await showModalBottomSheet<ReminderChoice>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) =>
                      ReminderSheet(current: DateTime(2026, 10, 8, 18, 30)),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Change reminder'), findsOneWidget);
    expect(find.text('Pick a date & time'), findsOneWidget);
    expect(find.text('Remove reminder'), findsOneWidget);
    await expectGolden(tester, 'goldens/reminder_sheet.png');

    expect(find.text('Repeat'), findsOneWidget);
    await tester.tap(find.text('Every day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ring at the exact time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow morning'));
    await tester.pumpAndSettle();
    expect(picked?.at?.hour, 9);
    expect(picked?.ring, isTrue);
    expect(picked?.repeat, ReminderRepeat.daily);
  });

  testWidgets('Coming up shows only what is due in the next day', (
    tester,
  ) async {
    final today = DateTime(now.year, now.month, now.day);
    final saves = [
      _save(
        2,
        'Weekend market in Bandra',
        today.add(const Duration(days: 3, hours: 10)),
      ),
      _save(3, 'Morning motivation', DateTime(2026, 9, 1, 7), repeat: 'daily'),
      _save(
        1,
        'How to fix a leaking tap',
        today.add(const Duration(days: 1, hours: 9)),
        ring: true,
      ),
    ];
    var seeAll = 0;
    await pumpAt390(
      tester,
      Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: ComingUpSection(onSeeAll: () => seeAll++),
          ),
        ),
      ),
      overrides: [urlStreamProvider.overrideWith((ref) => Stream.value(saves))],
    );
    await tester.pumpAndSettle();
    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Due in the next day'), findsOneWidget);
    // Next due first: the daily 7:00 tomorrow, then the 9:00 one.
    final motivation = tester.getTopLeft(find.text('Morning motivation'));
    final tap = tester.getTopLeft(find.text('How to fix a leaking tap'));
    expect(motivation.dy, lessThan(tap.dy));
    // Three days out waits in the Reminders filter.
    expect(find.text('Weekend market in Bandra'), findsNothing);
    await expectGolden(tester, 'goldens/reminder_coming_up.png');

    await tester.tap(find.text('Coming up'));
    expect(seeAll, 1);
  });

  testWidgets('a reminder days away keeps Coming up off Home', (tester) async {
    final saves = [_save(2, 'Weekend market', DateTime(2026, 10, 9, 10))];
    await pumpAt390(
      tester,
      const Scaffold(body: ComingUpSection()),
      overrides: [urlStreamProvider.overrideWith((ref) => Stream.value(saves))],
    );
    await tester.pumpAndSettle();
    expect(find.text('Coming up'), findsNothing);
  });

  testWidgets('nothing coming up shows nothing', (tester) async {
    await pumpAt390(
      tester,
      const Scaffold(body: ComingUpSection()),
      overrides: [
        urlStreamProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Coming up'), findsNothing);
  });
}
