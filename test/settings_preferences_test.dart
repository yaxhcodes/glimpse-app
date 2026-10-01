import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/analytics_consent.dart';
import 'package:glimpse/core/services/app_haptics.dart';
import 'package:glimpse/core/services/subscription_service.dart';
import 'package:glimpse/features/glimpses/glimpse.dart';
import 'package:glimpse/features/glimpses/glimpse_notification_prefs.dart';
import 'package:glimpse/features/settings/privacy_screen.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('haptics level', () {
    const channel = MethodChannel('com.shinrinyoku.glimpse/haptics');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> sent;

    setUp(() {
      sent = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent.add(call);
        return null;
      });
    });

    tearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await AppHaptics.setLevel(HapticsLevel.full);
    });

    test('off plays nothing, subtle plays the softest touch', () async {
      await AppHaptics.setLevel(HapticsLevel.off);
      await AppHaptics.play(AppHaptics.success);
      expect(sent, isEmpty);

      await AppHaptics.setLevel(HapticsLevel.subtle);
      await AppHaptics.play(AppHaptics.success);
      final args = sent.single.arguments as Map;
      expect(args['system'], [
        ['textHandleMove', 0],
        ['textHandleMove', 70],
      ]);
      for (final step in args['steps'] as List) {
        expect(step[1] as double, lessThanOrEqualTo(.35));
      }
    });

    test('the level survives a restart', () async {
      await AppHaptics.setLevel(HapticsLevel.subtle);
      AppHaptics.level = HapticsLevel.full;
      await AppHaptics.loadLevel();
      expect(AppHaptics.level, HapticsLevel.subtle);
    });
  });

  group('notification preferences', () {
    test('defaults allow every kind between 9 and 9', () async {
      final prefs = await GlimpseNotificationPrefs.load();
      expect(prefs.enabledCount, 4);
      expect(prefs.startHour, 9);
      expect(prefs.endHour, 21);
    });

    test('kinds and hours persist', () async {
      await GlimpseNotificationPrefs.setKindEnabled(GlimpseKind.idea, false);
      await GlimpseNotificationPrefs.setKindEnabled(GlimpseKind.weekly, false);
      await GlimpseNotificationPrefs.setKindEnabled(GlimpseKind.weekly, true);
      await GlimpseNotificationPrefs.setWindow(18, 22);
      final prefs = await GlimpseNotificationPrefs.load();
      expect(prefs.allows(GlimpseKind.idea), isFalse);
      expect(prefs.allows(GlimpseKind.weekly), isTrue);
      expect(prefs.enabledCount, 3);
      expect((prefs.startHour, prefs.endHour), (18, 22));
    });
  });

  test('yearly saving compares a year with twelve months', () {
    expect(
      SubscriptionPlans.savingPercent(monthlyPrice: 4.99, yearlyPrice: 39.99),
      33,
    );
    expect(
      SubscriptionPlans.savingPercent(monthlyPrice: 5, yearlyPrice: 60),
      isNull,
    );
    expect(SubscriptionPlans.savingPercent(yearlyPrice: 39.99), isNull);
  });

  testWidgets('Privacy turns usage analytics off and remembers it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          home: const PrivacyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // What leaves the phone is named honestly.
    await tester.scrollUntilVisible(find.text('Questions you ask'), 200);
    expect(find.text('Links you save'), findsOneWidget);

    final analytics = find.text('Usage analytics');
    await tester.scrollUntilVisible(analytics, 200);
    final toggle = find.descendant(
      of: find.ancestor(of: analytics, matching: find.byType(InkWell)).first,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(AnalyticsConsent.enabled, isFalse);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getBool(AnalyticsConsent.preferenceKey), isFalse);
    expect(
      find.text('Off — nothing about how you use Glimpse is sent'),
      findsOneWidget,
    );
  });
}
