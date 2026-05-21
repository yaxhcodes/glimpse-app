import '../config/app_environment.dart';
import 'ai_user_id_service.dart';

/// Cloudflare Worker proxy for Gemini and Voyage.
///
/// The user ID is generated at runtime on first launch and persisted
/// locally via [AiUserIdService]. No `--dart-define=AI_PROXY_USER_ID`
/// is needed.
///
/// Optional override (wins over [defaultBaseUrlForEnv]):
/// `--dart-define=AI_PROXY_BASE_URL=https://custom.example.com`
class AiProxyConfig {
  AiProxyConfig._();

  static const _prodDefaultBaseUrl = 'https://glimpse-proxy.glimpse.workers.dev';
  static const _devDefaultBaseUrl = 'https://glimpse-proxy.glimpse.workers.dev';

  static String get defaultBaseUrlForEnv =>
      AppEnvironment.isDev ? _devDefaultBaseUrl : _prodDefaultBaseUrl;

  static const baseUrlOverride = String.fromEnvironment('AI_PROXY_BASE_URL');

  /// Runtime-injected user ID. Set by [initUserId] during app startup.
  /// Falls back to a cached value from [AiUserIdService.cachedUserId]
  /// for synchronous reads after initialisation.
  static String _userId = '';

  /// Asynchronously loads or creates the persistent user ID.
  ///
  /// Must be called before any service that depends on
  /// [enabled] / [userId] is initialised.
  static Future<void> initUserId() async {
    _userId = await AiUserIdService.getOrCreateUserId();
  }

  /// The stable per-install user ID.
  ///
  /// Empty string until [initUserId] completes. Use the async
  /// [AiUserIdService.getOrCreateUserId()] if you need the ID
  /// before the app initialises.
  static String get userId =>
      _userId.isNotEmpty ? _userId : (AiUserIdService.cachedUserId ?? '');

  static String get baseUrl =>
      baseUrlOverride.isEmpty ? defaultBaseUrlForEnv : baseUrlOverride;

  /// When true, AI features use the Cloudflare Worker instead of provider APIs.
  static bool get enabled {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}
