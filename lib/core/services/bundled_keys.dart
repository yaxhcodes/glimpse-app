import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;

import 'ai_proxy_config.dart';

/// Compatibility facade for callers that gate optional AI features.
///
/// AI provider credentials are no longer read from the Flutter client. Gemini
/// and embedding availability now means "the proxy URL is configured".
class BundledKeys {
  BundledKeys._();

  static bool get hasGemini => AiProxyConfig.enabled;
  static bool get hasVoyage => AiProxyConfig.enabled;

  static void debugLogAvailability() {
    if (!kDebugMode) return;
    developer.log(
      'AI availability: hasGemini=$hasGemini, hasVoyage=$hasVoyage, '
      'proxyEnabled=${AiProxyConfig.enabled}, '
      'proxyUrl=${AiProxyConfig.baseUrl}, '
      'proxyUserId=${AiProxyConfig.userId.isNotEmpty ? '${AiProxyConfig.userId.substring(0, 8)}...' : "(empty)"}',
      name: 'BundledKeys',
    );
  }
}
