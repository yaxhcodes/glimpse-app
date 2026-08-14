import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/ai/ai_transport.dart';
import 'package:glimpse/core/services/ai_quota_service.dart';
import 'package:glimpse/core/services/usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends the versioned device scope and local migration count', () async {
    RequestOptions? captured;
    final backend = _QuotaBackend();
    final quota = _quotaService(
      onRequest: (options) {
        captured = options;
        return backend.respond(options);
      },
    );

    final snapshot = await quota.peek('aiSave', migrationUsed: 11);

    expect(snapshot.used, 11);
    expect(snapshot.remaining, 19);
    expect(captured?.path, endsWith('/quota'));
    expect(captured?.data, {
      'feature': 'aiSave',
      'commit': false,
      'scopeVersion': 2,
      'localUsed': 11,
    });
  });

  test('free account sees the shared device remainder', () async {
    SharedPreferences.setMockInitialValues({
      'usage_last_reset': DateTime.now().toUtc().toIso8601String(),
      'usage_aiSave_count': 11,
    });
    final backend = _QuotaBackend();
    final usage = UsageService(
      aiQuota: _quotaService(onRequest: backend.respond),
    );

    final remaining = await usage.getRemaining(UsageFeature.aiSave, false);

    expect(remaining, 19);
    expect(await usage.getUsage(UsageFeature.aiSave), 11);
  });

  test('successful Pro usage is counted for a later free account', () async {
    SharedPreferences.setMockInitialValues({
      'usage_last_reset': DateTime.now().toUtc().toIso8601String(),
      'usage_ask_count': 11,
    });
    var requests = 0;
    final requestBodies = <Map<String, dynamic>>[];
    final backend = _QuotaBackend();
    final usage = UsageService(
      aiQuota: _quotaService(
        onRequest: (options) {
          requests++;
          requestBodies.add(Map<String, dynamic>.from(options.data as Map));
          return backend.respond(options);
        },
      ),
    );

    expect(await usage.hasReachedLimit(UsageFeature.ask, true), isFalse);
    expect(requests, 0);

    await usage.incrementUsage(UsageFeature.ask);

    expect(requests, 1);
    expect(await usage.getUsage(UsageFeature.ask), 12);
    expect(await usage.getRemaining(UsageFeature.ask, false), 18);
    expect(requestBodies.first['localUsed'], 11);
    expect(requestBodies.last.containsKey('localUsed'), isFalse);
  });

  test(
    'free account receives zero after device usage reaches the cap',
    () async {
      final limit = UsageLimits.getLimit(UsageFeature.search);
      SharedPreferences.setMockInitialValues({
        'usage_last_reset': DateTime.now().toUtc().toIso8601String(),
        'usage_search_count': limit,
      });
      final backend = _QuotaBackend();
      final usage = UsageService(
        aiQuota: _quotaService(onRequest: backend.respond),
      );

      expect(await usage.getRemaining(UsageFeature.search, false), 0);
      expect(await usage.hasReachedLimit(UsageFeature.search, false), isTrue);
    },
  );

  test('local limit snapshot never performs a quota request', () async {
    final limit = UsageLimits.getLimit(UsageFeature.aiSave);
    SharedPreferences.setMockInitialValues({
      'usage_last_reset': DateTime.now().toUtc().toIso8601String(),
      'usage_aiSave_count': limit,
    });
    var requests = 0;
    final usage = UsageService(
      aiQuota: _quotaService(
        onRequest: (options) {
          requests++;
          return _QuotaBackend().respond(options);
        },
      ),
    );

    expect(
      await usage.hasReachedLocalLimit(UsageFeature.aiSave, false),
      isTrue,
    );
    expect(requests, 0);
  });
}

AiQuotaService _quotaService({
  required Map<String, dynamic> Function(RequestOptions options) onRequest,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: onRequest(options),
          ),
        );
      },
    ),
  );
  return AiQuotaService(
    transport: AiTransport(
      dio: dio,
      accessTokenProvider: ({bool forceRefresh = false}) async => 'access',
      appCheckTokenProvider: ({bool forceRefresh = false}) async => 'app-check',
      requestIdFactory: () => 'device-quota-request-0001',
    ),
  );
}

class _QuotaBackend {
  static const limit = 30;

  int used = 0;
  bool initialized = false;

  Map<String, dynamic> respond(RequestOptions options) {
    final body = Map<String, dynamic>.from(options.data as Map);
    final migrationUsed = (body['localUsed'] as num?)?.toInt();
    if (!initialized && migrationUsed != null) {
      used = migrationUsed.clamp(0, limit);
      initialized = true;
    }
    if (body['commit'] == true && used < limit) {
      used++;
      initialized = true;
    }
    return {
      'used': used,
      'limit': limit,
      'remaining': (limit - used).clamp(0, limit),
      'allowed': used < limit,
      'enforced': true,
    };
  }
}
