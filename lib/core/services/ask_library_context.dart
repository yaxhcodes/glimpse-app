import 'dart:convert';

import '../models/saved_url.dart';
import '../models/user_collection.dart';

/// Database facts are separate from the small evidence window sent to AI.
class AskLibrarySnapshot {
  AskLibrarySnapshot(Iterable<SavedUrl> saves, this.collections)
    : saves = saves.where((save) => !save.isInBin).toList(growable: false);

  final List<SavedUrl> saves;
  final List<UserCollection> collections;

  Map<String, int> _counts(Iterable<String> values) {
    final result = <String, int>{};
    for (final value in values) {
      result.update(value, (count) => count + 1, ifAbsent: () => 1);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'totalSavedLinks': saves.length,
    'scope': 'All non-Bin links, including completed/archived saves',
    'domains': _counts(saves.map((s) => s.domain)),
    'categories': _counts(saves.expand((s) => s.effectiveCategories.toSet())),
    'processing': _counts(saves.map((s) => s.processingStatus ?? 'unknown')),
    'collections': {
      for (final collection in collections)
        collection.name: saves
            .where((s) => collection.urlIds.contains(s.id))
            .length,
    },
  };

  Map<String, dynamic> promptFacts() {
    final facts = toJson();
    final result = <String, dynamic>{
      'totalSavedLinks': saves.length,
      'scope': facts['scope'],
    };
    for (final key in ['domains', 'categories', 'processing', 'collections']) {
      final values = (facts[key] as Map<String, int>).entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      result[key] = {
        for (final entry in values.where((e) => e.key.length <= 100).take(12))
          entry.key: entry.value,
      };
      result['${key}Complete'] = values.length == (result[key] as Map).length;
    }
    return result;
  }

  /// Only accept understood metadata predicates. Unknown topic words must never
  /// turn a semantic question into a falsely exact library-wide count.
  List<SavedUrl>? exactCountMatches(String question, {DateTime? now}) {
    var q = question.toLowerCase().trim().replaceAll(RegExp(r'[?!.,]+$'), '');
    const translatedCounts = {
      '保存したリンクは何件ありますか': 'how many links do i have',
      '¿cuántos enlaces tengo guardados': 'how many links do i have',
      'combien de liens ai-je enregistrés': 'how many links do i have',
      'quantos links eu tenho salvos': 'how many links do i have',
      'wie viele links habe ich gespeichert': 'how many links do i have',
    };
    q = q.replaceAll(RegExp(r'[？?]+$'), '').trim();
    q = translatedCounts[q] ?? q;
    if (!RegExp(r'\b(how many|number of|count)\b').hasMatch(q)) return null;
    if (!RegExp(r'\b(links?|saves?|bookmarks?|urls?)\b').hasMatch(q)) {
      return null;
    }
    var matches = saves;
    for (final collection in collections) {
      final name = collection.name.toLowerCase();
      if (q.contains(name) && RegExp(r'\b(in|collection)\b').hasMatch(q)) {
        matches = matches
            .where((s) => collection.urlIds.contains(s.id))
            .toList();
        q = q.replaceAll(name, '').replaceAll('collection', '');
      }
    }
    final hosts = saves.map((s) => s.domain.toLowerCase()).toSet();
    for (final host in hosts) {
      if (host.isNotEmpty && q.contains(host)) {
        matches = matches.where((s) => s.domain.toLowerCase() == host).toList();
        q = q.replaceAll(host, '');
      }
    }
    final categories = saves.expand((s) => s.effectiveCategories).toSet();
    for (final category in categories) {
      final name = category.toLowerCase();
      if (RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(q)) {
        matches = matches
            .where(
              (s) => s.effectiveCategories.any((c) => c.toLowerCase() == name),
            )
            .toList();
        q = q.replaceAll(name, '');
      }
    }
    final today = now ?? DateTime.now();
    DateTime? after;
    if (q.contains('today')) {
      after = DateTime(today.year, today.month, today.day);
      q = q.replaceAll('today', '');
    } else if (q.contains('this month')) {
      after = DateTime(today.year, today.month);
      q = q.replaceAll('this month', '');
    } else if (q.contains('this week')) {
      after = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: today.weekday - 1));
      q = q.replaceAll('this week', '');
    }
    if (after != null) {
      matches = matches.where((s) => !s.savedAt.isBefore(after!)).toList();
    }
    if (RegExp(r'\b(archived|completed)\b').hasMatch(q)) {
      matches = matches.where((s) => s.isDone).toList();
      q = q.replaceAll(RegExp(r'\b(archived|completed)\b'), '');
    }
    if (RegExp(r'\b(unopened|unread)\b').hasMatch(q)) {
      matches = matches.where((s) => s.openedAt == null).toList();
      q = q.replaceAll(RegExp(r'\b(unopened|unread)\b'), '');
    }
    q = q
        .replaceAll(
          RegExp(
            r'\b(how|many|number|of|count|links?|saves?|saved|bookmarks?|urls?|do|does|i|we|have|are|there|in|my|our|the|library|total|all|please|from|on|did|you|can|tell|me|a)\b',
          ),
          '',
        )
        .trim();
    return q.isEmpty ? matches : null;
  }
}

class AskEvidencePassage {
  const AskEvidencePassage(this.sourceId, this.text);
  final int sourceId;
  final String text;
}

/// Caches parsed evidence by content fingerprint, never by mutable object identity.
class AskPassageIndex {
  final _documents =
      <int, ({String fingerprint, List<String> passages, String searchText})>{};

  void refresh(List<SavedUrl> saves, List<UserCollection> collections) {
    final active = saves.map((s) => s.id).toSet();
    _documents.removeWhere((id, _) => !active.contains(id));
    final names = <int, List<String>>{};
    for (final collection in collections) {
      for (final id in collection.urlIds) {
        (names[id] ??= []).add(collection.name);
      }
    }
    for (final save in saves) {
      final fingerprint = [
        save.title,
        save.description,
        save.summary,
        save.enrichmentJson,
        save.highlightsJson,
        save.userNotes,
        ...save.tags,
        ...?names[save.id],
      ].join('\u0000');
      if (_documents[save.id]?.fingerprint == fingerprint) continue;
      final passages = <String>[
        save.title,
        save.description,
        save.summary ?? '',
        if (save.userNotes?.isNotEmpty == true)
          'Personal note: ${save.userNotes}',
        ...?names[save.id]?.map((name) => 'Collection: $name'),
        ...save.tags,
      ];
      for (final raw in [save.enrichmentJson, save.highlightsJson]) {
        if (raw == null || raw.isEmpty) continue;
        try {
          _strings(jsonDecode(raw), passages);
        } on FormatException {
          // Legacy malformed payloads remain searchable as plain evidence.
          passages.add(raw);
        }
      }
      _documents[save.id] = (
        fingerprint: fingerprint,
        searchText: passages.join(" ").toLowerCase(),
        passages: passages
            .expand((s) => s.split(RegExp(r'\n+|(?<=[.!?])\s+')))
            .where((s) => s.trim().isNotEmpty)
            .toSet()
            .toList(),
      );
    }
  }

  static void _strings(Object? value, List<String> result) {
    if (value is String) {
      result.add(value);
    } else if (value is List) {
      for (final item in value) {
        _strings(item, result);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        _strings(item, result);
      }
    }
  }

  List<AskEvidencePassage> passages(
    String query,
    int id, {
    int maxChars = 2600,
  }) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((s) => s.length > 2)
        .toSet();
    final ranked = [...?_documents[id]?.passages];
    int score(String s) =>
        terms.where((term) => s.toLowerCase().contains(term)).length;
    ranked.sort((a, b) => score(b).compareTo(score(a)));
    final result = <AskEvidencePassage>[];
    var remaining = maxChars;
    for (final text in ranked) {
      if (remaining <= 0) break;
      final clipped = text.length > remaining
          ? text.substring(0, remaining)
          : text;
      result.add(AskEvidencePassage(id, clipped));
      remaining -= clipped.length;
    }
    return result;
  }

  List<SavedUrl> search(String query, List<SavedUrl> saves, {int limit = 40}) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where(
          (s) =>
              s.length > 2 &&
              !const {
                'what',
                'which',
                'have',
                'saved',
                'about',
                'find',
                'show',
                'the',
                'that',
                'with',
                'from',
                'links',
                'saves',
                'please',
                'this',
                'how',
                'does',
                'explain',
              }.contains(s),
        )
        .toSet();
    if (terms.isEmpty) return [];
    final hits = <({SavedUrl save, int score})>[];
    for (final save in saves) {
      final text = _documents[save.id]?.searchText ?? '';
      final score = terms.where(text.contains).length;
      if (score > 0) hits.add((save: save, score: score));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).map((h) => h.save).toList();
  }
}
