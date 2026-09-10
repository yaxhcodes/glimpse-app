import '../../core/models/saved_url.dart';
import '../../core/services/notification_summary_formatter.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import 'glimpse.dart';
import 'glimpse_activity.dart';

String glimpseLabel(GlimpseKind kind, AppLocalizations l) => switch (kind) {
  GlimpseKind.connection => l.glimpsesConnection,
  GlimpseKind.idea => l.glimpsesIdea,
  GlimpseKind.intention => l.glimpsesIntention,
  GlimpseKind.daily => l.dailyRecap,
  GlimpseKind.weekly => l.glimpsesWeeklyReview,
  GlimpseKind.monthly => l.monthlyRecap,
};

String glimpseTitle(Glimpse g, AppLocalizations l, Map<int, SavedUrl> urls) {
  if (g.isRecap) return glimpseLabel(g.kind, l);
  if (g.kind == GlimpseKind.connection && g.topicLabel.isNotEmpty) {
    return g.topicLabel;
  }
  final url = urls[g.evidence.firstOrNull?.sourceId ?? g.sourceIds.first];
  return url == null
      ? glimpseLabel(g.kind, l)
      : TitleResolver.resolveDetailTitle(url);
}

String glimpseBody(Glimpse g, AppLocalizations l) => g.evidence.isEmpty
    ? l.glimpsesIntention
    : NotificationSummaryFormatter.format(g.evidence.first.text);

String glimpsePeriodSummary(GlimpsePeriod period, AppLocalizations l) {
  if (period.sources.isEmpty) return l.glimpsesNoSavesPeriod;
  if (period.topics.isEmpty) {
    return l.glimpsesPeriodCount(period.sources.length);
  }
  final topics = period.topics
      .take(3)
      .map(
        (t) => '${glimpseTopicLabel(t.subject.key, l)} (${t.sourceIds.length})',
      )
      .join(', ');
  return l.glimpsesPeriodSummary(period.sources.length, topics);
}

Future<String> glimpseNotificationBody(
  Glimpse g,
  AppLocalizations l,
  Map<int, SavedUrl> urls,
) async {
  if (!g.isRecap) return glimpseBody(g, l);
  final evidence = g.evidence
      .where((e) => urls.containsKey(e.sourceId))
      .firstOrNull;
  if (evidence == null) return l.glimpsesBrowsePeriod;
  return NotificationSummaryFormatter.format(
    '${TitleResolver.resolveDetailTitle(urls[evidence.sourceId]!)}: ${evidence.text}',
  );
}

String glimpseEvidenceLabel(GlimpseEvidence e, AppLocalizations l) =>
    switch (e.kind) {
      GlimpseEvidenceKind.highlight => l.glimpsesHighlight,
      GlimpseEvidenceKind.note => l.glimpsesNote,
      GlimpseEvidenceKind.summary => l.summary,
    };

String glimpseWhy(Glimpse g, AppLocalizations l, Map<int, SavedUrl> urls) {
  if (g.kind == GlimpseKind.connection) {
    final trigger = urls[g.sourceIds.first];
    if (trigger != null) {
      return l.glimpsesWhyConnection(
        TitleResolver.resolveDetailTitle(trigger),
        g.topicLabel,
      );
    }
  }
  if (g.isReminder) return l.glimpsesIntention;
  return switch (g.evidence.firstOrNull?.kind) {
    GlimpseEvidenceKind.highlight => l.glimpsesWhyHighlight,
    GlimpseEvidenceKind.note => l.glimpsesWhyNote,
    _ => l.glimpsesWhyEarlier,
  };
}

String glimpseTopicLabel(String key, AppLocalizations l) => switch (key) {
  'recipes' => l.glimpsesTopicRecipes,
  'anime_manga' => l.glimpsesTopicAnime,
  'motorcycles' => l.glimpsesTopicMotorcycles,
  'music' => l.glimpsesTopicMusic,
  'fitness' => l.glimpsesTopicFitness,
  'wildlife_nature' => l.glimpsesTopicNature,
  'travel_places' => l.glimpsesTopicTravel,
  'movies_watchlist' => l.glimpsesTopicMovies,
  'books_reading' => l.glimpsesTopicBooks,
  'spirituality' => l.glimpsesTopicSpirituality,
  'history_society' => l.glimpsesTopicHistory,
  'personal_growth' => l.glimpsesTopicGrowth,
  'finance_economics' => l.glimpsesTopicFinance,
  'design_creativity' => l.glimpsesTopicDesign,
  'software_ai' => l.glimpsesTopicSoftware,
  'science' => l.glimpsesTopicScience,
  _ => l.categoryOther,
};
