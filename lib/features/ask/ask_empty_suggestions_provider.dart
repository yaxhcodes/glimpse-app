import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../home/home_provider.dart';

/// What a suggestion is built from; the new-chat card picks its glyph by it.
enum AskSuggestionKind { explain, topic, recent, rediscover, connect, start }

class AskSuggestionChipData {
  const AskSuggestionChipData({
    required this.display,
    required this.promptText,
    this.headline,
    this.kind = AskSuggestionKind.start,
  });

  /// Short lead on the card ("Get the big idea"); null shows [display] alone.
  final String? headline;

  /// The detail under it: a save's title, or the question itself.
  final String display;

  /// The full question that goes into the composer, never shortened.
  final String promptText;
  final AskSuggestionKind kind;
}

/// UI fallback when suggestions fail to load.
const kAskOnboardingSuggestionChips = <AskSuggestionChipData>[
  AskSuggestionChipData(
    display: 'How do I save a link?',
    promptText: 'How do I save a link?',
  ),
];

Future<void> clearAskSuggestionsCache() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys().where(
    (key) =>
        key.startsWith('glimpse_suggestions_') ||
        key.startsWith('glimpse_ask_suggestions_'),
  )) {
    await prefs.remove(key);
  }
}

/// Questions worth asking of this library, most personal first: the newest
/// save's idea, the topic saved most lately, this week's saves, an older
/// save to revisit, and how another topic's saves connect.
List<AskSuggestionChipData> buildAskSuggestions(
  List<SavedUrl> saves,
  AppLocalizations l, {
  DateTime? now,
  int max = 4,
  String Function(SavedUrl save)? titleOf,
}) {
  final at = now ?? DateTime.now();
  final title = titleOf ?? (SavedUrl save) => save.title;
  AskSuggestionChipData chip(
    String headline,
    String display,
    String prompt,
    AskSuggestionKind kind,
  ) => AskSuggestionChipData(
    headline: headline,
    display: display,
    promptText: prompt,
    kind: kind,
  );

  final live = [
    for (final save in saves)
      if (!save.isInBin) save,
  ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  if (live.isEmpty) {
    return [
      chip(
        l.askHeadStart,
        l.askHowToSave,
        l.askHowToSave,
        AskSuggestionKind.start,
      ),
    ];
  }

  final titles = <SavedUrl, String>{
    for (final save in live) save: ?cleanSuggestionTitle(title(save)),
  };
  final titled = titles.keys.toList();
  final topics = _topTopics(live, at);
  final weekCount = live
      .where((s) => at.difference(s.savedAt).inDays < 7)
      .length;
  // An older save, chosen by the day so the card changes but doesn't flicker.
  final older = [
    for (final save in titled)
      if (at.difference(save.savedAt).inDays >= 30) save,
  ];
  final revisit = older.isEmpty
      ? null
      : older[(at.year * 400 + at.month * 31 + at.day) % older.length];

  final picks = <AskSuggestionChipData>[
    if (titled.isNotEmpty)
      chip(
        l.askHeadBigIdea,
        titles[titled.first]!,
        l.askSuggestBigIdea(_forPrompt(titles[titled.first]!)),
        AskSuggestionKind.explain,
      ),
    if (topics.isNotEmpty)
      chip(
        l.askHeadTopic(topics.first),
        l.askSubTopic,
        l.askSuggestTopic(topics.first),
        AskSuggestionKind.topic,
      ),
    if (weekCount >= 3)
      chip(
        l.askHeadWeek,
        l.askSubWeek,
        l.askSuggestThisWeek,
        AskSuggestionKind.recent,
      ),
    if (revisit != null && revisit != titled.firstOrNull)
      chip(
        l.askHeadRemind,
        titles[revisit]!,
        l.askSuggestRemind(_forPrompt(titles[revisit]!)),
        AskSuggestionKind.rediscover,
      ),
    if (topics.length > 1)
      chip(
        l.askHeadConnect,
        l.askSubConnect(topics[1]),
        l.askSuggestConnect(topics[1]),
        AskSuggestionKind.connect,
      ),
  ];
  if (picks.length < 2) {
    picks.add(
      chip(
        l.askHeadLibrary,
        l.askCountPrompt,
        l.askCountPrompt,
        AskSuggestionKind.start,
      ),
    );
  }
  return picks.take(max).toList();
}

/// A save's title tidied for a suggestion, or null when it would read as
/// noise: a bare URL, a handle, or a single word (usually a category that
/// stood in for a missing title).
String? cleanSuggestionTitle(String raw) {
  var title = raw
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'''^["'“”‘’]+|["'“”‘’]+$'''), '')
      .trim();
  // "Title | Site" and "Title - YouTube": keep the title.
  title = title.split(RegExp(r'\s[|•·–—-]\s')).first.trim();
  if (title.length < 3 ||
      title.startsWith('http') ||
      title.startsWith('@') ||
      !title.contains(' ') ||
      !RegExp(r'[\p{L}]', unicode: true).hasMatch(title)) {
    return null;
  }
  return title;
}

/// Very long titles stop at a word inside the question itself.
String _forPrompt(String title, {int maxLength = 90}) {
  if (title.length <= maxLength) return title;
  final cut = title.substring(0, maxLength);
  final space = cut.lastIndexOf(' ');
  return (space > maxLength ~/ 2 ? cut.substring(0, space) : cut).trimRight();
}

const _vagueTopics = {
  'other',
  'others',
  'general',
  'misc',
  'miscellaneous',
  'uncategorized',
  'uncategorised',
  'unknown',
  'none',
  'content',
  'link',
  'links',
};

/// Categories saved most in the last two months (else ever), at least three
/// saves each, without platform names or catch-alls.
List<String> _topTopics(List<SavedUrl> saves, DateTime now) {
  List<String> rank(Iterable<SavedUrl> pool) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final save in pool) {
      final seen = <String>{};
      for (final raw in [save.category, ...save.categories]) {
        final label = raw.trim();
        final key = label.toLowerCase();
        if (label.isEmpty ||
            _vagueTopics.contains(key) ||
            CategoryResolver.isPlatformName(label) ||
            !seen.add(key)) {
          continue;
        }
        counts[key] = (counts[key] ?? 0) + 1;
        labels.putIfAbsent(key, () => label);
      }
    }
    final ranked = counts.entries.where((e) => e.value >= 3).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in ranked) labels[e.key]!];
  }

  final recent = rank(
    saves.where((s) => now.difference(s.savedAt).inDays < 60),
  );
  return recent.length >= 2 ? recent : rank(saves);
}

final askEmptySuggestionsProvider =
    FutureProvider.autoDispose<List<AskSuggestionChipData>>((ref) async {
      final shown = ref.watch(displayedUrlsProvider).valueOrNull;
      final l = await loadBackgroundLocalizations();
      final saves = shown ?? await ref.read(isarServiceProvider).getAllUrls();
      final tags = ref.read(tagOccurrenceMapProvider);
      return buildAskSuggestions(
        saves,
        l,
        titleOf: (save) =>
            TitleResolver.resolveDetailTitle(save, tagFrequency: tags),
      );
    });
