import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/categorization_result.dart';

/// Service for all Anthropic Claude API interactions.
///
/// Handles categorization of URL metadata and (future) embedding generation.
/// API key is read from secure storage — never hardcoded.
class LlmService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-haiku-4-5';
  static const String _apiKeyStorageKey = 'anthropic_api_key';

  LlmService({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // --------------- API Key Management ---------------

  Future<String?> getApiKey() async {
    return _secureStorage.read(key: _apiKeyStorageKey);
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: key);
  }

  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: _apiKeyStorageKey);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  // --------------- Categorization ---------------

  /// Sends title + description to Claude and returns categorization result.
  /// Falls back to [CategorizationResult.uncategorized] on failure.
  Future<CategorizationResult> categorize({
    required String title,
    required String description,
  }) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return CategorizationResult.uncategorized();
      }

      final response = await _dio.post(
        _apiUrl,
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
        ),
        data: jsonEncode({
          'model': _model,
          'max_tokens': 256,
          'messages': [
            {
              'role': 'user',
              'content': '''You are a content classifier. Given the title and description of a webpage, return:
1. A short category label (e.g., "Plants", "Lizards", "Cooking", "Finance")
2. An emoji that represents it
3. 3–5 descriptive tags

Title: $title
Description: $description

Respond in JSON only, with keys: "category", "emoji", "tags" (array of strings).''',
            },
          ],
        }),
      );

      final content = response.data['content'][0]['text'] as String;

      // Parse JSON from response — handle possible markdown code fences
      String jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CategorizationResult.fromJson(parsed);
    } catch (e) {
      // On any failure, return uncategorized so the URL still gets saved.
      return CategorizationResult.uncategorized();
    }
  }

  // --------------- Embeddings (Phase 2) ---------------

  /// Generate an embedding vector for the given text.
  /// Placeholder for Phase 2 — returns empty list for now.
  Future<List<double>> generateEmbedding(String text) async {
    // TODO: Implement with Anthropic embeddings or voyage-3-lite in Phase 2
    return [];
  }
}
