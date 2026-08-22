import 'ai/ai_transport.dart';

/// Backwards-compatible shim for older service code.
///
/// New AI networking should depend on [AiTransport] directly. This class does
/// not perform HTTP itself; it delegates to the single transport layer.
class AiProxyException extends AiTransportException {
  AiProxyException(
    super.message, {
    required super.type,
    super.statusCode,
    super.body,
  });
}

class AiProxyClient {
  AiProxyClient._();

  static final AiProxyClient instance = AiProxyClient._();

  Future<String> postGemini({
    required Map<String, dynamic> body,
    AiRequestFeature? feature,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await AiTransport.instance.postGemini(
        body: body,
        feature: feature,
        timeout: timeout,
      );
    } on AiTransportException catch (e) {
      throw AiProxyException(
        e.message,
        type: e.type,
        statusCode: e.statusCode,
        body: e.body,
      );
    }
  }

  Future<Map<String, dynamic>> postVoyage({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await AiTransport.instance.postEmbedding(
        body: body,
        timeout: timeout,
      );
    } on AiTransportException catch (e) {
      throw AiProxyException(
        e.message,
        type: e.type,
        statusCode: e.statusCode,
        body: e.body,
      );
    }
  }

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
}
