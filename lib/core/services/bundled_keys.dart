import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;

import 'ai_proxy_config.dart';

/// API keys injected at build time via --dart-define.
/// Users never see or manage these directly.
///
/// When [AiProxyConfig.enabled] is true (dev secret set + runtime user ID
/// available), Gemini and Voyage traffic goes through the Cloudflare Worker;
/// direct keys may be empty.
class BundledKeys {
  BundledKeys._();

  static const geminiKey = String.fromEnvironment('GEMINI_KEY');
  static const voyageKey = String.fromEnvironment('VOYAGE_KEY');

  static bool get hasGemini => geminiKey.isNotEmpty || AiProxyConfig.enabled;
  static bool get hasVoyage => voyageKey.isNotEmpty || AiProxyConfig.enabled;

  /// Log key availability for debugging pipeline failures.
  /// Only logs in debug mode; never exposes actual key values.
  static void debugLogAvailability() {
    if (!kDebugMode) return;
    developer.log(
      'BundledKeys: hasGemini=$hasGemini, hasVoyage=$hasVoyage, '
      'proxyEnabled=${AiProxyConfig.enabled}, '
      'proxyUrl=${AiProxyConfig.baseUrl}, '
      'proxyUserId=${AiProxyConfig.userId.isNotEmpty ? '${AiProxyConfig.userId.substring(0, 8)}...' : "(empty)"}',
      name: 'BundledKeys',
    );
  }
}