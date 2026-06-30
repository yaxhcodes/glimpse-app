import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/device_diagnostics.dart';

class DeviceDiagnosticsService {
  DeviceDiagnosticsService({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  Future<DeviceDiagnostics> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = _platformName();
    String? osVersion;
    String? manufacturer;
    String? model;

    if (!kIsWeb && Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      osVersion = 'Android ${android.version.release}';
      manufacturer = android.manufacturer;
      model = android.model;
    } else if (!kIsWeb && Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      osVersion = '${ios.systemName} ${ios.systemVersion}';
      manufacturer = 'Apple';
      model = ios.utsname.machine;
    }

    return DeviceDiagnostics(
      platform: platform,
      appVersion: packageInfo.version,
      buildVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      osVersion: osVersion,
      deviceManufacturer: manufacturer,
      deviceModel: model,
    );
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
