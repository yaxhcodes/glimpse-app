import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/service_providers.dart';
import '../../l10n/l10n.dart';
import '../home/home_provider.dart';

class AskSuggestionChipData {
  const AskSuggestionChipData({
    required this.display,
    required this.promptText,
  });
  final String display;
  final String promptText;
}

/// No saves yet, or UI fallback when suggestion load fails.
const kAskOnboardingSuggestionChips = <AskSuggestionChipData>[
  AskSuggestionChipData(
    display: 'Save your first link',
    promptText: 'How do I save a link?',
  ),
  AskSuggestionChipData(
    display: 'Paste something to start',
    promptText: 'How do I save a link?',
  ),
  AskSuggestionChipData(
    display: 'Try a quick save',
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

final askEmptySuggestionsProvider =
    FutureProvider.autoDispose<List<AskSuggestionChipData>>((ref) async {
      ref.watch(displayedUrlsProvider);
      final l = await loadBackgroundLocalizations();
      final recent = await ref
          .read(isarServiceProvider)
          .getRecentUrls(limit: 2);
      return [
        AskSuggestionChipData(
          display: l.askCountPrompt,
          promptText: l.askCountPrompt,
        ),
        for (final save in recent)
          AskSuggestionChipData(
            display: l.askExplainTitle(save.title),
            promptText: l.askExplainTitle(save.title),
          ),
      ];
    });
