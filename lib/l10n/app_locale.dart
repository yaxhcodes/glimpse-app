import 'dart:ui';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appSupportedLocales = <Locale>[
  Locale('en'),
  Locale('ja'),
  Locale('es'),
  Locale('fr'),
  Locale('pt', 'BR'),
  Locale('de'),
];

enum AppLanguage {
  system,
  english,
  japanese,
  spanish,
  french,
  portugueseBrazil,
  german,
}

extension AppLanguageLocale on AppLanguage {
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.english => const Locale('en'),
    AppLanguage.japanese => const Locale('ja'),
    AppLanguage.spanish => const Locale('es'),
    AppLanguage.french => const Locale('fr'),
    AppLanguage.portugueseBrazil => const Locale('pt', 'BR'),
    AppLanguage.german => const Locale('de'),
  };

  String? get persistedTag => switch (this) {
    AppLanguage.system => null,
    AppLanguage.english => 'en',
    AppLanguage.japanese => 'ja',
    AppLanguage.spanish => 'es',
    AppLanguage.french => 'fr',
    AppLanguage.portugueseBrazil => 'pt-BR',
    AppLanguage.german => 'de',
  };

  static AppLanguage fromPersistedTag(String? value) => switch (value) {
    'en' => AppLanguage.english,
    'ja' => AppLanguage.japanese,
    'es' => AppLanguage.spanish,
    'fr' => AppLanguage.french,
    'pt-BR' || 'pt_BR' || 'pt' => AppLanguage.portugueseBrazil,
    'de' => AppLanguage.german,
    _ => AppLanguage.system,
  };
}

@immutable
class AppLocaleState {
  const AppLocaleState({
    this.preference = AppLanguage.system,
    required this.systemLocales,
  });

  final AppLanguage preference;
  final List<Locale> systemLocales;

  Locale get effectiveLocale => resolveAppLocale(
    preference.locale == null ? systemLocales : <Locale>[preference.locale!],
  );

  AppLocaleState copyWith({
    AppLanguage? preference,
    List<Locale>? systemLocales,
  }) => AppLocaleState(
    preference: preference ?? this.preference,
    systemLocales: systemLocales ?? this.systemLocales,
  );
}

Locale resolveAppLocale(List<Locale>? preferredLocales) {
  for (final locale in preferredLocales ?? const <Locale>[]) {
    switch (locale.languageCode.toLowerCase()) {
      case 'ja':
        return const Locale('ja');
      case 'es':
        return const Locale('es');
      case 'fr':
        return const Locale('fr');
      case 'pt':
        return const Locale('pt', 'BR');
      case 'de':
        return const Locale('de');
      case 'en':
        return const Locale('en');
    }
  }
  return const Locale('en');
}

String appLocaleTag(Locale locale) =>
    locale.languageCode == 'pt' ? 'pt-BR' : locale.languageCode.toLowerCase();

const _appLanguagePreferenceKey = 'glimpse_app_language';

class AppLocaleController extends StateNotifier<AppLocaleState>
    with WidgetsBindingObserver {
  AppLocaleController()
    : super(
        AppLocaleState(
          systemLocales: List<Locale>.from(PlatformDispatcher.instance.locales),
        ),
      ) {
    WidgetsBinding.instance.addObserver(this);
    ready = _load();
  }

  late final Future<void> ready;

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    if (!mounted) return;
    state = state.copyWith(
      preference: AppLanguageLocale.fromPersistedTag(
        preferences.getString(_appLanguagePreferenceKey),
      ),
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    await ready;
    state = state.copyWith(preference: language);
    final preferences = await SharedPreferences.getInstance();
    final tag = language.persistedTag;
    if (tag == null) {
      await preferences.remove(_appLanguagePreferenceKey);
    } else {
      await preferences.setString(_appLanguagePreferenceKey, tag);
    }
    await _clearLanguageSensitiveCaches(preferences);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    state = state.copyWith(
      systemLocales: List<Locale>.from(
        locales ?? PlatformDispatcher.instance.locales,
      ),
    );
    unawaited(
      SharedPreferences.getInstance().then(_clearLanguageSensitiveCaches),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

Future<void> _clearLanguageSensitiveCaches(
  SharedPreferences preferences,
) async {
  const exactKeys = <String>{
    'glimpse_suggestions_v2',
    'glimpse_suggestions_timestamp_v2',
    'glimpse_suggestions_clusters_v4',
    'glimpse_suggestions_clusters_ts_v4',
    'glimpse_suggestions_v3_clusters',
    'glimpse_suggestions_timestamp_v3',
  };
  final keys = preferences
      .getKeys()
      .where(
        (key) => exactKeys.contains(key) || key.startsWith('notif_copy_cache_'),
      )
      .toList(growable: false);
  await Future.wait(keys.map(preferences.remove));
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleController, AppLocaleState>(
      (ref) => AppLocaleController(),
    );

final effectiveAppLocaleProvider = Provider<Locale>(
  (ref) => ref.watch(appLocaleProvider).effectiveLocale,
);

Future<Locale> loadEffectiveAppLocale() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final selection = AppLanguageLocale.fromPersistedTag(
    preferences.getString(_appLanguagePreferenceKey),
  );
  return resolveAppLocale(
    selection.locale == null
        ? PlatformDispatcher.instance.locales
        : <Locale>[selection.locale!],
  );
}
