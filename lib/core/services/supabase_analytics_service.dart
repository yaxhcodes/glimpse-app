import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/device_diagnostics.dart';
import 'analytics_service.dart';
import 'device_diagnostics_service.dart';
import 'supabase_config.dart';

typedef AnalyticsUserIdProvider = FutureOr<String?> Function();

class SupabaseAnalyticsService implements AnalyticsService {
  SupabaseAnalyticsService({
    required AnalyticsUserIdProvider userIdProvider,
    DeviceDiagnosticsService? diagnosticsService,
    Connectivity? connectivity,
  }) : _userIdProvider = userIdProvider,
       _diagnosticsService = diagnosticsService ?? DeviceDiagnosticsService(),
       _connectivity = connectivity ?? Connectivity(),
       _sessionId = const Uuid().v4();

  static const _queueKey = 'glimpse_analytics_queue_v1';
  static const _maxQueueSize = 200;
  static const _batchSize = 25;
  static const _flushInterval = Duration(seconds: 30);

  final AnalyticsUserIdProvider _userIdProvider;
  final DeviceDiagnosticsService _diagnosticsService;
  final Connectivity _connectivity;
  final String _sessionId;
  final List<_QueuedAnalyticsEvent> _queue = [];

  DeviceDiagnostics? _diagnostics;
  Timer? _flushTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _initialized = false;
  bool _flushing = false;

  @override
  String get sessionId => _sessionId;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _diagnostics = await _diagnosticsService.load();
    await _restoreQueue();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (_hasConnection(results)) unawaited(flush());
    });
    _flushTimer = Timer.periodic(_flushInterval, (_) => unawaited(flush()));
    await trackEvent(AnalyticsEvent.sessionStart);
    await trackEvent(AnalyticsEvent.appOpen);
    unawaited(flush());
  }

  @override
  Future<void> trackEvent(
    AnalyticsEvent event, {
    AnalyticsScreen? screen,
  }) async {
    if (!_initialized) await initialize();
    _queue.add(
      _QueuedAnalyticsEvent(
        eventName: event.name,
        screenName: screen?.name,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (_queue.length > _maxQueueSize) {
      _queue.removeRange(0, _queue.length - _maxQueueSize);
    }
    await _persistQueue();
    if (_queue.length >= _batchSize) unawaited(flush());
  }

  @override
  Future<void> trackScreen(AnalyticsScreen screen) async {
    await trackEvent(AnalyticsEvent.screenOpen, screen: screen);
    final featureEvent = switch (screen) {
      AnalyticsScreen.home => AnalyticsEvent.homeOpened,
      AnalyticsScreen.search => AnalyticsEvent.searchOpened,
      AnalyticsScreen.rediscover => AnalyticsEvent.rediscoverOpened,
      AnalyticsScreen.askGlimpse => AnalyticsEvent.askGlimpseOpened,
      AnalyticsScreen.subscription => AnalyticsEvent.subscriptionScreenOpened,
      AnalyticsScreen.settings => AnalyticsEvent.settingsOpened,
      _ => null,
    };
    if (featureEvent != null) {
      await trackEvent(featureEvent, screen: screen);
    }
  }

  @override
  Future<void> flush() async {
    if (_flushing || _queue.isEmpty || !SupabaseConfig.isConfigured) return;
    final userId = await _userIdProvider();
    if (userId == null || userId.isEmpty) return;
    final connectivity = await _connectivity.checkConnectivity();
    if (!_hasConnection(connectivity)) return;
    final diagnostics = _diagnostics ?? await _diagnosticsService.load();
    _diagnostics = diagnostics;
    final batch = _queue.take(_batchSize).toList(growable: false);
    _flushing = true;
    try {
      await _client
          .from('analytics_events')
          .insert(
            batch
                .map(
                  (event) => {
                    'user_id': userId,
                    'session_id': _sessionId,
                    'event_name': event.eventName,
                    'screen_name': event.screenName,
                    'created_at': event.createdAt.toIso8601String(),
                    'app_version': diagnostics.appVersion,
                    'build_version': diagnostics.buildVersion,
                    'platform': diagnostics.platform,
                    'os_version': diagnostics.osVersion,
                    'device_manufacturer': diagnostics.deviceManufacturer,
                    'device_model': diagnostics.deviceModel,
                  },
                )
                .toList(growable: false),
          );
      _queue.removeRange(0, batch.length);
      await _persistQueue();
    } catch (e, st) {
      developer.log(
        'Analytics flush failed — $e',
        name: 'Analytics',
        stackTrace: st,
      );
    } finally {
      _flushing = false;
    }
  }

  @override
  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      await trackEvent(AnalyticsEvent.sessionEnd);
      await flush();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(flush());
    }
  }

  @override
  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await trackEvent(AnalyticsEvent.sessionEnd);
    await flush();
  }

  Future<void> _restoreQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _queue
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map(
                (row) => _QueuedAnalyticsEvent.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .whereType<_QueuedAnalyticsEvent>(),
        );
      if (_queue.length > _maxQueueSize) {
        _queue.removeRange(0, _queue.length - _maxQueueSize);
      }
    } catch (e) {
      developer.log('Analytics queue restore failed — $e', name: 'Analytics');
      await prefs.remove(_queueKey);
    }
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    if (_queue.isEmpty) {
      await prefs.remove(_queueKey);
      return;
    }
    await prefs.setString(
      _queueKey,
      jsonEncode(_queue.map((event) => event.toJson()).toList()),
    );
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}

class _QueuedAnalyticsEvent {
  const _QueuedAnalyticsEvent({
    required this.eventName,
    required this.screenName,
    required this.createdAt,
  });

  final String eventName;
  final String? screenName;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'event_name': eventName,
      'screen_name': screenName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static _QueuedAnalyticsEvent? fromJson(Map<String, dynamic> json) {
    final eventName = json['event_name'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (eventName is! String || eventName.isEmpty || createdAt == null) {
      return null;
    }
    final screenName = json['screen_name'];
    return _QueuedAnalyticsEvent(
      eventName: eventName,
      screenName: screenName is String && screenName.isNotEmpty
          ? screenName
          : null,
      createdAt: createdAt,
    );
  }
}
