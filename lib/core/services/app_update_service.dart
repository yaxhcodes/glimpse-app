import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import '../config/app_environment.dart';

class AppUpdatePolicy {
  const AppUpdatePolicy({
    this.immediatePriorityThreshold = 4,
    this.immediateStalenessDays = 7,
  });

  final int immediatePriorityThreshold;
  final int immediateStalenessDays;

  bool shouldUseImmediateUpdate(AppUpdateInfo info) {
    if (!info.immediateUpdateAllowed) return false;
    if (info.updatePriority >= immediatePriorityThreshold) return true;

    final staleDays = info.clientVersionStalenessDays;
    return staleDays != null && staleDays >= immediateStalenessDays;
  }

  bool shouldUseFlexibleUpdate(AppUpdateInfo info) {
    return info.flexibleUpdateAllowed;
  }
}

abstract class AppUpdateClient {
  Stream<InstallStatus> get installStatus;

  Future<AppUpdateInfo> checkForUpdate();

  Future<AppUpdateResult> performImmediateUpdate();

  Future<AppUpdateResult> startFlexibleUpdate();

  Future<void> completeFlexibleUpdate();
}

class GooglePlayAppUpdateClient implements AppUpdateClient {
  const GooglePlayAppUpdateClient();

  @override
  Stream<InstallStatus> get installStatus => InAppUpdate.installUpdateListener;

  @override
  Future<AppUpdateInfo> checkForUpdate() => InAppUpdate.checkForUpdate();

  @override
  Future<AppUpdateResult> performImmediateUpdate() {
    return InAppUpdate.performImmediateUpdate();
  }

  @override
  Future<AppUpdateResult> startFlexibleUpdate() {
    return InAppUpdate.startFlexibleUpdate();
  }

  @override
  Future<void> completeFlexibleUpdate() {
    return InAppUpdate.completeFlexibleUpdate();
  }
}

class AppUpdateService {
  AppUpdateService({
    AppUpdateClient client = const GooglePlayAppUpdateClient(),
    AppUpdatePolicy policy = const AppUpdatePolicy(),
    bool? enabled,
  }) : _client = client,
       _policy = policy,
       _enabled = enabled ?? _defaultEnabled {
    if (!_enabled) return;
    _installStatusSub = _client.installStatus.listen(
      _handleInstallStatus,
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Install status listener failed.',
          name: 'AppUpdateService',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  final AppUpdateClient _client;
  final AppUpdatePolicy _policy;
  final bool _enabled;
  final StreamController<void> _flexibleUpdateReadyController =
      StreamController<void>.broadcast();

  StreamSubscription<InstallStatus>? _installStatusSub;
  bool _checking = false;
  bool _updateFlowRunning = false;
  bool _flexibleStartedThisSession = false;
  bool _suppressedThisSession = false;
  DateTime? _lastReadySignalAt;

  static bool get _defaultEnabled {
    if (kIsWeb || !Platform.isAndroid) return false;
    return AppEnvironment.isProd && !AppEnvironment.isDevContext;
  }

  Stream<void> get flexibleUpdateReady => _flexibleUpdateReadyController.stream;

  Future<void> checkForUpdateOnLaunch() {
    return _checkForUpdate(canStartNewFlow: true);
  }

  Future<void> checkForUpdateOnResume() {
    return _checkForUpdate(canStartNewFlow: false);
  }

  Future<void> completeFlexibleUpdate() async {
    if (!_enabled || _updateFlowRunning) return;

    _updateFlowRunning = true;
    try {
      await _client.completeFlexibleUpdate();
    } catch (error, stackTrace) {
      developer.log(
        'Could not complete flexible app update.',
        name: 'AppUpdateService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _updateFlowRunning = false;
    }
  }

  Future<void> dispose() async {
    await _installStatusSub?.cancel();
    await _flexibleUpdateReadyController.close();
  }

  Future<void> _checkForUpdate({required bool canStartNewFlow}) async {
    if (!_enabled || _checking || _updateFlowRunning) return;

    _checking = true;
    try {
      final info = await _client.checkForUpdate();

      if (info.installStatus == InstallStatus.downloaded) {
        _signalFlexibleUpdateReady();
        return;
      }

      if (info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress &&
          info.immediateUpdateAllowed) {
        await _performImmediateUpdate();
        return;
      }

      if (!canStartNewFlow ||
          _suppressedThisSession ||
          info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (_policy.shouldUseImmediateUpdate(info)) {
        await _performImmediateUpdate();
        return;
      }

      if (!_flexibleStartedThisSession &&
          _policy.shouldUseFlexibleUpdate(info)) {
        await _startFlexibleUpdate();
      }
    } catch (error, stackTrace) {
      developer.log(
        'App update check failed.',
        name: 'AppUpdateService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _checking = false;
    }
  }

  Future<void> _performImmediateUpdate() async {
    _updateFlowRunning = true;
    try {
      final result = await _client.performImmediateUpdate();
      if (result != AppUpdateResult.success) {
        _suppressedThisSession = true;
      }
    } catch (error, stackTrace) {
      _suppressedThisSession = true;
      developer.log(
        'Immediate app update failed.',
        name: 'AppUpdateService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _updateFlowRunning = false;
    }
  }

  Future<void> _startFlexibleUpdate() async {
    _updateFlowRunning = true;
    _flexibleStartedThisSession = true;
    try {
      final result = await _client.startFlexibleUpdate();
      if (result == AppUpdateResult.userDeniedUpdate) {
        _suppressedThisSession = true;
      }
    } catch (error, stackTrace) {
      _suppressedThisSession = true;
      developer.log(
        'Flexible app update failed.',
        name: 'AppUpdateService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _updateFlowRunning = false;
    }
  }

  void _handleInstallStatus(InstallStatus status) {
    if (status == InstallStatus.downloaded) {
      _signalFlexibleUpdateReady();
    }
  }

  void _signalFlexibleUpdateReady() {
    if (_flexibleUpdateReadyController.isClosed) return;

    final now = DateTime.now();
    final last = _lastReadySignalAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }

    _lastReadySignalAt = now;
    _flexibleUpdateReadyController.add(null);
  }
}
