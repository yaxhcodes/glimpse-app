import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../ai_proxy_config.dart';
import '../supabase_auth_service.dart';
import 'app_attestation_service.dart';

typedef AccessTokenProvider = Future<String?> Function({bool forceRefresh});
typedef AppCheckTokenProvider = Future<String?> Function({bool forceRefresh});

enum AiRequestFeature { aiSave, ask }

enum AiTransportErrorType {
  timeout,
  rateLimited,
  unavailable,
  malformedResponse,
  http,
  network,
  invalidConfiguration,
}

/// Normalized AI transport error for proxy-backed Gemini and embedding calls.
class AiTransportException implements Exception {
  AiTransportException(
    this.message, {
    required this.type,
    this.statusCode,
    this.body,
  });

  final String message;
  final AiTransportErrorType type;
  final int? statusCode;
  final String? body;

  bool get isRetryable =>
      type == AiTransportErrorType.timeout ||
      type == AiTransportErrorType.network ||
      type == AiTransportErrorType.unavailable ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  @override
  String toString() =>
      'AiTransportException($message, type=$type'
      '${statusCode != null ? ', status=$statusCode' : ''})';
}

/// Single networking entrypoint for all AI features.
///
/// The client only talks to the Cloudflare Worker proxy. Provider API keys stay
/// server-side. Supabase and App Check credentials authorize paid work; the
/// stable installation ID is only an additional abuse signal.
class AiTransport {
  AiTransport({
    Dio? dio,
    AccessTokenProvider? accessTokenProvider,
    AppCheckTokenProvider? appCheckTokenProvider,
    String Function()? requestIdFactory,
  }) : _dio = dio ?? _defaultDio(),
       _accessTokenProvider =
           accessTokenProvider ?? SupabaseAuthService.currentAccessToken,
       _appCheckTokenProvider =
           appCheckTokenProvider ?? AppAttestationService.getToken,
       _requestIdFactory = requestIdFactory ?? _newRequestId;

  static final AiTransport instance = AiTransport();

  static const _maxAttempts = 2;
  static const _retryDelay = Duration(milliseconds: 700);

  final Dio _dio;
  final AccessTokenProvider _accessTokenProvider;
  final AppCheckTokenProvider _appCheckTokenProvider;
  final String Function() _requestIdFactory;

  static const _uuid = Uuid();

  static String _newRequestId() => _uuid.v4();

  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final raw = await _post(path, body: body, timeout: timeout);
    return _asJsonObject(raw);
  }

  /// POST to the worker's Gemini endpoint and return the first model text part.
  Future<String> postGemini({
    required Map<String, dynamic> body,
    AiRequestFeature? feature,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final raw = await _post(
      '/gemini',
      body: body,
      timeout: timeout,
      feature: feature,
    );
    final text = _extractGeminiText(raw);
    if (text == null || text.isEmpty) {
      throw AiTransportException(
        'Gemini response missing text',
        type: AiTransportErrorType.malformedResponse,
      );
    }
    return text;
  }

  /// POST embedding input to `/embed`, falling back to legacy `/voyage` only
  /// when the proxy has not yet deployed the newer route.
  Future<Map<String, dynamic>> postEmbedding({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await postJson('/embed', body: body, timeout: timeout);
    } on AiTransportException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      return postJson('/voyage', body: body, timeout: timeout);
    }
  }

  /// Sends supported social/video enrichment through the same authenticated
  /// public gateway as every other paid AI operation.
  Future<Map<String, dynamic>> postEnrichment({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 180),
  }) => postJson('/enrich-url', body: body, timeout: timeout);

  /// Resolves already-extracted books, movies, and places against deterministic
  /// catalogs. This route never invokes a model or consumes an AI allowance.
  Future<Map<String, dynamic>> postLibraryEntities({
    required List<Map<String, dynamic>> entities,
    Duration timeout = const Duration(seconds: 45),
  }) => postJson(
    '/resolve-library-entities',
    body: {'entities': entities},
    timeout: timeout,
  );

  Future<dynamic> _post(
    String path, {
    required Map<String, dynamic> body,
    required Duration timeout,
    AiRequestFeature? feature,
  }) async {
    final base = Uri.tryParse(AiProxyConfig.baseUrl);
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      throw AiTransportException(
        'AI proxy base URL is invalid',
        type: AiTransportErrorType.invalidConfiguration,
      );
    }

    final url = base.resolve(path.startsWith('/') ? path.substring(1) : path);
    if (kDebugMode) {
      developer.log('POST $url', name: 'AiTransport');
    }

    final requestId = _requestIdFactory();
    Object? lastError;
    var forceCredentialRefresh = false;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelay);
      }
      try {
        final response = await _dio
            .post<dynamic>(
              url.toString(),
              data: body,
              options: Options(
                headers: await _headers(
                  requestId: requestId,
                  forceRefresh: forceCredentialRefresh,
                  feature: feature,
                ),
                validateStatus: (_) => true,
              ),
            )
            .timeout(timeout);

        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          if (status == 401 && attempt == 0) {
            forceCredentialRefresh = true;
            continue;
          }
          developer.log(
            'AI proxy HTTP $status for $path: ${_debugBody(response.data)}',
            name: 'AiTransport',
          );
          _debugLog(
            'AI proxy HTTP $status for $path: ${_debugBody(response.data)}',
          );
          throw _httpError(status, response.data);
        }
        return _decodeJsonIfNeeded(response.data, status);
      } on AiTransportException catch (e) {
        lastError = e;
        developer.log('AI proxy failed for $path: $e', name: 'AiTransport');
        _debugLog('AI proxy failed for $path: $e');
        if (attempt == 0 && e.isRetryable) continue;
        rethrow;
      } on DioException catch (e) {
        final normalized = _dioError(e);
        lastError = normalized;
        developer.log(
          'AI proxy Dio failure for $path: $normalized',
          name: 'AiTransport',
        );
        _debugLog('AI proxy Dio failure for $path: $normalized');
        if (attempt == 0 && normalized.isRetryable) continue;
        throw normalized;
      } on FormatException catch (e) {
        throw AiTransportException(
          'AI proxy returned malformed JSON: $e',
          type: AiTransportErrorType.malformedResponse,
        );
      }
    }

    throw AiTransportException(
      'AI proxy request failed: $lastError',
      type: AiTransportErrorType.network,
    );
  }

  Future<Map<String, String>> _headers({
    required String requestId,
    required bool forceRefresh,
    AiRequestFeature? feature,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Idempotency-Key': requestId,
    };
    final userId = AiProxyConfig.userId;
    if (userId.isNotEmpty) {
      headers['X-User-Id'] = userId;
    }
    if (feature != null) {
      headers['X-Glimpse-Feature'] = feature.name;
    }
    final accessToken = await _accessTokenProvider(forceRefresh: forceRefresh);
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final appCheckToken = await _appCheckTokenProvider(
      forceRefresh: forceRefresh,
    );
    if (appCheckToken != null && appCheckToken.isNotEmpty) {
      headers['X-Firebase-AppCheck'] = appCheckToken;
    } else {
      _debugLog(
        'App Check header omitted; initialized=${AppAttestationService.isAvailable}, '
        'initError=${AppAttestationService.initError}, '
        'tokenError=${AppAttestationService.lastTokenError}',
      );
    }
    return headers;
  }

  static dynamic _decodeJsonIfNeeded(dynamic raw, int statusCode) {
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (e) {
        throw AiTransportException(
          'AI proxy response is not valid JSON',
          type: AiTransportErrorType.malformedResponse,
          statusCode: statusCode,
          body: kDebugMode ? raw : null,
        );
      }
    }
    return raw;
  }

  static Map<String, dynamic> _asJsonObject(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw AiTransportException(
      'AI proxy response is not a JSON object',
      type: AiTransportErrorType.malformedResponse,
    );
  }

  static AiTransportException _httpError(int status, dynamic raw) {
    final bodyStr = raw is String ? raw : jsonEncode(raw);
    return AiTransportException(
      'AI proxy HTTP $status',
      type: _typeForStatus(status),
      statusCode: status,
      body: kDebugMode ? bodyStr : null,
    );
  }

  static AiTransportException _dioError(DioException e) {
    final status = e.response?.statusCode;
    final raw = e.response?.data;
    final bodyStr = raw is String ? raw : jsonEncode(raw);
    final isTimeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
    return AiTransportException(
      e.message ?? 'AI proxy network error',
      type: isTimeout
          ? AiTransportErrorType.timeout
          : status == null
          ? AiTransportErrorType.network
          : _typeForStatus(status),
      statusCode: status,
      body: kDebugMode ? bodyStr : null,
    );
  }

  static AiTransportErrorType _typeForStatus(int status) {
    if (status == 429) return AiTransportErrorType.rateLimited;
    if (status == 502 || status == 503 || status == 504) {
      return AiTransportErrorType.unavailable;
    }
    return AiTransportErrorType.http;
  }

  static String _debugBody(dynamic raw) {
    if (!kDebugMode) return '';
    final text = raw is String ? raw : jsonEncode(raw);
    return text.length > 300 ? '${text.substring(0, 300)}...' : text;
  }

  static void _debugLog(String message) {
    debugPrint('[AiTransport] $message');
  }

  static String? _extractGeminiText(dynamic decoded) {
    Object? d = decoded;
    if (d is String) {
      try {
        d = jsonDecode(d);
      } catch (_) {
        return null;
      }
    }
    if (d is! Map) return null;
    final map = Map<String, dynamic>.from(d);
    final candidates = map['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    final content = first['content'];
    if (content is! Map) return null;
    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;
    final p0 = parts.first;
    if (p0 is! Map) return null;
    return p0['text'] as String?;
  }
}
