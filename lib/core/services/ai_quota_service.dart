import 'ai/ai_transport.dart';
import 'usage_limits.dart';

/// A snapshot of a feature's server-side monthly quota.
class AiQuotaSnapshot {
  const AiQuotaSnapshot({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.allowed,
    required this.enforced,
  });

  /// Uses consumed this month for the verified account.
  final int used;

  /// Monthly allowance for free users.
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

/// Server-authoritative monthly quota for costly AI features.
///
/// Talks to the Cloudflare Worker `/quota` endpoint, which counts usage per
/// the verified Supabase account and resets monthly. `X-User-Id` remains only a
/// secondary installation signal and never owns quota. This source of truth
/// survives reinstall / "clear app data" —
/// closing the free-tier farming hole that a purely local counter cannot.
///
/// AI enrichment itself requires the worker, so when the worker is unreachable
/// (and a peek/consume throws) no AI — and therefore no cost — happens; callers
/// can safely fall back to the local mirror without opening an abuse hole.
class AiQuotaService {
  AiQuotaService({AiTransport? transport})
    : _transport = transport ?? AiTransport.instance;

  static final AiQuotaService instance = AiQuotaService();

  final AiTransport _transport;

  /// Maps a [UsageFeature] to its server feature key, or `null` when the
  /// feature is metered purely locally (no server-side cost ceiling yet).
  static String? serverFeature(UsageFeature feature) => switch (feature) {
    UsageFeature.aiSave => 'aiSave',
    UsageFeature.ask => 'ask',
    UsageFeature.search => 'search',
  };

  /// Reads the current count without consuming (the gate check).
  Future<AiQuotaSnapshot> peek(String feature) => _call(feature, commit: false);

  /// Atomically checks and consumes one unit (called on a successful AI save).
  Future<AiQuotaSnapshot> consume(String feature) =>
      _call(feature, commit: true);

  Future<AiQuotaSnapshot> _call(String feature, {required bool commit}) async {
    final json = await _transport.postJson(
      '/quota',
      body: {'feature': feature, 'commit': commit},
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
