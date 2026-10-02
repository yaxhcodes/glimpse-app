import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/device_diagnostics_service.dart';
import '../../core/services/supabase_config.dart';

enum FeedbackKind { bug, idea }

enum FeedbackFailure { signedOut, failed }

class FeedbackException implements Exception {
  const FeedbackException(this.reason);

  final FeedbackFailure reason;
}

/// What the report screen opens with: where the person was and, when they
/// shook the phone, a picture of it.
class FeedbackLaunch {
  const FeedbackLaunch({
    this.screenshot,
    this.screenName,
    this.fromShake = false,
  });

  final Uint8List? screenshot;
  final String? screenName;
  final bool fromShake;
}

/// Sends a bug report or idea to the `feedback` table, its screenshot to
/// the private `feedback-screenshots` bucket under the person's own folder
/// (see supabase/migrations/20261002120000_feedback.sql).
class FeedbackService {
  FeedbackService({
    SupabaseClient? client,
    DeviceDiagnosticsService? diagnostics,
  }) : _client = client,
       _diagnostics = diagnostics ?? DeviceDiagnosticsService();

  final SupabaseClient? _client;
  final DeviceDiagnosticsService _diagnostics;

  static const _bucket = 'feedback-screenshots';

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<void> submit({
    required FeedbackKind kind,
    required String message,
    String? screenName,
    Uint8List? screenshotPng,
    String? locale,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw const FeedbackException(FeedbackFailure.failed);
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const FeedbackException(FeedbackFailure.signedOut);
    }
    try {
      String? screenshotPath;
      if (screenshotPng != null && screenshotPng.isNotEmpty) {
        screenshotPath = '$userId/${const Uuid().v4()}.png';
        await _supabase.storage
            .from(_bucket)
            .uploadBinary(
              screenshotPath,
              screenshotPng,
              fileOptions: const FileOptions(contentType: 'image/png'),
            );
      }
      final device = await _diagnostics.load();
      await _supabase.from('feedback').insert({
        'user_id': userId,
        'kind': kind.name,
        'message': message.trim(),
        'screen_name': screenName,
        'screenshot_path': screenshotPath,
        'app_version': device.appVersion,
        'build_version': device.buildVersion,
        'platform': device.platform,
        'os_version': device.osVersion,
        'device_manufacturer': device.deviceManufacturer,
        'device_model': device.deviceModel,
        'locale': locale,
      });
    } on FeedbackException {
      rethrow;
    } catch (_) {
      throw const FeedbackException(FeedbackFailure.failed);
    }
  }
}

final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(),
);

/// Shake to report: on unless turned off in Settings › Personalization.
abstract final class ShakeToReportPrefs {
  static const enabledKey = 'glimpse_shake_to_report';
  static const tipShownKey = 'glimpse_shake_to_report_tip_shown';

  static Future<bool> enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? true;
  }

  /// True the first time only: the screen then explains how to turn it off.
  static Future<bool> takeFirstShakeTip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(tipShownKey) ?? false) return false;
    await prefs.setBool(tipShownKey, true);
    return true;
  }
}

class ShakeToReportNotifier extends StateNotifier<bool> {
  ShakeToReportNotifier() : super(true) {
    ShakeToReportPrefs.enabled().then((enabled) {
      if (mounted) state = enabled;
    });
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ShakeToReportPrefs.enabledKey, enabled);
  }
}

final shakeToReportProvider =
    StateNotifierProvider<ShakeToReportNotifier, bool>(
      (ref) => ShakeToReportNotifier(),
    );
