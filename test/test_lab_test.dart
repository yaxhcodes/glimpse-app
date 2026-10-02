import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/test_lab.dart';
import 'package:glimpse/core/services/usage_limits.dart';
import 'package:glimpse/core/services/usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestLab.debugSetRunning(null));

  test('Play pre-launch robots never get a paid AI call', () async {
    TestLab.debugSetRunning(true);
    final usage = UsageService();
    for (final feature in UsageFeature.values) {
      expect(
        await usage.hasReachedLimit(feature, false),
        isTrue,
        reason: '$feature',
      );
      expect(await usage.hasReachedLocalLimit(feature, false), isTrue);
    }
  });

  test('people are unaffected', () async {
    TestLab.debugSetRunning(false);
    final usage = UsageService();
    expect(
      await usage.hasReachedLocalLimit(UsageFeature.aiSave, false),
      isFalse,
    );
  });

  test('off Android it is never a test robot', () async {
    expect(await TestLab.isRunning(), isFalse);
  });
}
