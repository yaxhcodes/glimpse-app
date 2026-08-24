import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

/// Moves Glimpse behind the source app without destroying its Flutter engine.
class AppTaskService {
  AppTaskService({
    MethodChannel channel = const MethodChannel(_channelName),
    bool? isAndroid,
  }) : _channel = channel,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  static const _channelName = 'com.shinrinyoku.glimpse/app_task';
  static const _tag = 'AppTaskService';

  final MethodChannel _channel;
  final bool _isAndroid;

  Future<bool> startEnrichmentKeepAlive(String processingId) async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'startEnrichmentKeepAlive',
            processingId,
          ) ??
          false;
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Could not protect share enrichment in the background.',
        name: _tag,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> finishEnrichmentKeepAlive(String processingId) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'finishEnrichmentKeepAlive',
        processingId,
      );
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Could not release share enrichment background protection.',
        name: _tag,
        error: error,
        stackTrace: stackTrace,
      );
    } on MissingPluginException {
      // The bridge is intentionally Android-only.
    }
  }

  Future<bool> moveToBackground() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('moveToBackground') ?? false;
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Could not move the Android task to the background.',
        name: _tag,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
