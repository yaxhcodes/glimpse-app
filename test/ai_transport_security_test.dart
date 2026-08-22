import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/ai/ai_transport.dart';

void main() {
  test(
    'reuses one idempotency key and refreshes credentials once on 401',
    () async {
      final requests = <RequestOptions>[];
      final accessRefreshes = <bool>[];
      final appCheckRefreshes = <bool>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (requests.length == 1) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'error': 'unauthorized'},
                ),
              );
              return;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': 'secured response'},
                        ],
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final transport = AiTransport(
        dio: dio,
        accessTokenProvider: ({bool forceRefresh = false}) async {
          accessRefreshes.add(forceRefresh);
          return forceRefresh ? 'fresh-access-token' : 'initial-access-token';
        },
        appCheckTokenProvider: ({bool forceRefresh = false}) async {
          appCheckRefreshes.add(forceRefresh);
          return forceRefresh ? 'fresh-app-check' : 'initial-app-check';
        },
        requestIdFactory: () => 'request-idempotency-0001',
      );

      final result = await transport.postGemini(
        feature: AiRequestFeature.ask,
        body: {
          'contents': [
            {
              'parts': [
                {'text': 'hello'},
              ],
            },
          ],
        },
      );

      expect(result, 'secured response');
      expect(requests, hasLength(2));
      expect(accessRefreshes, [false, true]);
      expect(appCheckRefreshes, [false, true]);
      expect(
        requests.map((request) => request.headers['Idempotency-Key']).toSet(),
        {'request-idempotency-0001'},
      );
      expect(
        requests.last.headers['Authorization'],
        'Bearer fresh-access-token',
      );
      expect(requests.last.headers['X-Firebase-AppCheck'], 'fresh-app-check');
      expect(
        requests.map((request) => request.headers['X-Glimpse-Feature']).toSet(),
        {'ask'},
      );
    },
  );

  test('does not retry a 429 response', () async {
    var requestCount = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount += 1;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 429,
              data: {'error': 'rate_limit_exceeded'},
            ),
          );
        },
      ),
    );
    final transport = AiTransport(
      dio: dio,
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          'access-token',
      appCheckTokenProvider: ({bool forceRefresh = false}) async => 'app-check',
      requestIdFactory: () => 'request-rate-limit-0001',
    );

    await expectLater(
      transport.postGemini(
        body: {
          'contents': [
            {
              'parts': [
                {'text': 'hello'},
              ],
            },
          ],
        },
      ),
      throwsA(
        isA<AiTransportException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having(
              (error) => error.type,
              'type',
              AiTransportErrorType.rateLimited,
            ),
      ),
    );
    expect(requestCount, 1);
  });

  test('bounds retries for a 503 response', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 503,
              data: {'error': 'security_control_unavailable'},
            ),
          );
        },
      ),
    );
    final transport = AiTransport(
      dio: dio,
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          'access-token',
      appCheckTokenProvider: ({bool forceRefresh = false}) async => 'app-check',
      requestIdFactory: () => 'request-unavailable-0001',
    );

    await expectLater(
      transport.postGemini(
        body: {
          'contents': [
            {
              'parts': [
                {'text': 'hello'},
              ],
            },
          ],
        },
      ),
      throwsA(
        isA<AiTransportException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    expect(requests, hasLength(2));
    expect(
      requests.map((request) => request.headers['Idempotency-Key']).toSet(),
      {'request-unavailable-0001'},
    );
  });

  test('routes enrichment through the authenticated proxy gateway', () async {
    RequestOptions? captured;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {'meaningful_title': 'Cached save'},
            ),
          );
        },
      ),
    );
    final transport = AiTransport(
      dio: dio,
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          'access-token',
      appCheckTokenProvider: ({bool forceRefresh = false}) async => 'app-check',
      requestIdFactory: () => 'request-enrichment-0001',
    );

    await transport.postEnrichment(body: {'url': 'https://youtu.be/example'});

    expect(captured?.uri.path, '/enrich-url');
    expect(captured?.headers['Authorization'], 'Bearer access-token');
    expect(captured?.headers['X-Firebase-AppCheck'], 'app-check');
  });
}
