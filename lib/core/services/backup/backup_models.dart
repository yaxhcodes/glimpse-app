class BackupData {
  static const int currentVersion = 5;

  final int version;
  final String createdAt;
  final String appVersion;
  final String? device;
  final List<SavedUrlBackup> links;
  final List<UserCollectionBackup> collections;
  final List<PlaceItineraryBackup> placeItineraries;
  final List<SessionRecordBackup> saveSessions;
  final SettingsBackup settings;
  final Map<String, dynamic>? rediscoverProfile;

  BackupData({
    this.version = currentVersion,
    required this.createdAt,
    required this.appVersion,
    this.device,
    required this.links,
    required this.collections,
    this.placeItineraries = const [],
    required this.saveSessions,
    required this.settings,
    this.rediscoverProfile,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt,
    'appVersion': appVersion,
    if (device != null) 'device': device,
    'links': links.map((e) => e.toJson()).toList(),
    'collections': collections.map((e) => e.toJson()).toList(),
    if (placeItineraries.isNotEmpty)
      'placeItineraries': placeItineraries.map((e) => e.toJson()).toList(),
    'saveSessions': saveSessions.map((e) => e.toJson()).toList(),
    'settings': settings.toJson(),
    if (rediscoverProfile != null) 'rediscoverProfile': rediscoverProfile,
  };

  factory BackupData.fromJson(Map<String, dynamic> json) => BackupData(
    version: json['version'] as int? ?? 0,
    createdAt: json['createdAt'] as String? ?? '',
    appVersion: json['appVersion'] as String? ?? '',
    device: json['device'] as String?,
    links:
        (json['links'] as List<dynamic>?)
            ?.map((e) => SavedUrlBackup.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    collections:
        (json['collections'] as List<dynamic>?)
            ?.map(
              (e) => UserCollectionBackup.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [],
    placeItineraries:
        (json['placeItineraries'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PlaceItineraryBackup.fromJson)
            .toList() ??
        const [],
    saveSessions:
        (json['saveSessions'] as List<dynamic>?)
            ?.map(
              (e) => SessionRecordBackup.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [],
    settings: SettingsBackup.fromJson(
      json['settings'] as Map<String, dynamic>? ?? {},
    ),
    rediscoverProfile: json['rediscoverProfile'] is Map
        ? Map<String, dynamic>.from(json['rediscoverProfile'] as Map)
        : null,
  );
}

class SavedUrlBackup {
  final String rawUrl;
  final String domain;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String category;
  final String categoryEmoji;
  final List<String> categories;
  final List<String> tags;
  final String? userNotes;
  final List<SavedAskNoteBackup> askNotes;
  final String? summary;
  final String? enrichmentJson;
  final String? processingStatus;
  final String? processingId;
  final int? processingAttempt;
  final String? processingUpdatedAt;
  final String? processingError;
  final String savedAt;
  final String? deletedAt;
  final String? openedAt;
  final String? resurfacedAt;
  final String? rediscoverDismissedAt;
  final String? intentStatus;
  final String? intentAction;
  final String? intentSetAt;
  final String? revisitAfter;
  final List<double>? embedding;

  SavedUrlBackup({
    required this.rawUrl,
    required this.domain,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    required this.category,
    required this.categoryEmoji,
    required this.categories,
    required this.tags,
    this.userNotes,
    this.askNotes = const [],
    this.summary,
    this.enrichmentJson,
    this.processingStatus,
    this.processingId,
    this.processingAttempt,
    this.processingUpdatedAt,
    this.processingError,
    required this.savedAt,
    this.deletedAt,
    this.openedAt,
    this.resurfacedAt,
    this.rediscoverDismissedAt,
    this.intentStatus,
    this.intentAction,
    this.intentSetAt,
    this.revisitAfter,
    this.embedding,
  });

  Map<String, dynamic> toJson() {
    final sanitizedEmbedding = _sanitizeEmbeddingForJson(embedding);

    return {
      'rawUrl': rawUrl,
      'domain': domain,
      'title': title,
      'description': description,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'category': category,
      'categoryEmoji': categoryEmoji,
      'categories': categories,
      'tags': tags,
      if (userNotes != null) 'userNotes': userNotes,
      if (askNotes.isNotEmpty)
        'askNotes': askNotes.map((note) => note.toJson()).toList(),
      if (summary != null) 'summary': summary,
      if (enrichmentJson != null) 'enrichmentJson': enrichmentJson,
      if (processingStatus != null) 'processingStatus': processingStatus,
      if (processingId != null) 'processingId': processingId,
      if (processingAttempt != null) 'processingAttempt': processingAttempt,
      if (processingUpdatedAt != null)
        'processingUpdatedAt': processingUpdatedAt,
      if (processingError != null) 'processingError': processingError,
      'savedAt': savedAt,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (openedAt != null) 'openedAt': openedAt,
      if (resurfacedAt != null) 'resurfacedAt': resurfacedAt,
      if (rediscoverDismissedAt != null)
        'rediscoverDismissedAt': rediscoverDismissedAt,
      if (intentStatus != null) 'intentStatus': intentStatus,
      if (intentAction != null) 'intentAction': intentAction,
      if (intentSetAt != null) 'intentSetAt': intentSetAt,
      if (revisitAfter != null) 'revisitAfter': revisitAfter,
      ...?_optionalEmbeddingJson(sanitizedEmbedding),
    };
  }

  static Map<String, dynamic>? _optionalEmbeddingJson(List<double>? embedding) {
    return embedding == null ? null : {'embedding': embedding};
  }

  static List<double>? _sanitizeEmbeddingForJson(List<double>? embedding) {
    if (embedding == null || embedding.isEmpty) return null;

    final sanitized = <double>[];
    for (final v in embedding) {
      if (v.isFinite) {
        sanitized.add(v);
      }
    }
    return sanitized.isEmpty ? null : sanitized;
  }

  factory SavedUrlBackup.fromJson(Map<String, dynamic> json) => SavedUrlBackup(
    rawUrl: (json['rawUrl'] as String?) ?? '',
    domain: (json['domain'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String?,
    category: (json['category'] as String?) ?? 'Other',
    categoryEmoji: (json['categoryEmoji'] as String?) ?? '📂',
    categories:
        (json['categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [],
    userNotes: json['userNotes'] as String?,
    askNotes:
        (json['askNotes'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(SavedAskNoteBackup.fromJson)
            .toList() ??
        const [],
    summary: json['summary'] as String?,
    enrichmentJson: json['enrichmentJson'] as String?,
    processingStatus: json['processingStatus'] as String?,
    processingId: json['processingId'] as String?,
    processingAttempt: json['processingAttempt'] as int?,
    processingUpdatedAt: json['processingUpdatedAt'] as String?,
    processingError: json['processingError'] as String?,
    savedAt: (json['savedAt'] as String?) ?? DateTime.now().toIso8601String(),
    deletedAt: json['deletedAt'] as String?,
    openedAt: json['openedAt'] as String?,
    resurfacedAt: json['resurfacedAt'] as String?,
    rediscoverDismissedAt: json['rediscoverDismissedAt'] as String?,
    intentStatus: json['intentStatus'] as String?,
    intentAction: json['intentAction'] as String?,
    intentSetAt: json['intentSetAt'] as String?,
    revisitAfter: json['revisitAfter'] as String?,
    embedding: _sanitizeEmbeddingForJson(
      (json['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    ),
  );
}

class SavedAskNoteBackup {
  const SavedAskNoteBackup({
    required this.id,
    this.sourceMessageId,
    required this.question,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String? sourceMessageId;
  final String question;
  final String body;
  final String? createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (sourceMessageId != null) 'sourceMessageId': sourceMessageId,
    'question': question,
    'body': body,
    if (createdAt != null) 'createdAt': createdAt,
  };

  factory SavedAskNoteBackup.fromJson(Map<String, dynamic> json) {
    return SavedAskNoteBackup(
      id: (json['id'] as String?) ?? '',
      sourceMessageId: json['sourceMessageId'] as String?,
      question: (json['question'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      createdAt: json['createdAt'] as String?,
    );
  }
}

class UserCollectionBackup {
  final String name;
  final String emoji;
  final String? description;
  final String createdAt;
  final List<String> linkUrls;

  UserCollectionBackup({
    required this.name,
    required this.emoji,
    this.description,
    required this.createdAt,
    required this.linkUrls,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    if (description != null) 'description': description,
    'createdAt': createdAt,
    'linkUrls': linkUrls,
  };

  factory UserCollectionBackup.fromJson(Map<String, dynamic> json) =>
      UserCollectionBackup(
        name: (json['name'] as String?) ?? '',
        emoji: (json['emoji'] as String?) ?? '📁',
        description: json['description'] as String?,
        createdAt:
            (json['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
        linkUrls:
            (json['linkUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class PlaceItineraryBackup {
  const PlaceItineraryBackup({
    required this.name,
    this.areaKey,
    this.areaTitle,
    this.country,
    this.date,
    required this.createdAt,
    required this.updatedAt,
    required this.stops,
  });

  final String name;
  final String? areaKey;
  final String? areaTitle;
  final String? country;
  final String? date;
  final String createdAt;
  final String updatedAt;
  final List<PlaceItineraryStopBackup> stops;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (areaKey != null) 'areaKey': areaKey,
    if (areaTitle != null) 'areaTitle': areaTitle,
    if (country != null) 'country': country,
    if (date != null) 'date': date,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'stops': stops.map((stop) => stop.toJson()).toList(),
  };

  factory PlaceItineraryBackup.fromJson(Map<String, dynamic> json) {
    return PlaceItineraryBackup(
      name: json['name'] as String? ?? '',
      areaKey: json['areaKey'] as String?,
      areaTitle: json['areaTitle'] as String?,
      country: json['country'] as String?,
      date: json['date'] as String?,
      createdAt:
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt:
          json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      stops:
          (json['stops'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(PlaceItineraryStopBackup.fromJson)
              .toList() ??
          const [],
    );
  }
}

class PlaceItineraryStopBackup {
  const PlaceItineraryStopBackup({
    required this.entityKey,
    required this.provisionalKey,
    this.catalogId,
    this.catalogSource,
    this.sourceUrls = const [],
    required this.title,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.imageUrl,
  });

  final String entityKey;
  final String provisionalKey;
  final String? catalogId;
  final String? catalogSource;
  final List<String> sourceUrls;
  final String title;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
    'entityKey': entityKey,
    'provisionalKey': provisionalKey,
    if (catalogId != null) 'catalogId': catalogId,
    if (catalogSource != null) 'catalogSource': catalogSource,
    if (sourceUrls.isNotEmpty) 'sourceUrls': sourceUrls,
    'title': title,
    if (city != null) 'city': city,
    if (country != null) 'country': country,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  factory PlaceItineraryStopBackup.fromJson(Map<String, dynamic> json) {
    return PlaceItineraryStopBackup(
      entityKey: json['entityKey'] as String? ?? '',
      provisionalKey: json['provisionalKey'] as String? ?? '',
      catalogId: json['catalogId'] as String?,
      catalogSource: json['catalogSource'] as String?,
      sourceUrls:
          (json['sourceUrls'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const [],
      title: json['title'] as String? ?? '',
      city: json['city'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class SessionRecordBackup {
  final String rawUrl;
  final String sessionId;
  final String savedAt;

  SessionRecordBackup({
    required this.rawUrl,
    required this.sessionId,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'rawUrl': rawUrl,
    'sessionId': sessionId,
    'savedAt': savedAt,
  };

  factory SessionRecordBackup.fromJson(Map<String, dynamic> json) =>
      SessionRecordBackup(
        rawUrl: (json['rawUrl'] as String?) ?? '',
        sessionId: (json['sessionId'] as String?) ?? '',
        savedAt:
            (json['savedAt'] as String?) ?? DateTime.now().toIso8601String(),
      );
}

class SettingsBackup {
  final String? themeMode;
  final bool? amoledSurfaces;
  final int? accentColorIndex;
  final String? userDisplayName;
  final String? categoryOrder;
  final String? leftSwipeAction;
  final String? rightSwipeAction;
  final bool? digestEnabled;
  final bool? hasSeenOnboarding;
  final bool? hasSeenShareTip;
  final bool? hasShownFirstSaveCelebration;
  final String? collectionsSurfaceMode;
  final List<String> hiddenLibraryEntityKeys;

  SettingsBackup({
    this.themeMode,
    this.amoledSurfaces,
    this.accentColorIndex,
    this.userDisplayName,
    this.categoryOrder,
    this.leftSwipeAction,
    this.rightSwipeAction,
    this.digestEnabled,
    this.hasSeenOnboarding,
    this.hasSeenShareTip,
    this.hasShownFirstSaveCelebration,
    this.collectionsSurfaceMode,
    this.hiddenLibraryEntityKeys = const [],
  });

  Map<String, dynamic> toJson() => {
    if (themeMode != null) 'themeMode': themeMode,
    if (amoledSurfaces != null) 'amoledSurfaces': amoledSurfaces,
    if (accentColorIndex != null) 'accentColorIndex': accentColorIndex,
    if (userDisplayName != null) 'userDisplayName': userDisplayName,
    if (categoryOrder != null) 'categoryOrder': categoryOrder,
    if (leftSwipeAction != null) 'leftSwipeAction': leftSwipeAction,
    if (rightSwipeAction != null) 'rightSwipeAction': rightSwipeAction,
    if (digestEnabled != null) 'digestEnabled': digestEnabled,
    if (hasSeenOnboarding != null) 'hasSeenOnboarding': hasSeenOnboarding,
    if (hasSeenShareTip != null) 'hasSeenShareTip': hasSeenShareTip,
    if (hasShownFirstSaveCelebration != null)
      'hasShownFirstSaveCelebration': hasShownFirstSaveCelebration,
    if (collectionsSurfaceMode != null)
      'collectionsSurfaceMode': collectionsSurfaceMode,
    if (hiddenLibraryEntityKeys.isNotEmpty)
      'hiddenLibraryEntityKeys': hiddenLibraryEntityKeys,
  };

  factory SettingsBackup.fromJson(Map<String, dynamic> json) => SettingsBackup(
    themeMode: json['themeMode'] as String?,
    amoledSurfaces: json['amoledSurfaces'] as bool?,
    accentColorIndex: json['accentColorIndex'] as int?,
    userDisplayName: json['userDisplayName'] as String?,
    categoryOrder: json['categoryOrder'] as String?,
    leftSwipeAction: json['leftSwipeAction'] as String?,
    rightSwipeAction: json['rightSwipeAction'] as String?,
    digestEnabled: json['digestEnabled'] as bool?,
    hasSeenOnboarding: json['hasSeenOnboarding'] as bool?,
    hasSeenShareTip: json['hasSeenShareTip'] as bool?,
    hasShownFirstSaveCelebration: json['hasShownFirstSaveCelebration'] as bool?,
    collectionsSurfaceMode: json['collectionsSurfaceMode'] as String?,
    hiddenLibraryEntityKeys:
        (json['hiddenLibraryEntityKeys'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const [],
  );
}

enum RestoreMode { merge, replace }

enum BackupStatus {
  idle,
  exporting,
  savingLocal,
  importing,
  validating,
  previewing,
  restoring,
  success,
  savedLocal,
  error,
}

class BackupError {
  final String message;
  final String? detail;

  const BackupError({required this.message, this.detail});

  @override
  String toString() => detail != null ? '$message: $detail' : message;
}
