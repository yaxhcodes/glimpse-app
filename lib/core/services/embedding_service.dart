import 'package:dio/dio.dart';

/// Calls the Voyage AI API to generate text embeddings.
class EmbeddingService {
  static const _endpoint = 'https://api.voyageai.com/v1/embeddings';
  static const _embeddingModel = 'voyage-3-lite';

  final Dio _dio;
  final String _apiKey;

  EmbeddingService(this._apiKey) : _dio = Dio();

  /// Generates a single embedding vector for the given text.
  /// Returns an empty list if the text is empty or on error.
  Future<List<double>> generateEmbedding(String text) async {
    if (text.trim().isEmpty) return [];
    final batch = await generateEmbeddingsBatch([text]);
    if (batch.isEmpty || batch.first.isEmpty) return [];
    return batch.first;
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
