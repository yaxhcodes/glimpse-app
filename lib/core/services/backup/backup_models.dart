class BackupData {
  static const int currentVersion = 1;

  final int version;
  final String createdAt;
  final String appVersion;
  final String? device;
  final List<SavedUrlBackup> links;
  final List<UserCollectionBackup> collections;
  final List<SessionRecordBackup> saveSessions;
  final SettingsBackup settings;

  BackupData({
    this.version = currentVersion,
    required this.createdAt,
    required this.appVersion,
    this.device,
    required this.links,
    required this.collections,
    required this.saveSessions,
    required this.settings,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'createdAt': createdAt,
        'appVersion': appVersion,
        if (device != null) 'device': device,
        'links': links.map((e) => e.toJson()).toList(),
        'collections': collections.map((e) => e.toJson()).toList(),
        'saveSessions': saveSessions.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  factory BackupData.fromJson(Map<String, dynamic> json) => BackupData(
        version: json['version'] as int? ?? 0,
        createdAt: json['createdAt'] as String? ?? '',
        appVersion: json['appVersion'] as String? ?? '',
        device: json['device'] as String?,
        links: (json['links'] as List<dynamic>?)
                ?.map(
                    (e) => SavedUrlBackup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        collections: (json['collections'] as List<dynamic>?)
                ?.map((e) =>
                    UserCollectionBackup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        saveSessions: (json['saveSessions'] as List<dynamic>?)
                ?.map((e) =>
                    SessionRecordBackup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        settings: SettingsBackup.fromJson(
            json['settings'] as Map<String, dynamic>? ?? {}),
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
  final String? summary;
  final String savedAt;
  final String? openedAt;
  final String? resurfacedAt;
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
    this.summary,
    required this.savedAt,
    this.openedAt,
    this.resurfacedAt,
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
      if (summary != null) 'summary': summary,
      'savedAt': savedAt,
      if (openedAt != null) 'openedAt': openedAt,
      if (resurfacedAt != null) 'resurfacedAt': resurfacedAt,
      if (sanitizedEmbedding != null) 'embedding': sanitizedEmbedding,
    };
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
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        userNotes: json['userNotes'] as String?,
        summary: json['summary'] as String?,
        savedAt:
            (json['savedAt'] as String?) ?? DateTime.now().toIso8601String(),
        openedAt: json['openedAt'] as String?,
        resurfacedAt: json['resurfacedAt'] as String?,
        embedding: _sanitizeEmbeddingForJson(
          (json['embedding'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList(),
        ),
      );
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
        linkUrls: (json['linkUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
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
        hasShownFirstSaveCelebration:
            json['hasShownFirstSaveCelebration'] as bool?,
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
