import '../config/app_environment.dart';

/// Cloudflare Worker proxy for Gemini and Voyage.
///
/// Build with:
/// `--dart-define=AI_PROXY_DEV_SECRET=... --dart-define=AI_PROXY_USER_ID=...`
///
/// Optional override (wins over [defaultBaseUrlForEnv]):
/// `--dart-define=AI_PROXY_BASE_URL=https://custom.example.com`
///
/// Per-environment defaults (see [AppEnvironment]) let you point `ENV=dev` at
/// a staging worker without changing code.
class AiProxyConfig {
  AiProxyConfig._();

  static const _prodDefaultBaseUrl = 'https://glimpse-proxy.glimpse.workers.dev';
  static const _devDefaultBaseUrl = 'https://glimpse-proxy.glimpse.workers.dev';

  static String get defaultBaseUrlForEnv =>
      AppEnvironment.isDev ? _devDefaultBaseUrl : _prodDefaultBaseUrl;

  static const baseUrlOverride = String.fromEnvironment('AI_PROXY_BASE_URL');
  static const devSecret = String.fromEnvironment('AI_PROXY_DEV_SECRET');
  static const userId = String.fromEnvironment('AI_PROXY_USER_ID');

  static String get baseUrl =>
      baseUrlOverride.isEmpty ? defaultBaseUrlForEnv : baseUrlOverride;

  /// When true, [EmbeddingService] and [GeminiService] use the worker instead
  /// of calling Google / Voyage directly.
  static bool get enabled => devSecret.isNotEmpty && userId.isNotEmpty;
}
