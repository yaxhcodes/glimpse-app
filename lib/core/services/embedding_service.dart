import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'ai_proxy_client.dart';
import 'ai_proxy_config.dart';

/// Thrown when the Voyage embedding pipeline fails after all retries.
class EmbeddingException implements Exception {
  EmbeddingException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'EmbeddingException($message${statusCode != null ? ', status=$statusCode' : ''})';
}

/// Calls the Voyage AI API (direct) or the Cloudflare Worker `POST /voyage`
/// when [AiProxyConfig.enabled].
///
/// Intended to be used as a single shared instance via a Riverpod provider.
/// See [embeddingServiceProvider] in `core/providers/service_providers.dart`.
class EmbeddingService {
  EmbeddingService({required String apiKey, Dio? dio})
      : _apiKey = apiKey,
        _dio = dio ?? Dio();

  static const _directEndpoint = 'https://api.voyageai.com/v1/embeddings';
  static const _embeddingModel = 'voyage-3-lite';
  static const _queryCacheMaxSize = 50;
  static const _maxAttempts = 3;
  static const _baseBackoff = Duration(milliseconds: 400);

  /// Session-scoped LRU cache for single-text query embeddings.
  /// Keyed on the normalized (trimmed, lowercased) input string.
  static final Map<String, List<double>> _queryCache =
      <String, List<double>>{};

  final Dio _dio;
  final String _apiKey;

  /// Generates a single embedding vector for the given text.
  ///
  /// Returns an empty list if [text] is empty. Throws [EmbeddingException]
  /// on persistent failure so callers can distinguish "no input" from
  /// "service unavailable".
  Future<List<double>> generateEmbedding(String text) async {
    if (text.trim().isEmpty) return const [];
    final cacheKey = text.trim().toLowerCase();
    final cached = _queryCache[cacheKey];
    if (cached != null) return cached;
    final batch = await generateEmbeddingsBatch([text]);
    if (batch.isEmpty || batch.first.isEmpty) {
      throw EmbeddingException('empty vector returned');
    }
    _putCache(cacheKey, batch.first);
    return batch.first;
  }

  static void _putCache(String key, List<double> value) {
    if (_queryCache.length >= _queryCacheMaxSize) {
      _queryCache.remove(_queryCache.keys.first);
    }
    _queryCache[key] = value;
  }

  /// One Voyage request for multiple strings; order matches [texts].
  /// Empty vectors for empty strings; throws [EmbeddingException] if the
  /// whole request fails after retries so callers see the failure instead
  /// of silently saving empty vectors.
  Future<List<List<double>>> generateEmbeddingsBatch(
    List<String> texts,
  ) async {
    if (texts.isEmpty) return const [];
    final trimmed = texts.map((t) => t.trim()).toList();

    Object? lastError;
    int? lastStatus;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_baseBackoff * (1 << (attempt - 1)));
      }
      try {
        return await _doBatch(trimmed);
      } on EmbeddingException catch (e) {
        lastError = e;
        lastStatus = e.statusCode;
        if (!_isRetryable(e.statusCode)) break;
        developer.log(
          'Embedding attempt ${attempt + 1}/$_maxAttempts failed: $e',
          name: 'EmbeddingService',
        );
      } catch (e) {
        lastError = e;
        developer.log(
          'Embedding attempt ${attempt + 1}/$_maxAttempts failed: $e',
          name: 'EmbeddingService',
        );
      }
    }

    throw EmbeddingException(
      'embedding request failed: $lastError',
      statusCode: lastStatus,
    );
  }

  static bool _isRetryable(int? status) {
    if (status == null) return true; // network error
    return status == 429 || status == 500 || status == 502 ||
        status == 503 || status == 504;
  }

  Future<List<List<double>>> _doBatch(List<String> trimmed) async {
    final Map<String, dynamic> responseData;
    int? status;

    if (AiProxyConfig.enabled) {
      try {
        responseData = await AiProxyClient.instance.postVoyage(
          body: {
            'model': _embeddingModel,
            'input': trimmed,
          },
          timeout: const Duration(seconds: 15),
        );
      } on AiProxyException catch (e) {
        throw EmbeddingException(
          'proxy error: ${e.message}',
          statusCode: e.statusCode,
        );
      }
    } else {
      try {
        final response = await _dio
            .post<Map<String, dynamic>>(
              _directEndpoint,
              data: {
                'input': trimmed,
                'model': _embeddingModel,
              },
              options: Options(
                headers: {
                  'Authorization': 'Bearer $_apiKey',
                  'Content-Type': 'application/json',
                },
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 15),
                validateStatus: (_) => true,
              ),
            )
            .timeout(const Duration(seconds: 30));

        status = response.statusCode;
        if (status != 200) {
          throw EmbeddingException(
            'voyage HTTP $status',
            statusCode: status,
          );
        }
        responseData = response.data ?? const {};
      } on DioException catch (e) {
        throw EmbeddingException(
          'network error: ${e.message}',
          statusCode: e.response?.statusCode,
        );
      }
    }

    final data = responseData['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) {
      throw EmbeddingException('voyage returned no data', statusCode: status);
    }

    final hasIndex = data.first is Map &&
        (data.first as Map).containsKey('index');

    if (hasIndex) {
      final out = List<List<double>>.generate(trimmed.length, (_) => const []);
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final idx = (item['index'] as num?)?.toInt();
        final emb = item['embedding'] as List<dynamic>?;
        if (idx == null || emb == null || idx < 0 || idx >= out.length) {
          continue;
        }
        out[idx] = emb.map((v) => (v as num).toDouble()).toList();
      }
      return out;
    }

    final out = <List<double>>[];
    for (var i = 0; i < data.length && i < trimmed.length; i++) {
      final item = data[i];
      if (item is! Map<String, dynamic>) {
        out.add(const []);
        continue;
      }
      final emb = item['embedding'] as List<dynamic>?;
      out.add(
        emb?.map((v) => (v as num).toDouble()).toList() ?? const [],
      );
    }
    while (out.length < trimmed.length) {
      out.add(const []);
    }
    return out;
  }
}
