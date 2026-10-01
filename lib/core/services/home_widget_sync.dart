import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import '../providers/service_providers.dart';
import 'category_resolver.dart';
import 'rediscovery_service.dart';
import 'saved_media_resolver.dart';
import 'title_resolver.dart';

/// Fetches a save's picture, reusing the app's own image cache: Instagram
/// links expire, but a picture the library already showed is still there.
typedef WidgetImageFetcher = Future<File?> Function(String url);

final homeWidgetSyncProvider = Provider<HomeWidgetSync>((ref) {
  return HomeWidgetSync(isarService: ref.read(isarServiceProvider));
});

/// Keeps the Rediscover home screen widget in step with the library.
///
/// Ranking, titles and pictures all live on this side, so the widget gets a
/// short ranked list of ready-to-show saves (see `HomeWidgetStore.kt`) and
/// turns through it on its own while the app is closed.
class HomeWidgetSync {
  HomeWidgetSync({
    required IsarService isarService,
    MethodChannel channel = const MethodChannel(_channelName),
    bool? isAndroid,
    Future<Directory> Function()? directory,
    WidgetImageFetcher? fetchImage,
  }) : _isar = isarService,
       _channel = channel,
       _isAndroid = isAndroid ?? Platform.isAndroid,
       _directory = directory ?? _defaultDirectory,
       _fetchImage = fetchImage ?? _fetchFromAppCache;

  static const _tag = 'HomeWidgetSync';
  static const _channelName = 'com.shinrinyoku.glimpse/home_widget';

  /// Enough to turn over for a day or two between app opens.
  static const maxSaves = 8;

  /// Under this, a save is still fresh in mind; nothing to rediscover.
  static const minAge = Duration(days: 1);

  static const _minInterval = Duration(seconds: 30);
  static const _maxPictureBytes = 6 * 1024 * 1024;

  final IsarService _isar;
  final MethodChannel _channel;
  final bool _isAndroid;
  final Future<Directory> Function() _directory;
  final WidgetImageFetcher _fetchImage;

  Future<void>? _inFlight;
  DateTime? _lastSync;

  /// Pushes fresh saves when a widget is placed. Cheap to call often: it
  /// coalesces with a sync in flight and skips one that just ran.
  Future<void> sync({bool force = false}) {
    if (!_isAndroid) return Future.value();
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final last = _lastSync;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minInterval) {
      return Future.value();
    }
    return _inFlight = _run().whenComplete(() {
      _inFlight = null;
      _lastSync = DateTime.now();
    });
  }

  Future<void> _run() async {
    try {
      final inUse = await _channel.invokeMethod<bool>('isInUse') ?? false;
      if (!inUse) return;

      final ranked = await RediscoveryService(
        _isar,
      ).getRediscoveryLinks(limit: maxSaves * 2);
      final library = await _isar.getAllUrls();
      final saves = selectWidgetSaves(ranked: ranked, library: library);

      final dir = await _pictureDirectory();
      final entries = <Map<String, Object?>>[];
      final kept = <String>{};
      for (final save in saves) {
        final picture = await _cachePicture(save, dir);
        if (picture != null) kept.add(picture.uri.pathSegments.last);
        entries.add(widgetEntryFor(save, picturePath: picture?.path));
      }
      await _channel.invokeMethod<void>(
        'updateRediscover',
        jsonEncode(entries),
      );
      await _prune(dir, kept);
    } on MissingPluginException {
      // The widget bridge is Android-only.
    } catch (error, stackTrace) {
      developer.log(
        'Could not update the home screen widget.',
        name: _tag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Rediscover's ranking first, topped up with older saves the user has
  /// not opened (then any older ones), so a small library still has a
  /// widget to show. Never a save from the last day: that isn't a memory.
  @visibleForTesting
  static List<SavedUrl> selectWidgetSaves({
    required List<SavedUrl> ranked,
    required List<SavedUrl> library,
    int limit = maxSaves,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    bool eligible(SavedUrl u) =>
        !u.isInBin &&
        !u.isDone &&
        u.rediscoverDismissedAt == null &&
        u.isProcessingReady &&
        u.savedAt.isBefore(cutoff);

    final picked = <SavedUrl>[];
    final seen = <int>{};
    void take(Iterable<SavedUrl> source) {
      for (final u in source) {
        if (picked.length >= limit) return;
        if (eligible(u) && seen.add(u.id)) picked.add(u);
      }
    }

    take(ranked);
    final oldestFirst = library.toList()
      ..sort((a, b) => a.savedAt.compareTo(b.savedAt));
    take(oldestFirst.where((u) => u.openedAt == null));
    take(oldestFirst);
    return picked;
  }

  /// What the widget needs to show one save, already resolved.
  @visibleForTesting
  static Map<String, Object?> widgetEntryFor(
    SavedUrl save, {
    String? picturePath,
  }) {
    return {
      'id': save.id,
      'title': TitleResolver.resolveDetailTitle(save),
      'source': CategoryResolver.displaySourceName(
        rawUrl: save.rawUrl,
        fallbackDomain: save.domain,
      ),
      'savedAt': save.savedAt.millisecondsSinceEpoch,
      'image': picturePath,
    };
  }

  /// A copy of the save's picture the widget can read later, even after the
  /// app's image cache has moved on.
  Future<File?> _cachePicture(SavedUrl save, Directory dir) async {
    final candidates = SavedMediaResolver.imageCandidates(save);
    if (candidates.isEmpty) return null;
    final key = sha1.convert(utf8.encode(candidates.first)).toString();
    final target = File('${dir.path}/save_${save.id}_${key.substring(0, 12)}');
    if (await target.exists()) return target;

    for (final url in candidates.take(2)) {
      try {
        final file = await _fetchImage(
          url,
        ).timeout(const Duration(seconds: 12));
        if (file == null) continue;
        final length = await file.length();
        if (length == 0 || length > _maxPictureBytes) continue;
        return await file.copy(target.path);
      } catch (_) {
        // Expired or unreachable: try the next picture, or go without.
      }
    }
    return null;
  }

  Future<Directory> _pictureDirectory() async {
    final dir = Directory('${(await _directory()).path}/home_widget');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _prune(Directory dir, Set<String> kept) async {
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (kept.contains(entity.uri.pathSegments.last)) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  static Future<Directory> _defaultDirectory() =>
      getApplicationSupportDirectory();

  static Future<File?> _fetchFromAppCache(String url) {
    return DefaultCacheManager().getSingleFile(
      url,
      headers: SavedMediaResolver.imageHttpHeaders(url) ?? const {},
    );
  }
}
