/// Cloudflare Worker proxy for Gemini and Voyage.
///
/// Build with:
/// `--dart-define=AI_PROXY_DEV_SECRET=... --dart-define=AI_PROXY_USER_ID=...`
///
/// Optional override:
/// `--dart-define=AI_PROXY_BASE_URL=https://custom.example.com`
class AiProxyConfig {
  AiProxyConfig._();

  static const defaultBaseUrl = 'https://glimpse-proxy.glimpse.workers.dev';

  static const baseUrlOverride = String.fromEnvironment('AI_PROXY_BASE_URL');
  static const devSecret = String.fromEnvironment('AI_PROXY_DEV_SECRET');
  static const userId = String.fromEnvironment('AI_PROXY_USER_ID');

  static String get baseUrl =>
      baseUrlOverride.isEmpty ? defaultBaseUrl : baseUrlOverride;

  /// When true, [EmbeddingService] and [GeminiService] use the worker instead
  /// of calling Google / Voyage directly.
  static bool get enabled => devSecret.isNotEmpty && userId.isNotEmpty;
}
