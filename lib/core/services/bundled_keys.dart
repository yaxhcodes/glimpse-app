import 'ai_proxy_config.dart';

/// API keys injected at build time via --dart-define.
/// Users never see or manage these directly.
///
/// When [AiProxyConfig.enabled] is true (dev secret + user id set), Gemini and
/// Voyage traffic goes through the Cloudflare Worker; direct keys may be empty.
class BundledKeys {
  BundledKeys._();

  static const geminiKey = String.fromEnvironment('GEMINI_KEY');
  static const voyageKey = String.fromEnvironment('VOYAGE_KEY');

  static bool get hasGemini => geminiKey.isNotEmpty || AiProxyConfig.enabled;
  static bool get hasVoyage => voyageKey.isNotEmpty || AiProxyConfig.enabled;
}
