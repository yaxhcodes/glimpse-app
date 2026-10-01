import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/engagement_event.dart';
import 'package:glimpse/core/models/glimpse_record.dart';
import 'package:glimpse/core/models/place_itinerary.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/models/vault_item.dart';
import 'package:glimpse/core/services/backup/backup_models.dart';
import 'package:glimpse/core/services/notification_action_handler.dart';
import 'package:glimpse/core/services/reminders/reminder_times.dart';
import 'package:glimpse/core/services/reminders/save_reminders.dart';
import 'package:glimpse/l10n/generated/app_localizations_en.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Isar database;
  late IsarService service;

  setUpAll(() async {
    final pubCache =
        Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows
            ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
            : '${Platform.environment['HOME']}/.pub-cache');
    final packageRoot =
        '$pubCache${Platform.pathSeparator}hosted${Platform.pathSeparator}pub.dev'
        '${Platform.pathSeparator}isar_flutter_libs-3.1.0+1';
    final libraryPath = Platform.isWindows
        ? '$packageRoot${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll'
        : Platform.isMacOS
        ? '$packageRoot${Platform.pathSeparator}macos${Platform.pathSeparator}libisar.dylib'
        : '$packageRoot${Platform.pathSeparator}linux${Platform.pathSeparator}libisar.so';
    await Isar.initializeIsarCore(libraries: {Abi.current(): libraryPath});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('glimpse-remind-');
    database = await Isar.open([
      SavedUrlSchema,
      GlimpseRecordSchema,
      UserCollectionSchema,
      EngagementEventSchema,
      PlaceItinerarySchema,
      VaultItemSchema,
    ], directory: tempDirectory.path);
    service = IsarService();
    await service.ensureInitialized();
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<SavedUrl> saved(String path) async {
    final url = SavedUrl()
      ..rawUrl = 'https://example.com/$path'
      ..domain = 'example.com'
      ..title = 'Saved $path'
      ..description = ''
      ..category = 'Other'
      ..categoryEmoji = 'O'
      ..categories = ['Other']
      ..tags = []
      ..savedAt = DateTime.utc(2026, 1, 1);
    await service.saveUrl(url);
    return url;
  }

  NotificationResponse action(String actionId, int urlId) =>
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: actionId,
        id: SaveReminders.notificationIdFor(urlId),
        payload: jsonEncode({
          'type': SaveReminders.notificationType,
          'route': 'url_detail',
          'linkIds': [urlId],
          'notifId': 'reminder_$urlId',
          'firedAt': DateTime.now().toIso8601String(),
        }),
      );

  test('reminders are stored, listed soonest first, and cleared', () async {
    final a = await saved('a');
    final b = await saved('b');
    final soon = DateTime.now().add(const Duration(hours: 2));
    final later = DateTime.now().add(const Duration(days: 3));

    await SaveReminders.set(service, a.id, later, ring: true);
    await SaveReminders.set(service, b.id, soon);

    final upcoming = await service.getUpcomingReminders();
    expect(upcoming.map((u) => u.id), [b.id, a.id]);
    expect(upcoming.last.remindRing, isTrue);

    await SaveReminders.set(service, a.id, null);
    final cleared = await service.getUrlById(a.id);
    expect(cleared?.remindAt, isNull);
    expect(cleared?.remindRing, isFalse);
  });

  test('a save in the Bin has no upcoming reminder until restored', () async {
    final url = await saved('binned');
    await SaveReminders.set(
      service,
      url.id,
      DateTime.now().add(const Duration(hours: 5)),
    );
    await service.moveUrlToBin(url.id);
    expect(await service.getUpcomingReminders(), isEmpty);

    await service.restoreUrlFromBin(url.id);
    expect((await service.getUpcomingReminders()).single.id, url.id);
  });

  test(
    'Snooze on a reminder brings it back in an hour, keeping Ring',
    () async {
      final url = await saved('snooze');
      await SaveReminders.set(
        service,
        url.id,
        DateTime.now().add(const Duration(minutes: 1)),
        ring: true,
      );
      final before = DateTime.now();

      expect(
        await NotificationActionHandler.handleIfAction(
          action(NotificationActions.snooze, url.id),
        ),
        isTrue,
      );

      final updated = await service.getUrlById(url.id);
      expect(
        updated!.remindAt!.difference(before).inMinutes,
        inInclusiveRange(59, 61),
      );
      expect(updated.remindRing, isTrue);
      // A reminder's Snooze is its own; it doesn't push the save three days.
      expect(updated.intentStatus, isNull);
    },
  );

  test('Done on a reminder settles it and marks the save done', () async {
    final url = await saved('done');
    await SaveReminders.set(
      service,
      url.id,
      DateTime.now().add(const Duration(minutes: 1)),
    );

    await NotificationActionHandler.handleIfAction(
      action(NotificationActions.markDone, url.id),
    );

    final updated = await service.getUrlById(url.id);
    expect(updated?.remindAt, isNull);
    expect(updated?.intentStatus, 'done');
    expect(updated?.intentAction, 'reminder_done');
  });

  test('launch forgets reminders long past and keeps future ones', () async {
    final old = await saved('old');
    final future = await saved('future');
    await service.setReminder(
      old.id,
      DateTime.now().subtract(const Duration(days: 3)),
    );
    await service.setReminder(
      future.id,
      DateTime.now().add(const Duration(days: 3)),
    );

    await SaveReminders.reconcile(service);

    expect((await service.getUrlById(old.id))?.remindAt, isNull);
    expect((await service.getUrlById(future.id))?.remindAt, isNotNull);
  });

  test('a backup carries the reminder and its Ring', () {
    final at = DateTime.utc(2026, 11, 2, 9);
    final link = SavedUrlBackup.fromJson({
      'rawUrl': 'https://example.com/x',
      'domain': 'example.com',
      'title': 'X',
      'description': '',
      'category': 'Other',
      'categoryEmoji': 'O',
      'categories': ['Other'],
      'tags': <String>[],
      'savedAt': '2026-01-01T00:00:00.000Z',
      'remindAt': at.toIso8601String(),
      'remindRing': true,
    });
    expect(link.remindAt, at.toIso8601String());
    expect(link.remindRing, isTrue);
    final json = link.toJson();
    expect(json['remindAt'], at.toIso8601String());
    expect(json['remindRing'], isTrue);
  });

  group('repeating reminders', () {
    test('stay upcoming after their first time has passed', () async {
      final url = await saved('daily');
      await SaveReminders.set(
        service,
        url.id,
        DateTime.now().add(const Duration(minutes: 5)),
        repeat: ReminderRepeat.daily,
      );
      await service.setReminder(
        url.id,
        DateTime.now().subtract(const Duration(days: 4)),
        repeat: 'daily',
      );

      expect((await service.getUpcomingReminders()).single.id, url.id);
      await SaveReminders.reconcile(service);
      final kept = await service.getUrlById(url.id);
      expect(kept?.remindRepeat, 'daily');
      expect(kept?.remindAt, isNotNull);
    });

    test('Done clears today only; the repeat and the save carry on', () async {
      final url = await saved('daily-done');
      await SaveReminders.set(
        service,
        url.id,
        DateTime.now().add(const Duration(minutes: 1)),
        repeat: ReminderRepeat.weekdays,
      );

      await NotificationActionHandler.handleIfAction(
        action(NotificationActions.markDone, url.id),
      );

      final updated = await service.getUrlById(url.id);
      expect(updated?.remindRepeat, 'weekdays');
      expect(updated?.remindAt, isNotNull);
      expect(updated?.intentStatus, isNull);
    });

    test('Snooze adds one more without moving the repeat', () async {
      final url = await saved('daily-snooze');
      final anchor = DateTime.now().add(const Duration(minutes: 1));
      await SaveReminders.set(
        service,
        url.id,
        anchor,
        repeat: ReminderRepeat.daily,
      );

      await NotificationActionHandler.handleIfAction(
        action(NotificationActions.snooze, url.id),
      );

      final updated = await service.getUrlById(url.id);
      expect(updated?.remindAt, anchor);
      expect(updated?.remindRepeat, 'daily');
    });

    test('removing a repeating reminder stops it for good', () async {
      final url = await saved('daily-remove');
      await SaveReminders.set(
        service,
        url.id,
        DateTime.now().add(const Duration(hours: 1)),
        repeat: ReminderRepeat.weekly,
      );
      await SaveReminders.set(service, url.id, null);
      final updated = await service.getUrlById(url.id);
      expect(updated?.remindAt, isNull);
      expect(updated?.remindRepeat, isNull);
      expect(await service.getUpcomingReminders(), isEmpty);
    });
  });

  group('notification wording', () {
    final strings = AppLocalizationsEn();
    SavedUrl url({
      String domain = 'example.com',
      String path = 'post',
      String category = 'Other',
      String? intent,
    }) => SavedUrl()
      ..rawUrl = 'https://$domain/$path'
      ..domain = domain
      ..title = 'T'
      ..description = ''
      ..category = category
      ..categoryEmoji = 'O'
      ..categories = [category]
      ..tags = []
      ..intentAction = intent
      ..savedAt = DateTime.utc(2026);

    String lead(SavedUrl u, [ReminderRepeat r = ReminderRepeat.none]) =>
        SaveReminders.leadFor(strings, u, r);

    test('says what to do with it', () {
      expect(lead(url(domain: 'youtube.com')), 'Time to watch');
      expect(
        lead(url(domain: 'instagram.com', path: 'reel/abc')),
        'Time to watch',
      );
      expect(lead(url(category: 'Food & Cooking')), 'Time to cook');
      expect(lead(url(intent: 'read_later')), 'Time to read');
      expect(lead(url(intent: 'try_this_weekend')), 'Time to try it');
      expect(lead(url(domain: 'open.spotify.com')), 'Time to listen');
      expect(lead(url()), 'Time to come back to this');
    });

    test("the person's own intent beats the site", () {
      expect(
        lead(url(domain: 'youtube.com', intent: 'learn_this')),
        'Time to learn',
      );
    });

    test('a repeating link is a daily or weekly one', () {
      expect(
        lead(url(domain: 'youtube.com'), ReminderRepeat.daily),
        'Your daily link',
      );
      expect(lead(url(), ReminderRepeat.weekdays), 'Your daily link');
      expect(lead(url(), ReminderRepeat.weekly), 'Your weekly link');
    });
  });
}
