import 'ai/ai_transport.dart';
import 'usage_limits.dart';

/// A snapshot of a feature's server-side plan quota.
class AiQuotaSnapshot {
  const AiQuotaSnapshot({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.allowed,
    required this.enforced,
  });

  /// Uses consumed in the active plan window.
  final int used;

  /// Allowance for the active plan window.
  final int limit;

  /// Remaining uses (`limit - used`, floored at 0).
  final int remaining;

  /// Whether a further consume is permitted right now.
  final bool allowed;

  /// `false` when the worker has no quota store configured. The caller should
  /// then fall back to its local counter rather than trust [used].
  final bool enforced;

  /// The user is enforced *and* out of allowance.
  bool get reached => enforced && !allowed;
}

/// Server-authoritative plan quota for costly AI features.
///
/// Talks to the Cloudflare Worker `/quota` endpoint, which counts usage per
/// durable installation. Free AI saves are lifetime; Pro AI saves and the
/// remaining free features reset monthly. The verified Supabase account and
/// App Check token authorize the request, while `X-User-Id` owns the shared
/// device allowance. This source of truth survives account switches and, when
/// the platform durable store restores successfully, reinstall / "clear app
/// data".
///
/// AI enrichment itself requires the worker, so when the worker is unreachable
/// (and a peek/consume throws) no AI — and therefore no cost — happens; callers
/// can safely fall back to the local mirror without opening an abuse hole.
class AiQuotaService {
  AiQuotaService({AiTransport? transport})
    : _transport = transport ?? AiTransport.instance;

  static final AiQuotaService instance = AiQuotaService();

  final AiTransport _transport;
  static const int _deviceScopeVersion = 3;

  /// Maps a [UsageFeature] to its server feature key, or `null` when the
  /// feature is metered purely locally (no server-side cost ceiling yet).
  static String? serverFeature(UsageFeature feature) => switch (feature) {
    UsageFeature.aiSave => 'aiSave',
    UsageFeature.ask => 'ask',
    UsageFeature.search => 'search',
  };

  /// Reads the current count without consuming (the gate check).
  Future<AiQuotaSnapshot> peek(String feature, {int? migrationUsed}) =>
      _call(feature, commit: false, migrationUsed: migrationUsed);

  /// Atomically checks and consumes one unit (called on a successful AI save).
  Future<AiQuotaSnapshot> consume(String feature, {int? migrationUsed}) =>
      _call(feature, commit: true, migrationUsed: migrationUsed);

  Future<AiQuotaSnapshot> _call(
    String feature, {
    required bool commit,
    int? migrationUsed,
  }) async {
    final json = await _transport.postJson(
      '/quota',
      body: {
        'feature': feature,
        'commit': commit,
        'scopeVersion': _deviceScopeVersion,
        // build_runner's pinned analyzer cannot parse null-aware map entries.
        // ignore: use_null_aware_elements
        if (migrationUsed != null) 'localUsed': migrationUsed,
      },
    );
    return AiQuotaSnapshot(
      used: (json['used'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      allowed: json['allowed'] as bool? ?? true,
      enforced: json['enforced'] as bool? ?? false,
    );
  }
}
