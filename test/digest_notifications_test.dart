import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/digest_notifications.dart';
import 'package:glimpse/core/services/digest_prefs.dart';
import 'package:glimpse/core/services/url_save_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('notification group summary', () {
    test('save status notification ids are stable and non-summary', () {
      final first = UrlSaveNotifications.notificationIdForSavedUrl(42);

      expect(first, UrlSaveNotifications.notificationIdForSavedUrl(42));
      expect(first, isNot(0));
      expect(first, greaterThanOrEqualTo(0x20000000));
      expect(first, lessThan(0x40000000));
      expect(first, isNot(UrlSaveNotifications.notificationIdForSavedUrl(43)));
    });

    test(
      'counts every active child while limiting neither count nor source',
      () {
        final active = <ActiveNotification>[
          for (var i = 1; i <= 7; i++)
            ActiveNotification(
              id: i,
              groupKey: 'glimpse_notifications',
              title: 'Notification $i',
            ),
          const ActiveNotification(
            id: 0,
            groupKey: 'glimpse_notifications',
            title: 'Glimpse',
          ),
          const ActiveNotification(
            id: 8,
            groupKey: 'another_group',
            title: 'Unrelated',
          ),
        ];

        final snapshot = DigestNotifications.snapshotForActiveNotifications(
          active,
        );

        expect(snapshot.count, 7);
        expect(snapshot.titles, hasLength(7));
        expect(snapshot.titles.last, 'Notification 7');
      },
    );
  });

  group('notification history', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('is persisted and announced immediately', () async {
      final changed = DigestPrefs.historyChanges.first;

      final historyId = await DigestPrefs.addDigestToHistory(
        ids: const [42],
        summaries: const ['A concise notification body.'],
        topic: 'Ready to revisit',
        type: 'resurface',
        notifId: 'notif_42',
        body: 'A concise notification body.',
      );

      await changed;
      final history = await DigestPrefs.loadHistory();
      expect(history, hasLength(1));
      expect(history.single['id'], historyId);
      expect(history.single['notifId'], 'notif_42');
      expect(history.single['ids'], [42]);
    });

    test('removes save status notifications from curated history', () async {
      SharedPreferences.setMockInitialValues({
        'digest_history': jsonEncode([
          {
            'id': 'save-status',
            'notifId': 'notif_save',
            'topic': 'Capturing what caught your eye.',
          },
          {
            'id': 'curated',
            'notifId': 'notif_curated',
            'topic': 'A collection worth revisiting',
          },
        ]),
        DigestPrefs.notifPayloadKey('notif_save'): jsonEncode({
          'type': 'url_capture_started',
        }),
        DigestPrefs.notifPayloadKey('notif_curated'): jsonEncode({'type': 'R'}),
      });

      final history = await DigestPrefs.loadHistory();

      expect(history, hasLength(1));
      expect(history.single['id'], 'curated');

      final preferences = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(preferences.getString('digest_history')!) as List<dynamic>;
      expect(stored, hasLength(1));
    });
  });
}
