import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'glimpse_service.dart';

void openGlimpse(
  BuildContext context,
  String key,
  List<int> sourceIds, {
  bool homeBackStack = false,
}) {
  final ids = sourceIds.toSet();
  if (ids.length == 1) {
    final service = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(glimpseServiceProvider);
    unawaited(
      service.openKey(key).catchError((Object error, StackTrace stack) {
        developer.log(
          'Could not record the opened glimpse',
          name: 'Glimpse',
          error: error,
          stackTrace: stack,
        );
      }),
    );
  }
  if (homeBackStack) context.go('/');
  if (ids.length == 1) {
    context.push('/url/${ids.single}');
  } else {
    context.push('/glimpses/detail', extra: key);
  }
}
