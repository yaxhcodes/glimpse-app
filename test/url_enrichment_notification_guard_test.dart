import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/url_enrichment_notification_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('publishes a terminal notification once per processing run', () async {
    var deliveries = 0;

    final first = await UrlEnrichmentNotificationGuard.deliverOnce(
      'processing-42',
      UrlEnrichmentNotificationOutcome.ready,
      () async => deliveries++,
    );
    final duplicate = await UrlEnrichmentNotificationGuard.deliverOnce(
      'processing-42',
      UrlEnrichmentNotificationOutcome.ready,
      () async => deliveries++,
    );
    final nextRun = await UrlEnrichmentNotificationGuard.deliverOnce(
      'processing-43',
      UrlEnrichmentNotificationOutcome.ready,
      () async => deliveries++,
    );

    expect(first, isTrue);
    expect(duplicate, isFalse);
    expect(nextRun, isTrue);
    expect(deliveries, 2);
  });

  test('does not consume the receipt when publication fails', () async {
    await expectLater(
      UrlEnrichmentNotificationGuard.deliverOnce(
        'processing-42',
        UrlEnrichmentNotificationOutcome.ready,
        () => Future<void>.error(StateError('notification failed')),
      ),
      throwsStateError,
    );

    var delivered = false;
    expect(
      await UrlEnrichmentNotificationGuard.deliverOnce(
        'processing-42',
        UrlEnrichmentNotificationOutcome.ready,
        () async => delivered = true,
      ),
      isTrue,
    );
    expect(delivered, isTrue);
  });

  test('tracks expected delivery until notification publication', () async {
    await UrlEnrichmentNotificationGuard.markDeliveryExpected('processing-42');

    expect(
      await UrlEnrichmentNotificationGuard.isDeliveryExpected(
        'processing-42',
      ),
      isTrue,
    );

    await UrlEnrichmentNotificationGuard.deliverOnce(
      'processing-42',
      UrlEnrichmentNotificationOutcome.ready,
      () async {},
    );

    expect(
      await UrlEnrichmentNotificationGuard.isDeliveryExpected(
        'processing-42',
      ),
      isFalse,
    );
  });

  test('legacy processing runs have no pending notification intent', () async {
    expect(
      await UrlEnrichmentNotificationGuard.shouldDeliverFor(
        'legacy-processing',
        notifyOnCompletion: true,
      ),
      isFalse,
    );
  });

  test('notification-disabled jobs remain silent when intent exists', () async {
    await UrlEnrichmentNotificationGuard.markDeliveryExpected('processing-42');

    expect(
      await UrlEnrichmentNotificationGuard.shouldDeliverFor(
        'processing-42',
        notifyOnCompletion: false,
      ),
      isFalse,
    );
  });

  test('ready replaces a prior failure but cannot regress afterward', () async {
    final delivered = <UrlEnrichmentNotificationOutcome>[];

    expect(
      await UrlEnrichmentNotificationGuard.deliverOnce(
        'processing-42',
        UrlEnrichmentNotificationOutcome.failed,
        () async => delivered.add(UrlEnrichmentNotificationOutcome.failed),
      ),
      isTrue,
    );
    expect(
      await UrlEnrichmentNotificationGuard.deliverOnce(
        'processing-42',
        UrlEnrichmentNotificationOutcome.ready,
        () async => delivered.add(UrlEnrichmentNotificationOutcome.ready),
      ),
      isTrue,
    );
    expect(
      await UrlEnrichmentNotificationGuard.deliverOnce(
        'processing-42',
        UrlEnrichmentNotificationOutcome.failed,
        () async => delivered.add(UrlEnrichmentNotificationOutcome.failed),
      ),
      isFalse,
    );
    expect(delivered, const [
      UrlEnrichmentNotificationOutcome.failed,
      UrlEnrichmentNotificationOutcome.ready,
    ]);
  });
}
