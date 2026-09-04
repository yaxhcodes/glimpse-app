// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get musicDetailsUnavailable =>
      'Einige Songdetails konnten nicht geladen werden.';

  @override
  String get loadingMusicDetails => 'Songdetails werden geladen…';

  @override
  String get couldNotSaveMusicProvider =>
      'Deine Musik-App konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get libraryMusicEmptyDescription =>
      'Songs aus deinen gespeicherten Links erscheinen hier.';

  @override
  String get libraryMusicDescription => 'Songs aus deinen gespeicherten Links';

  @override
  String get libraryMusic => 'Musik';

  @override
  String get appName => 'Glimpse';

  @override
  String get home => 'Start';

  @override
  String get collections => 'Sammlungen';

  @override
  String get interests => 'Interessen';

  @override
  String get search => 'Suchen';

  @override
  String get askGlimpse => 'Glimpse fragen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get accountAndPlan => 'Konto & Tarif';

  @override
  String get personalization => 'Personalisierung';

  @override
  String get lookAndFeel => 'Darstellung';

  @override
  String get themeAndAccent => 'Design und Akzentfarbe';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemeinstellung';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageJapanese => 'Japanisch';

  @override
  String get languageSpanish => 'Spanisch';

  @override
  String get languageFrench => 'Französisch';

  @override
  String get languagePortugueseBrazil => 'Portugiesisch (Brasilien)';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get chooseLanguage => 'Sprache auswählen';

  @override
  String get musicApp => 'Musik-App';

  @override
  String get chooseWhereSongsOpen => 'Festlegen, wo Songs geöffnet werden';

  @override
  String get loadingPreference => 'Einstellung wird geladen';

  @override
  String get libraryGestures => 'Bibliotheksgesten';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get privacyAndData => 'Datenschutz & Daten';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get privacySubtitle => 'Was lokal bleibt und was hochgeladen wird';

  @override
  String get dataAndBackup => 'Daten & Sicherung';

  @override
  String get dataAndBackupSubtitle =>
      'Gespeichertes Wissen schützen und wiederherstellen';

  @override
  String get bin => 'Papierkorb';

  @override
  String get binSubtitle => 'Gelöschte Elemente werden 30 Tage aufbewahrt';

  @override
  String get clearAllData => 'Alle Daten löschen';

  @override
  String get clearAllDataSubtitle =>
      'Alle gespeicherten Links endgültig löschen';

  @override
  String get about => 'Über die App';

  @override
  String get aboutGlimpse => 'Über Glimpse';

  @override
  String get aboutSubtitle => 'Version, Rechtliches & Hilfe';

  @override
  String get accountActions => 'Kontoaktionen';

  @override
  String get logOut => 'Abmelden';

  @override
  String get logOutSubtitle => 'Von diesem Gerät abmelden';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountSubtitle => 'Kontolöschung beantragen';

  @override
  String get deletingAccount => 'Konto wird gelöscht…';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get deleteAll => 'Alle löschen';

  @override
  String get clearAllDataQuestion => 'Alle Daten löschen?';

  @override
  String get clearAllDataWarning =>
      'Dadurch werden alle gespeicherten URLs endgültig gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get allDataCleared => 'Alle Daten gelöscht';

  @override
  String get logOutQuestion => 'Abmelden?';

  @override
  String get logOutWarning =>
      'Du musst dich erneut anmelden, um auf dein Glimpse-Konto zuzugreifen.';

  @override
  String get deleteAccountQuestion => 'Konto löschen?';

  @override
  String get manageSubscription => 'Abo verwalten';

  @override
  String get accountDeleted => 'Konto gelöscht';

  @override
  String get manageYourPlan => 'Tarif verwalten';

  @override
  String get checkingSaveAllowance => 'Verfügbare Speicherungen werden geprüft';

  @override
  String aiSavesLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count KI-Speicherungen verfügbar',
      one: 'Noch 1 KI-Speicherung verfügbar',
    );
    return '$_temp0';
  }

  @override
  String get captureBody => 'Wir benachrichtigen dich, sobald es fertig ist.';

  @override
  String get captureQueuedWithoutNotifications =>
      'Es wird in Glimpse fertiggestellt.';

  @override
  String get captureSchedulingFallback =>
      'Gespeichert. Öffne Glimpse, um die Verarbeitung abzuschließen.';

  @override
  String get captureCouldNotSave =>
      'Dieser Link konnte nicht gespeichert werden';

  @override
  String savedToCollection(String collectionName) {
    return 'In $collectionName gespeichert';
  }

  @override
  String get savedWithoutAi => 'Ohne KI-Anreicherung gespeichert';

  @override
  String get aiLimitBody =>
      'Du hast deine 30 lebenslangen KI-Speicherungen verbraucht. Tippe zum Upgraden.';

  @override
  String get proAiLimitBody =>
      'Du hast diesen Monat 500 KI-Speicherungen verbraucht. Dein Link wurde ohne KI-Anreicherung gespeichert.';

  @override
  String get alreadyInYourWorld => 'Bereits in deiner Welt.';

  @override
  String get enrichmentFailed =>
      'Anreicherung konnte nicht abgeschlossen werden';

  @override
  String get tapToRetry => 'Tippe, um diese Speicherung erneut zu versuchen.';

  @override
  String get notification => 'Benachrichtigung';

  @override
  String get today => 'Heute';

  @override
  String get yesterday => 'Gestern';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get close => 'Schließen';

  @override
  String get addUrl => 'URL hinzufügen';

  @override
  String get newCollection => 'Neue Sammlung';

  @override
  String get captured => 'Gespeichert';

  @override
  String get undo => 'Rückgängig';

  @override
  String get alreadyInGlimpse => 'Bereits in Glimpse';

  @override
  String get open => 'Öffnen';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get exitSelection => 'Auswahl beenden';

  @override
  String get sources => 'Quellen';

  @override
  String get viewAllSources => 'Alle Quellen anzeigen';

  @override
  String get pasteLink => 'Link einfügen…';

  @override
  String get dismissClipboardSuggestion => 'Zwischenablagevorschlag schließen';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get editCollection => 'Sammlung bearbeiten';

  @override
  String get moveContents => 'Inhalte verschieben';

  @override
  String get deleteSelectedCollections => 'Ausgewählte Sammlungen löschen';

  @override
  String get delete => 'Löschen';

  @override
  String get collectionOptions => 'Sammlungsoptionen';

  @override
  String get grid => 'Raster';

  @override
  String get list => 'Liste';

  @override
  String get manual => 'Manuell';

  @override
  String get newest => 'Neueste';

  @override
  String get alphabetical => 'A–Z';

  @override
  String get reorder => 'Neu anordnen';

  @override
  String get upgradeToPro => 'Auf Pro upgraden';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get applyFilters => 'Filter anwenden';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get capture => 'Speichern';

  @override
  String get capturing => 'Wird gespeichert…';

  @override
  String get pasteFromClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get addToCollection => 'Zur Sammlung hinzufügen';

  @override
  String get more => 'Mehr';

  @override
  String get notes => 'Notizen';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryBusiness => 'Wirtschaft';

  @override
  String get categoryFinance => 'Finanzen';

  @override
  String get categoryScience => 'Wissenschaft';

  @override
  String get categoryHealth => 'Gesundheit';

  @override
  String get categoryEducation => 'Bildung';

  @override
  String get categoryNews => 'Nachrichten';

  @override
  String get categoryDesign => 'Design';

  @override
  String get categoryHistory => 'Geschichte';

  @override
  String get categoryPhilosophy => 'Philosophie';

  @override
  String get categoryNature => 'Natur';

  @override
  String get categoryFood => 'Essen';

  @override
  String get categoryTravel => 'Reisen';

  @override
  String get categoryEntertainment => 'Unterhaltung';

  @override
  String get categoryLifestyle => 'Lebensstil';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryOther => 'Sonstiges';

  @override
  String minutesAgo(Object count) {
    return 'vor $count Min.';
  }

  @override
  String hoursAgo(Object count) {
    return 'vor $count Std.';
  }

  @override
  String daysAgo(Object count) {
    return 'vor $count T.';
  }

  @override
  String get smartNotificationsDescription =>
      'Intelligente Benachrichtigungen zu deinen gespeicherten Links';

  @override
  String get done => 'Fertig';

  @override
  String get later => 'Später';

  @override
  String get notificationFallbackTitle => 'Benachrichtigung';

  @override
  String newNotificationCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Benachrichtigungen',
      one: '1 neue Benachrichtigung',
    );
    return '$_temp0';
  }

  @override
  String get captureSomethingWorthReturning =>
      'Speichere etwas, zu dem du zurückkehren möchtest';

  @override
  String get captureContextAfter =>
      'Glimpse findet den Kontext, nachdem du es gespeichert hast.';

  @override
  String get link => 'Link';

  @override
  String get detectedFromClipboard => 'In der Zwischenablage erkannt';

  @override
  String get collection => 'Sammlung';

  @override
  String get noCollection => 'Keine Sammlung';

  @override
  String get savingTo => 'Speichern in';

  @override
  String get chooseCollection => 'Sammlung auswählen';

  @override
  String get chooseACollection => 'Eine Sammlung auswählen';

  @override
  String get processingLink => 'Link wird verarbeitet…';

  @override
  String get couldNotLoadCollections =>
      'Sammlungen konnten nicht geladen werden.';

  @override
  String linkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Links',
      one: '1 Link',
      zero: 'Keine Links',
    );
    return '$_temp0';
  }

  @override
  String get noteOptional => 'Notiz (optional)';

  @override
  String get addNoteOptional => 'Notiz hinzufügen (optional)';

  @override
  String get pleaseEnterUrl => 'Bitte gib eine URL ein';

  @override
  String get couldNotCaptureLink =>
      'Dieser Link konnte nicht gespeichert werden';

  @override
  String get findingSavedVersion => 'Gespeicherte Version wird gesucht…';

  @override
  String get openSavedItem => 'Gespeichertes Element öffnen';

  @override
  String collectionSelection(String collectionName) {
    return 'Sammlung, $collectionName';
  }

  @override
  String get capturedInGlimpse => 'In Glimpse gespeichert';

  @override
  String get firstCapturedReady =>
      'Dein erstes gespeichertes Element ist unten bereit.';

  @override
  String get shareAnyApp =>
      'Teile aus jeder App — Glimpse sortiert es für dich.';

  @override
  String get howGlimpseWorks => 'So funktioniert Glimpse';

  @override
  String get capturingWhatCaughtYourEye =>
      'Was dir aufgefallen ist, wird gespeichert';

  @override
  String get findingContext => 'Kontext wird gesucht';

  @override
  String get invalidLink => 'Ungültiger Link';

  @override
  String get rediscover => 'Wiederentdecken';

  @override
  String get rediscoverSubtitle => 'Einen erneuten Blick wert';

  @override
  String get rediscoverTip =>
      'Wiederentdecken wählt täglich einige Erinnerungen aus, zu denen es sich zurückzukehren lohnt.';

  @override
  String get dismissRediscoverTip => 'Hinweis zu Wiederentdecken schließen';

  @override
  String get pinned => 'Angeheftet';

  @override
  String get recentSaves => 'Neueste Speicherungen';

  @override
  String get justNow => 'gerade eben';

  @override
  String weeksAgo(Object count) {
    return 'vor $count Wo.';
  }

  @override
  String monthsAgo(Object count) {
    return 'vor $count Mon.';
  }

  @override
  String yearsAgo(Object count) {
    return 'vor $count J.';
  }

  @override
  String get retrying => 'Erneuter Versuch';

  @override
  String get processing => 'Verarbeitung';

  @override
  String get processingSavedHeadline => 'In deiner Bibliothek gespeichert';

  @override
  String get processingSavedDetail => 'Deine Speicherung wird vorbereitet';

  @override
  String get processingOpeningHeadline => 'Inhalt wird geöffnet';

  @override
  String get processingOpeningDetail => 'Der gespeicherte Inhalt wird geprüft';

  @override
  String processingReadingHeadline(String content) {
    return '$content wird gelesen';
  }

  @override
  String get processingExtractingDetail =>
      'Nützliche Details werden herausgearbeitet';

  @override
  String get processingUnderstoodHeadline => 'Inhalt verstanden';

  @override
  String get processingUnderstoodDetail =>
      'Der Inhalt wird in eine nützliche Speicherung verwandelt';

  @override
  String get processingFindingHeadline => 'Das Wesentliche wird gesucht';

  @override
  String get processingFindingDetail => 'Die wichtigsten Ideen werden gefunden';

  @override
  String get processingConnectingHeadline => 'Verbindungen werden hergestellt';

  @override
  String get processingConnectingDetail =>
      'Verknüpfung mit verwandten Speicherungen';

  @override
  String get processingFinishingHeadline => 'Speicherung wird fertiggestellt';

  @override
  String get processingFinishingDetail =>
      'Suche und Wiederentdecken werden vorbereitet';

  @override
  String get processingRetryHeadline => 'Dieser Schritt wird erneut versucht';

  @override
  String get processingRetryDetail =>
      'Der Verarbeitungsschritt wird erneut ausgeführt';

  @override
  String get processingFailedHeadline => 'Verarbeitung nicht abgeschlossen';

  @override
  String get processingFailedDetail =>
      'Deine Speicherung ist sicher. Versuche es erneut';

  @override
  String get processingDefaultHeadline => 'Diese Speicherung wird verstanden';

  @override
  String get processingDefaultDetail => 'Bewahrenswerte Ideen werden gesucht';

  @override
  String get processingContentReel => 'Reel';

  @override
  String get processingContentVideo => 'Video';

  @override
  String get processingContentPin => 'Pin';

  @override
  String get processingContentPage => 'Seite';

  @override
  String get needsAttention => 'Erfordert Aufmerksamkeit';

  @override
  String get read => 'Gelesen';

  @override
  String get unread => 'Ungelesen';

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get linkCopied => 'Link kopiert';

  @override
  String get openOriginal => 'Original öffnen';

  @override
  String get share => 'Teilen';

  @override
  String get enrichmentComplete => 'Anreicherung abgeschlossen';

  @override
  String get couldNotEnrichSave =>
      'Diese Speicherung konnte nicht angereichert werden';

  @override
  String get allSources => 'Alle Quellen';

  @override
  String get all => 'Alle';

  @override
  String get apps => 'Apps';

  @override
  String get websites => 'Websites';

  @override
  String get results => 'Ergebnisse';

  @override
  String get topSources => 'Top-Quellen';

  @override
  String get searchSources => 'Apps, Websites und Domains suchen…';

  @override
  String get filterSources => 'Quellen filtern';

  @override
  String get couldNotLoadSources => 'Quellen konnten nicht geladen werden';

  @override
  String noSourcesMatch(String query) {
    return 'Keine Quellen entsprechen „$query“';
  }

  @override
  String get noSavesFromApps => 'Noch keine Speicherungen aus Apps';

  @override
  String get noWebsiteSaves => 'Noch keine Website-Speicherungen';

  @override
  String get noSourcesYet => 'Noch keine Quellen';

  @override
  String get noSavesYet => 'Noch keine Speicherungen';

  @override
  String saveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Speicherungen',
      one: '1 Speicherung',
    );
    return '$_temp0';
  }

  @override
  String savesThisWeek(Object count) {
    return '+$count diese Woche';
  }

  @override
  String get growing => 'Zunehmend';

  @override
  String lastSaved(String time) {
    return 'Zuletzt gespeichert: $time';
  }

  @override
  String get leftSwipe => 'Nach links wischen';

  @override
  String get rightSwipe => 'Nach rechts wischen';

  @override
  String get chooseSwipeAction => 'Wischaktion auswählen';

  @override
  String get markReadUnread => 'Als gelesen/ungelesen markieren';

  @override
  String get pin => 'Anheften';

  @override
  String get none => 'Keine';

  @override
  String get smartNotifications => 'Intelligente Benachrichtigungen';

  @override
  String get behaviorBasedAlerts => 'Verhaltensbasierte Hinweise';

  @override
  String get whereDoYouListen => 'Wo hörst du Musik?';

  @override
  String get chooseMusicProvider =>
      'Wähle die App, die Glimpse für gefundene Songs verwenden soll.';

  @override
  String get brightness => 'Helligkeit';

  @override
  String get brightnessDescription =>
      'Lege fest, wann helle oder dunkle Farben verwendet werden.';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Hell';

  @override
  String get darkTheme => 'Dunkel';

  @override
  String get amoledBlack => 'AMOLED-Schwarz';

  @override
  String get amoledUnavailable =>
      'Verfügbar, wenn nicht das helle Design verwendet wird.';

  @override
  String get amoledDescription =>
      'Reinschwarze Hintergründe auf OLED — spart Energie.';

  @override
  String get accentColor => 'Akzentfarbe';

  @override
  String get dynamicAccentDescription =>
      'Dynamisch verwendet auf unterstützten Geräten die Farben deines Hintergrundbilds.';

  @override
  String selectedAccent(String accent) {
    return 'Ausgewählt: $accent';
  }

  @override
  String get themePreview => 'Designvorschau';

  @override
  String get themePreviewDescription =>
      'Akzent und Oberflächen werden anhand deiner Auswahl aktualisiert.';

  @override
  String get accentDynamic => 'Dynamisch';

  @override
  String get accentPurple => 'Violett';

  @override
  String get accentBlue => 'Blau';

  @override
  String get accentTeal => 'Türkis';

  @override
  String get accentGreen => 'Grün';

  @override
  String get accentLime => 'Limette';

  @override
  String get accentYellow => 'Gelb';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRed => 'Rot';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentSakura => 'Sakura';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentSlate => 'Schiefer';

  @override
  String get accentMonochrome => 'Monochrom';

  @override
  String get deleted => 'Gelöscht';

  @override
  String get noNotificationsYet => 'Noch keine Benachrichtigungen';

  @override
  String get notificationsEmptyDescription =>
      'Reisehinweise, neue Entdeckungen, Leseerinnerungen und wöchentliche Zusammenfassungen erscheinen hier.';

  @override
  String get ready => 'bereit';

  @override
  String waitingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warten',
      one: '1 wartet',
    );
    return '$_temp0';
  }

  @override
  String get backInView => 'Wieder im Blick';

  @override
  String get couldNotLoadSource => 'Diese Quelle konnte nicht geladen werden';

  @override
  String get noSavesFromSource => 'Keine Speicherungen aus dieser Quelle';

  @override
  String get saves => 'Speicherungen';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get opened => 'Geöffnet';

  @override
  String get topThemes => 'Top-Themen';

  @override
  String get allItems => 'Alle Elemente';

  @override
  String get oldest => 'Älteste';

  @override
  String get recentlyOpened => 'Zuletzt geöffnet';

  @override
  String get showItems => 'Elemente anzeigen';

  @override
  String get sortBy => 'Sortieren nach';

  @override
  String get noItemsFromSource => 'Keine Elemente aus dieser Quelle';

  @override
  String get noUnreadItems => 'Keine ungelesenen Elemente';

  @override
  String get noReadItems => 'Keine gelesenen Elemente';

  @override
  String get lastSavedLabel => 'Zuletzt gespeichert';

  @override
  String get markAllRead => 'Alle als gelesen markieren';

  @override
  String get back => 'Zurück';

  @override
  String get subscription => 'Abonnement';

  @override
  String get couldNotLoadSubscription =>
      'Abonnementinformationen konnten nicht geladen werden';

  @override
  String get coreLibrary => 'Kernbibliothek';

  @override
  String get unlimitedLinkSaving => 'Unbegrenztes Speichern von Links';

  @override
  String get unlimitedLinkSavingDescription => 'Speichere beliebig viele Links';

  @override
  String get collectionsOrganization => 'Sammlungen & Organisation';

  @override
  String get collectionsOrganizationDescription =>
      'Lesezeichen nach deinen Vorstellungen gruppieren und verwalten';

  @override
  String get smartNotificationsLongDescription =>
      'Verhaltensbasierte Hinweise und Leseerinnerungen';

  @override
  String get aiAssistant => 'KI-Assistent';

  @override
  String get aiTaggingCategorization => 'KI-Tags & Kategorisierung';

  @override
  String get freeSavesProUnlimited =>
      'Kostenlos: 30 KI-Speicherungen insgesamt · Pro: 500/Monat';

  @override
  String get keywordSearch => 'Stichwortsuche';

  @override
  String get freeSearchesProUnlimited =>
      'Kostenlos: 30 Suchen/Monat · Pro: Erweiterter Zugriff';

  @override
  String get askYourBookmarks => 'Frage deine Lesezeichen';

  @override
  String get freeQuestionsProUnlimited =>
      'Kostenlos: 30 Fragen/Monat · Pro: Großzügige faire Nutzung';

  @override
  String get proInsights => 'Pro-Einblicke';

  @override
  String get semanticSearch => 'Semantische Suche';

  @override
  String get semanticSearchDescription =>
      'Links nach Bedeutung statt nur nach Wörtern finden';

  @override
  String get weeklyRecap => 'Wochenrückblick';

  @override
  String get weeklyRecapDescription =>
      'KI-generierte Zusammenfassung deiner gespeicherten Links';

  @override
  String get multiLinkSynthesis => 'Linkübergreifende Synthese';

  @override
  String get multiLinkSynthesisDescription =>
      'Beliebige Lesezeichen gemeinsam analysieren';

  @override
  String get active => 'Aktiv';

  @override
  String get free => 'Kostenlos';

  @override
  String get proPlanDescription =>
      '500 KI-angereicherte Speicherungen pro Monat sowie erweiterter Ask- und Suchzugriff auf deine Bibliothek.';

  @override
  String get proPlanDevDescription =>
      '500 KI-angereicherte Speicherungen pro Monat sowie erweiterter Ask- und Suchzugriff. (Entwicklerüberschreibung; Store: Kostenlos)';

  @override
  String get freePlanDescription =>
      'Speichere unbegrenzt Links und teste KI mit 30 lebenslangen angereicherten Speicherungen vor dem Upgrade.';

  @override
  String get upgradeToGlimpsePro => 'Auf Glimpse Pro upgraden';

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get manageOnGooglePlay => 'Bei Google Play verwalten';

  @override
  String get local => 'Lokal';

  @override
  String get uploaded => 'Hochgeladen';

  @override
  String get bookmarks => 'Lesezeichen';

  @override
  String get aiSummaries => 'KI-Zusammenfassungen';

  @override
  String get accountInformation => 'Kontoinformationen';

  @override
  String get subscriptionStatus => 'Abonnementstatus';

  @override
  String get anonymousProductAnalytics => 'Anonyme Produktanalyse';

  @override
  String get storageLocation => 'Speicherort';

  @override
  String get pickAFolder => 'Ordner auswählen';

  @override
  String get chooseBackupFolderDescription =>
      'Tippe, um den Speicherort für Sicherungen auszuwählen';

  @override
  String get backupFolderInfo =>
      'Wird zum Speichern deiner Sicherungsdateien verwendet. Wähle den Ordner einmal aus und Glimpse speichert dort weiterhin neue Sicherungen.';

  @override
  String get automaticBackup => 'Automatische Sicherung';

  @override
  String get off => 'Aus';

  @override
  String get backupFrequencyDescription =>
      'Wie oft eine Sicherung am Speicherort erstellt werden soll';

  @override
  String get backupSensitiveInfo =>
      'Bewahre Kopien deiner Sicherungen auch an anderen Orten auf. Sicherungen können deine gesamte Bibliothek enthalten — behandle sie beim Teilen als vertraulich.';

  @override
  String get backupAndRestore => 'Sichern und wiederherstellen';

  @override
  String get createBackup => 'Sicherung erstellen';

  @override
  String get restoreBackup => 'Sicherung wiederherstellen';

  @override
  String lastBackup(Object time) {
    return 'Letzte Sicherung: $time';
  }

  @override
  String get backupLocalInfo =>
      'Sicherungen enthalten deine gesamte Bibliothek — Links, Sammlungen, Tags und Metadaten. Sie bleiben auf deinem Gerät.';

  @override
  String get deletedItemsRetention =>
      'Gelöschte Elemente werden 30 Tage aufbewahrt und bei der nächsten Bereinigung durch Glimpse endgültig entfernt.';

  @override
  String daysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Tage',
      one: 'Noch 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get expiresToday => 'Läuft heute ab';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get deletePermanently => 'Endgültig löschen';

  @override
  String get restoreAll => 'Alle wiederherstellen';

  @override
  String get emptyBin => 'Papierkorb leeren';

  @override
  String get binActions => 'Papierkorbaktionen';

  @override
  String get itemActions => 'Elementaktionen';

  @override
  String get binIsEmpty => 'Papierkorb ist leer';

  @override
  String get binEmptyDescription =>
      'Gelöschte Elemente erscheinen hier 30 Tage lang.';

  @override
  String get deleteAccountProWarning =>
      'Dadurch werden die Metadaten deines Glimpse-Kontos entfernt, die Abrechnung im Store jedoch nicht beendet. Pro kann nicht auf ein anderes Glimpse-Konto übertragen werden. Verwalte daher dein Abonnement vor dem Löschen. Deine Bibliothek auf dem Gerät wird nicht zu Supabase hochgeladen.';

  @override
  String get deleteAccountFreeWarning =>
      'Dadurch werden die Metadaten deines Glimpse-Kontos entfernt. Deine Bibliothek auf dem Gerät wird nicht zu Supabase hochgeladen.';

  @override
  String get details => 'Details';

  @override
  String openInSource(Object source) {
    return 'In $source öffnen';
  }

  @override
  String get summary => 'Zusammenfassung';

  @override
  String get addNote => 'Notiz hinzufügen';

  @override
  String get keyTakeaways => 'Wichtigste Erkenntnisse';

  @override
  String get fullBreakdown => 'Vollständige Aufschlüsselung';

  @override
  String get transcriptAndCaption => 'Transkript & Bildunterschrift';

  @override
  String get caption => 'Bildunterschrift';

  @override
  String get transcript => 'Transkript';

  @override
  String get onScreenText => 'Bildschirmtext';

  @override
  String get peopleMentioned => 'Erwähnte Personen';

  @override
  String peopleMentionedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erwähnte Personen',
      one: '1 erwähnte Person',
    );
    return '$_temp0';
  }

  @override
  String get alsoMentioned => 'Ebenfalls erwähnt';

  @override
  String get quotes => 'Zitate';

  @override
  String get tags => 'Tags';

  @override
  String get informationMayBeInaccurate => 'Informationen können ungenau sein';

  @override
  String get originalContentAttribution =>
      'Der Originalinhalt gehört dem jeweiligen Urheber.';

  @override
  String everyHours(Object count) {
    return 'Alle $count Stunden';
  }

  @override
  String get weekly => 'Wöchentlich';

  @override
  String get addTag => 'Tag hinzufügen';

  @override
  String get changeCategory => 'Kategorie ändern';

  @override
  String get worthWatching => 'Sehenswert';

  @override
  String get worthReading => 'Lesenswert';

  @override
  String get gamesMentioned => 'Erwähnte Spiele';

  @override
  String get musicMentioned => 'Erwähnte Musik';

  @override
  String get toolsMentioned => 'Erwähnte Tools';

  @override
  String get worthALook => 'Einen Blick wert';

  @override
  String get appsToTry => 'Apps zum Ausprobieren';

  @override
  String get placesToVisit => 'Orte zum Besuchen';

  @override
  String get websitesMentioned => 'Erwähnte Websites';

  @override
  String get claimsToRemember => 'Wichtige Aussagen';

  @override
  String get termsMentioned => 'Erwähnte Begriffe';

  @override
  String get notableDetails => 'Bemerkenswerte Details';

  @override
  String get library => 'Bibliothek';

  @override
  String get libraryDescription =>
      'Bücher, Filme, Orte & Musik aus deinen gespeicherten Links';

  @override
  String get buildsQuietly => 'Wächst unauffällig beim Speichern';

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente',
      one: '1 Element',
    );
    return '$_temp0';
  }

  @override
  String addedTime(Object time) {
    return 'Hinzugefügt · $time';
  }

  @override
  String get rediscoverIntentTitle =>
      'Einige Erinnerungen, die jetzt nützlich sein könnten';

  @override
  String chosenFromUnopened(Object count) {
    return 'Aus $count ungeöffneten Speicherungen und aktuellen Interessen ausgewählt.';
  }

  @override
  String get chosenFromSaved =>
      'Aus deinen gespeicherten, geöffneten und zurückgestellten Inhalten ausgewählt.';

  @override
  String get todayStableSet =>
      'Eine feste Auswahl für heute — kein endloser Feed.';

  @override
  String get recaps => 'Rückblicke';

  @override
  String get recapsDescription =>
      'Wöchentliche und monatliche Muster aus deinen eigenen Speicherungen.';

  @override
  String get dailyRecap => 'Tagesrückblick';

  @override
  String get monthlyRecap => 'Monatsrückblick';

  @override
  String recapSummary(num count, Object waiting) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Speicherungen',
      one: '1 Speicherung',
    );
    return '$_temp0 · $waiting warten';
  }

  @override
  String get yourWeekInSaves => 'Deine Woche in Speicherungen';

  @override
  String get yourMonthInMemories => 'Dein Monat in Erinnerungen';

  @override
  String topicKeptShowingUp(Object topic) {
    return '$topic tauchte immer wieder auf';
  }

  @override
  String get queued => 'In Warteschlange';

  @override
  String get forgottenGem => 'Vergessener Schatz';

  @override
  String get fromYourPast => 'Aus deiner Vergangenheit';

  @override
  String get rediscoverOptions => 'Optionen für Wiederentdecken';

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String get hideFor7Days => '7 Tage ausblenden';

  @override
  String get lessLikeThis => 'Weniger davon';

  @override
  String get reduceSimilarTopics => 'Ähnliche Themen reduzieren';

  @override
  String get nothingStrongToday => 'Heute nichts Relevantes genug';

  @override
  String get rediscoverQuiet =>
      'Wiederentdecken bleibt ruhig, bis eine Speicherung wirklich eine Rückkehr wert ist.';

  @override
  String get searchYourLibrary => 'Bibliothek durchsuchen…';

  @override
  String get findAnythingSaved => 'Gespeicherte Inhalte finden';

  @override
  String get searchEmptyDescription =>
      'Durchsuche Titel, Tags, Notizen und Zusammenfassungen und grenze die Ansicht anschließend ein.';

  @override
  String get filters => 'Filter';

  @override
  String get filtersActive => 'Filter aktiv';

  @override
  String get time => 'Zeitraum';

  @override
  String get allTime => 'Gesamter Zeitraum';

  @override
  String get thisMonth => 'Dieser Monat';

  @override
  String get status => 'Status';

  @override
  String get hasNotes => 'Mit Notizen';

  @override
  String get noNotes => 'Ohne Notizen';

  @override
  String get inCollection => 'In einer Sammlung';

  @override
  String get notInCollection => 'In keiner Sammlung';

  @override
  String get specificCollection => 'Bestimmte Sammlung';

  @override
  String get sort => 'Sortieren';

  @override
  String get relevance => 'Relevanz';

  @override
  String get newestSaved => 'Zuletzt gespeichert';

  @override
  String get oldestSaved => 'Zuerst gespeichert';

  @override
  String get learningInterests =>
      'Es wird gelernt, was deine Aufmerksamkeit hält';

  @override
  String get readingInterests => 'Interessen werden gelesen…';

  @override
  String get topSignal => 'Stärkstes Signal';

  @override
  String get growingInterests => 'Zunehmende Interessen';

  @override
  String get quieterInterests => 'Ruhigere Interessen';

  @override
  String interestStats(num patterns, num saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns Muster',
      one: '1 Muster',
    );
    String _temp1 = intl.Intl.pluralLogic(
      saves,
      locale: localeName,
      other: '$saves Speicherungen',
      one: '1 Speicherung',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String interestGroupedStats(Object grouped, num patterns, Object saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns Muster',
      one: '1 Muster',
    );
    return '$_temp0 · $grouped von $saves Speicherungen gruppiert';
  }

  @override
  String noPatternsScanned(Object saves) {
    return 'Noch keine Muster · $saves Speicherungen analysiert';
  }

  @override
  String get rebuildMap => 'Karte neu erstellen';

  @override
  String get couldNotBuildClusters => 'Cluster konnten nicht erstellt werden';

  @override
  String get interestMapEmpty => 'Deine Interessenkarte ist leer';

  @override
  String get interestMapEmptyDescription =>
      'Speichere mindestens 3 Links und Glimpse verbindet wiederkehrende Themen.';

  @override
  String lastAddedTime(Object time) {
    return 'Zuletzt hinzugefügt: $time';
  }

  @override
  String get hiddenFor7Days => '7 Tage ausgeblendet';

  @override
  String get seeLessLikeThis => 'Du wirst weniger Ähnliches sehen';

  @override
  String get searchingLibrary => 'Bibliothek wird durchsucht…';

  @override
  String get semanticMatch => 'Semantische Übereinstimmung';

  @override
  String get noMatchesForFilter => 'Keine Treffer für diesen Filter';

  @override
  String get broadenSearch =>
      'Versuche einen anderen Zeitraum oder erweitere deine Suche.';

  @override
  String get monthlyLimitReached => 'Monatliches Limit erreicht';

  @override
  String get searchFailed => 'Suche fehlgeschlagen';

  @override
  String get monthlySearchLimitDescription =>
      'Du hast dein monatliches Suchlimit erreicht. Upgrade auf Glimpse Pro für erweiterten Suchzugriff.';

  @override
  String get openingInterest => 'Interesse wird geöffnet…';

  @override
  String get couldNotOpenInterest =>
      'Dieses Interesse konnte nicht geöffnet werden.';

  @override
  String get interestNotFound => 'Interesse nicht gefunden';

  @override
  String interestSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Speicherungen in diesem Interesse.',
      one: '1 Speicherung in diesem Interesse.',
    );
    return '$_temp0';
  }

  @override
  String interestTopicsSummary(Object count, Object topics) {
    return '$count Speicherungen in $topics Themen';
  }

  @override
  String get reorderCollections => 'Sammlungen neu anordnen';

  @override
  String get dragToSetManualOrder =>
      'Ziehen, um die manuelle Reihenfolge festzulegen';

  @override
  String movedToCollection(Object name) {
    return 'Nach $name verschoben';
  }

  @override
  String movedLinksAndDeletedSources(num count, Object name, num sourceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Links',
      one: '1 Link',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sourceCount,
      locale: localeName,
      other: 'die Quellsammlungen gelöscht',
      one: 'die Quellsammlung gelöscht',
    );
    return '$_temp0 nach $name verschoben und $_temp1';
  }

  @override
  String deleteCollectionNamed(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String deleteCollectionsCount(Object count) {
    return '$count Sammlungen löschen?';
  }

  @override
  String get deleteCollectionDescription =>
      'Die gespeicherten Links bleiben in deiner Bibliothek. Nur die Sammlung wird entfernt.';

  @override
  String get deleteCollectionsDescription =>
      'Die gespeicherten Links bleiben in deiner Bibliothek. Nur die Sammlungen werden entfernt.';

  @override
  String collectionsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sammlungen gelöscht',
      one: 'Sammlung gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get createFirstCollection => 'Erstelle deine erste Sammlung';

  @override
  String get collectionEmptyDescription =>
      'Gruppiere Links in ruhigen, fokussierten Bereichen.';

  @override
  String get libraryBooks => 'Bücher';

  @override
  String get libraryMoviesShows => 'Filme & Serien';

  @override
  String get libraryPlaces => 'Orte';

  @override
  String get libraryBook => 'Buch';

  @override
  String get libraryMovie => 'Film';

  @override
  String get libraryPlace => 'Ort';

  @override
  String get libraryReadingList => 'Leseliste';

  @override
  String get libraryWatchlist => 'Merkliste';

  @override
  String get libraryNotInReadingList => 'Nicht in der Leseliste';

  @override
  String get libraryNotInWatchlist => 'Nicht in der Merkliste';

  @override
  String get libraryNotListed => 'Nicht aufgeführt';

  @override
  String get libraryPlanning => 'Geplant';

  @override
  String get libraryReading => 'Wird gelesen';

  @override
  String get libraryWatching => 'Wird angesehen';

  @override
  String get libraryInProgress => 'In Bearbeitung';

  @override
  String get libraryDropped => 'Abgebrochen';

  @override
  String get libraryRead => 'Gelesen';

  @override
  String get libraryWatched => 'Angesehen';

  @override
  String get libraryVisited => 'Besucht';

  @override
  String libraryStatusSemantics(Object status) {
    return 'Status: $status';
  }

  @override
  String libraryReadingPageStatus(Object page) {
    return 'Beim Lesen · S. $page';
  }

  @override
  String get libraryGenreFantasy => 'Fantasy';

  @override
  String get libraryGenreScienceFiction => 'Science-Fiction';

  @override
  String get libraryGenreMysteryThriller => 'Mystery & Thriller';

  @override
  String get libraryGenreRomance => 'Liebesroman';

  @override
  String get libraryGenreHorror => 'Horror';

  @override
  String get libraryGenreBiographyMemoir => 'Biografie & Memoiren';

  @override
  String get libraryGenreHistory => 'Geschichte';

  @override
  String get libraryGenrePhilosophy => 'Philosophie';

  @override
  String get libraryGenrePsychology => 'Psychologie';

  @override
  String get libraryGenreBusiness => 'Wirtschaft';

  @override
  String get libraryGenreFinanceInvesting => 'Finanzen & Geldanlage';

  @override
  String get libraryGenreTechnology => 'Technologie';

  @override
  String get libraryGenreScience => 'Wissenschaft';

  @override
  String get libraryGenreSelfDevelopment => 'Persönliche Entwicklung';

  @override
  String get libraryGenreHealthWellness => 'Gesundheit & Wohlbefinden';

  @override
  String get libraryGenrePoliticsSociety => 'Politik & Gesellschaft';

  @override
  String get libraryGenreArtDesign => 'Kunst & Design';

  @override
  String get libraryGenreTravel => 'Reisen';

  @override
  String get libraryGenreComicsGraphicNovels => 'Comics & Graphic Novels';

  @override
  String get libraryGenreFiction => 'Belletristik';

  @override
  String get libraryGenreAction => 'Action';

  @override
  String get libraryGenreAdventure => 'Abenteuer';

  @override
  String get libraryGenreAnimation => 'Animation';

  @override
  String get libraryGenreComedy => 'Komödie';

  @override
  String get libraryGenreCrime => 'Krimi';

  @override
  String get libraryGenreDocumentary => 'Dokumentarfilm';

  @override
  String get libraryGenreDrama => 'Drama';

  @override
  String get libraryGenreFamily => 'Familie';

  @override
  String get libraryGenreMystery => 'Mystery';

  @override
  String get libraryGenreThriller => 'Thriller';

  @override
  String get libraryGenreWar => 'Krieg';

  @override
  String get libraryGenreWestern => 'Western';

  @override
  String get libraryGenreMusic => 'Musik';

  @override
  String get libraryGenreOther => 'Sonstiges';

  @override
  String get librarySubtypeTvShow => 'TV-Serie';

  @override
  String get librarySubtypeSeries => 'Serie';

  @override
  String get couldNotOpenLibrary => 'Bibliothek konnte nicht geöffnet werden';

  @override
  String searchLibraryItems(Object kind) {
    return '$kind durchsuchen';
  }

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get clearAll => 'Alle löschen';

  @override
  String get recentlyDiscovered => 'Kürzlich entdeckt';

  @override
  String get titleAZ => 'Titel A–Z';

  @override
  String get yearNewest => 'Neuestes Jahr';

  @override
  String libraryOptions(Object kind) {
    return 'Optionen für $kind';
  }

  @override
  String filterLibraryItems(Object kind) {
    return '$kind filtern';
  }

  @override
  String get readingStatus => 'Lesestatus';

  @override
  String get watchStatus => 'Ansehstatus';

  @override
  String get anyStatus => 'Beliebiger Status';

  @override
  String get genre => 'Genre';

  @override
  String get allGenres => 'Alle Genres';

  @override
  String get nothingMatchesFilters => 'Nichts entspricht diesen Filtern.';

  @override
  String get nothingRecognizedHere => 'Hier wurde noch nichts erkannt.';

  @override
  String get couldNotUpdateLibraryItem =>
      'Dieses Bibliothekselement konnte nicht aktualisiert werden.';

  @override
  String get foundInYourSaves => 'In deinen Speicherungen gefunden';

  @override
  String get recognizedOrganizedByType => 'Automatisch nach Typ sortiert';

  @override
  String libraryBookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bücher',
      one: '1 Buch',
    );
    return '$_temp0';
  }

  @override
  String libraryMovieCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String libraryPlaceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Orte',
      one: '1 Ort',
    );
    return '$_temp0';
  }

  @override
  String libraryStopCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stopps',
      one: '1 Stopp',
    );
    return '$_temp0';
  }

  @override
  String get nothingRecognizedYet => 'Noch nichts erkannt';

  @override
  String get recognizedTitlesGatherHere =>
      'Erkannte Titel werden hier gesammelt';

  @override
  String recognizedCount(Object count) {
    return '$count erkannt';
  }

  @override
  String get savedPlacesAppearOnMap =>
      'Gespeicherte Orte erscheinen auf einer Karte';

  @override
  String get addingDetails => 'Details werden hinzugefügt';

  @override
  String get extraDetailsUnavailable =>
      'Zusätzliche Details sind vorübergehend nicht verfügbar';

  @override
  String itemsCouldNotRefresh(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente konnten nicht aktualisiert werden',
      one: '1 Element konnte nicht aktualisiert werden',
    );
    return '$_temp0';
  }

  @override
  String progressOf(Object completed, Object total) {
    return '$completed von $total';
  }

  @override
  String get savedDetailsRemainAvailable =>
      'Gespeicherte Details bleiben verfügbar';

  @override
  String waitingToRetry(Object count) {
    return '$count warten auf einen erneuten Versuch';
  }

  @override
  String get libraryBuildsAsYouSave => 'Sie wächst beim Speichern';

  @override
  String get libraryEmptyDescription =>
      'Speichere Empfehlungen für Bücher, Filme, Orte und Musik. Glimpse ordnet die Inhalte hier für dich.';

  @override
  String get libraryUnavailable => 'Bibliothek ist derzeit nicht verfügbar';

  @override
  String get yourPlaces => 'Deine Orte';

  @override
  String placesAreasSummary(num areas, num places) {
    String _temp0 = intl.Intl.pluralLogic(
      places,
      locale: localeName,
      other: '$places Orte',
      one: '1 Ort',
    );
    String _temp1 = intl.Intl.pluralLogic(
      areas,
      locale: localeName,
      other: '$areas Gebiete',
      one: '1 Gebiet',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get planThisArea => 'Dieses Gebiet planen';

  @override
  String get planAnItinerary => 'Reiseplan erstellen';

  @override
  String get searchSavedPlaces => 'Gespeicherte Orte suchen';

  @override
  String get yourPlans => 'Deine Pläne';

  @override
  String get plan => 'Planen';

  @override
  String get locationUnavailable => 'Standort nicht verfügbar';

  @override
  String openNamedItem(Object name) {
    return '$name öffnen';
  }

  @override
  String get wantToVisit => 'Möchte ich besuchen';

  @override
  String get savedPlace => 'Gespeicherter Ort';

  @override
  String get planAVisit => 'Besuch planen';

  @override
  String get maps => 'Karten';

  @override
  String get noSavedPlacesMatch =>
      'Keine gespeicherten Orte entsprechen dieser Suche.';

  @override
  String get noPlacesDiscovered => 'Noch keine Orte entdeckt';

  @override
  String get placesMentionedGatherHere =>
      'In deinen Speicherungen erwähnte Orte werden hier gesammelt.';

  @override
  String get fitAllPlaces => 'Alle Orte einpassen';

  @override
  String get noMappedPlaces => 'Noch keine Orte auf der Karte';

  @override
  String get mapUnavailablePlacesListed =>
      'Karte nicht verfügbar — deine Orte werden unten weiterhin aufgeführt';

  @override
  String get libraryItemUnavailable =>
      'Dieses Bibliothekselement ist nicht verfügbar.';

  @override
  String get couldNotUpdateBookmark =>
      'Dein Lesezeichen konnte nicht aktualisiert werden.';

  @override
  String hiddenFromLibrary(Object name) {
    return '$name aus der Bibliothek ausgeblendet';
  }

  @override
  String get libraryItemOptions => 'Optionen für Bibliothekselement';

  @override
  String get hideFromLibrary => 'Aus Bibliothek ausblenden';

  @override
  String get addToReadingList => 'Zur Leseliste hinzufügen';

  @override
  String get addToWatchlist => 'Zur Merkliste hinzufügen';

  @override
  String get removeFromReadingList => 'Aus Leseliste entfernen';

  @override
  String get removeFromWatchlist => 'Aus Merkliste entfernen';

  @override
  String get whyItMattered => 'Warum es wichtig war';

  @override
  String get plot => 'Handlung';

  @override
  String get yourBookmark => 'Dein Lesezeichen';

  @override
  String get savePageYouAreOn => 'Aktuelle Seite speichern';

  @override
  String savePlaceAboutPages(Object count) {
    return 'Stelle speichern · etwa $count Seiten';
  }

  @override
  String pageNumber(Object page) {
    return 'Seite $page';
  }

  @override
  String pageAboutPages(Object count, Object page) {
    return 'Seite $page · etwa $count Seiten';
  }

  @override
  String get setCurrentPage => 'Aktuelle Seite festlegen';

  @override
  String get updatePage => 'Seite aktualisieren';

  @override
  String get updateYourBookmark => 'Lesezeichen aktualisieren';

  @override
  String aboutPages(Object count) {
    return 'etwa $count Seiten';
  }

  @override
  String get currentPage => 'Aktuelle Seite';

  @override
  String get enterPageNumber => 'Seitenzahl eingeben';

  @override
  String get saveBookmark => 'Lesezeichen speichern';

  @override
  String get pageGreaterThanZero => 'Gib eine Seitenzahl größer als null ein';

  @override
  String libraryItemSemantics(Object kind, Object title) {
    return '$kind: $title';
  }

  @override
  String libraryItemOpenHint(Object list) {
    return 'Doppeltippen zum Öffnen. Gedrückt halten, um den Status in $list zu ändern.';
  }

  @override
  String get collectionEditSubtitle =>
      'Diesen gespeicherten Bereich verfeinern.';

  @override
  String get collectionCreateSubtitle =>
      'Einen fokussierten Bereich für gespeicherte Ideen erstellen.';

  @override
  String get nameLabel => 'Name';

  @override
  String get descriptionLabel => 'Beschreibung';

  @override
  String get collectionNameHint => 'Reisen & Fernweh';

  @override
  String get collectionDescriptionHint => 'Optionale Notiz für diesen Bereich';

  @override
  String get save => 'Speichern';

  @override
  String get create => 'Erstellen';

  @override
  String get nameCollectionError => 'Benenne deine Sammlung';

  @override
  String get duplicateCollectionError =>
      'Eine Sammlung mit diesem Namen existiert bereits';

  @override
  String get deleteCollection => 'Sammlung löschen';

  @override
  String get addLink => 'Link hinzufügen';

  @override
  String get noLinksInCollection => 'Noch keine Links in dieser Sammlung.';

  @override
  String get notificationTravelPlaces => 'Reisen & Orte';

  @override
  String get notificationNewDiscovery => 'Neue Entdeckung';

  @override
  String get notificationReadingReminder => 'Leseerinnerung';

  @override
  String get notificationActivity => 'Aktivität';

  @override
  String get notificationWorthRevisiting => 'Erneuten Blick wert';

  @override
  String get notificationRevisitReminder => 'Erinnerung zum Wiederentdecken';

  @override
  String get notificationWeeklyDigest => 'Wochenübersicht';

  @override
  String get enrichmentNeedsAttention =>
      'Anreicherung erfordert Aufmerksamkeit';

  @override
  String get aiDetailsAvailable => 'KI-Details verfügbar';

  @override
  String get enrich => 'Anreichern';

  @override
  String get enriching => 'Wird angereichert';

  @override
  String get messageGlimpse => 'Nachricht an Glimpse…';

  @override
  String get askAboutThisSave => 'Zu dieser Speicherung fragen…';

  @override
  String get sending => 'Wird gesendet…';

  @override
  String get send => 'Senden';

  @override
  String get askGreetingEarlyMorning => 'Schon früh wach?';

  @override
  String get askGreetingMorning => 'Guten Morgen.';

  @override
  String get askGreetingAfternoon => 'Was erkunden wir?';

  @override
  String get askGreetingEvening => 'Guten Abend.';

  @override
  String get askGreetingNight => 'Heute Abend noch neugierig?';

  @override
  String get askGreetingLateNight => 'Wieder lange wach?';

  @override
  String get saveYourFirstLink => 'Speichere deinen ersten Link';

  @override
  String get moreSelectionActions => 'Weitere Auswahlaktionen';

  @override
  String get moveToCollection => 'In Sammlung verschieben';

  @override
  String get markRead => 'Als gelesen markieren';

  @override
  String get markUnread => 'Als ungelesen markieren';

  @override
  String get toggleReadStatus => 'Lesestatus umschalten';

  @override
  String get unpin => 'Lösen';

  @override
  String get yourNote => 'Deine Notiz';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get notePrompt => 'Was ist dir aufgefallen?';

  @override
  String get quickAdd => 'Schnell hinzufügen';

  @override
  String get noteSaving => 'Wird gespeichert…';

  @override
  String get noteSaved => 'Gespeichert';

  @override
  String get noteCouldNotSave => 'Konnte nicht gespeichert werden';

  @override
  String get addYourNote => 'Deine Notiz hinzufügen';

  @override
  String get showLess => 'Weniger anzeigen';

  @override
  String get showMore => 'Mehr anzeigen';

  @override
  String showAllCount(Object count) {
    return 'Alle $count anzeigen';
  }

  @override
  String get answerCopied => 'Antwort kopiert';

  @override
  String get deleteAskNoteQuestion => 'Ask-Notiz löschen?';

  @override
  String get deleteAskNoteDescription =>
      'Dadurch wird die gespeicherte Antwort von diesem Link entfernt. Deine eigene Notiz bleibt unverändert.';

  @override
  String get askNoteDeleted => 'Ask-Notiz gelöscht';

  @override
  String get couldNotDeleteAskNote => 'Ask-Notiz konnte nicht gelöscht werden';

  @override
  String get askNoteActions => 'Aktionen für Ask-Notiz';

  @override
  String get copyAnswer => 'Antwort kopieren';

  @override
  String get quickTryThisWeekend => 'Dieses Wochenende ausprobieren';

  @override
  String get quickNeedIngredients => 'Zutaten benötigt';

  @override
  String get quickShareWithSomeone => 'Mit jemandem teilen';

  @override
  String get quickAlreadyTried => 'Bereits ausprobiert';

  @override
  String get quickWatchLater => 'Später ansehen';

  @override
  String get quickAddToWatchlist => 'Zur Merkliste hinzufügen';

  @override
  String get quickAlreadyWatched => 'Bereits angesehen';

  @override
  String get quickAddToReadingList => 'Zur Leseliste hinzufügen';

  @override
  String get quickReadLater => 'Später lesen';

  @override
  String get quickResearchThis => 'Dazu recherchieren';

  @override
  String get quickAlreadyRead => 'Bereits gelesen';

  @override
  String get quickTryThisTool => 'Dieses Tool ausprobieren';

  @override
  String get quickCompareAlternatives => 'Alternativen vergleichen';

  @override
  String get quickUseInProject => 'Im Projekt verwenden';

  @override
  String get quickShareWithTeam => 'Mit dem Team teilen';

  @override
  String get quickPlanItinerary => 'Reiseplan erstellen';

  @override
  String get quickCheckBestSeason => 'Beste Reisezeit prüfen';

  @override
  String get quickSaveRoute => 'Route speichern';

  @override
  String get quickPracticeLater => 'Später üben';

  @override
  String get quickMakeChecklist => 'Checkliste erstellen';

  @override
  String get quickRevisitNotes => 'Notizen erneut ansehen';

  @override
  String get quickRevisitLater => 'Später erneut ansehen';

  @override
  String get quickWorthTrying => 'Einen Versuch wert';

  @override
  String get quickAlreadyChecked => 'Bereits geprüft';

  @override
  String get aboutTagline => 'Speichere, was es wert ist, bewahrt zu werden';

  @override
  String versionBuild(Object build, Object version) {
    return 'Version $version (Build $build)';
  }

  @override
  String get loadingVersion => 'Version wird geladen…';

  @override
  String get legal => 'Rechtliches';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get help => 'Hilfe';

  @override
  String get faq => 'FAQ';

  @override
  String get sendFeedback => 'Feedback senden';

  @override
  String get rateOnPlayStore => 'Im Play Store bewerten';

  @override
  String get shareGlimpse => 'Glimpse teilen';

  @override
  String get feedbackEmailSubject => 'Feedback zu Glimpse';

  @override
  String shareGlimpseText(Object url) {
    return 'Glimpse hilft dir, Links zu speichern, zu denen du zurückkehren möchtest. Probiere es aus: $url';
  }

  @override
  String get couldNotOpenLink => 'Dieser Link konnte nicht geöffnet werden.';

  @override
  String get couldNotShareGlimpse => 'Glimpse konnte nicht geteilt werden.';

  @override
  String get keepsakeQuoteCuriosity =>
      'Bewahre die Dinge, die deine Neugier wecken.';

  @override
  String get keepsakeQuoteIdea =>
      'Ein kleiner Einblick kann zu einer bleibenden Idee werden.';

  @override
  String get keepsakeQuoteSpark =>
      'Bewahre den Funken. Kehre zurück, wenn es zählt.';

  @override
  String get keepsakeQuoteFutureSelf =>
      'Dein zukünftiges Ich könnte danach suchen.';

  @override
  String get keepsakeQuoteNoticing => 'Bemerkenswert. Bewahrenswert.';

  @override
  String get other => 'Sonstiges';

  @override
  String get shareBackup => 'Sicherung teilen';

  @override
  String get shareBackupDescription =>
      'Sicherung an eine andere App oder einen Cloud-Dienst senden';

  @override
  String backupSavedLinksTo(num count, Object location) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Links',
      one: '1 Link',
    );
    return '$_temp0 unter $location gespeichert';
  }

  @override
  String backupSavedTo(Object location) {
    return 'Sicherung unter $location gespeichert';
  }

  @override
  String get errorDetails => 'Fehlerdetails';

  @override
  String get copy => 'Kopieren';

  @override
  String get couldNotReadSelectedFile =>
      'Die ausgewählte Datei konnte nicht gelesen werden.';

  @override
  String get folderSelected => 'Ordner ausgewählt';

  @override
  String get couldNotSaveFolderPermission =>
      'Ordnerberechtigung konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get permanentBackupFolderAndroid =>
      'Ein dauerhafter Sicherungsordner ist unter Android verfügbar';

  @override
  String get tapToChange => 'Zum Ändern tippen';

  @override
  String get forgetFolder => 'Ordner vergessen';

  @override
  String get autoBackupAndroidOnly =>
      'Automatische Sicherung läuft unter Android, wenn ein Speicherordner festgelegt ist';

  @override
  String lastAutomaticBackup(Object time) {
    return 'Letzte automatische Sicherung: $time';
  }

  @override
  String lastBackupAttemptFailed(Object time) {
    return 'Letzter Versuch fehlgeschlagen: $time. Glimpse versucht es automatisch erneut.';
  }

  @override
  String get setStorageBeforeAutoBackup =>
      'Lege oben einen Speicherort fest, bevor automatische Sicherungen ausgeführt werden können.';

  @override
  String get folderBackup => 'Ordnersicherung';

  @override
  String lastSavedToFolder(Object time) {
    return 'Zuletzt im Ordner gespeichert: $time';
  }

  @override
  String get noBackupFileInFolder =>
      'Noch keine Sicherungsdatei in diesem Ordner. Wähle zuerst diesen Ort und tippe dann oben auf „Sicherung erstellen“.';
}
