import 'package:dio/dio.dart';

/// Calls the Voyage AI API to generate text embeddings.
class EmbeddingService {
  static const _endpoint = 'https://api.voyageai.com/v1/embeddings';
  static const _embeddingModel = 'voyage-3-lite';
  static const _queryCacheMaxSize = 50;

  /// Session-scoped LRU cache for single-text query embeddings.
  /// Keyed on the normalized (trimmed, lowercased) input string.
  static final Map<String, List<double>> _queryCache =
      <String, List<double>>{};

  final Dio _dio;
  final String _apiKey;

  EmbeddingService(this._apiKey) : _dio = Dio();

  /// Generates a single embedding vector for the given text.
  /// Returns an empty list if the text is empty or on error.
  ///
  /// Results are cached in-memory so repeated queries within a session
  /// (e.g. the same search term or Ask question) skip the Voyage API.
  Future<List<double>> generateEmbedding(String text) async {
    if (text.trim().isEmpty) return [];
    final cacheKey = text.trim().toLowerCase();
    final cached = _queryCache[cacheKey];
    if (cached != null) return cached;
    final batch = await generateEmbeddingsBatch([text]);
    if (batch.isEmpty || batch.first.isEmpty) return [];
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
  /// Empty vectors for empty strings or on total failure.
  Future<List<List<double>>> generateEmbeddingsBatch(List<String> texts) async {
    if (texts.isEmpty) return [];
    final trimmed = texts.map((t) => t.trim()).toList();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
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
        ),
      );

      final data = response.data?['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) {
        return List.generate(trimmed.length, (_) => <double>[]);
      }

      final hasIndex = data.isNotEmpty &&
          data.first is Map &&
          (data.first as Map).containsKey('index');

      if (hasIndex) {
        final out = List<List<double>>.generate(trimmed.length, (_) => []);
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
          out.add([]);
          continue;
        }
        final emb = item['embedding'] as List<dynamic>?;
        out.add(emb?.map((v) => (v as num).toDouble()).toList() ?? []);
      }
      while (out.length < trimmed.length) {
        out.add([]);
      }
      return out;
    } on DioException {
      return List.generate(trimmed.length, (_) => <double>[]);
    }
  }
}
