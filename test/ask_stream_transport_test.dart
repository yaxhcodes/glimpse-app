import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/ai/ai_transport.dart';

void main() {
  test(
    'Ask stream preserves UTF-8 across arbitrary network chunks and credentials',
    () async {
      final dio = Dio();
      RequestOptions? request;
      final bytes = utf8.encode(
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '日本語 🌱'},
                ],
              },
            },
          ],
        })}\n\n',
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: ResponseBody(
                  Stream.fromIterable(
                    bytes.map((byte) => Uint8List.fromList([byte])),
                  ),
                  200,
                ),
              ),
            );
          },
        ),
      );
      final transport = AiTransport(
        dio: dio,
        accessTokenProvider: ({bool forceRefresh = false}) async =>
            'test-access',
        appCheckTokenProvider: ({bool forceRefresh = false}) async =>
            'test-attestation',
      );
      final text = await transport
          .streamAsk(
            body: {},
            turnId: 'logical-turn-000000000001',
            cancelToken: CancelToken(),
          )
          .join();
      expect(text, '日本語 🌱');
      expect(request!.headers['Idempotency-Key'], 'logical-turn-000000000001');
      expect(request!.headers['Authorization'], 'Bearer test-access');
      expect(request!.headers['X-Firebase-AppCheck'], 'test-attestation');
      expect(request!.headers['X-Glimpse-Feature'], 'ask');
      expect(request!.uri.path, endsWith('/ask/stream'));
    },
  );

  test('stream failure never silently starts another generation', () async {
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 503,
              data: ResponseBody.fromString('', 503),
            ),
          );
        },
      ),
    );
    final transport = AiTransport(
      dio: dio,
      accessTokenProvider: ({bool forceRefresh = false}) async => null,
      appCheckTokenProvider: ({bool forceRefresh = false}) async =>
          'test-attestation',
    );
    await expectLater(
      transport
          .streamAsk(
            body: {},
            turnId: 'logical-turn-000000000002',
            cancelToken: CancelToken(),
          )
          .toList(),
      throwsA(isA<AiTransportException>()),
    );
    expect(requests, 1);
  });
}
