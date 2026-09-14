import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/notification_permission_coordinator.dart';

void main() {
  test('already enabled bypasses explanation and OS request', () async {
    final coordinator = NotificationPermissionCoordinator(
      enabled: () async => true,
      requestable: () async => throw StateError('not needed'),
      request: () async => throw StateError('not needed'),
    );
    expect(
      await coordinator.enable(
        explain: () async => throw StateError('not needed'),
      ),
      NotificationPermissionResult.enabled,
    );
  });
  test('declining explanation never requests permission', () async {
    final coordinator = NotificationPermissionCoordinator(
      enabled: () async => false,
      requestable: () async => throw StateError('not needed'),
      request: () async => throw StateError('not needed'),
    );
    expect(
      await coordinator.enable(explain: () async => false),
      NotificationPermissionResult.declined,
    );
  });
  test(
    'blocked permission offers settings without repeating OS prompt',
    () async {
      final coordinator = NotificationPermissionCoordinator(
        enabled: () async => false,
        requestable: () async => false,
        request: () async => throw StateError('blocked'),
      );
      expect(
        await coordinator.enable(explain: () async => true),
        NotificationPermissionResult.settings,
      );
    },
  );
  for (final result in [true, false, null]) {
    test('explicit opt-in handles OS result $result', () async {
      var requests = 0;
      var marked = 0;
      final coordinator = NotificationPermissionCoordinator(
        enabled: () async => false,
        requestable: () async => true,
        request: () async {
          requests++;
          return result;
        },
        markRequested: () async {
          marked++;
        },
      );
      expect(
        await coordinator.enable(explain: () async => true),
        result == true
            ? NotificationPermissionResult.enabled
            : NotificationPermissionResult.declined,
      );
      expect(requests, 1);
      expect(marked, result == null ? 0 : 1);
    });
  }
  test(
    'platform failures propagate to the localized UI error handler',
    () async {
      final coordinator = NotificationPermissionCoordinator(
        enabled: () async => false,
        requestable: () async => throw StateError('platform unavailable'),
      );
      expect(coordinator.enable(explain: () async => true), throwsStateError);
    },
  );
}
