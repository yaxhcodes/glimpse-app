export 'app_locale.dart';
export 'generated/app_localizations.dart';

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';
import 'app_locale.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}

Future<AppLocalizations> loadBackgroundLocalizations() async {
  final locale = await loadEffectiveAppLocale();
  return AppLocalizations.delegate.load(locale);
}

String localizedCategoryLabel(AppLocalizations strings, String category) =>
    switch (category.trim()) {
      'Technology' => strings.categoryTechnology,
      'Business' => strings.categoryBusiness,
      'Finance' => strings.categoryFinance,
      'Science' => strings.categoryScience,
      'Health' => strings.categoryHealth,
      'Education' => strings.categoryEducation,
      'News' => strings.categoryNews,
      'Design' => strings.categoryDesign,
      'History' => strings.categoryHistory,
      'Philosophy' => strings.categoryPhilosophy,
      'Nature' => strings.categoryNature,
      'Food' => strings.categoryFood,
      'Travel' => strings.categoryTravel,
      'Entertainment' => strings.categoryEntertainment,
      'Lifestyle' => strings.categoryLifestyle,
      'Sports' => strings.categorySports,
      'Other' => strings.categoryOther,
      'Movies & TV' => strings.libraryMoviesShows,
      _ => category,
    };

String localizedTagLabel(AppLocalizations strings, String label) {
  final trimmed = label.trim();
  final localizedCategory = localizedCategoryLabel(strings, trimmed);
  if (localizedCategory != trimmed) return localizedCategory;

  return switch (trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')) {
    'appletv' || 'apple tv' || 'apple tv+' => 'Apple TV+',
    _ => trimmed,
  };
}
