import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android protects share enrichment with one deferred data-sync service',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final service = File(
        'android/app/src/main/kotlin/com/shinrinyoku/glimpse/'
        'EnrichmentKeepAliveService.kt',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'),
      );
      expect(manifest, contains('android.permission.WAKE_LOCK'));
      expect(manifest, contains('android:foregroundServiceType="dataSync"'));
      expect(
        service,
        contains('private const val NOTIFICATION_ID = 0x10000001'),
      );
      expect(service, contains('startForeground(NOTIFICATION_ID'));
      expect(
        service,
        contains('NotificationCompat.FOREGROUND_SERVICE_DEFERRED'),
      );
      expect(service, contains('setSilent(true)'));
      expect(service, contains('linkedSetOf<String>()'));
      expect(service, contains('PARTIAL_WAKE_LOCK'));
    },
  );
}
