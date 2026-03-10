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

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        data: {
          'input': [text.trim()],
          'model': _embeddingModel,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data?['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) return [];

      final embedding = data.first['embedding'] as List<dynamic>?;
      if (embedding == null) return [];

      return embedding.map((v) => (v as num).toDouble()).toList();
    } on DioException {
      return [];
    }
  }
}
