import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release shrinking keeps what scheduled notifications need', () {
    // Without these, R8 drops the generic signatures on the Gson TypeTokens
    // flutter_local_notifications uses, and every reminder or digest crashes
    // the release app when it fires. Debug builds never show it.
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    expect(rules, contains('-keepattributes Signature'));
    expect(
      rules,
      contains('class * extends com.google.gson.reflect.TypeToken'),
    );
    expect(
      rules,
      contains('-keep class com.dexterous.flutterlocalnotifications.** { *; }'),
    );
  });

  test('the share sheet never registers the splash exit handoff', () {
    final activity = File(
      'android/app/src/main/kotlin/com/shinrinyoku/glimpse/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('this !is ShareActivity'));
    expect(activity, contains('clearOnExitAnimationListener()'));
  });
}
