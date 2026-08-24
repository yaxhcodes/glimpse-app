import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/app_shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.shinrinyoku.glimpse/app_shortcut');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('maps every native shortcut identifier and rejects unknown values', () {
    for (final action in AppShortcutAction.values) {
      expect(AppShortcutAction.fromPlatformValue(action.platformValue), action);
    }
    expect(AppShortcutAction.fromPlatformValue('settings'), isNull);
    expect(AppShortcutAction.fromPlatformValue(null), isNull);
  });

  test('delivers cold and warm shortcut launches in order', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInitialAppShortcut');
      return AppShortcutAction.search.platformValue;
    });

    final service = AppShortcutService(channel: channel, isAndroid: true);
    final received = <AppShortcutAction>[];
    final subscription = service.incoming.listen(received.add);

    await service.start();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('onAppShortcut', AppShortcutAction.ask.platformValue),
      ),
      null,
    );
    await pumpEventQueue();

    expect(received, const [AppShortcutAction.search, AppShortcutAction.ask]);

    await subscription.cancel();
    await service.dispose();
  });

  test('ignores unknown warm shortcut identifiers', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final service = AppShortcutService(channel: channel, isAndroid: true);
    final received = <AppShortcutAction>[];
    final subscription = service.incoming.listen(received.add);

    await service.start();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        const MethodCall('onAppShortcut', 'unknown'),
      ),
      null,
    );
    await pumpEventQueue();

    expect(received, isEmpty);

    await subscription.cancel();
    await service.dispose();
  });
}
