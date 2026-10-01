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

  test('shortcut icons are themed tiles, readable on dark launchers', () {
    const ids = <String>['capture', 'search', 'ask', 'rediscover'];
    const res = 'android/app/src/main/res';
    final light = File('$res/values/shortcut_colors.xml').readAsStringSync();
    final dark = File(
      '$res/values-night/shortcut_colors.xml',
    ).readAsStringSync();

    for (final id in ids) {
      final adaptive = File(
        '$res/drawable-anydpi-v26/shortcut_$id.xml',
      ).readAsStringSync();
      expect(adaptive, contains('<adaptive-icon'));
      expect(adaptive, contains('@color/shortcut_${id}_bg'));
      expect(adaptive, contains('<monochrome'), reason: 'themed icons');

      // A fixed glyph colour is what left the old icons black on dark.
      final legacy = File('$res/drawable/shortcut_$id.xml').readAsStringSync();
      final glyph = File(
        '$res/drawable/shortcut_${id}_glyph.xml',
      ).readAsStringSync();
      for (final xml in [legacy, glyph]) {
        expect(xml, isNot(contains('#FF1D1B20')));
        expect(xml, contains('@color/shortcut_${id}_fg'));
      }

      for (final role in ['bg', 'fg']) {
        expect(light, contains('name="shortcut_${id}_$role"'));
        expect(dark, contains('name="shortcut_${id}_$role"'));
      }
    }
  });

  test('both home screen widgets are registered with the launcher', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final provider in [
      ('.RediscoverWidgetProvider', '@xml/widget_rediscover_info'),
      ('.ActionBarWidgetProvider', '@xml/widget_action_bar_info'),
    ]) {
      expect(manifest, contains('android:name="${provider.$1}"'));
      expect(manifest, contains('android:resource="${provider.$2}"'));
    }
  });
}
