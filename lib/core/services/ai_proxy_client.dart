import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'ai_proxy_config.dart';

/// Thrown when the AI proxy returns a non-2xx response or malformed payload.
class AiProxyException implements Exception {
  AiProxyException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() =>
      'AiProxyException($message${statusCode != null ? ', status=$statusCode' : ''})';
}

/// HTTP client for `POST /gemini` and `POST /voyage` on the Cloudflare Worker.
///
/// Headers (always):
/// - `Content-Type: application/json`
/// - `Authorization: Bearer <AI_PROXY_DEV_SECRET>`
/// - `X-User-Id: <runtime-generated user ID>`
class AiProxyClient {
  AiProxyClient._()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

  static final AiProxyClient instance = AiProxyClient._();

  final Dio _dio;

  static Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AiProxyConfig.devSecret}',
      'X-User-Id': AiProxyConfig.userId,
    };
  }

  /// POST [AiProxyConfig.baseUrl]/gemini — body matches Gemini REST
  /// `generateContent` (e.g. `contents`, optional `generationConfig`,
  /// `systemInstruction`).
  ///
  /// Returns the first text part from `candidates[0].content.parts`.
  Future<String> postGemini({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final url = '${AiProxyConfig.baseUrl}/gemini';
    if (kDebugMode) {
      developer.log('POST $url', name: 'AiProxy');
    }

    try {
      final response = await _dio
          .post<dynamic>(
            url,
            data: body,
            options: Options(headers: _headers()),
          )
          .timeout(timeout);

      final status = response.statusCode ?? 0;
      final raw = response.data;

      if (status != 200) {
        final bodyStr = raw is String ? raw : jsonEncode(raw);
        throw AiProxyException(
          'Gemini proxy request failed',
          statusCode: status,
          body: kDebugMode ? bodyStr : null,
        );
      }

      final text = _extractGeminiText(raw);
      if (text == null || text.isEmpty) {
        throw AiProxyException(
          'Gemini response missing text',
          statusCode: status,
        );
      }
      return text;
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      final raw = e.response?.data;
      final bodyStr = raw is String ? raw : jsonEncode(raw);
      Error.throwWithStackTrace(
        AiProxyException(
          e.message ?? 'Gemini proxy network error',
          statusCode: status,
          body: kDebugMode ? bodyStr : null,
        ),
        st,
      );
    }
  }

  /// POST [AiProxyConfig.baseUrl]/voyage — body like Voyage embeddings API
  /// (`model`, `input`, etc.).
  Future<Map<String, dynamic>> postVoyage({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final url = '${AiProxyConfig.baseUrl}/voyage';
    if (kDebugMode) {
      developer.log('POST $url', name: 'AiProxy');
    }

    try {
      final response = await _dio
          .post<dynamic>(
            url,
            data: body,
            options: Options(headers: _headers()),
          )
          .timeout(timeout);

      final status = response.statusCode ?? 0;
      final raw = response.data;

      if (status != 200) {
        final bodyStr = raw is String ? raw : jsonEncode(raw);
        throw AiProxyException(
          'Voyage proxy request failed',
          statusCode: status,
          body: kDebugMode ? bodyStr : null,
        );
      }

      if (raw is! Map<String, dynamic>) {
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        throw AiProxyException(
          'Voyage response is not a JSON object',
          statusCode: status,
        );
      }
      return raw;
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      final raw = e.response?.data;
      final bodyStr = raw is String ? raw : jsonEncode(raw);
      Error.throwWithStackTrace(
        AiProxyException(
          e.message ?? 'Voyage proxy network error',
          statusCode: status,
          body: kDebugMode ? bodyStr : null,
        ),
        st,
      );
    }
  }

  /// Minimal Gemini user turn: `{ "contents": [ { "parts": [ { "text": "..." } ] } ] }`.
  static Map<String, dynamic> contentsOnlyBody(String prompt) {
    return {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    };
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
    final text = p0['text'] as String?;
    return text;
  }
}
