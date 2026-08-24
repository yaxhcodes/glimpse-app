import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/app_task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.shinrinyoku.glimpse/app_task');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('moves the Android task behind the sharing app', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'moveToBackground');
      return true;
    });

    final service = AppTaskService(channel: channel, isAndroid: true);

    expect(await service.moveToBackground(), isTrue);
  });

  test('starts and finishes enrichment background protection', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'startEnrichmentKeepAlive' ? true : null;
    });

    final service = AppTaskService(channel: channel, isAndroid: true);

    expect(await service.startEnrichmentKeepAlive('processing-42'), isTrue);
    await service.finishEnrichmentKeepAlive('processing-42');
    expect(calls.map((call) => call.method), const [
      'startEnrichmentKeepAlive',
      'finishEnrichmentKeepAlive',
    ]);
    expect(calls.map((call) => call.arguments), const [
      'processing-42',
      'processing-42',
    ]);
  });

  test('does nothing on non-Android platforms', () async {
    final service = AppTaskService(channel: channel, isAndroid: false);

    expect(await service.moveToBackground(), isFalse);
    expect(await service.startEnrichmentKeepAlive('processing-42'), isFalse);
    await service.finishEnrichmentKeepAlive('processing-42');
  });
}
