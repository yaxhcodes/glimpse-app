import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android shortcut resources explicitly target both app flavors', () {
    const resources = <String, String>{
      'android/app/src/main/res/xml/shortcuts.xml': 'com.shinrinyoku.glimpse',
      'android/app/src/dev/res/xml/shortcuts.xml':
          'com.shinrinyoku.glimpse.dev',
    };
    const actions = <String>['CAPTURE', 'SEARCH', 'ASK', 'REDISCOVER'];

    for (final entry in resources.entries) {
      final xml = File(entry.key).readAsStringSync();
      expect(
        RegExp(
          'android:targetPackage="${RegExp.escape(entry.value)}"',
        ).allMatches(xml),
        hasLength(4),
        reason: '${entry.key} must use an explicit flavor package.',
      );
      expect(xml, isNot(contains('@string/shortcut_target_package')));
      expect(
        RegExp(
          'android:targetClass="com\\.shinrinyoku\\.glimpse\\.MainActivity"',
        ).allMatches(xml),
        hasLength(4),
      );
      for (final action in actions) {
        expect(
          xml,
          contains('com.shinrinyoku.glimpse.action.$action'),
          reason: '${entry.key} is missing $action.',
        );
      }
    }

    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:name="android.app.shortcuts"'));
    expect(manifest, contains('android:resource="@xml/shortcuts"'));
  });
}
