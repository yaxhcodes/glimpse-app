import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'patterns reach the bridge for both engines, system by default',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? sent;
      const channel = MethodChannel('com.shinrinyoku.glimpse/haptics');
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent = call;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await AppHaptics.play(AppHaptics.success, intensity: .5);
      expect(sent?.method, 'compose');
      final args = sent!.arguments as Map;
      expect(args['name'], 'success');
      expect(args['engine'], 'system');
      expect(args['system'], [
        ['clockTick', 0],
        ['confirm', 70],
      ]);
      expect(args['steps'], [
        [HapticPrimitive.quickRise.id, .15, 0],
        [HapticPrimitive.click.id, .425, 20],
        [HapticPrimitive.tick.id, .175, 80],
      ]);

      // Faint cues play as the softest system haptic.
      await AppHaptics.play(AppHaptics.land, intensity: .3);
      expect((sent!.arguments as Map)['system'], [
        ['textHandleMove', 0],
      ]);
    },
  );

  test('the in-app switch silences everything', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var calls = 0;
    const channel = MethodChannel('com.shinrinyoku.glimpse/haptics');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls++;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      AppHaptics.enabled = true;
    });
    AppHaptics.enabled = false;
    await AppHaptics.play(AppHaptics.confirm);
    expect(calls, 0);
  });

  test('falls back to framework haptics when the bridge is missing', () async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await AppHaptics.play(AppHaptics.tick);
    await AppHaptics.play(AppHaptics.success);
    await AppHaptics.play(AppHaptics.confirm);
    expect(calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
