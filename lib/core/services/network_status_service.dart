import 'package:connectivity_plus/connectivity_plus.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

class NetworkStatusService {
  NetworkStatusService({ConnectivityCheck? checkConnectivity})
    : _checkConnectivity =
          checkConnectivity ?? Connectivity().checkConnectivity;

  final ConnectivityCheck _checkConnectivity;

  /// Returns true only when the platform reports that no network transport is
  /// available. A connected transport is not treated as proof of internet
  /// access; remote calls still retain their normal failure handling.
  Future<bool> isDefinitelyOffline() async {
    try {
      final results = await _checkConnectivity();
      return results.isEmpty ||
          results.every((result) => result == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
