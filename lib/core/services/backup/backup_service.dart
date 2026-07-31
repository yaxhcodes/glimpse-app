import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/isar_service.dart';
import '../../models/saved_url.dart';
import '../../services/session_tracking_service.dart';
import 'backup_models.dart';

class BackupService {
  final IsarService _isarService;

  static const _tag = 'BackupService';

  BackupService({required IsarService isarService})
    : _isarService = isarService;

  BackupResult? _lastResult;
  BackupResult? get lastResult => _lastResult;

  SavedUrlBackup toBackup(SavedUrl url) {
    final embedding = _sanitizeEmbedding(url.embedding);

    return SavedUrlBackup(
      rawUrl: url.rawUrl,
      domain: url.domain,
      title: url.title,
      description: url.description,
      thumbnailUrl: url.thumbnailUrl,
      category: url.category,
      categoryEmoji: url.categoryEmoji,
      categories: List<String>.from(url.categories),
      tags: List<String>.from(url.tags),
      userNotes: url.userNotes,
      summary: url.summary,
      enrichmentJson: url.enrichmentJson,
      processingStatus: url.processingStatus,
      processingId: url.processingId,
      processingAttempt: url.processingAttempt,
      processingUpdatedAt: url.processingUpdatedAt?.toIso8601String(),
      processingError: url.processingError,
      savedAt: url.savedAt.toIso8601String(),
      openedAt: url.openedAt?.toIso8601String(),
      resurfacedAt: url.resurfacedAt?.toIso8601String(),
      rediscoverDismissedAt: url.rediscoverDismissedAt?.toIso8601String(),
      intentStatus: url.intentStatus,
      intentAction: url.intentAction,
      intentSetAt: url.intentSetAt?.toIso8601String(),
      revisitAfter: url.revisitAfter?.toIso8601String(),
      embedding: embedding,
    );
  }

  List<double>? _sanitizeEmbedding(List<double>? embedding) {
    if (embedding == null || embedding.isEmpty) return null;

    bool hasBad = false;
    for (final v in embedding) {
      if (v.isNaN || v.isInfinite || v.isNegative && v.isInfinite) {
        hasBad = true;
        break;
      }
    }

    if (!hasBad) return List<double>.from(embedding);

    developer.log(
      'Embedding contains non-finite values — stripping for JSON safety',
      name: _tag,
    );

    final sanitized = <double>[];
    for (final v in embedding) {
      if (v.isFinite) {
        sanitized.add(v);
      }
    }
    return sanitized.isEmpty ? null : sanitized;
  }

  SavedUrl fromBackup(SavedUrlBackup b) => SavedUrl()
    ..rawUrl = b.rawUrl
    ..domain = b.domain
    ..title = b.title
    ..description = b.description
    ..thumbnailUrl = b.thumbnailUrl
    ..category = b.category
    ..categoryEmoji = b.categoryEmoji
    ..categories = List<String>.from(b.categories)
    ..tags = List<String>.from(b.tags)
    ..userNotes = b.userNotes
    ..summary = b.summary
    ..enrichmentJson = b.enrichmentJson
    ..processingStatus = b.processingStatus
    ..processingId = b.processingId
    ..processingAttempt = b.processingAttempt
    ..processingUpdatedAt = _parseOptionalDate(b.processingUpdatedAt)
    ..processingError = b.processingError
    ..savedAt = DateTime.parse(b.savedAt)
    ..openedAt = _parseOptionalDate(b.openedAt)
    ..resurfacedAt = _parseOptionalDate(b.resurfacedAt)
    ..rediscoverDismissedAt = _parseOptionalDate(b.rediscoverDismissedAt)
    ..intentStatus = b.intentStatus
    ..intentAction = b.intentAction
    ..intentSetAt = _parseOptionalDate(b.intentSetAt)
    ..revisitAfter = _parseOptionalDate(b.revisitAfter)
    ..embedding = b.embedding != null ? List<double>.from(b.embedding!) : null;

  DateTime? _parseOptionalDate(String? value) =>
      value == null ? null : DateTime.parse(value);

  SessionRecordBackup toSessionBackup(SessionRecord r, String rawUrl) =>
      SessionRecordBackup(
        rawUrl: rawUrl,
        sessionId: r.sessionId,
        savedAt: r.savedAt.toIso8601String(),
      );

  /// Builds the backup JSON payload + counts without writing it anywhere.
  ///
  /// Used by both the share flow (which writes to a temp file) and the
  /// "Save to device" flow (which hands the bytes to the OS file picker).
  Future<BackupPayload> buildBackupPayload() async {
    developer.log('Building backup payload', name: _tag);

    developer.log('Loading URLs from Isar...', name: _tag);
    final urls = await _isarService.getAllUrls();
    developer.log('Loaded ${urls.length} URLs', name: _tag);

    developer.log('Loading collections from Isar...', name: _tag);
    final collections = await _isarService.getAllCollections();
    developer.log('Loaded ${collections.length} collections', name: _tag);

    developer.log('Loading session records...', name: _tag);
    final sessionService = SessionTrackingService();
    final sessionRecords = await sessionService.readAll();
    developer.log(
      'Loaded ${sessionRecords.length} session records',
      name: _tag,
    );

    final urlById = {for (final u in urls) u.id: u};

    developer.log('Serializing ${urls.length} links...', name: _tag);
    final linkBackups = urls.map((u) => toBackup(u)).toList();

    final embeddingCount = linkBackups.where((l) => l.embedding != null).length;
    final totalEmbeddingDims = linkBackups.fold<int>(
      0,
      (sum, l) => sum + (l.embedding?.length ?? 0),
    );
    developer.log(
      'Embeddings: $embeddingCount links with vectors, $totalEmbeddingDims total dimensions',
      name: _tag,
    );

    final urlMap = {for (final u in urls) u.id: u.rawUrl};
    final collectionBackups = collections
        .map(
          (c) => UserCollectionBackup(
            name: c.name,
            emoji: c.emoji,
            description: c.description,
            createdAt: c.createdAt.toIso8601String(),
            linkUrls: c.urlIds
                .map((id) => urlMap[id] ?? '')
                .where((u) => u.isNotEmpty)
                .toList(),
          ),
        )
        .toList();

    final sessionBackups = sessionRecords
        .map((r) {
          final rawUrl = urlById[r.urlId]?.rawUrl ?? '';
          if (rawUrl.isEmpty) return null;
          return toSessionBackup(r, rawUrl);
        })
        .whereType<SessionRecordBackup>()
        .toList();

    developer.log('Exporting settings...', name: _tag);
    final settings = await _exportSettings();

    final packageInfo = await PackageInfo.fromPlatform();
    final device =
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

    final backup = BackupData(
      version: BackupData.currentVersion,
      createdAt: DateTime.now().toIso8601String(),
      appVersion: packageInfo.version,
      device: device,
      links: linkBackups,
      collections: collectionBackups,
      saveSessions: sessionBackups,
      settings: settings,
    );

    developer.log('Encoding JSON...', name: _tag);
    String json;
    try {
      json = const JsonEncoder.withIndent('  ').convert(backup.toJson());
      developer.log('JSON encoded: ${json.length} characters', name: _tag);
    } catch (e, st) {
      developer.log(
        'jsonEncode FAILED: $e',
        name: _tag,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    return BackupPayload(
      json: json,
      fileName: defaultBackupFileName(),
      linkCount: linkBackups.length,
      collectionCount: collectionBackups.length,
      sessionCount: sessionBackups.length,
    );
  }

  /// Fixed filename so each new write replaces the previous snapshot in the folder.
  static String defaultBackupFileName() => 'glimpse-backup.json';

  /// Builds the backup, writes it to a temp file, and returns the path.
  /// Used by the share-sheet flow.
  Future<String> exportBackup() async {
    developer.log('Export started', name: _tag);
    final payload = await buildBackupPayload();

    developer.log('Writing temp file: ${payload.fileName}', name: _tag);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${payload.fileName}');

    try {
      await file.writeAsString(payload.json);
      developer.log(
        'Temp file written: ${file.path} (${payload.json.length} chars)',
        name: _tag,
      );
    } catch (e, st) {
      developer.log(
        'File write FAILED: $e',
        name: _tag,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    _lastResult = BackupResult(
      linkCount: payload.linkCount,
      collectionCount: payload.collectionCount,
      sessionCount: payload.sessionCount,
      filePath: file.path,
    );

    developer.log('Export complete successfully', name: _tag);
    return file.path;
  }

  /// Builds the backup, writes it to the given absolute filesystem path,
  /// and returns the path. Used when we already know where to save (e.g. when
  /// the OS file picker returns a writable path on Android < 11 / iOS).
  Future<String> saveBackupToPath(String destinationPath) async {
    developer.log('Saving backup to path: $destinationPath', name: _tag);
    final payload = await buildBackupPayload();

    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(payload.json);

    _lastResult = BackupResult(
      linkCount: payload.linkCount,
      collectionCount: payload.collectionCount,
      sessionCount: payload.sessionCount,
      filePath: file.path,
    );

    developer.log('Backup saved to: ${file.path}', name: _tag);
    return file.path;
  }

  /// Returns the JSON payload as UTF-8 bytes plus its metadata, without
  /// writing anywhere. Use this when handing the file off to the platform
  /// file picker (which writes through SAF on Android).
  Future<({Uint8List bytes, BackupPayload payload})> buildBackupBytes() async {
    final payload = await buildBackupPayload();
    final bytes = Uint8List.fromList(utf8.encode(payload.json));
    _lastResult = BackupResult(
      linkCount: payload.linkCount,
      collectionCount: payload.collectionCount,
      sessionCount: payload.sessionCount,
      filePath: payload.fileName,
    );
    return (bytes: bytes, payload: payload);
  }

  Future<ShareResult> shareBackup(String filePath) async {
    developer.log('Sharing backup file: $filePath', name: _tag);
    final result = await Share.shareXFiles([
      XFile(filePath),
    ], text: 'Glimpse backup — ${_lastResult?.linkCount ?? 0} links');
    developer.log('Share result: ${result.status}', name: _tag);
    return result;
  }

  Future<BackupData> validateBackup(String jsonContent) async {
    developer.log(
      'Validating backup (${jsonContent.length} chars)',
      name: _tag,
    );

    if (jsonContent.isEmpty) {
      throw BackupValidationException('The selected file is empty.');
    }

    // Quick sniff: if the content doesn't even look like JSON (no opening
    // brace early on, or contains lots of NUL bytes from a binary file
    // like an Isar DB), give a friendlier message than "invalid JSON".
    final head = jsonContent.length > 64
        ? jsonContent.substring(0, 64)
        : jsonContent;
    final looksBinary =
        head.contains('\u0000') || !RegExp(r'\s*\{').hasMatch(head);
    if (looksBinary) {
      throw BackupValidationException(
        'This isn\u2019t a Glimpse backup file. '
        'Backups are JSON files named "glimpse-backup.json".',
      );
    }

    Object decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } catch (e) {
      developer.log('JSON decode failed: $e', name: _tag);
      throw BackupValidationException(
        'This file isn\u2019t a valid Glimpse backup. '
        'It may be corrupted or from a different app.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw BackupValidationException('Invalid format: not a JSON object');
    }

    final version = decoded['version'] as int?;
    if (version == null) {
      throw BackupValidationException('Invalid backup: missing version field');
    }

    if (version > BackupData.currentVersion) {
      throw BackupValidationException(
        'This backup was created with a newer version of Glimpse (v$version). '
        'Please update the app to restore it.',
      );
    }

    if (version < 1) {
      throw BackupValidationException(
        'This backup format is no longer supported',
      );
    }

    final requiredFields = ['createdAt', 'appVersion', 'links'];
    for (final field in requiredFields) {
      if (!decoded.containsKey(field)) {
        throw BackupValidationException(
          'Invalid backup: missing required field "$field"',
        );
      }
    }

    final links = decoded['links'];
    if (links is! List) {
      throw BackupValidationException('Invalid backup: links is not a list');
    }

    try {
      _validateBackupRecords(decoded, links);
      final backup = BackupData.fromJson(decoded);
      developer.log(
        'Backup valid: v${backup.version}, ${backup.links.length} links, '
        '${backup.collections.length} collections',
        name: _tag,
      );
      return backup;
    } on BackupValidationException {
      rethrow;
    } catch (e, st) {
      developer.log(
        'BackupData.fromJson failed: $e',
        name: _tag,
        error: e,
        stackTrace: st,
      );
      throw BackupValidationException(
        'Could not read backup data. The file may be corrupted.',
      );
    }
  }

  void _validateBackupRecords(
    Map<String, dynamic> decoded,
    List<dynamic> links,
  ) {
    _requireDate(decoded['createdAt'], 'backup creation date');

    final seenUrls = <String>{};
    for (var index = 0; index < links.length; index++) {
      final raw = links[index];
      if (raw is! Map<String, dynamic>) {
        throw BackupValidationException(
          'Invalid backup: link ${index + 1} is not an object.',
        );
      }

      final rawUrl = raw['rawUrl'];
      final domain = raw['domain'];
      final title = raw['title'];
      if (rawUrl is! String || rawUrl.trim().isEmpty) {
        throw BackupValidationException(
          'Invalid backup: link ${index + 1} has no URL.',
        );
      }
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        throw BackupValidationException(
          'Invalid backup: link ${index + 1} has an invalid URL.',
        );
      }
      if (!seenUrls.add(rawUrl)) {
        throw BackupValidationException(
          'Invalid backup: the same link appears more than once.',
        );
      }
      if (domain is! String || domain.trim().isEmpty) {
        throw BackupValidationException(
          'Invalid backup: link ${index + 1} has no domain.',
        );
      }
      if (title is! String || title.trim().isEmpty) {
        throw BackupValidationException(
          'Invalid backup: link ${index + 1} has no title.',
        );
      }

      _requireDate(raw['savedAt'], 'saved date for link ${index + 1}');
      for (final field in const [
        'openedAt',
        'resurfacedAt',
        'rediscoverDismissedAt',
        'intentSetAt',
        'revisitAfter',
        'processingUpdatedAt',
      ]) {
        final value = raw[field];
        if (value != null) {
          _requireDate(value, '$field for link ${index + 1}');
        }
      }

      final embedding = raw['embedding'];
      if (embedding != null &&
          (embedding is! List ||
              embedding.any((value) => value is! num || !value.isFinite))) {
        throw BackupValidationException(
          'Invalid backup: link ${index + 1} has a damaged embedding.',
        );
      }

      final enrichmentJson = raw['enrichmentJson'];
      if (enrichmentJson != null) {
        if (enrichmentJson is! String) {
          throw BackupValidationException(
            'Invalid backup: link ${index + 1} has invalid enrichment data.',
          );
        }
        try {
          jsonDecode(enrichmentJson);
        } catch (_) {
          throw BackupValidationException(
            'Invalid backup: link ${index + 1} has damaged enrichment data.',
          );
        }
      }
    }

    final collections = decoded['collections'];
    if (collections != null && collections is! List) {
      throw BackupValidationException(
        'Invalid backup: collections is not a list.',
      );
    }
    if (collections is List) {
      final seenCollectionNames = <String>{};
      for (var index = 0; index < collections.length; index++) {
        final raw = collections[index];
        if (raw is! Map<String, dynamic>) {
          throw BackupValidationException(
            'Invalid backup: collection ${index + 1} is not an object.',
          );
        }
        final name = raw['name'];
        if (name is! String || name.trim().isEmpty) {
          throw BackupValidationException(
            'Invalid backup: collection ${index + 1} has no name.',
          );
        }
        if (!seenCollectionNames.add(name)) {
          throw BackupValidationException(
            'Invalid backup: the collection "$name" appears more than once.',
          );
        }
        _requireDate(
          raw['createdAt'],
          'creation date for collection ${index + 1}',
        );
        final linkUrls = raw['linkUrls'];
        if (linkUrls is! List ||
            linkUrls.any(
              (value) => value is! String || !seenUrls.contains(value),
            )) {
          throw BackupValidationException(
            'Invalid backup: collection "$name" refers to a missing link.',
          );
        }
      }
    }
  }

  void _requireDate(Object? value, String label) {
    if (value is! String || DateTime.tryParse(value) == null) {
      throw BackupValidationException('Invalid backup: invalid $label.');
    }
  }

  /// Computes what would change if the user restored [backup] in [mode],
  /// without actually touching the database. Used by the preview screen so
  /// users can see how many links/collections will be added vs updated
  /// before committing.
  Future<RestoreImpact> previewImpact(
    BackupData backup,
    RestoreMode mode,
  ) async {
    if (mode == RestoreMode.replace) {
      // Replace wipes everything first, so every backup item is "new".
      return RestoreImpact(
        mode: mode,
        addedLinks: backup.links.length,
        updatedLinks: 0,
        addedCollections: backup.collections.length,
        updatedCollections: 0,
      );
    }

    final existingUrls = await _isarService.getAllUrls();
    final existingByUrl = {for (final u in existingUrls) u.rawUrl};

    var addedLinks = 0;
    var updatedLinks = 0;
    for (final l in backup.links) {
      if (existingByUrl.contains(l.rawUrl)) {
        updatedLinks++;
      } else {
        addedLinks++;
      }
    }

    final existingCollections = await _isarService.getAllCollections();
    final existingByName = {for (final c in existingCollections) c.name};

    var addedCollections = 0;
    var updatedCollections = 0;
    for (final c in backup.collections) {
      if (existingByName.contains(c.name)) {
        updatedCollections++;
      } else {
        addedCollections++;
      }
    }

    return RestoreImpact(
      mode: mode,
      addedLinks: addedLinks,
      updatedLinks: updatedLinks,
      addedCollections: addedCollections,
      updatedCollections: updatedCollections,
    );
  }

  Future<int> restoreBackup(
    BackupData backup,
    RestoreMode mode, {
    void Function(double progress)? onProgress,
  }) async {
    developer.log(
      'Restore started: mode=$mode, '
      '${backup.links.length} links, ${backup.collections.length} collections',
      name: _tag,
    );

    try {
      final int count;
      switch (mode) {
        case RestoreMode.replace:
          count = await _replaceRestore(backup, onProgress: onProgress);
          break;
        case RestoreMode.merge:
          count = await _mergeRestore(backup, onProgress: onProgress);
          break;
      }
      developer.log('Restore complete: $count links restored', name: _tag);
      return count;
    } catch (e, st) {
      developer.log('Restore FAILED: $e', name: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> _replaceRestore(
    BackupData backup, {
    void Function(double progress)? onProgress,
  }) async {
    developer.log('Replace mode: clearing existing data...', name: _tag);
    await _isarService.deleteAll();

    final sessionService = SessionTrackingService();
    await sessionService.clear();

    return _writeBackupData(backup, onProgress: onProgress);
  }

  Future<int> _mergeRestore(
    BackupData backup, {
    void Function(double progress)? onProgress,
  }) async {
    developer.log('Merge mode: loading existing data...', name: _tag);
    final existingUrls = await _isarService.getAllUrls();
    final existingByUrl = {for (final u in existingUrls) u.rawUrl: u};

    final existingCollections = await _isarService.getAllCollections();
    final existingByName = {for (final c in existingCollections) c.name: c};

    final totalOps = backup.links.length + backup.collections.length;
    var completed = 0;

    final urlIdByRawUrl = <String, int>{};
    var mergedCount = 0;
    var addedCount = 0;

    for (final linkBackup in backup.links) {
      final existing = existingByUrl[linkBackup.rawUrl];
      if (existing != null) {
        final merged = _mergeLink(existing, linkBackup);
        await _isarService.updateUrl(merged);
        urlIdByRawUrl[linkBackup.rawUrl] = existing.id;
        mergedCount++;
      } else {
        final newUrl = fromBackup(linkBackup);
        final newId = await _isarService.saveUrl(newUrl);
        urlIdByRawUrl[linkBackup.rawUrl] = newId;
        addedCount++;
      }
      completed++;
      onProgress?.call(completed / (totalOps > 0 ? totalOps : 1));
    }

    developer.log(
      'Merge link results: $mergedCount merged, $addedCount added',
      name: _tag,
    );

    for (final colBackup in backup.collections) {
      final urlIds = <int>[];
      for (final rawUrl in colBackup.linkUrls) {
        final id = urlIdByRawUrl[rawUrl];
        if (id != null) {
          urlIds.add(id);
        } else {
          final match = await _isarService.findByRawUrl(rawUrl);
          if (match != null) urlIds.add(match.id);
        }
      }

      final existing = existingByName[colBackup.name];
      if (existing != null) {
        final mergedIds = <int>{...existing.urlIds, ...urlIds};
        existing.urlIds = mergedIds.toList();
        if (colBackup.description != null) {
          existing.description = colBackup.description;
        }
        await _isarService.updateCollection(existing);
      } else {
        final newCol = await _isarService.createCollection(
          name: colBackup.name,
          emoji: colBackup.emoji,
          description: colBackup.description,
        );
        for (final id in urlIds) {
          await _isarService.addUrlToCollection(
            collectionId: newCol.id,
            urlId: id,
          );
        }
      }
      completed++;
      onProgress?.call(completed / (totalOps > 0 ? totalOps : 1));
    }

    if (backup.saveSessions.isNotEmpty) {
      final sessionService = SessionTrackingService();
      final existingSessionIds = await sessionService.allSessionIds();
      final existingSessionSet = existingSessionIds.toSet();
      final newRecords = <SessionRecord>[];

      for (final sb in backup.saveSessions) {
        if (!existingSessionSet.contains(sb.sessionId)) {
          final urlId = urlIdByRawUrl[sb.rawUrl];
          if (urlId != null) {
            newRecords.add(
              SessionRecord(
                urlId: urlId,
                sessionId: sb.sessionId,
                savedAt: DateTime.parse(sb.savedAt),
              ),
            );
          }
        }
      }

      if (newRecords.isNotEmpty) {
        final existing = await sessionService.readAll();
        await sessionService.writeAll([...existing, ...newRecords]);
      }
    }

    await _importSettings(backup.settings, merge: true);

    return backup.links.length;
  }

  Future<int> _writeBackupData(
    BackupData backup, {
    void Function(double progress)? onProgress,
  }) async {
    final totalOps = backup.links.length + backup.collections.length;
    var completed = 0;

    final urlIdByRawUrl = <String, int>{};

    for (final linkBackup in backup.links) {
      final newUrl = fromBackup(linkBackup);
      final id = await _isarService.saveUrl(newUrl);
      urlIdByRawUrl[linkBackup.rawUrl] = id;
      completed++;
      onProgress?.call(completed / (totalOps > 0 ? totalOps : 1));
    }

    for (final colBackup in backup.collections) {
      final urlIds = <int>[];
      for (final rawUrl in colBackup.linkUrls) {
        final id = urlIdByRawUrl[rawUrl];
        if (id != null) {
          urlIds.add(id);
        }
      }

      final collection = await _isarService.createCollection(
        name: colBackup.name,
        emoji: colBackup.emoji,
        description: colBackup.description,
      );

      for (final urlId in urlIds) {
        await _isarService.addUrlToCollection(
          collectionId: collection.id,
          urlId: urlId,
        );
      }
      completed++;
      onProgress?.call(completed / (totalOps > 0 ? totalOps : 1));
    }

    if (backup.saveSessions.isNotEmpty) {
      final sessionService = SessionTrackingService();
      final records = <SessionRecord>[];
      for (final sb in backup.saveSessions) {
        final urlId = urlIdByRawUrl[sb.rawUrl];
        if (urlId != null) {
          records.add(
            SessionRecord(
              urlId: urlId,
              sessionId: sb.sessionId,
              savedAt: DateTime.parse(sb.savedAt),
            ),
          );
        }
      }
      await sessionService.writeAll(records);
    }

    await _importSettings(backup.settings, merge: false);

    return backup.links.length;
  }

  SavedUrl _mergeLink(SavedUrl existing, SavedUrlBackup incoming) {
    final incomingSavedAt = DateTime.parse(incoming.savedAt);
    final mergedEmbedding = incoming.embedding ?? existing.embedding;
    final incomingProcessingUpdatedAt = _parseOptionalDate(
      incoming.processingUpdatedAt,
    );
    final useIncomingProcessing =
        incoming.processingStatus != null &&
        (existing.processingStatus == null ||
            existing.processingUpdatedAt == null ||
            (incomingProcessingUpdatedAt?.isAfter(
                  existing.processingUpdatedAt!,
                ) ??
                false));
    final incomingIntentSetAt = _parseOptionalDate(incoming.intentSetAt);
    final useIncomingIntent =
        incoming.intentStatus != null &&
        (existing.intentStatus == null ||
            existing.intentSetAt == null ||
            (incomingIntentSetAt?.isAfter(existing.intentSetAt!) ?? false));

    return SavedUrl()
      ..id = existing.id
      ..rawUrl = existing.rawUrl
      ..domain = existing.domain
      ..title = existing.title
      ..description = existing.description
      ..thumbnailUrl = incoming.thumbnailUrl ?? existing.thumbnailUrl
      ..category = existing.category
      ..categoryEmoji = existing.categoryEmoji
      ..categories = _mergeLists(existing.categories, incoming.categories)
      ..tags = _mergeLists(existing.tags, incoming.tags)
      ..userNotes = incoming.userNotes ?? existing.userNotes
      ..summary = incoming.summary ?? existing.summary
      ..enrichmentJson = incoming.enrichmentJson ?? existing.enrichmentJson
      ..processingStatus = useIncomingProcessing
          ? incoming.processingStatus
          : existing.processingStatus
      ..processingId = useIncomingProcessing
          ? incoming.processingId
          : existing.processingId
      ..processingAttempt = useIncomingProcessing
          ? incoming.processingAttempt
          : existing.processingAttempt
      ..processingUpdatedAt = useIncomingProcessing
          ? incomingProcessingUpdatedAt
          : existing.processingUpdatedAt
      ..processingError = useIncomingProcessing
          ? incoming.processingError
          : existing.processingError
      ..savedAt = _earliest(existing.savedAt, incomingSavedAt)
      ..openedAt = _latestNullable(
        existing.openedAt,
        _parseOptionalDate(incoming.openedAt),
      )
      ..resurfacedAt = _latestNullable(
        existing.resurfacedAt,
        _parseOptionalDate(incoming.resurfacedAt),
      )
      ..rediscoverDismissedAt = _latestNullable(
        existing.rediscoverDismissedAt,
        _parseOptionalDate(incoming.rediscoverDismissedAt),
      )
      ..intentStatus = useIncomingIntent
          ? incoming.intentStatus
          : existing.intentStatus
      ..intentAction = useIncomingIntent
          ? incoming.intentAction
          : existing.intentAction
      ..intentSetAt = useIncomingIntent
          ? incomingIntentSetAt
          : existing.intentSetAt
      ..revisitAfter = useIncomingIntent
          ? _parseOptionalDate(incoming.revisitAfter)
          : existing.revisitAfter
      ..embedding = mergedEmbedding;
  }

  List<String> _mergeLists(List<String> existing, List<String> incoming) {
    final set = <String>{...existing, ...incoming};
    return set.toList()..sort();
  }

  DateTime _earliest(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  DateTime? _latestNullable(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  Future<SettingsBackup> _exportSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return SettingsBackup(
      themeMode: _readInt(prefs, 'theme_mode')?.toString(),
      // `amoled_surfaces` is stored as an int (0/1) by ThemeProvider, but a
      // legacy build briefly stored it as a bool. Read defensively.
      amoledSurfaces: _readBoolFlexible(prefs, 'amoled_surfaces'),
      accentColorIndex: _readInt(prefs, 'accent_color'),
      userDisplayName: _readString(prefs, 'glimpse_user_display_name'),
      categoryOrder: _readString(prefs, 'glimpse_category_order'),
      leftSwipeAction: _readString(prefs, 'glimpse_left_swipe_action'),
      rightSwipeAction: _readString(prefs, 'glimpse_right_swipe_action'),
      digestEnabled: _readBoolFlexible(prefs, 'digest_enabled'),
      hasSeenOnboarding: _readBoolFlexible(prefs, 'has_seen_onboarding'),
      hasSeenShareTip: _readBoolFlexible(prefs, 'has_seen_share_tip'),
      hasShownFirstSaveCelebration: _readBoolFlexible(
        prefs,
        'has_shown_first_save_celebration',
      ),
    );
  }

  /// Defensive pref readers — a single corrupt or wrongly-typed key must
  /// never abort the entire export.

  bool? _readBoolFlexible(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.get(key);
      if (raw == null) return null;
      if (raw is bool) return raw;
      if (raw is int) return raw != 0;
      if (raw is String) {
        final v = raw.toLowerCase();
        if (v == 'true' || v == '1') return true;
        if (v == 'false' || v == '0') return false;
      }
    } catch (e) {
      developer.log('Pref read failed for "$key": $e', name: _tag);
    }
    return null;
  }

  int? _readInt(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.get(key);
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is bool) return raw ? 1 : 0;
      if (raw is String) return int.tryParse(raw);
    } catch (e) {
      developer.log('Pref read failed for "$key": $e', name: _tag);
    }
    return null;
  }

  String? _readString(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.get(key);
      if (raw == null) return null;
      return raw is String ? raw : raw.toString();
    } catch (e) {
      developer.log('Pref read failed for "$key": $e', name: _tag);
    }
    return null;
  }

  Future<void> _importSettings(
    SettingsBackup settings, {
    required bool merge,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!merge) {
      if (settings.themeMode != null) {
        final idx = int.tryParse(settings.themeMode!);
        if (idx != null && idx < 3) {
          await prefs.setInt('theme_mode', idx);
        }
      }
      if (settings.amoledSurfaces != null) {
        await prefs.setInt('amoled_surfaces', settings.amoledSurfaces! ? 1 : 0);
      }
      if (settings.accentColorIndex != null) {
        await prefs.setInt('accent_color', settings.accentColorIndex!);
      }
      if (settings.userDisplayName != null) {
        await prefs.setString(
          'glimpse_user_display_name',
          settings.userDisplayName!,
        );
      }
      if (settings.categoryOrder != null) {
        await prefs.setString(
          'glimpse_category_order',
          settings.categoryOrder!,
        );
      }
      if (settings.leftSwipeAction != null) {
        await prefs.setString(
          'glimpse_left_swipe_action',
          settings.leftSwipeAction!,
        );
      }
      if (settings.rightSwipeAction != null) {
        await prefs.setString(
          'glimpse_right_swipe_action',
          settings.rightSwipeAction!,
        );
      }
      if (settings.digestEnabled != null) {
        await prefs.setBool('digest_enabled', settings.digestEnabled!);
      }
    } else {
      if (settings.userDisplayName != null &&
          (prefs.getString('glimpse_user_display_name') ?? '').isEmpty) {
        await prefs.setString(
          'glimpse_user_display_name',
          settings.userDisplayName!,
        );
      }
    }

    if (settings.hasSeenOnboarding != null) {
      await prefs.setBool('has_seen_onboarding', settings.hasSeenOnboarding!);
    }
    if (settings.hasSeenShareTip != null) {
      await prefs.setBool('has_seen_share_tip', settings.hasSeenShareTip!);
    }
    if (settings.hasShownFirstSaveCelebration != null) {
      await prefs.setBool(
        'has_shown_first_save_celebration',
        settings.hasShownFirstSaveCelebration!,
      );
    }
  }
}

class BackupResult {
  final int linkCount;
  final int collectionCount;
  final int sessionCount;
  final String filePath;

  BackupResult({
    required this.linkCount,
    required this.collectionCount,
    required this.sessionCount,
    required this.filePath,
  });
}

/// Pure-data summary of what a restore would do, used by the preview
/// screen so the user can see "5 new, 12 updated" before committing.
class RestoreImpact {
  final RestoreMode mode;
  final int addedLinks;
  final int updatedLinks;
  final int addedCollections;
  final int updatedCollections;

  const RestoreImpact({
    required this.mode,
    required this.addedLinks,
    required this.updatedLinks,
    required this.addedCollections,
    required this.updatedCollections,
  });
}

/// In-memory backup ready to be persisted somewhere.
///
/// Contains the encoded JSON, the suggested file name, and the counts that
/// the UI surfaces in success messages.
class BackupPayload {
  final String json;
  final String fileName;
  final int linkCount;
  final int collectionCount;
  final int sessionCount;

  const BackupPayload({
    required this.json,
    required this.fileName,
    required this.linkCount,
    required this.collectionCount,
    required this.sessionCount,
  });
}

class BackupValidationException implements Exception {
  final String message;
  BackupValidationException(this.message);

  @override
  String toString() => message;
}
