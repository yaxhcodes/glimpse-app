import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/shell/shell_chrome_provider.dart';

void main() {
  late ProviderContainer container;
  late ShellChromeVisibilityNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    notifier = container.read(shellChromeVisibilityProvider.notifier);
  });

  test('hides only after intentional downward scrolling', () {
    expect(container.read(shellChromeVisibilityProvider), isTrue);

    notifier.handleUserScroll(delta: 12, isAtTop: false);
    notifier.handleUserScroll(delta: 15, isAtTop: false);
    expect(container.read(shellChromeVisibilityProvider), isTrue);

    notifier.handleUserScroll(delta: 1, isAtTop: false);
    expect(container.read(shellChromeVisibilityProvider), isFalse);
  });

  test('a slight upward scroll restores hidden chrome', () {
    notifier.handleUserScroll(
      delta: ShellChromeVisibilityNotifier.hideThreshold,
      isAtTop: false,
    );

    notifier.handleUserScroll(delta: -8, isAtTop: false);
    expect(container.read(shellChromeVisibilityProvider), isFalse);

    notifier.handleUserScroll(delta: -4, isAtTop: false);
    expect(container.read(shellChromeVisibilityProvider), isTrue);
  });

  test(
    'direction changes and gesture boundaries reset accumulated movement',
    () {
      notifier.handleUserScroll(delta: 20, isAtTop: false);
      notifier.handleUserScroll(delta: -2, isAtTop: false);
      notifier.handleUserScroll(delta: 10, isAtTop: false);
      expect(container.read(shellChromeVisibilityProvider), isTrue);

      notifier.endGesture();
      notifier.handleUserScroll(delta: 20, isAtTop: false);
      expect(container.read(shellChromeVisibilityProvider), isTrue);
    },
  );

  test('returning to the top always restores shell chrome', () {
    notifier.handleUserScroll(
      delta: ShellChromeVisibilityNotifier.hideThreshold,
      isAtTop: false,
    );
    expect(container.read(shellChromeVisibilityProvider), isFalse);

    notifier.handleUserScroll(delta: 1, isAtTop: true);
    expect(container.read(shellChromeVisibilityProvider), isTrue);
  });
}
