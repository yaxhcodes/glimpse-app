import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'glimpse_activity.dart';
import 'glimpse_service.dart';

final glimpseActivityProvider = FutureProvider<GlimpseActivity>((ref) async {
  final sources = await ref.watch(glimpseSourcesProvider.future);
  final now = DateTime.now();
  final timer = Timer(
    DateTime(now.year, now.month, now.day + 1).difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return compute(buildGlimpseActivity, (sources.values.toList(), now));
});
