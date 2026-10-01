import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/providers/usage_providers.dart';
import 'package:glimpse/core/services/entitlement_service.dart';
import 'package:glimpse/core/services/subscription_service.dart';
import 'package:glimpse/features/settings/subscription_screen.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Package plan(String id, PackageType type, double price, String label) =>
      Package(
        id,
        type,
        StoreProduct(id, '', 'Glimpse Pro', price, label, 'USD'),
        const PresentedOfferingContext('default', null, null),
      );

  Future<void> pumpPlanPage(
    WidgetTester tester, {
    SubscriptionPlans? plans,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionTierProvider.overrideWith(_FreeTier.new),
          devProOverrideProvider.overrideWith(_NoOverride.new),
          subscriptionPlansProvider.overrideWith((ref) async => plans),
          remainingUsageProvider.overrideWith((ref, feature) async => 1),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Free shows usage, plans with prices, and the comparison', (
    tester,
  ) async {
    await pumpPlanPage(
      tester,
      plans: SubscriptionPlans(
        monthly: plan('monthly', PackageType.monthly, 4.99, r'$4.99'),
        yearly: plan('annual', PackageType.annual, 39.99, r'$39.99'),
      ),
    );

    expect(find.text('Glimpse Free'), findsOneWidget);
    expect(find.text('Your usage'), findsOneWidget);

    expect(find.text('29 of 30 free AI saves used'), findsOneWidget);

    // Yearly is the default pick, and the button carries its price.
    await tester.scrollUntilVisible(find.text('Monthly'), 200);
    await tester.ensureVisible(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text(r'$39.99 / year'), findsOneWidget);
    expect(find.text('Save 33%'), findsOneWidget);
    expect(find.text(r'Start Pro · $39.99 / year'), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text(r'Start Pro · $4.99 / month'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Multi-Link Synthesis'), 200);
    expect(find.text('Free and Pro'), findsOneWidget);
    expect(find.text('500 / month'), findsOneWidget);
    expect(find.text('Unlimited*'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('Terms of Service'), 200);
    expect(
      find.text(
        'Renews automatically until you cancel. '
        'Cancel anytime in Google Play.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without store prices the button stays generic', (tester) async {
    await pumpPlanPage(tester);
    expect(find.text('Choose a plan'), findsNothing);
    expect(find.text('Upgrade to Glimpse Pro'), findsOneWidget);
  });
}

class _FreeTier extends SubscriptionTierNotifier {
  @override
  Future<SubscriptionTier> build() async => SubscriptionTier.free;
}

class _NoOverride extends DevProOverrideNotifier {
  @override
  Future<bool> build() async => false;
}
