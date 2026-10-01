import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/l10n.dart';
import '../../database/isar_service.dart';
import '../../models/saved_url.dart';
import '../notification_action_handler.dart';
import '../title_resolver.dart';
import 'reminder_times.dart';

/// What happened when a reminder was set.
enum ReminderScheduling {
  /// Scheduled as asked.
  scheduled,

  /// Ring was asked for but exact alarms aren't allowed, so it was scheduled
  /// to arrive about on time instead.
  inexactFallback,

  /// Stored, but the notification couldn't be scheduled.
  failed,
}

/// Reminders the person sets on their saves: a stored time on the save
/// ([SavedUrl.remindAt]) and a notification Android delivers at it, whether
/// or not Glimpse is running.
///
/// Static, like the rest of the notification code, so the background
/// isolate that handles Snooze and Done can use it too.
class SaveReminders {
  SaveReminders._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const notificationType = 'reminder';
  static const _channelId = 'glimpse_reminders_v1';
  static const _ringChannelId = 'glimpse_reminders_ring_v1';
  static const snoozeFor = Duration(hours: 1);
  static const _alarmSound = 'content://settings/system/alarm_alert';

  /// Reminder notifications live in their own id range (save status uses
  /// 0x20000000, Glimpses 0x40000000), one per save.
  static int notificationIdFor(int urlId) =>
      0x60000000 + (urlId.abs() & 0x1fffffff);

  /// A save's extra reminder slots: 0 is a snoozed repeat, 1–5 are Monday to
  /// Friday for a weekdays reminder.
  static int _slotIdFor(int urlId, int slot) =>
      0x70000000 + ((urlId.abs() & 0x01ffffff) << 3) + slot;

  /// Sets (or with [at] null, removes) the reminder on [urlId] and schedules
  /// it. [at] is the first time it goes off; [repeat] brings it back.
  static Future<ReminderScheduling> set(
    IsarService isar,
    int urlId,
    DateTime? at, {
    bool ring = false,
    ReminderRepeat repeat = ReminderRepeat.none,
  }) async {
    final url = await isar.setReminder(
      urlId,
      at,
      ring: ring,
      repeat: repeat.stored,
    );
    await cancel(urlId);
    if (url == null || at == null) return ReminderScheduling.scheduled;
    return schedule(url);
  }

  /// Schedules [url]'s reminder; nothing when it has none, a one-off one is
  /// past, or the save is in the Bin.
  static Future<ReminderScheduling> schedule(SavedUrl url) async {
    final anchor = url.remindAt;
    final repeat = ReminderRepeat.parse(url.remindRepeat);
    if (anchor == null || url.deletedAt != null) {
      return ReminderScheduling.scheduled;
    }
    if (!repeat.repeats && !anchor.isAfter(DateTime.now())) {
      return ReminderScheduling.scheduled;
    }
    try {
      final strings = await loadBackgroundLocalizations();
      await _ensureChannels(strings);
      var exact = url.remindRing;
      if (exact && !await canRingExactly()) exact = false;
      final now = DateTime.now();

      Future<void> at(int id, DateTime when, {DateTimeComponents? every}) =>
          _plugin.zonedSchedule(
            id,
            leadFor(strings, url, repeat),
            _body(url),
            // An absolute instant: the local wall-clock time was already
            // resolved (DST included) when [when] was made. A repeat keeps the
            // same instant each day or week.
            tz.TZDateTime.from(when.toUtc(), tz.UTC),
            NotificationDetails(
              android: _details(strings, ring: exact, body: _body(url)),
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: every,
            payload: _payload(url, when, repeat),
          );

      switch (repeat) {
        case ReminderRepeat.none:
          await at(notificationIdFor(url.id), anchor);
        case ReminderRepeat.daily:
          await at(
            notificationIdFor(url.id),
            nextReminderOccurrence(anchor, repeat, now: now),
            every: DateTimeComponents.time,
          );
        case ReminderRepeat.weekly:
          await at(
            notificationIdFor(url.id),
            nextReminderOccurrence(anchor, repeat, now: now),
            every: DateTimeComponents.dayOfWeekAndTime,
          );
        case ReminderRepeat.weekdays:
          // One weekly repeat per weekday, each from its first time on or
          // after the anchor.
          final first = nextReminderOccurrence(anchor, repeat, now: now);
          for (var i = 0; i < 7; i++) {
            final day = DateTime(
              first.year,
              first.month,
              first.day + i,
              first.hour,
              first.minute,
            );
            if (day.weekday > DateTime.friday) continue;
            await at(
              _slotIdFor(url.id, day.weekday),
              day,
              every: DateTimeComponents.dayOfWeekAndTime,
            );
          }
      }
      return url.remindRing && !exact
          ? ReminderScheduling.inexactFallback
          : ReminderScheduling.scheduled;
    } catch (error, stackTrace) {
      developer.log(
        'Could not schedule a reminder.',
        name: 'SaveReminders',
        error: error,
        stackTrace: stackTrace,
      );
      return ReminderScheduling.failed;
    }
  }

  /// Snooze on a repeating reminder: one extra time, an hour out, leaving
  /// the repeat as it was.
  static Future<void> snoozeOnce(SavedUrl url, DateTime from) async {
    try {
      final strings = await loadBackgroundLocalizations();
      await _ensureChannels(strings);
      final exact = url.remindRing && await canRingExactly();
      final when = from.add(snoozeFor);
      final repeat = ReminderRepeat.parse(url.remindRepeat);
      await _plugin.zonedSchedule(
        _slotIdFor(url.id, 0),
        leadFor(strings, url, repeat),
        _body(url),
        tz.TZDateTime.from(when.toUtc(), tz.UTC),
        NotificationDetails(
          android: _details(strings, ring: exact, body: _body(url)),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _payload(url, when, repeat),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not snooze a repeating reminder.',
        name: 'SaveReminders',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> cancel(int urlId) async {
    for (final id in [
      notificationIdFor(urlId),
      for (var slot = 0; slot <= 5; slot++) _slotIdFor(urlId, slot),
    ]) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  /// Brings [urlIds]' notifications in line with what's stored: after the
  /// Bin, an undo, a restore, or a move into the Vault.
  static Future<void> sync(IsarService isar, Iterable<int> urlIds) async {
    for (final id in urlIds.toSet()) {
      await cancel(id);
      final url = await isar.getUrlById(id);
      if (url != null) await schedule(url);
    }
  }

  /// At launch: schedules every live reminder again (a restored backup, a
  /// reinstall, a cleared alarm) and forgets one-off ones long past.
  static Future<void> reconcile(IsarService isar) async {
    final now = DateTime.now();
    for (final url in await isar.getAllWithReminders()) {
      final at = url.remindAt!;
      final repeats = ReminderRepeat.parse(url.remindRepeat).repeats;
      if (repeats || at.isAfter(now)) {
        await cancel(url.id);
        await schedule(url);
      } else if (now.difference(at) > const Duration(days: 1)) {
        await isar.setReminder(url.id, null);
      }
    }
  }

  /// The notification's first line, worded by what the save is: "Time to
  /// watch", "Time to read", "Your daily link".
  static String leadFor(
    AppLocalizations strings,
    SavedUrl url,
    ReminderRepeat repeat,
  ) {
    switch (repeat) {
      case ReminderRepeat.daily:
      case ReminderRepeat.weekdays:
        return strings.reminderLeadDaily;
      case ReminderRepeat.weekly:
        return strings.reminderLeadWeekly;
      case ReminderRepeat.none:
        break;
    }
    return switch (_kindOf(url)) {
      _Kind.watch => strings.reminderLeadWatch,
      _Kind.read => strings.reminderLeadRead,
      _Kind.cook => strings.reminderLeadCook,
      _Kind.listen => strings.reminderLeadListen,
      _Kind.plan => strings.reminderLeadPlan,
      _Kind.buy => strings.reminderLeadBuy,
      _Kind.learn => strings.reminderLeadLearn,
      _Kind.tryIt => strings.reminderLeadTry,
      _Kind.revisit => strings.reminderLeadRevisit,
    };
  }

  /// What the person meant to do with it: their own intent first, then the
  /// save's topic, then the kind of site it's from.
  static _Kind _kindOf(SavedUrl url) {
    bool has(String text, List<String> words) => words.any(text.contains);
    final intent = (url.intentAction ?? '').toLowerCase();
    if (intent.isNotEmpty) {
      if (has(intent, ['watch'])) return _Kind.watch;
      if (has(intent, ['read'])) return _Kind.read;
      if (has(intent, ['cook', 'recipe'])) return _Kind.cook;
      if (has(intent, ['listen'])) return _Kind.listen;
      if (has(intent, ['visit', 'plan', 'trip', 'travel'])) return _Kind.plan;
      if (has(intent, ['buy', 'shop'])) return _Kind.buy;
      if (has(intent, ['learn', 'study', 'practice'])) return _Kind.learn;
      if (has(intent, ['try', 'make', 'build'])) return _Kind.tryIt;
    }
    final category = url.category.toLowerCase();
    if (has(category, ['food', 'cook', 'recipe'])) return _Kind.cook;
    if (has(category, ['music'])) return _Kind.listen;
    if (has(category, ['travel'])) return _Kind.plan;
    if (has(category, ['shopping', 'fashion'])) return _Kind.buy;
    if (has(category, ['education'])) return _Kind.learn;
    if (has(category, ['entertainment', 'movie', 'film'])) return _Kind.watch;
    final address = '${url.domain} ${url.rawUrl}'.toLowerCase();
    if (has(address, [
      'youtube.',
      'youtu.be',
      'tiktok.',
      'netflix.',
      'primevideo.',
      'hotstar.',
      '/reel',
    ])) {
      return _Kind.watch;
    }
    if (has(address, ['spotify.', 'music.apple.', 'soundcloud.'])) {
      return _Kind.listen;
    }
    if (has(address, ['medium.', 'substack.', '/blog', '/article'])) {
      return _Kind.read;
    }
    return _Kind.revisit;
  }

  /// The save's title, then the person's own note if they left one.
  static String _body(SavedUrl url) {
    final title = TitleResolver.resolveDetailTitle(url);
    final note = url.userNotes?.trim() ?? '';
    return note.isEmpty ? title : '$title\n$note';
  }

  static String _payload(SavedUrl url, DateTime when, ReminderRepeat repeat) =>
      jsonEncode({
        'type': notificationType,
        'route': 'url_detail',
        'linkIds': [url.id],
        'notifId': 'reminder_${url.id}_${when.millisecondsSinceEpoch}',
        'firedAt': when.toIso8601String(),
        if (repeat.repeats) 'repeat': repeat.name,
      });

  /// Whether Android lets Glimpse fire on the exact minute.
  static Future<bool> canRingExactly() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.canScheduleExactNotifications() ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens Android's "Alarms & reminders" setting; true once allowed.
  static Future<bool> requestRingPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestExactAlarmsPermission();
      return canRingExactly();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static AndroidNotificationDetails _details(
    AppLocalizations strings, {
    required bool ring,
    required String body,
  }) {
    final actions = [
      AndroidNotificationAction(
        NotificationActions.markDone,
        strings.done,
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        NotificationActions.snooze,
        strings.reminderSnooze,
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];
    if (!ring) {
      return AndroidNotificationDetails(
        _channelId,
        strings.reminderChannelName,
        channelDescription: strings.reminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body),
        icon: 'ic_notification',
        actions: actions,
      );
    }
    return AndroidNotificationDetails(
      _ringChannelId,
      strings.reminderRingChannelName,
      channelDescription: strings.reminderChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const UriAndroidNotificationSound(_alarmSound),
      // Keeps sounding until it's answered, like an alarm, without taking
      // over the screen.
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
      styleInformation: BigTextStyleInformation(body),
      icon: 'ic_notification',
      actions: actions,
    );
  }

  static Future<void> _ensureChannels(AppLocalizations strings) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        strings.reminderChannelName,
        description: strings.reminderChannelDescription,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _ringChannelId,
        strings.reminderRingChannelName,
        description: strings.reminderChannelDescription,
        importance: Importance.max,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: const UriAndroidNotificationSound(_alarmSound),
      ),
    );
  }
}

enum _Kind { watch, read, cook, listen, plan, buy, learn, tryIt, revisit }
