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
      if (action == AppShortcutAction.openSave) continue;
      expect(AppShortcutAction.fromPlatformValue(action.platformValue), action);
    }
    expect(AppShortcutAction.fromPlatformValue('settings'), isNull);
    expect(AppShortcutAction.fromPlatformValue(null), isNull);
  });

  test('a widget tap names its save, and a bare or bad id is ignored', () {
    final request = AppShortcutRequest.fromPlatformValue('save:42');
    expect(request?.action, AppShortcutAction.openSave);
    expect(request?.saveId, 42);

    expect(AppShortcutAction.fromPlatformValue('save'), isNull);
    expect(AppShortcutRequest.fromPlatformValue('save'), isNull);
    expect(AppShortcutRequest.fromPlatformValue('save:'), isNull);
    expect(AppShortcutRequest.fromPlatformValue('save:0'), isNull);
    expect(AppShortcutRequest.fromPlatformValue('save:abc'), isNull);
    expect(
      AppShortcutRequest.fromPlatformValue('search')?.action,
      AppShortcutAction.search,
    );
  });

  test('delivers cold and warm shortcut launches in order', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInitialAppShortcut');
      return AppShortcutAction.search.platformValue;
    });

    final service = AppShortcutService(channel: channel, isAndroid: true);
    final received = <AppShortcutAction>[];
    final subscription = service.incoming
        .map((request) => request.action)
        .listen(received.add);

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
    final subscription = service.incoming
        .map((request) => request.action)
        .listen(received.add);

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
