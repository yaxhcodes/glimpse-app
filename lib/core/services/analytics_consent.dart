import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether usage analytics may be sent. On unless the person turns it off
/// in Settings › Privacy. The analytics service checks it before recording
/// or sending anything, and drops whatever is still queued when it goes off.
abstract final class AnalyticsConsent {
  static const preferenceKey = 'glimpse_analytics_enabled';

  static bool _enabled = true;
  static bool _loaded = false;

  static bool get enabled => _enabled;

  static Future<bool> load() async {
    if (_loaded) return _enabled;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(preferenceKey) ?? true;
    _loaded = true;
    return _enabled;
  }

  static Future<void> set(bool enabled) async {
    _enabled = enabled;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey, enabled);
  }
}

class AnalyticsConsentNotifier extends StateNotifier<bool> {
  AnalyticsConsentNotifier() : super(AnalyticsConsent.enabled) {
    AnalyticsConsent.load().then((enabled) {
      if (mounted) state = enabled;
    });
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await AnalyticsConsent.set(enabled);
  }
}

final analyticsConsentProvider =
    StateNotifierProvider<AnalyticsConsentNotifier, bool>(
      (ref) => AnalyticsConsentNotifier(),
    );
