import 'dart:convert';

import 'package:crypto/crypto.dart';

enum GlimpseKind { connection, idea, intention, daily, weekly, monthly }

enum GlimpseEvidenceKind { highlight, note, summary }

enum GlimpseAction { opened, gotIt, later, done, lessLikeThis }

class GlimpseEvidence {
  const GlimpseEvidence({
    required this.sourceId,
    required this.text,
    required this.kind,
    this.sectionKey,
  });

  final int sourceId;
  final String text;
  final GlimpseEvidenceKind kind;
  final String? sectionKey;

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'text': text,
    'kind': kind.name,
    'sectionKey': sectionKey,
  };

  factory GlimpseEvidence.fromJson(Map<String, dynamic> json) =>
      GlimpseEvidence(
        sourceId: (json['sourceId'] as num).toInt(),
        text: json['text'] as String,
        kind: GlimpseEvidenceKind.values.byName(json['kind'] as String),
        sectionKey: json['sectionKey'] as String?,
      );
}

class Glimpse {
  const Glimpse({
    required this.key,
    required this.kind,
    required this.topicKey,
    required this.topicLabel,
    required this.sourceIds,
    required this.evidence,
    required this.createdAt,
    required this.availableAt,
    required this.expiresAt,
    required this.score,
    this.strong = false,
    this.periodStart,
    this.periodEnd,
    this.returnedCount = 0,
    this.notedCount = 0,
    this.completedCount = 0,
  });

  final String key;
  final GlimpseKind kind;
  final String topicKey;
  final String topicLabel;
  final List<int> sourceIds;
  final List<GlimpseEvidence> evidence;
  final DateTime createdAt;
  final DateTime availableAt;
  final DateTime expiresAt;
  final double score;
  final bool strong;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int returnedCount;
  final int notedCount;
  final int completedCount;

  bool get isRecap =>
      kind == GlimpseKind.daily ||
      kind == GlimpseKind.weekly ||
      kind == GlimpseKind.monthly;
  bool get isReminder => kind == GlimpseKind.intention;
  bool get hasValue => evidence.any((e) => e.text.trim().length >= 40);
  bool get canNotify =>
      isReminder ||
      (hasValue &&
          (kind == GlimpseKind.idea ||
              kind == GlimpseKind.weekly ||
              (kind == GlimpseKind.connection && strong)));

  String get revision => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'kind': kind.name,
            'sourceIds': sourceIds,
            'evidence': evidence.map((e) => e.toJson()).toList(),
            'periodStart': periodStart?.toIso8601String(),
          }),
        ),
      )
      .toString();

  Map<String, Object?> toJson() => {
    'version': 1,
    'key': key,
    'kind': kind.name,
    'topicKey': topicKey,
    'topicLabel': topicLabel,
    'sourceIds': sourceIds,
    'evidence': evidence.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'availableAt': availableAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'score': score,
    'strong': strong,
    'periodStart': periodStart?.toIso8601String(),
    'periodEnd': periodEnd?.toIso8601String(),
    'returnedCount': returnedCount,
    'notedCount': notedCount,
    'completedCount': completedCount,
  };

  factory Glimpse.fromJson(Map<String, dynamic> json) => Glimpse(
    key: json['key'] as String,
    kind: GlimpseKind.values.byName(json['kind'] as String),
    topicKey: json['topicKey'] as String,
    topicLabel: json['topicLabel'] as String,
    sourceIds: (json['sourceIds'] as List)
        .cast<num>()
        .map((n) => n.toInt())
        .toList(),
    evidence: (json['evidence'] as List)
        .map(
          (e) => GlimpseEvidence.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    availableAt: DateTime.parse(json['availableAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    score: (json['score'] as num).toDouble(),
    strong: json['strong'] == true,
    periodStart: DateTime.tryParse(json['periodStart']?.toString() ?? ''),
    periodEnd: DateTime.tryParse(json['periodEnd']?.toString() ?? ''),
    returnedCount: (json['returnedCount'] as num?)?.toInt() ?? 0,
    notedCount: (json['notedCount'] as num?)?.toInt() ?? 0,
    completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
  );
}

String glimpseDateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int glimpseNotificationId(int recordId) => 0x40000000 + (recordId & 0x1fffffff);
