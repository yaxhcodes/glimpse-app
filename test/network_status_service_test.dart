import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/network_status_service.dart';

void main() {
  test('reports offline when no transport is available', () async {
    final service = NetworkStatusService(
      checkConnectivity: () async => [ConnectivityResult.none],
    );

    expect(await service.isDefinitelyOffline(), isTrue);
  });

  test('does not treat a transport as proof of being offline', () async {
    final service = NetworkStatusService(
      checkConnectivity: () async => [ConnectivityResult.mobile],
    );

    expect(await service.isDefinitelyOffline(), isFalse);
  });

  test('falls back to the remote path when the platform check fails', () async {
    final service = NetworkStatusService(
      checkConnectivity: () => Future.error(StateError('unavailable')),
    );

    expect(await service.isDefinitelyOffline(), isFalse);
  });
}
