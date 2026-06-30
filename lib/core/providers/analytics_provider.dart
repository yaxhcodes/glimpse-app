import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import '../services/supabase_analytics_service.dart';
import 'auth_provider.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final service = SupabaseAnalyticsService(
    userIdProvider: () => ref.read(authServiceProvider).currentUser?.id,
  );
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
