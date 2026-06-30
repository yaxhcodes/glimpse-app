import 'package:flutter/foundation.dart';

@immutable
class DeviceDiagnostics {
  const DeviceDiagnostics({
    required this.platform,
    required this.appVersion,
    required this.buildVersion,
    this.osVersion,
    this.deviceManufacturer,
    this.deviceModel,
  });

  final String platform;
  final String appVersion;
  final String buildVersion;
  final String? osVersion;
  final String? deviceManufacturer;
  final String? deviceModel;
}
