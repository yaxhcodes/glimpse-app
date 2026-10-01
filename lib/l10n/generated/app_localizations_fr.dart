// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get yourSaves => 'Vos liens enregistrés';

  @override
  String get savesLastSevenDays => '7 derniers jours';

  @override
  String get savesLastThirtyDays => '30 derniers jours';

  @override
  String get savesEarlier => 'Plus anciens';

  @override
  String get readerAskAbout => 'Poser une question sur ce contenu';

  @override
  String get readerEnrichingTitle => 'Votre Glimpse prend forme.';

  @override
  String get readerEnrichingBody =>
      'Déjà enregistré. Nous rassemblons les informations utiles.';

  @override
  String get musicDetailsUnavailable =>
      'Les détails de certaines chansons n’ont pas pu être chargés.';

  @override
  String get loadingMusicDetails => 'Chargement des détails des chansons…';

  @override
  String get couldNotSaveMusicProvider =>
      'Impossible d’enregistrer votre appli de musique. Réessayez.';

  @override
  String get libraryMusicEmptyDescription =>
      'Les titres et artistes trouvés dans vos liens enregistrés apparaîtront ici.';

  @override
  String get libraryMusicDescription =>
      'Titres et artistes de vos enregistrements';

  @override
  String get libraryMusicSongs => 'Titres';

  @override
  String get libraryMusicArtists => 'Artistes';

  @override
  String libraryArtistMentions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mentionné dans $count enregistrements',
      one: 'Mentionné dans 1 enregistrement',
    );
    return '$_temp0';
  }

  @override
  String get libraryMusic => 'Musique';

  @override
  String get appName => 'Glimpse';

  @override
  String get home => 'Accueil';

  @override
  String get collections => 'Collections';

  @override
  String get interests => 'Centres d’intérêt';

  @override
  String get search => 'Recherche';

  @override
  String get askGlimpse => 'Demander à Glimpse';

  @override
  String get settings => 'Réglages';

  @override
  String get accountAndPlan => 'Compte et forfait';

  @override
  String get personalization => 'Personnalisation';

  @override
  String get lookAndFeel => 'Apparence';

  @override
  String get themeAndAccent => 'Thème et couleur d’accentuation';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageJapanese => 'Japonais';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageFrench => 'Français';

  @override
  String get languagePortugueseBrazil => 'Portugais (Brésil)';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get chooseLanguage => 'Choisir la langue';

  @override
  String get musicApp => 'Application musicale';

  @override
  String get chooseWhereSongsOpen => 'Choisissez où ouvrir les morceaux';

  @override
  String get loadingPreference => 'Chargement du réglage';

  @override
  String get libraryGestures => 'Actions de balayage';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacyAndData => 'Confidentialité et données';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get privacySubtitle => 'Ce qui reste local et ce qui est envoyé';

  @override
  String get dataAndBackup => 'Données et sauvegarde';

  @override
  String get dataAndBackupSubtitle =>
      'Protégez et restaurez vos éléments enregistrés';

  @override
  String get bin => 'Corbeille';

  @override
  String get binSubtitle =>
      'Les éléments supprimés sont conservés pendant 30 jours';

  @override
  String get clearAllData => 'Effacer toutes les données';

  @override
  String get clearAllDataSubtitle =>
      'Supprimer définitivement tous les liens enregistrés';

  @override
  String get about => 'À propos';

  @override
  String get aboutGlimpse => 'À propos de Glimpse';

  @override
  String get aboutSubtitle => 'Version, mentions légales et aide';

  @override
  String get accountActions => 'Actions du compte';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get logOutSubtitle => 'Se déconnecter de cet appareil';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountSubtitle => 'Demander la suppression du compte';

  @override
  String get deletingAccount => 'Suppression de votre compte…';

  @override
  String get cancel => 'Annuler';

  @override
  String get deleteAll => 'Tout supprimer';

  @override
  String get clearAllDataQuestion => 'Effacer toutes les données ?';

  @override
  String get clearAllDataWarning =>
      'Toutes les URL enregistrées seront définitivement supprimées. Cette action est irréversible.';

  @override
  String get allDataCleared => 'Toutes les données ont été effacées';

  @override
  String get logOutQuestion => 'Se déconnecter ?';

  @override
  String get logOutWarning =>
      'Vous devrez vous reconnecter pour accéder à votre compte Glimpse.';

  @override
  String get deleteAccountQuestion => 'Supprimer le compte ?';

  @override
  String get manageSubscription => 'Gérer l’abonnement';

  @override
  String get accountDeleted => 'Compte supprimé';

  @override
  String get manageYourPlan => 'Gérer votre forfait';

  @override
  String get checkingSaveAllowance =>
      'Vérification des enregistrements disponibles';

  @override
  String aiSavesLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il reste $count enregistrements IA gratuits',
      one: 'Il reste 1 enregistrement IA gratuit',
    );
    return '$_temp0';
  }

  @override
  String get captureCouldNotSave => 'Impossible d’enregistrer ce lien';

  @override
  String savedToCollection(String collectionName) {
    return 'Enregistré dans $collectionName';
  }

  @override
  String get savedWithoutAi => 'Enregistré sans analyse IA';

  @override
  String get aiLimitBody =>
      'Vous avez utilisé vos 30 enregistrements IA gratuits à vie. Touchez pour changer de forfait.';

  @override
  String get proAiLimitBody =>
      'Vous avez utilisé 500 enregistrements IA ce mois-ci. Le lien a été enregistré sans analyse IA.';

  @override
  String get alreadyInYourWorld => 'Déjà présent dans vos éléments.';

  @override
  String get enrichmentFailed => 'Impossible de terminer l’analyse';

  @override
  String get tapToRetry => 'Touchez pour réessayer.';

  @override
  String get notification => 'Notification';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get retry => 'Réessayer';

  @override
  String get close => 'Fermer';

  @override
  String get addUrl => 'Ajouter une URL';

  @override
  String get newCollection => 'Nouvelle collection';

  @override
  String get captured => 'Enregistré';

  @override
  String get undo => 'Annuler';

  @override
  String get alreadyInGlimpse => 'Déjà dans Glimpse';

  @override
  String get open => 'Ouvrir';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get exitSelection => 'Quitter la sélection';

  @override
  String get sources => 'Sources';

  @override
  String get viewAllSources => 'Voir toutes les sources';

  @override
  String get pasteLink => 'Coller un lien…';

  @override
  String get dismissClipboardSuggestion =>
      'Fermer la suggestion du presse-papiers';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get editCollection => 'Modifier la collection';

  @override
  String get moveContents => 'Déplacer le contenu';

  @override
  String get deleteSelectedCollections =>
      'Supprimer les collections sélectionnées';

  @override
  String get delete => 'Supprimer';

  @override
  String get collectionOptions => 'Options de la collection';

  @override
  String get grid => 'Grille';

  @override
  String get list => 'Liste';

  @override
  String get manual => 'Manuel';

  @override
  String get newest => 'Plus récentes';

  @override
  String get alphabetical => 'A–Z';

  @override
  String get reorder => 'Réorganiser';

  @override
  String get upgradeToPro => 'Passer à Pro';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get applyFilters => 'Appliquer les filtres';

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String get capture => 'Enregistrer';

  @override
  String get capturing => 'Enregistrement…';

  @override
  String get pasteFromClipboard => 'Coller depuis le presse-papiers';

  @override
  String get addToCollection => 'Ajouter à une collection';

  @override
  String get more => 'Plus';

  @override
  String get notes => 'Notes';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryBusiness => 'Économie';

  @override
  String get categoryFinance => 'Finance';

  @override
  String get categoryScience => 'Science';

  @override
  String get categoryHealth => 'Santé';

  @override
  String get categoryEducation => 'Éducation';

  @override
  String get categoryNews => 'Actualités';

  @override
  String get categoryDesign => 'Design';

  @override
  String get categoryHistory => 'Histoire';

  @override
  String get categoryPhilosophy => 'Philosophie';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryFood => 'Cuisine';

  @override
  String get categoryTravel => 'Voyage';

  @override
  String get categoryEntertainment => 'Divertissement';

  @override
  String get categoryLifestyle => 'Art de vivre';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryOther => 'Autre';

  @override
  String minutesAgo(Object count) {
    return 'il y a $count min';
  }

  @override
  String hoursAgo(Object count) {
    return 'il y a $count h';
  }

  @override
  String daysAgo(Object count) {
    return 'il y a $count j';
  }

  @override
  String get smartNotificationsDescription =>
      'Notifications intelligentes sur vos liens enregistrés';

  @override
  String get done => 'Terminé';

  @override
  String get later => 'Plus tard';

  @override
  String get notificationFallbackTitle => 'Notification';

  @override
  String newNotificationCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles notifications',
      one: '1 nouvelle notification',
    );
    return '$_temp0';
  }

  @override
  String get captureSomethingWorthReturning =>
      'Enregistrez quelque chose à retrouver plus tard';

  @override
  String get captureContextAfter =>
      'Glimpse retrouvera le contexte après l’enregistrement.';

  @override
  String get link => 'Lien';

  @override
  String get detectedFromClipboard => 'Détecté dans le presse-papiers';

  @override
  String get collection => 'Collection';

  @override
  String get noCollection => 'Aucune collection';

  @override
  String get chooseCollection => 'Choisir une collection';

  @override
  String get searchCollections => 'Rechercher des collections';

  @override
  String get noCollectionsMatch => 'Aucune collection ne correspond';

  @override
  String get chooseACollection => 'Choisissez une collection';

  @override
  String get processingLink => 'Traitement du lien…';

  @override
  String get couldNotLoadCollections =>
      'Impossible de charger les collections.';

  @override
  String get couldNotLoadLibrary => 'Impossible de charger votre bibliothèque.';

  @override
  String linkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liens',
      one: '1 lien',
      zero: 'Aucun lien',
    );
    return '$_temp0';
  }

  @override
  String get noteOptional => 'Note (facultative)';

  @override
  String get addNoteOptional => 'Ajouter une note (facultative)';

  @override
  String get pleaseEnterUrl => 'Saisissez une URL';

  @override
  String get couldNotCaptureLink => 'Impossible d’enregistrer ce lien';

  @override
  String get findingSavedVersion => 'Recherche de la version enregistrée…';

  @override
  String get openSavedItem => 'Ouvrir l’élément enregistré';

  @override
  String collectionSelection(String collectionName) {
    return 'Collection, $collectionName';
  }

  @override
  String get capturedInGlimpse => 'Enregistré dans Glimpse';

  @override
  String get firstCapturedReady =>
      'Votre premier élément enregistré est prêt ci-dessous.';

  @override
  String get shareAnyApp =>
      'Partagez depuis n’importe quelle app, Glimpse l’organise pour vous.';

  @override
  String get howGlimpseWorks => 'Comment fonctionne Glimpse';

  @override
  String get capturingWhatCaughtYourEye =>
      'Enregistrement de ce qui vous a marqué';

  @override
  String get findingContext => 'Recherche du contexte';

  @override
  String get invalidLink => 'Lien non valide';

  @override
  String get rediscover => 'Redécouvrir';

  @override
  String get rediscoverSubtitle => 'À reprendre là où vous l’aviez laissé';

  @override
  String get rediscoverTip =>
      'Chaque jour, Redécouvrir choisit quelques souvenirs qui méritent votre attention.';

  @override
  String get dismissRediscoverTip => 'Fermer l’astuce Redécouvrir';

  @override
  String get gotIt => 'Compris';

  @override
  String get pinned => 'Épinglés';

  @override
  String get recentSaves => 'Enregistrements récents';

  @override
  String get justNow => 'à l’instant';

  @override
  String weeksAgo(Object count) {
    return 'il y a $count sem';
  }

  @override
  String monthsAgo(Object count) {
    return 'il y a $count mois';
  }

  @override
  String yearsAgo(Object count) {
    return 'il y a $count an(s)';
  }

  @override
  String get retrying => 'Nouvelle tentative';

  @override
  String get processing => 'Traitement';

  @override
  String get processingSavedHeadline => 'Préparation en cours';

  @override
  String get processingSavedDetail => 'Préparation de votre enregistrement';

  @override
  String get processingOpeningHeadline => 'Ouverture du contenu';

  @override
  String get processingOpeningDetail => 'Vérification du contenu enregistré';

  @override
  String processingReadingHeadline(String content) {
    return 'Lecture de $content';
  }

  @override
  String get processingExtractingDetail => 'Extraction des détails utiles';

  @override
  String get processingUnderstoodHeadline => 'Contenu compris';

  @override
  String get processingUnderstoodDetail => 'Transformation en contenu utile';

  @override
  String get processingFindingHeadline => 'Recherche de l’essentiel';

  @override
  String get processingFindingDetail =>
      'Recherche des idées les plus importantes';

  @override
  String get processingConnectingHeadline => 'Création de liens';

  @override
  String get processingConnectingDetail =>
      'Connexion aux enregistrements associés';

  @override
  String get processingFinishingHeadline => 'Finalisation de l’enregistrement';

  @override
  String get processingFinishingDetail =>
      'Préparation de la recherche et de la redécouverte';

  @override
  String get processingRetryHeadline => 'Nouvel essai de cette étape';

  @override
  String get processingRetryDetail => 'Nouvelle tentative de cette étape';

  @override
  String get processingFailedHeadline => 'Impossible de terminer le traitement';

  @override
  String get processingFailedDetail =>
      'Votre enregistrement est sûr. Réessayez';

  @override
  String get processingFailedShort => 'Inachevé';

  @override
  String get processingDefaultHeadline => 'Analyse de cet enregistrement';

  @override
  String get processingDefaultDetail => 'Recherche des idées à conserver';

  @override
  String get processingContentReel => 'reel';

  @override
  String get processingContentVideo => 'vidéo';

  @override
  String get processingContentPin => 'épingle';

  @override
  String get processingContentPage => 'page';

  @override
  String get needsAttention => 'Attention requise';

  @override
  String get read => 'Lu';

  @override
  String get unread => 'Non lu';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get linkCopied => 'Lien copié';

  @override
  String get openOriginal => 'Ouvrir l’original';

  @override
  String get share => 'Partager';

  @override
  String get enrichmentComplete => 'Traitement terminé';

  @override
  String get couldNotEnrichSave => 'Impossible de traiter cet élément';

  @override
  String get allSources => 'Toutes les sources';

  @override
  String get all => 'Tout';

  @override
  String get apps => 'Applications';

  @override
  String get websites => 'Sites web';

  @override
  String get results => 'Résultats';

  @override
  String get topSources => 'Sources principales';

  @override
  String get searchSources => 'Rechercher des apps, sites et domaines…';

  @override
  String get filterSources => 'Filtrer les sources';

  @override
  String get couldNotLoadSources => 'Impossible de charger les sources';

  @override
  String noSourcesMatch(String query) {
    return 'Aucune source ne correspond à « $query »';
  }

  @override
  String get noSavesFromApps =>
      'Aucun enregistrement depuis une app pour le moment';

  @override
  String get noWebsiteSaves =>
      'Aucun enregistrement depuis un site pour le moment';

  @override
  String get noSourcesYet => 'Aucune source pour le moment';

  @override
  String get noSavesYet => 'Aucun enregistrement pour le moment';

  @override
  String saveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements',
      one: '1 enregistrement',
    );
    return '$_temp0';
  }

  @override
  String savesThisWeek(Object count) {
    return '+$count cette semaine';
  }

  @override
  String get growing => 'En hausse';

  @override
  String lastSaved(String time) {
    return 'Dernier enregistrement $time';
  }

  @override
  String get leftSwipe => 'Balayage vers la gauche';

  @override
  String get rightSwipe => 'Balayage vers la droite';

  @override
  String get chooseSwipeAction => 'Choisir l’action de balayage';

  @override
  String get markReadUnread => 'Marquer comme lu/non lu';

  @override
  String get pin => 'Épingler';

  @override
  String get none => 'Aucune';

  @override
  String get smartNotifications => 'Notifications intelligentes';

  @override
  String get behaviorBasedAlerts => 'Alertes adaptées à votre activité';

  @override
  String get whereDoYouListen => 'Où écoutez-vous votre musique ?';

  @override
  String get chooseMusicProvider =>
      'Choisissez l’app utilisée par Glimpse pour les morceaux trouvés.';

  @override
  String get brightness => 'Luminosité';

  @override
  String get brightnessDescription =>
      'Choisissez quand utiliser des couleurs claires ou sombres.';

  @override
  String get systemTheme => 'Système';

  @override
  String get lightTheme => 'Clair';

  @override
  String get darkTheme => 'Sombre';

  @override
  String get amoledBlack => 'Noir AMOLED';

  @override
  String get amoledUnavailable =>
      'Disponible lorsque le thème clair n’est pas utilisé.';

  @override
  String get amoledDescription =>
      'Des arrière-plans noirs purs sur OLED pour économiser l’énergie.';

  @override
  String get accentColor => 'Couleur d’accent';

  @override
  String get dynamicAccentDescription =>
      'Dynamique utilise la palette de votre fond d’écran sur les appareils compatibles.';

  @override
  String selectedAccent(String accent) {
    return 'Sélection : $accent';
  }

  @override
  String get themePreview => 'Aperçu du thème';

  @override
  String get themePreviewDescription =>
      'L’accent et les surfaces changent selon vos choix ci-dessous.';

  @override
  String get accentDynamic => 'Dynamique';

  @override
  String get accentPurple => 'Violet';

  @override
  String get accentBlue => 'Bleu';

  @override
  String get accentTeal => 'Sarcelle';

  @override
  String get accentGreen => 'Vert';

  @override
  String get accentLime => 'Citron vert';

  @override
  String get accentYellow => 'Jaune';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRed => 'Rouge';

  @override
  String get accentPink => 'Rose';

  @override
  String get accentSakura => 'Sakura';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentSlate => 'Ardoise';

  @override
  String get accentMonochrome => 'Monochrome';

  @override
  String get deleted => 'Supprimé';

  @override
  String get noNotificationsYet => 'Aucune notification pour le moment';

  @override
  String get notificationsEmptyDescription =>
      'Les alertes de voyage, nouvelles découvertes, rappels de lecture et résumés hebdomadaires apparaîtront ici.';

  @override
  String get ready => 'prêt';

  @override
  String waitingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non ouverts',
      one: '1 non ouvert',
    );
    return '$_temp0';
  }

  @override
  String get backInView => 'Vous y revenez';

  @override
  String get couldNotLoadSource => 'Impossible de charger cette source';

  @override
  String get noSavesFromSource => 'Aucun enregistrement de cette source';

  @override
  String get saves => 'Enregistrements';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get opened => 'Ouverts';

  @override
  String get topThemes => 'Thèmes principaux';

  @override
  String get allItems => 'Tous les éléments';

  @override
  String get oldest => 'Plus anciens';

  @override
  String get recentlyOpened => 'Ouverts récemment';

  @override
  String get showItems => 'Afficher les éléments';

  @override
  String get sortBy => 'Trier par';

  @override
  String get noItemsFromSource => 'Aucun élément de cette source';

  @override
  String get noUnreadItems => 'Aucun élément non lu';

  @override
  String get noReadItems => 'Aucun élément lu';

  @override
  String get lastSavedLabel => 'Dernier enregistrement';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get back => 'Retour';

  @override
  String get subscription => 'Abonnement';

  @override
  String get couldNotLoadSubscription =>
      'Impossible de charger les informations d’abonnement';

  @override
  String get coreLibrary => 'Bibliothèque principale';

  @override
  String get unlimitedLinkSaving => 'Enregistrement illimité de liens';

  @override
  String get unlimitedLinkSavingDescription =>
      'Enregistrez autant de liens que vous le souhaitez';

  @override
  String get collectionsOrganization => 'Collections et organisation';

  @override
  String get collectionsOrganizationDescription =>
      'Regroupez et organisez vos favoris à votre façon';

  @override
  String get smartNotificationsLongDescription =>
      'Alertes selon vos habitudes et rappels de lecture';

  @override
  String get aiAssistant => 'Assistant IA';

  @override
  String get aiTaggingCategorization => 'Étiquetage et classement par IA';

  @override
  String get freeSavesProUnlimited => 'Gratuit : 30 IA à vie · Pro : 500/mois';

  @override
  String get keywordSearch => 'Recherche par mots-clés';

  @override
  String get freeSearchesProUnlimited =>
      'Gratuit : 30 recherches/mois · Pro : accès étendu';

  @override
  String get askYourBookmarks => 'Interroger vos favoris';

  @override
  String get freeQuestionsProUnlimited =>
      'Gratuit : 30 questions/mois · Pro : usage raisonnable généreux';

  @override
  String get proInsights => 'Analyses Pro';

  @override
  String get semanticSearch => 'Recherche sémantique';

  @override
  String get semanticSearchDescription =>
      'Trouvez des liens par leur sens, pas seulement par leurs mots';

  @override
  String get weeklyRecap => 'Récapitulatif hebdomadaire';

  @override
  String get weeklyRecapDescription =>
      'Résumé de vos liens enregistrés généré par IA';

  @override
  String get multiLinkSynthesis => 'Synthèse de plusieurs liens';

  @override
  String get multiLinkSynthesisDescription =>
      'Analysez ensemble n’importe quel groupe de favoris';

  @override
  String get active => 'Actif';

  @override
  String get free => 'Gratuit';

  @override
  String get proPlanDescription =>
      '500 enregistrements IA par mois, avec un accès étendu à Ask et à la recherche.';

  @override
  String get proPlanDevDescription =>
      '500 enregistrements IA par mois, avec un accès étendu à Ask et à la recherche. (forçage développeur ; boutique : Gratuit)';

  @override
  String get freePlanDescription =>
      'Enregistrez des liens sans limite et essayez l’IA avec 30 enrichissements gratuits à vie.';

  @override
  String get upgradeToGlimpsePro => 'Passer à Glimpse Pro';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get manageOnGooglePlay => 'Gérer sur Google Play';

  @override
  String get local => 'Local';

  @override
  String get uploaded => 'Téléversé';

  @override
  String get bookmarks => 'Favoris';

  @override
  String get aiSummaries => 'Résumés par IA';

  @override
  String get accountInformation => 'Informations du compte';

  @override
  String get subscriptionStatus => 'État de l’abonnement';

  @override
  String get anonymousProductAnalytics => 'Données d’utilisation anonymes';

  @override
  String get storageLocation => 'Emplacement de stockage';

  @override
  String get pickAFolder => 'Choisir un dossier';

  @override
  String get chooseBackupFolderDescription =>
      'Touchez pour choisir où stocker les sauvegardes';

  @override
  String get backupFolderInfo =>
      'Cet emplacement sert à enregistrer vos fichiers de sauvegarde. Choisissez un dossier une fois et Glimpse continuera d’y écrire les nouvelles sauvegardes.';

  @override
  String get automaticBackup => 'Sauvegarde automatique';

  @override
  String get off => 'Désactivée';

  @override
  String get backupFrequencyDescription =>
      'Fréquence d’enregistrement dans votre emplacement de stockage';

  @override
  String get backupSensitiveInfo =>
      'Conservez aussi des copies ailleurs. Les sauvegardes peuvent contenir toute votre bibliothèque ; traitez-les comme des données sensibles si vous partagez les fichiers.';

  @override
  String get backupAndRestore => 'Sauvegarde et restauration';

  @override
  String get createBackup => 'Créer une sauvegarde';

  @override
  String get restoreBackup => 'Restaurer une sauvegarde';

  @override
  String lastBackup(Object time) {
    return 'Dernière sauvegarde : $time';
  }

  @override
  String get noBackupsYet => 'Aucune sauvegarde pour l’instant';

  @override
  String get backupLocalInfo =>
      'Les sauvegardes contiennent toute votre bibliothèque : liens, collections, étiquettes et métadonnées. Elles restent sur votre appareil.';

  @override
  String get deletedItemsRetention =>
      'Les éléments supprimés sont conservés pendant 30 jours, puis effacés définitivement lors du prochain nettoyage de Glimpse.';

  @override
  String daysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count jours',
      one: 'Encore 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get expiresToday => 'Expire aujourd’hui';

  @override
  String get restore => 'Restaurer';

  @override
  String get deletePermanently => 'Supprimer définitivement';

  @override
  String get restoreAll => 'Tout restaurer';

  @override
  String get emptyBin => 'Vider la corbeille';

  @override
  String get binActions => 'Actions de la corbeille';

  @override
  String get itemActions => 'Actions de l’élément';

  @override
  String get binIsEmpty => 'La corbeille est vide';

  @override
  String get binEmptyDescription =>
      'Les éléments supprimés apparaîtront ici pendant 30 jours.';

  @override
  String get deleteAccountProWarning =>
      'Cette action supprime les métadonnées de votre compte Glimpse, mais n’annule pas la facturation de la boutique. Pro ne peut pas être transféré vers un autre compte Glimpse ; gérez votre abonnement avant la suppression. Votre bibliothèque sur l’appareil n’est pas téléversée vers Supabase.';

  @override
  String get deleteAccountFreeWarning =>
      'Cette action supprime les métadonnées de votre compte Glimpse. Votre bibliothèque sur l’appareil n’est pas téléversée vers Supabase.';

  @override
  String get details => 'Détails';

  @override
  String openInSource(Object source) {
    return 'Ouvrir dans $source';
  }

  @override
  String openSourcePage(Object source) {
    return 'Voir tout ce qui vient de $source';
  }

  @override
  String get summary => 'Résumé';

  @override
  String get inBrief => 'En bref';

  @override
  String get fullExplanation => 'Explication complète';

  @override
  String get resourcesAndReferences => 'Ressources et références';

  @override
  String get searchForResource => 'Rechercher cette ressource';

  @override
  String get rawSourceMaterial => 'Contenu source brut';

  @override
  String get addNote => 'Ajouter une note';

  @override
  String get keyTakeaways => 'Points clés';

  @override
  String get fullBreakdown => 'Analyse détaillée';

  @override
  String get transcriptAndCaption => 'Transcription et légende';

  @override
  String get caption => 'Légende';

  @override
  String get transcript => 'Transcription';

  @override
  String get onScreenText => 'Texte à l’écran';

  @override
  String get peopleMentioned => 'Personnes mentionnées';

  @override
  String peopleMentionedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes mentionnées',
      one: '1 personne mentionnée',
    );
    return '$_temp0';
  }

  @override
  String get alsoMentioned => 'Également mentionné';

  @override
  String get quotes => 'Citations';

  @override
  String get tags => 'Étiquettes';

  @override
  String get informationMayBeInaccurate =>
      'Les informations peuvent être inexactes';

  @override
  String get originalContentAttribution =>
      'Le contenu original appartient à son créateur.';

  @override
  String everyHours(Object count) {
    return 'Toutes les $count heures';
  }

  @override
  String get weekly => 'Chaque semaine';

  @override
  String get addTag => 'Ajouter une étiquette';

  @override
  String get changeCategory => 'Changer de catégorie';

  @override
  String get worthWatching => 'À regarder';

  @override
  String get worthReading => 'À lire';

  @override
  String get gamesMentioned => 'Jeux mentionnés';

  @override
  String get musicMentioned => 'Musique mentionnée';

  @override
  String get toolsMentioned => 'Outils mentionnés';

  @override
  String get worthALook => 'À découvrir';

  @override
  String get appsToTry => 'Apps à essayer';

  @override
  String get placesToVisit => 'Lieux à visiter';

  @override
  String get websitesMentioned => 'Sites web mentionnés';

  @override
  String get claimsToRemember => 'Affirmations à retenir';

  @override
  String get termsMentioned => 'Termes mentionnés';

  @override
  String get notableDetails => 'Détails notables';

  @override
  String get library => 'Bibliothèque';

  @override
  String get libraryDescription =>
      'Livres, films, lieux et musique trouvés dans vos liens enregistrés';

  @override
  String get buildsQuietly => 'S’enrichit au fil de vos sauvegardes';

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String addedTime(Object time) {
    return 'Ajouté · $time';
  }

  @override
  String get rediscoverIntentTitle => 'Quelques souvenirs à retrouver';

  @override
  String chosenFromUnopened(Object count) {
    return 'Choisis parmi $count sauvegardes non ouvertes et ce qui compte maintenant.';
  }

  @override
  String get chosenFromSaved =>
      'Choisis parmi vos contenus sauvegardés, ouverts ou gardés pour plus tard.';

  @override
  String get todayStableSet =>
      'Une sélection stable pour aujourd’hui, sans fil infini.';

  @override
  String get recaps => 'Récapitulatifs';

  @override
  String get recapsDescription =>
      'Tendances hebdomadaires et mensuelles de vos sauvegardes.';

  @override
  String get dailyRecap => 'Récapitulatif quotidien';

  @override
  String get monthlyRecap => 'Récapitulatif mensuel';

  @override
  String recapSummary(num count, Object waiting) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sauvegardes',
      one: '1 sauvegarde',
    );
    return '$_temp0 · $waiting non ouvertes';
  }

  @override
  String get yourWeekInSaves => 'Votre semaine en sauvegardes';

  @override
  String get yourMonthInMemories => 'Votre mois en souvenirs';

  @override
  String topicKeptShowingUp(Object topic) {
    return '$topic revenait souvent';
  }

  @override
  String get queued => 'En attente';

  @override
  String get forgottenGem => 'Trésor oublié';

  @override
  String get fromYourPast => 'De votre passé';

  @override
  String get rediscoverOptions => 'Options de redécouverte';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get hideFor7Days => 'Masquer pendant 7 jours';

  @override
  String get lessLikeThis => 'Moins de contenus similaires';

  @override
  String get reduceSimilarTopics => 'Réduire les thèmes similaires';

  @override
  String get nothingStrongToday => 'Rien d’assez pertinent aujourd’hui';

  @override
  String get rediscoverQuiet =>
      'Redécouvrir restera discret jusqu’à ce qu’une sauvegarde mérite vraiment de revenir.';

  @override
  String get searchYourLibrary => 'Rechercher dans votre bibliothèque…';

  @override
  String get findAnythingSaved => 'Retrouvez tout ce que vous avez sauvegardé';

  @override
  String get searchEmptyDescription =>
      'Recherchez dans les titres, tags, notes et résumés, puis affinez les résultats.';

  @override
  String get filters => 'Filtres';

  @override
  String get filtersActive => 'Filtres actifs';

  @override
  String get time => 'Période';

  @override
  String get allTime => 'Depuis toujours';

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get status => 'Statut';

  @override
  String get hasNotes => 'Avec des notes';

  @override
  String get noNotes => 'Sans notes';

  @override
  String get inCollection => 'Dans une collection';

  @override
  String get notInCollection => 'Hors collection';

  @override
  String get specificCollection => 'Collection précise';

  @override
  String get sort => 'Trier';

  @override
  String get relevance => 'Pertinence';

  @override
  String get newestSaved => 'Sauvegardes récentes';

  @override
  String get oldestSaved => 'Sauvegardes anciennes';

  @override
  String get learningInterests =>
      'Découverte de ce qui retient votre attention';

  @override
  String get readingInterests => 'Analyse de vos centres d’intérêt…';

  @override
  String get topSignal => 'Intérêt principal';

  @override
  String get growingInterests => 'Intérêts émergents';

  @override
  String get quieterInterests => 'Autres intérêts';

  @override
  String interestStats(num patterns, num saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns tendances',
      one: '1 tendance',
    );
    String _temp1 = intl.Intl.pluralLogic(
      saves,
      locale: localeName,
      other: '$saves sauvegardes',
      one: '1 sauvegarde',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String noPatternsScanned(Object saves) {
    return 'Aucune tendance pour le moment · $saves sauvegardes analysées';
  }

  @override
  String get rebuildMap => 'Reconstruire la carte';

  @override
  String get couldNotBuildClusters => 'Impossible de créer les groupes';

  @override
  String get interestMapEmpty => 'Votre carte d’intérêts est vide';

  @override
  String get interestMapEmptyDescription =>
      'Sauvegardez au moins 3 liens et Glimpse reliera les thèmes récurrents.';

  @override
  String lastAddedTime(Object time) {
    return 'Dernier ajout : $time';
  }

  @override
  String get hiddenFor7Days => 'Masqué pendant 7 jours';

  @override
  String get seeLessLikeThis => 'Vous verrez moins de contenus similaires';

  @override
  String get searchingLibrary => 'Recherche dans votre bibliothèque…';

  @override
  String get semanticMatch => 'Correspondance sémantique';

  @override
  String get noMatchesForFilter => 'Aucun résultat pour ce filtre';

  @override
  String get broadenSearch =>
      'Essayez une autre période ou élargissez votre recherche.';

  @override
  String get monthlyLimitReached => 'Limite mensuelle atteinte';

  @override
  String get searchFailed => 'Échec de la recherche';

  @override
  String get monthlySearchLimitDescription =>
      'Vous avez atteint votre limite mensuelle de recherches. Passez à Glimpse Pro pour un accès étendu.';

  @override
  String get openingInterest => 'Ouverture de l’intérêt…';

  @override
  String get couldNotOpenInterest => 'Impossible d’ouvrir cet intérêt.';

  @override
  String get interestNotFound => 'Intérêt introuvable';

  @override
  String interestSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sauvegardes dans cet intérêt.',
      one: '1 sauvegarde dans cet intérêt.',
    );
    return '$_temp0';
  }

  @override
  String interestTopicsSummary(Object count, Object topics) {
    return '$count sauvegardes réparties sur $topics thèmes';
  }

  @override
  String get reorderCollections => 'Réorganiser les collections';

  @override
  String get dragToSetManualOrder =>
      'Faites glisser pour définir l’ordre manuel';

  @override
  String movedToCollection(Object name) {
    return 'Déplacé vers $name';
  }

  @override
  String movedLinksAndDeletedSources(num count, Object name, num sourceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liens déplacés',
      one: '1 lien déplacé',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sourceCount,
      locale: localeName,
      other: 'collections sources supprimées',
      one: 'collection source supprimée',
    );
    return '$_temp0 vers $name et $_temp1';
  }

  @override
  String deleteCollectionNamed(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String deleteCollectionsCount(Object count) {
    return 'Supprimer $count collections ?';
  }

  @override
  String get deleteCollectionDescription =>
      'Les liens sauvegardés resteront dans votre bibliothèque. Seule la collection sera supprimée.';

  @override
  String get deleteCollectionsDescription =>
      'Les liens sauvegardés resteront dans votre bibliothèque. Seules les collections seront supprimées.';

  @override
  String collectionsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections supprimées',
      one: 'Collection supprimée',
    );
    return '$_temp0';
  }

  @override
  String get createFirstCollection => 'Créez votre première collection';

  @override
  String get collectionEmptyDescription =>
      'Regroupez vos liens dans des espaces calmes et organisés.';

  @override
  String get libraryBooks => 'Livres';

  @override
  String get libraryMoviesShows => 'Films et séries';

  @override
  String get libraryPlaces => 'Lieux';

  @override
  String get libraryBook => 'Livre';

  @override
  String get libraryMovie => 'Film';

  @override
  String get libraryPlace => 'Lieu';

  @override
  String get libraryReadingList => 'Liste de lecture';

  @override
  String get libraryWatchlist => 'Liste à regarder';

  @override
  String get libraryNotInReadingList => 'Hors liste de lecture';

  @override
  String get libraryNotInWatchlist => 'Hors liste à regarder';

  @override
  String get libraryNotListed => 'Non répertorié';

  @override
  String get libraryPlanning => 'Prévu';

  @override
  String get libraryReading => 'En cours de lecture';

  @override
  String get libraryWatching => 'En cours de visionnage';

  @override
  String get libraryInProgress => 'En cours';

  @override
  String get libraryDropped => 'Abandonné';

  @override
  String get libraryRead => 'Lu';

  @override
  String get libraryWatched => 'Vu';

  @override
  String get libraryVisited => 'Visité';

  @override
  String libraryStatusSemantics(Object status) {
    return 'Statut : $status';
  }

  @override
  String libraryReadingPageStatus(Object page) {
    return 'Lecture · p. $page';
  }

  @override
  String get libraryGenreFantasy => 'Fantasy';

  @override
  String get libraryGenreScienceFiction => 'Science-fiction';

  @override
  String get libraryGenreMysteryThriller => 'Mystère et thriller';

  @override
  String get libraryGenreRomance => 'Romance';

  @override
  String get libraryGenreHorror => 'Horreur';

  @override
  String get libraryGenreBiographyMemoir => 'Biographie et mémoires';

  @override
  String get libraryGenreHistory => 'Histoire';

  @override
  String get libraryGenrePhilosophy => 'Philosophie';

  @override
  String get libraryGenrePsychology => 'Psychologie';

  @override
  String get libraryGenreBusiness => 'Économie et affaires';

  @override
  String get libraryGenreFinanceInvesting => 'Finance et investissement';

  @override
  String get libraryGenreTechnology => 'Technologie';

  @override
  String get libraryGenreScience => 'Sciences';

  @override
  String get libraryGenreSelfDevelopment => 'Développement personnel';

  @override
  String get libraryGenreHealthWellness => 'Santé et bien-être';

  @override
  String get libraryGenrePoliticsSociety => 'Politique et société';

  @override
  String get libraryGenreArtDesign => 'Art et design';

  @override
  String get libraryGenreTravel => 'Voyage';

  @override
  String get libraryGenreComicsGraphicNovels => 'BD et romans graphiques';

  @override
  String get libraryGenreFiction => 'Fiction';

  @override
  String get libraryGenreAction => 'Action';

  @override
  String get libraryGenreAdventure => 'Aventure';

  @override
  String get libraryGenreAnimation => 'Animation';

  @override
  String get libraryGenreComedy => 'Comédie';

  @override
  String get libraryGenreCrime => 'Policier';

  @override
  String get libraryGenreDocumentary => 'Documentaire';

  @override
  String get libraryGenreDrama => 'Drame';

  @override
  String get libraryGenreFamily => 'Famille';

  @override
  String get libraryGenreMystery => 'Mystère';

  @override
  String get libraryGenreThriller => 'Thriller';

  @override
  String get libraryGenreWar => 'Guerre';

  @override
  String get libraryGenreWestern => 'Western';

  @override
  String get libraryGenreMusic => 'Musique';

  @override
  String get libraryGenreOther => 'Autre';

  @override
  String get librarySubtypeTvShow => 'Série TV';

  @override
  String get librarySubtypeSeries => 'Série';

  @override
  String get couldNotOpenLibrary => 'Impossible d’ouvrir la Bibliothèque';

  @override
  String searchLibraryItems(Object kind) {
    return 'Rechercher dans $kind';
  }

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get recentlyDiscovered => 'Découvert récemment';

  @override
  String get titleAZ => 'Titre A–Z';

  @override
  String get yearNewest => 'Année la plus récente';

  @override
  String libraryOptions(Object kind) {
    return 'Options de $kind';
  }

  @override
  String filterLibraryItems(Object kind) {
    return 'Filtrer $kind';
  }

  @override
  String get readingStatus => 'Statut de lecture';

  @override
  String get watchStatus => 'Statut de visionnage';

  @override
  String get anyStatus => 'Tous les statuts';

  @override
  String get genre => 'Genre';

  @override
  String get allGenres => 'Tous les genres';

  @override
  String get nothingMatchesFilters =>
      'Aucun résultat ne correspond à ces filtres.';

  @override
  String get nothingRecognizedHere => 'Rien n’a encore été reconnu ici.';

  @override
  String get couldNotUpdateLibraryItem =>
      'Impossible de mettre à jour cet élément de la Bibliothèque.';

  @override
  String get foundInYourSaves => 'Trouvé dans vos sauvegardes';

  @override
  String get recognizedOrganizedByType => 'Classé automatiquement par type';

  @override
  String libraryBookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livres',
      one: '1 livre',
    );
    return '$_temp0';
  }

  @override
  String libraryMovieCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
    );
    return '$_temp0';
  }

  @override
  String libraryPlaceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lieux',
      one: '1 lieu',
    );
    return '$_temp0';
  }

  @override
  String libraryStopCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return '$_temp0';
  }

  @override
  String get nothingRecognizedYet => 'Rien de reconnu pour le moment';

  @override
  String get recognizedTitlesGatherHere =>
      'Les titres reconnus apparaîtront ici';

  @override
  String recognizedCount(Object count) {
    return '$count reconnus';
  }

  @override
  String get savedPlacesAppearOnMap =>
      'Les lieux sauvegardés apparaîtront sur une carte';

  @override
  String get addingDetails => 'Ajout des détails';

  @override
  String get extraDetailsUnavailable =>
      'Les détails supplémentaires sont temporairement indisponibles';

  @override
  String itemsCouldNotRefresh(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments n’ont pas pu être actualisés',
      one: '1 élément n’a pas pu être actualisé',
    );
    return '$_temp0';
  }

  @override
  String progressOf(Object completed, Object total) {
    return '$completed sur $total';
  }

  @override
  String get savedDetailsRemainAvailable =>
      'Les détails enregistrés restent disponibles';

  @override
  String waitingToRetry(Object count) {
    return '$count en attente d’une nouvelle tentative';
  }

  @override
  String get libraryBuildsAsYouSave => 'Elle s’enrichit avec vos sauvegardes';

  @override
  String get libraryEmptyDescription =>
      'Enregistrez des recommandations de livres, films, lieux et musique. Glimpse organisera ici ce qu’elles contiennent.';

  @override
  String get libraryUnavailable =>
      'La Bibliothèque est indisponible pour le moment';

  @override
  String get showOnMap => 'Voir sur la carte';

  @override
  String get yourPlaces => 'Vos lieux';

  @override
  String placesAreasSummary(num areas, num places) {
    String _temp0 = intl.Intl.pluralLogic(
      places,
      locale: localeName,
      other: '$places lieux',
      one: '1 lieu',
    );
    String _temp1 = intl.Intl.pluralLogic(
      areas,
      locale: localeName,
      other: '$areas pays',
      one: '1 pays',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String placeRegionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count régions',
      one: '1 région',
    );
    return '$_temp0';
  }

  @override
  String get otherPlaces => 'Autres lieux';

  @override
  String itineraryDayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get chartOther => 'Autres';

  @override
  String get formulaWhere => 'Où';

  @override
  String get visualsHeading => 'En un coup d’œil';

  @override
  String get itineraryHeading => 'Le programme';

  @override
  String itineraryDay(Object day) {
    return 'Jour $day';
  }

  @override
  String get itineraryTips => 'Bon à savoir';

  @override
  String get planThisTrip => 'Planifier ce voyage';

  @override
  String get openYourPlan => 'Ouvrir ton plan';

  @override
  String planThesePlaces(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Planifier ces $count lieux',
      one: 'Planifier ce lieu',
    );
    return '$_temp0';
  }

  @override
  String get planFromSaveHint =>
      'Un programme dans l’ordre de cette publication';

  @override
  String itineraryStopCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return '$_temp0';
  }

  @override
  String get planThisArea => 'Planifier cette zone';

  @override
  String get planAnItinerary => 'Planifier un itinéraire';

  @override
  String get searchSavedPlaces => 'Rechercher dans les lieux sauvegardés';

  @override
  String get yourPlans => 'Vos itinéraires';

  @override
  String get plan => 'Planifier';

  @override
  String get locationUnavailable => 'Localisation indisponible';

  @override
  String get wantToVisit => 'À visiter';

  @override
  String get planAVisit => 'Planifier une visite';

  @override
  String get maps => 'Cartes';

  @override
  String get noSavedPlacesMatch =>
      'Aucun lieu sauvegardé ne correspond à cette recherche.';

  @override
  String get noPlacesDiscovered => 'Aucun lieu découvert pour le moment';

  @override
  String get placesMentionedGatherHere =>
      'Les lieux mentionnés dans vos sauvegardes apparaîtront ici.';

  @override
  String get fitAllPlaces => 'Afficher tous les lieux';

  @override
  String get noMappedPlaces => 'Aucun lieu sur la carte pour le moment';

  @override
  String get mapUnavailablePlacesListed =>
      'Carte indisponible — vos lieux restent listés ci-dessous';

  @override
  String get libraryItemUnavailable =>
      'Cet élément de la Bibliothèque est indisponible.';

  @override
  String get couldNotUpdateBookmark =>
      'Impossible de mettre à jour votre marque-page.';

  @override
  String hiddenFromLibrary(Object name) {
    return '$name a été masqué de la Bibliothèque';
  }

  @override
  String get libraryItemOptions => 'Options de l’élément de la Bibliothèque';

  @override
  String get hideFromLibrary => 'Masquer de la Bibliothèque';

  @override
  String get addToReadingList => 'Ajouter à votre liste de lecture';

  @override
  String get addToWatchlist => 'Ajouter à votre liste à regarder';

  @override
  String get removeFromReadingList => 'Retirer de la liste de lecture';

  @override
  String get removeFromWatchlist => 'Retirer de la liste à regarder';

  @override
  String get whyItMattered => 'Pourquoi c’était important';

  @override
  String get plot => 'Synopsis';

  @override
  String get yourBookmark => 'Votre marque-page';

  @override
  String get savePageYouAreOn => 'Enregistrez la page en cours';

  @override
  String savePlaceAboutPages(Object count) {
    return 'Enregistrez votre progression · environ $count pages';
  }

  @override
  String pageNumber(Object page) {
    return 'Page $page';
  }

  @override
  String pageAboutPages(Object count, Object page) {
    return 'Page $page · environ $count pages';
  }

  @override
  String get setCurrentPage => 'Définir la page actuelle';

  @override
  String get updatePage => 'Mettre à jour la page';

  @override
  String get updateYourBookmark => 'Mettre à jour votre marque-page';

  @override
  String aboutPages(Object count) {
    return 'environ $count pages';
  }

  @override
  String get currentPage => 'Page actuelle';

  @override
  String get enterPageNumber => 'Saisissez un numéro de page';

  @override
  String get saveBookmark => 'Enregistrer le marque-page';

  @override
  String get pageGreaterThanZero =>
      'Saisissez un numéro de page supérieur à zéro';

  @override
  String libraryItemSemantics(Object kind, Object title) {
    return '$kind : $title';
  }

  @override
  String libraryItemOpenHint(Object list) {
    return 'Touchez deux fois pour ouvrir. Appuyez longuement pour changer le statut de $list.';
  }

  @override
  String get collectionEditSubtitle => 'Affinez cet espace de sauvegarde.';

  @override
  String get collectionCreateSubtitle =>
      'Créez un espace dédié à vos idées enregistrées.';

  @override
  String get nameLabel => 'Nom';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get collectionNameHint => 'Voyages et découvertes';

  @override
  String get collectionDescriptionHint => 'Note facultative pour cet espace';

  @override
  String get save => 'Enregistrer';

  @override
  String get create => 'Créer';

  @override
  String get nameCollectionError => 'Donnez un nom à la collection';

  @override
  String get duplicateCollectionError => 'Une collection porte déjà ce nom';

  @override
  String get deleteCollection => 'Supprimer la collection';

  @override
  String get addLink => 'Ajouter un lien';

  @override
  String get noLinksInCollection =>
      'Cette collection ne contient encore aucun lien.';

  @override
  String get notificationTravelPlaces => 'Voyages et lieux';

  @override
  String get notificationNewDiscovery => 'Nouvelle découverte';

  @override
  String get notificationReadingReminder => 'Rappel de lecture';

  @override
  String get notificationActivity => 'Activité';

  @override
  String get notificationWorthRevisiting => 'À revoir';

  @override
  String get notificationRevisitReminder => 'Rappel de revisite';

  @override
  String get notificationWeeklyDigest => 'Récapitulatif hebdomadaire';

  @override
  String get enrichmentNeedsAttention => 'L’analyse nécessite votre attention';

  @override
  String get aiDetailsAvailable => 'Des détails IA sont disponibles';

  @override
  String get enrich => 'Analyser';

  @override
  String get enriching => 'Analyse en cours';

  @override
  String get messageGlimpse => 'Écrire à Glimpse...';

  @override
  String get askAboutThisSave => 'Poser une question sur cet enregistrement...';

  @override
  String get sending => 'Envoi...';

  @override
  String get send => 'Envoyer';

  @override
  String get askGreetingEarlyMorning => 'Déjà debout ?';

  @override
  String get askGreetingMorning => 'Bonjour.';

  @override
  String get askGreetingAfternoon => 'Qu’explorons-nous ?';

  @override
  String get askGreetingEvening => 'Bonsoir.';

  @override
  String get askGreetingNight => 'Toujours curieux ce soir ?';

  @override
  String get askGreetingLateNight => 'Encore debout tard ?';

  @override
  String get saveYourFirstLink => 'Enregistrez votre premier lien';

  @override
  String get moreSelectionActions => 'Plus d’actions de sélection';

  @override
  String get moveToCollection => 'Déplacer vers une collection';

  @override
  String get markRead => 'Marquer comme lu';

  @override
  String get markUnread => 'Marquer comme non lu';

  @override
  String get toggleReadStatus => 'Changer le statut de lecture';

  @override
  String get unpin => 'Désépingler';

  @override
  String get yourNote => 'Votre note';

  @override
  String get edit => 'Modifier';

  @override
  String get notePrompt => 'Qu’est-ce qui vous a marqué ?';

  @override
  String get quickAdd => 'Ajout rapide';

  @override
  String get noteSaving => 'Enregistrement…';

  @override
  String get noteSaved => 'Enregistré';

  @override
  String get noteCouldNotSave => 'Impossible d’enregistrer';

  @override
  String get addYourNote => 'Ajouter votre note';

  @override
  String get showLess => 'Afficher moins';

  @override
  String get showMore => 'Afficher plus';

  @override
  String showAllCount(Object count) {
    return 'Tout afficher ($count)';
  }

  @override
  String get answerCopied => 'Réponse copiée';

  @override
  String get deleteAskNoteQuestion => 'Supprimer la note Ask ?';

  @override
  String get deleteAskNoteDescription =>
      'Cette action supprime la réponse enregistrée de ce lien. Votre propre note ne sera pas modifiée.';

  @override
  String get askNoteDeleted => 'Note Ask supprimée';

  @override
  String get couldNotDeleteAskNote => 'Impossible de supprimer la note Ask';

  @override
  String get askNoteActions => 'Actions de la note Ask';

  @override
  String get copyAnswer => 'Copier la réponse';

  @override
  String get quickTryThisWeekend => 'Essayer ce week-end';

  @override
  String get quickNeedIngredients => 'Ingrédients nécessaires';

  @override
  String get quickShareWithSomeone => 'Partager avec quelqu’un';

  @override
  String get quickAlreadyTried => 'Déjà essayé';

  @override
  String get quickWatchLater => 'Regarder plus tard';

  @override
  String get quickAddToWatchlist => 'Ajouter à la liste de visionnage';

  @override
  String get quickAlreadyWatched => 'Déjà regardé';

  @override
  String get quickAddToReadingList => 'Ajouter à la liste de lecture';

  @override
  String get quickReadLater => 'Lire plus tard';

  @override
  String get quickResearchThis => 'Faire des recherches';

  @override
  String get quickAlreadyRead => 'Déjà lu';

  @override
  String get quickTryThisTool => 'Essayer cet outil';

  @override
  String get quickCompareAlternatives => 'Comparer les alternatives';

  @override
  String get quickUseInProject => 'Utiliser dans un projet';

  @override
  String get quickShareWithTeam => 'Partager avec l’équipe';

  @override
  String get quickPlanItinerary => 'Planifier l’itinéraire';

  @override
  String get quickCheckBestSeason => 'Vérifier la meilleure saison';

  @override
  String get quickSaveRoute => 'Enregistrer l’itinéraire';

  @override
  String get quickPracticeLater => 'Pratiquer plus tard';

  @override
  String get quickMakeChecklist => 'Créer une liste';

  @override
  String get quickRevisitNotes => 'Revoir les notes';

  @override
  String get quickRevisitLater => 'Revoir plus tard';

  @override
  String get quickWorthTrying => 'À essayer';

  @override
  String get quickAlreadyChecked => 'Déjà vérifié';

  @override
  String get aboutTagline => 'Enregistrez ce qui mérite d’être conservé';

  @override
  String versionBuild(Object build, Object version) {
    return 'Version $version (build $build)';
  }

  @override
  String get loadingVersion => 'Chargement de la version…';

  @override
  String get legal => 'Mentions légales';

  @override
  String get termsOfService => 'Conditions d’utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get help => 'Aide';

  @override
  String get faq => 'Questions fréquentes';

  @override
  String get sendFeedback => 'Envoyer un avis';

  @override
  String get rateOnPlayStore => 'Noter sur le Play Store';

  @override
  String get shareGlimpse => 'Partager Glimpse';

  @override
  String get feedbackEmailSubject => 'Avis sur Glimpse';

  @override
  String shareGlimpseText(Object url) {
    return 'Glimpse vous aide à enregistrer les liens auxquels vous souhaitez revenir. Essayez-le : $url';
  }

  @override
  String get couldNotOpenLink => 'Impossible d’ouvrir ce lien.';

  @override
  String get couldNotShareGlimpse => 'Impossible de partager Glimpse.';

  @override
  String get keepsakeQuoteCuriosity => 'Gardez ce qui nourrit votre curiosité.';

  @override
  String get keepsakeQuoteIdea =>
      'Un bref aperçu peut devenir une idée durable.';

  @override
  String get keepsakeQuoteSpark =>
      'Gardez l’étincelle. Revenez-y quand elle comptera.';

  @override
  String get keepsakeQuoteFutureSelf =>
      'Votre futur vous cherche peut-être ceci.';

  @override
  String get keepsakeQuoteNoticing =>
      'Cela mérite d’être remarqué. Et conservé.';

  @override
  String get other => 'Autre';

  @override
  String get shareBackup => 'Partager la sauvegarde';

  @override
  String get shareBackupDescription =>
      'Envoyez une sauvegarde vers une autre application ou un service cloud';

  @override
  String backupSavedLinksTo(num count, Object location) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liens enregistrés',
      one: '1 lien enregistré',
    );
    return '$_temp0 dans $location';
  }

  @override
  String backupSavedTo(Object location) {
    return 'Sauvegarde enregistrée dans $location';
  }

  @override
  String get errorDetails => 'Détails de l’erreur';

  @override
  String get copy => 'Copier';

  @override
  String get couldNotReadSelectedFile =>
      'Impossible de lire le fichier sélectionné.';

  @override
  String get folderSelected => 'Dossier sélectionné';

  @override
  String get couldNotSaveFolderPermission =>
      'Impossible de conserver l’autorisation du dossier. Réessayez.';

  @override
  String get permanentBackupFolderAndroid =>
      'Le dossier de sauvegarde permanent est disponible sur Android';

  @override
  String get tapToChange => 'Touchez pour modifier';

  @override
  String get forgetFolder => 'Oublier le dossier';

  @override
  String get autoBackupAndroidOnly =>
      'La sauvegarde automatique fonctionne sur Android lorsqu’un dossier est défini';

  @override
  String lastAutomaticBackup(Object time) {
    return 'Dernière sauvegarde automatique : $time';
  }

  @override
  String lastBackupAttemptFailed(Object time) {
    return 'La dernière tentative a échoué $time. Glimpse réessaiera automatiquement.';
  }

  @override
  String get setStorageBeforeAutoBackup =>
      'Définissez une destination ci-dessus avant d’activer les sauvegardes automatiques.';

  @override
  String get folderBackup => 'Sauvegarde du dossier';

  @override
  String lastSavedToFolder(Object time) {
    return 'Dernier enregistrement dans le dossier : $time';
  }

  @override
  String get noBackupFileInFolder =>
      'Ce dossier ne contient encore aucune sauvegarde. Choisissez la destination, puis utilisez Créer une sauvegarde ci-dessus.';

  @override
  String get readerAudioUnavailable =>
      'Votre contenu est bien enregistré. Le texte de l’audio n’était pas disponible : cet aperçu peut donc omettre des détails de la vidéo. Ouvrez la source pour la voir en entier ou ajoutez une note sur ce qui vous a intéressé.';

  @override
  String get highlight => 'Surligner';

  @override
  String get removeHighlight => 'Supprimer le surlignage';

  @override
  String get highlightAdded => 'Surlignage enregistré';

  @override
  String get highlightRemoved => 'Surlignage supprimé';

  @override
  String get highlightFailed => 'Impossible de modifier le surlignage.';

  @override
  String get readerOverviewOnly =>
      'Seul un bref aperçu est disponible pour cet élément. Ouvrez la source pour consulter le contenu complet.';

  @override
  String get glimpsesTitle => 'Vos Glimpses';

  @override
  String get glimpsesIntro => 'Un regard sur ce qui a retenu votre attention.';

  @override
  String get glimpsesConnection => 'Un lien avec votre nouvel enregistrement';

  @override
  String get glimpsesIdea => 'Une idée à retenir';

  @override
  String get glimpsesIntention => 'Vous souhaitiez y revenir';

  @override
  String get glimpsesBriefs => 'Vos récapitulatifs';

  @override
  String get glimpsesPrevious => 'Glimpses précédents';

  @override
  String get glimpsesEmpty =>
      'Rien ne demande votre attention pour le moment. Vos récapitulatifs grandiront au fil de vos enregistrements.';

  @override
  String get glimpsesGotIt => 'Compris';

  @override
  String get glimpsesReflect => 'Réfléchir';

  @override
  String get glimpsesRecall =>
      'Que retenez-vous de cette idée ? Prenez un instant avant de la révéler.';

  @override
  String get glimpsesReveal => 'Révéler l’idée';

  @override
  String get glimpsesNote => 'Votre note';

  @override
  String get glimpsesHighlight => 'Votre passage surligné';

  @override
  String get glimpsesExpand => 'Approfondir ce récapitulatif';

  @override
  String get glimpsesExplain => 'Expliquer ce lien';

  @override
  String get glimpsesAiConsent =>
      'Envoyez uniquement ces extraits sélectionnés à l’IA pour obtenir une explication avec des sources. Cela utilise votre quota Ask. Les notes personnelles sont exclues sauf si vous les ajoutez ci-dessous.';

  @override
  String get glimpsesIncludeNotes => 'Inclure mes notes personnelles';

  @override
  String get glimpsesGenerate => 'Générer l’explication';

  @override
  String get glimpsesAiUnavailable =>
      'L’explication est indisponible pour le moment. Vos idées enregistrées restent ici.';

  @override
  String get glimpsesAiLimit =>
      'Votre quota Ask est atteint. Vous pouvez toujours lire ce récapitulatif local.';

  @override
  String get glimpsesAiLabel => 'Explication IA · fondée sur ces extraits';

  @override
  String get glimpsesMissing =>
      'Ce Glimpse n’est plus disponible. Ses sources ont peut-être changé.';

  @override
  String get glimpsesLaterFeedback => 'Mis de côté pour trois jours';

  @override
  String get glimpsesHistoryNote =>
      'D’après l’activité enregistrée sur cet appareil.';

  @override
  String get glimpsesReturned => 'Revisités';

  @override
  String get glimpsesNoted => 'Notes ajoutées';

  @override
  String get glimpsesCompleted => 'Intentions réalisées';

  @override
  String get glimpsesRelatedReason =>
      'Ces contenus partagent un sujet précis. Relisez l’idée précédente avec votre nouvel enregistrement.';

  @override
  String get glimpsesSynthesisSources => 'Extraits à envoyer';

  @override
  String get glimpsesDay => 'Jour';

  @override
  String get glimpsesWeek => 'Semaine';

  @override
  String get glimpsesMonth => 'Mois';

  @override
  String get glimpsesThreads => 'Les fils de votre mois';

  @override
  String get glimpsesActionFailed =>
      'Impossible de mettre à jour ce Glimpse. Réessayez.';

  @override
  String get glimpsesTopTopics => 'Thèmes principaux';

  @override
  String get glimpsesActivity => 'Enregistrements par jour';

  @override
  String get glimpsesChartHint =>
      'Choisissez un jour pour retrouver ses enregistrements.';

  @override
  String get glimpsesBrowsePeriod => 'Explorer ces enregistrements';

  @override
  String get glimpsesNoSavesPeriod =>
      'Aucun enregistrement sur cette période pour le moment.';

  @override
  String glimpsesPeriodCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vous avez enregistré $count éléments sur cette période.',
      one: 'Vous avez enregistré un élément sur cette période.',
    );
    return '$_temp0';
  }

  @override
  String glimpsesPeriodSummary(int count, String topics) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vous avez enregistré $count éléments. Parmi les thèmes : $topics.',
      one: 'Vous avez enregistré un élément sur $topics.',
    );
    return '$_temp0';
  }

  @override
  String get glimpsesPreviousDay => 'Jour précédent';

  @override
  String get glimpsesNextDay => 'Jour suivant';

  @override
  String get glimpsesPreviousMonth => 'Mois précédent';

  @override
  String get glimpsesNextMonth => 'Mois suivant';

  @override
  String get glimpsesClear => 'Effacer';

  @override
  String get glimpsesNotificationCleared => 'Notification effacée';

  @override
  String get glimpsesTopicRecipes => 'Recettes et cuisine';

  @override
  String get glimpsesTopicAnime => 'Anime et manga';

  @override
  String get glimpsesTopicMotorcycles => 'Motos';

  @override
  String get glimpsesTopicMusic => 'Musique';

  @override
  String get glimpsesTopicFitness => 'Santé et forme';

  @override
  String get glimpsesTopicNature => 'Faune et nature';

  @override
  String get glimpsesTopicTravel => 'Voyages et lieux';

  @override
  String get glimpsesTopicMovies => 'Films à voir';

  @override
  String get glimpsesTopicBooks => 'Livres et lecture';

  @override
  String get glimpsesTopicSpirituality => 'Spiritualité';

  @override
  String get glimpsesTopicHistory => 'Histoire et société';

  @override
  String get glimpsesTopicGrowth => 'Développement personnel et philosophie';

  @override
  String get glimpsesTopicFinance => 'Finance et économie';

  @override
  String get glimpsesTopicDesign => 'Design et créativité';

  @override
  String get glimpsesTopicSoftware => 'Logiciels et IA';

  @override
  String get glimpsesTopicScience => 'Science';

  @override
  String get glimpsesWeeklyReview => 'Revue de la semaine';

  @override
  String get glimpsesHistorySubtitle =>
      'Votre historique et vos centres d’intérêt récurrents';

  @override
  String get glimpsesPastReviews => 'Semaines précédentes';

  @override
  String glimpsesReviewPreview(String title) {
    return 'Commencez par $title';
  }

  @override
  String get glimpsesWhyToday => 'Pourquoi aujourd’hui';

  @override
  String get glimpsesStartHere => 'Commencez ici';

  @override
  String get glimpsesMoreToExplore => 'À explorer aussi';

  @override
  String glimpsesWhyConnection(String title, String topic) {
    return 'Votre nouvel enregistrement, « $title », fait écho à ces anciens enregistrements sur $topic.';
  }

  @override
  String get glimpsesWhyHighlight =>
      'Vous avez surligné un passage dans cet enregistrement. Commencez par là.';

  @override
  String get glimpsesWhyNote =>
      'Vous avez ajouté une note à cet enregistrement. Retrouvez ce que vous avez écrit.';

  @override
  String get glimpsesWhyEarlier => 'Parmi vos anciens enregistrements';

  @override
  String get glimpsesWhatExplored => 'Ce que vous avez exploré';

  @override
  String get glimpsesReviewStartReason =>
      'Un point de départ parmi les enregistrements de cette semaine.';

  @override
  String get glimpsesReviewConnection => 'Un lien à explorer';

  @override
  String get glimpsesReviewSettings => 'Résumé hebdomadaire par IA';

  @override
  String get glimpsesEnableReviews => 'Activer les revues écrites';

  @override
  String get glimpsesDisableReviews => 'Désactiver les revues écrites';

  @override
  String get glimpsesReviewDescription =>
      'Résume vos enregistrements de la semaine passée à l’ouverture de Rediscover.';

  @override
  String get glimpsesReviewConsent =>
      'Une sélection de résumés et de passages surlignés est envoyée à une IA dans le cloud. Vos notes personnelles restent sur votre appareil. Utilise au maximum 1 requête Ask par semaine. Votre historique local fonctionne aussi sans cette option.';

  @override
  String get obBody2 =>
      'Transformez vos liens en idées claires et en détails utiles.';

  @override
  String get obContinue => 'Continuer';

  @override
  String get obSkip => 'Passer';

  @override
  String get obExample => 'Exemple illustratif';

  @override
  String get obSummary =>
      'Explorez des destinations françaises moins connues pour un voyage plus authentique, tout en soulageant les lieux les plus fréquentés.';

  @override
  String get obPoint =>
      'Au-delà des sites très fréquentés, la France regorge de lieux à découvrir.';

  @override
  String get obPlaceNote =>
      'Présenté par le créateur comme une destination recommandée.';

  @override
  String get obShare => 'Partager → Glimpse, ou collez un lien';

  @override
  String get obAnswer =>
      'Je les ai retrouvés dans ton guide de la France :\n\n**Gorges du Tarn** — un paysage de gorges.\n\n**Cascade de l’Éventail** — une halte près d’une cascade.\n\n**Abbaye de Moissac** — une abbaye historique.\n\nLe guide mêle nature et histoire, au-delà des étapes touristiques habituelles. Ces trois lieux sont un point de départ pour ce genre de voyage.';

  @override
  String get obError =>
      'Impossible de sauvegarder votre progression. Réessayez.';

  @override
  String get obDismiss => 'Fermer le guide';

  @override
  String get obFirstSave => 'Gardez votre première découverte';

  @override
  String get obCopy => 'Copiez un lien, puis collez-le dans Glimpse';

  @override
  String get obReaderGuide =>
      'Lisez les idées ici, puis utilisez Ask pour explorer votre lien et ses sources.';

  @override
  String get obLibraryGuide =>
      'Ces éléments viennent de vos liens. Vos collections regroupent les liens de votre choix.';

  @override
  String get obRediscoverGuide =>
      'Ouvrez une idée pour retrouver ses sources. Vos intentions vous aident à revenir au moment choisi.';

  @override
  String get obNotifyTitle => 'Une place pour un rappel utile';

  @override
  String get obNotifyBody =>
      'Activez les alertes pour vos intentions de retour et les idées de vos liens. Modifiable dans les réglages.';

  @override
  String get obNotifyEnable => 'Activer les notifications';

  @override
  String get obNotNow => 'Pas maintenant';

  @override
  String get obAlertsOff =>
      'Les alertes sont désactivées. Vos intentions restent dans l’app.';

  @override
  String get obOpenSettings => 'Ouvrir les réglages de notifications';

  @override
  String get obPermissionError =>
      'Impossible de mettre à jour les notifications. Réessayez.';

  @override
  String obPosition(int current, int total) {
    return 'Chapitre $current sur $total';
  }

  @override
  String get obTakeaway2 =>
      'Partager des lieux paisibles peut aussi les exposer à la surfréquentation.';

  @override
  String get obTakeaway3 =>
      'Le créateur présente les voyages à la campagne comme une expérience qui donne envie de revenir.';

  @override
  String get obSaveTitle => 'France authentique · Destinations moins connues';

  @override
  String askExactLinkCount(int count) {
    return 'Vous avez $count liens enregistrés dans ce périmètre.';
  }

  @override
  String get askNoMatch =>
      'Aucun résultat évident. Vous souvenez-vous du titre, de l’auteur, d’une phrase ou de la date ?';

  @override
  String get askRecentChats => 'Discussions récentes';

  @override
  String get askStop => 'Arrêter';

  @override
  String get askCopyAnswer => 'Copier la réponse';

  @override
  String get askEditMessage => 'Modifier le message';

  @override
  String get askEditConfirm =>
      'Remplacer ce message et les réponses suivantes ?';

  @override
  String get askJumpLatest => 'Aller à la fin';

  @override
  String get askInterrupted => 'Réponse interrompue';

  @override
  String askExplainTitle(String title) {
    return 'Explique $title';
  }

  @override
  String get askCountPrompt => 'Combien de liens ai-je enregistrés ?';

  @override
  String get askRenameChat => 'Renommer la discussion';

  @override
  String askEntityCount(int count, String kind) {
    return 'Vos contenus enregistrés contiennent $count éléments identifiés dans $kind.';
  }

  @override
  String get obWelcomeTitle => 'Gardez ce qui éveille votre curiosité.';

  @override
  String get obWelcomeBody =>
      'Les reels, posts et articles que vous enregistrez deviennent un savoir que vous pouvez vraiment utiliser.';

  @override
  String get obShareTitle => 'Enregistrez depuis n’importe où.';

  @override
  String get obShareBody =>
      'Vous repérez quelque chose sur Instagram, YouTube ou le web ? Touchez Partager, puis Glimpse.';

  @override
  String get obReadTitle => 'Glimpse le lit pour vous.';

  @override
  String get obReadBody =>
      'Chaque enregistrement devient une page claire : l’essentiel, les idées clés et tout ce qui y est mentionné.';

  @override
  String get obFindTitle => 'Retrouvez tout.';

  @override
  String get obFindBody =>
      'Cherchez ou demandez avec vos propres mots. Les films, la musique et les lieux de vos contenus se rassemblent dans votre Bibliothèque.';

  @override
  String get obGrowTitle => 'Toujours mieux à chaque enregistrement.';

  @override
  String get obGrowBody =>
      'Glimpse apprend ce qui vous intéresse et fait remonter le meilleur.';

  @override
  String get obGetStarted => 'Commencer';

  @override
  String get obNext => 'Suivant';

  @override
  String get authTitleFirstRun => 'Une dernière étape.';

  @override
  String get authTitleReturning => 'Bon retour.';

  @override
  String get authBody =>
      'Votre compte gère votre offre. Vos enregistrements restent stockés sur ce téléphone.';

  @override
  String authContinueAs(String name) {
    return 'Continuer en tant que $name';
  }

  @override
  String get authContinueGoogle => 'Continuer avec Google';

  @override
  String get authAnotherGoogle => 'Utiliser un autre compte Google';

  @override
  String get authContinueApple => 'Continuer avec Apple';

  @override
  String get authPrivacy => 'Politique de confidentialité';

  @override
  String get authPrivacyError =>
      'Impossible d’ouvrir la Politique de confidentialité.';

  @override
  String get obStartSaving => 'Commencer à enregistrer';

  @override
  String obFreeNote(int count) {
    return 'L’offre gratuite inclut $count enregistrements enrichis par IA. Passez à Pro quand vous voulez.';
  }

  @override
  String get obReelFollow => 'Suivre';

  @override
  String get obReelCaption =>
      '3 idées qui ont sauvé ma concentration, et les livres derrière 📚… plus';

  @override
  String get obReelAudio => 'Son original';

  @override
  String get obShareMessages => 'Messages';

  @override
  String get savedToGlimpse => 'Enregistré dans Glimpse';

  @override
  String get note => 'Note';

  @override
  String get noteAdded => 'Note ajoutée';

  @override
  String get saveEditFailed => 'Mise à jour impossible';

  @override
  String get obReelSource => 'Reel Instagram · 0:48';

  @override
  String get obReading => 'Lecture du reel…';

  @override
  String get obDemoTitle => 'Trois idées qui ont sauvé ma concentration';

  @override
  String get obDemoBrief =>
      'Commencer les habitudes en tout petit, protéger de longs créneaux pour le vrai travail et ralentir avant les grandes décisions.';

  @override
  String get obDemoPoint1 => 'Réduisez toute nouvelle habitude à deux minutes.';

  @override
  String get obDemoPoint2 =>
      'Bloquez des créneaux de 90 minutes, notifications coupées.';

  @override
  String get obDemoPoint3 =>
      'Dormez sur les décisions qui semblent urgentes et évidentes.';

  @override
  String get obTermTwoMinute => 'Règle des deux minutes';

  @override
  String get obTermDeepWork => 'Travail en profondeur';

  @override
  String get obTermSystems => 'Système 1 et 2';

  @override
  String get obFilmsMusic => 'Films et musique';

  @override
  String get obSearchQuery => 'l’astuce pour démarrer une habitude ?';

  @override
  String get obSearchAnswer =>
      'Réduisez une nouvelle habitude à deux minutes. Tiré du reel de thereadingroom.';

  @override
  String get obGrowToday => 'Aujourd’hui';

  @override
  String get obGrowSoon => 'Après quelques enregistrements';

  @override
  String get obGrowLater => 'Avec le temps';

  @override
  String get obGrowAnytime => 'Quand vous voulez';

  @override
  String get obGrowLibrary =>
      'Livres, films, musique et lieux de chaque enregistrement.';

  @override
  String get obGrowInterests =>
      'Vos contenus se regroupent d’eux-mêmes selon vos centres d’intérêt.';

  @override
  String get obGrowRediscover =>
      'Vos anciens contenus reviennent quand ils méritent un second regard.';

  @override
  String get obGrowCollections =>
      'Rassemblez vos contenus à votre façon, pour un voyage ou un projet.';

  @override
  String get obShareStage =>
      'Exemple : toucher Partager sur un reel Instagram, puis Glimpse, l’enregistre.';

  @override
  String get obReadStage =>
      'Exemple : le reel enregistré devient une page avec un résumé, des points clés, des termes et les livres mentionnés.';

  @override
  String get obFindStage =>
      'Exemple : films, musique et lieux de vos contenus, et une recherche qui retrouve la règle des deux minutes.';

  @override
  String get planNamePro => 'Glimpse Pro';

  @override
  String get planNameFree => 'Glimpse Free';

  @override
  String get accountLoading => 'Chargement du compte';

  @override
  String get accountSignedIn => 'Connecté';

  @override
  String get accountCheckingSession => 'Vérification de la session…';

  @override
  String get accountFallbackSubtitle => 'Compte Glimpse';

  @override
  String get couldNotDeleteAccount =>
      'Impossible de supprimer ton compte. Vérifie ta connexion et réessaie.';

  @override
  String get privacyOnDevice => 'Sur cet appareil';

  @override
  String get privacyOnDeviceNote =>
      'Ta bibliothèque reste sur ce téléphone. Les sauvegardes ne vont que là où tu les mets.';

  @override
  String get privacySentToServers => 'Envoyé aux serveurs de Glimpse';

  @override
  String get privacyLinksTitle => 'Les liens que tu enregistres';

  @override
  String get privacyLinksDetail =>
      'Le lien, son titre et sa description, pour que Glimpse puisse le lire et le résumer';

  @override
  String get privacyAskTitle => 'Les questions que tu poses';

  @override
  String get privacyAskDetail =>
      'Avec les enregistrements sur lesquels elles s’appuient, pour que Glimpse puisse répondre';

  @override
  String get privacyAccountDetail => 'Ton nom et ton e-mail, pour te connecter';

  @override
  String get privacySubscriptionDetail => 'Si tu as Pro';

  @override
  String get privacyAnalyticsTitle => 'Statistiques d’utilisation';

  @override
  String get privacyAnalyticsDetail =>
      'Les fonctionnalités que tu utilises et le modèle de ton appareil, jamais ce que tu enregistres';

  @override
  String get privacyAnalyticsOff =>
      'Désactivé : rien sur ton utilisation de Glimpse n’est envoyé';

  @override
  String get privacyServersNote =>
      'Glimpse ne vend jamais tes données. La politique de confidentialité explique combien de temps elles sont conservées et comment les supprimer.';

  @override
  String get binItemGone => 'Cet élément n’est plus dans la corbeille';

  @override
  String get binRestored => 'Restauré';

  @override
  String get binCouldNotRestore => 'Impossible de restaurer l’élément';

  @override
  String get binNoneRestored => 'Aucun élément n’a été restauré';

  @override
  String binItemsRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments restaurés',
      one: '1 élément restauré',
    );
    return '$_temp0';
  }

  @override
  String get binCouldNotRestoreMany => 'Impossible de restaurer les éléments';

  @override
  String get cannotBeUndone => 'Cette action est irréversible.';

  @override
  String deleteItemsPermanentlyQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count éléments définitivement ?',
      one: 'Supprimer définitivement ?',
    );
    return '$_temp0';
  }

  @override
  String get binPermanentlyDeleted => 'Supprimé définitivement';

  @override
  String binItemsPermanentlyDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments supprimés définitivement',
      one: '1 élément supprimé définitivement',
    );
    return '$_temp0';
  }

  @override
  String get binCouldNotDelete => 'Impossible de supprimer l’élément';

  @override
  String get binCouldNotDeleteMany => 'Impossible de supprimer les éléments';

  @override
  String get emptyBinQuestion => 'Vider la corbeille ?';

  @override
  String get binEmptied => 'Corbeille vidée';

  @override
  String get binCouldNotEmpty => 'Impossible de vider la corbeille';

  @override
  String get restoreSelected => 'Restaurer la sélection';

  @override
  String get deleteSelectedPermanently =>
      'Supprimer définitivement la sélection';

  @override
  String get backupPreview => 'Aperçu de la sauvegarde';

  @override
  String get noBackupData => 'Aucune donnée de sauvegarde';

  @override
  String get backupDetails => 'Détails de la sauvegarde';

  @override
  String get backupDate => 'Date';

  @override
  String get backupAppVersion => 'Version de l’app';

  @override
  String get backupDevice => 'Appareil';

  @override
  String get backupLinksLabel => 'Liens';

  @override
  String get backupSaveSessions => 'Sessions d’enregistrement';

  @override
  String get backupEmbeddings => 'Embeddings inclus';

  @override
  String get restoreMode => 'Mode de restauration';

  @override
  String get restoreMergeTitle => 'Fusionner avec la bibliothèque actuelle';

  @override
  String get restoreMergeSubtitle =>
      'Ajoute les nouveaux liens de la sauvegarde (y compris ceux que tu as supprimés) et met à jour les existants. Rien n’est retiré de ta bibliothèque actuelle.';

  @override
  String get restoreReplaceTitle => 'Remplacer la bibliothèque actuelle';

  @override
  String get restoreReplaceSubtitle =>
      'Remplace toutes les données actuelles par la sauvegarde. Ta bibliothèque actuelle sera supprimée.';

  @override
  String restoringProgress(int percent) {
    return 'Restauration… $percent %';
  }

  @override
  String get replaceLibraryQuestion => 'Remplacer la bibliothèque ?';

  @override
  String get mergeBackupQuestion => 'Fusionner la sauvegarde ?';

  @override
  String get replaceLibraryWarning =>
      'Ta bibliothèque actuelle sera remplacée par la sauvegarde. Tous tes liens et collections actuels seront définitivement supprimés.';

  @override
  String get mergeBackupExplanation =>
      'Les liens de la sauvegarde seront fusionnés avec ta bibliothèque actuelle. Les doublons seront ignorés.';

  @override
  String get replaceAction => 'Remplacer';

  @override
  String get mergeAction => 'Fusionner';

  @override
  String collectionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections',
      one: '1 collection',
    );
    return '$_temp0';
  }

  @override
  String restoreImpactReplace(String links, String collections) {
    return 'Ta bibliothèque actuelle sera supprimée, puis $links et $collections seront restaurés depuis la sauvegarde.';
  }

  @override
  String get impactNewLinks => 'Nouveaux liens à restaurer';

  @override
  String get impactNewLinksHint =>
      'Y compris les liens que tu avais supprimés.';

  @override
  String get impactUpdatedLinks => 'Liens existants à mettre à jour';

  @override
  String get impactNewCollections => 'Nouvelles collections';

  @override
  String get impactUpdatedCollections => 'Collections à mettre à jour';

  @override
  String get calculatingChanges => 'Calcul des changements…';

  @override
  String get couldNotPreviewChanges => 'Impossible d’afficher les changements.';

  @override
  String restoredLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liens restaurés',
      one: '1 lien restauré',
    );
    return '$_temp0';
  }

  @override
  String get restoreComplete => 'Restauration terminée';

  @override
  String get subscriptionsUnavailableBuild =>
      'Les abonnements ne sont pas disponibles dans cette version.';

  @override
  String get subscriptionsUnavailableNow =>
      'Les abonnements sont indisponibles pour le moment.';

  @override
  String get welcomeToPro => 'Bienvenue dans Glimpse Pro !';

  @override
  String get purchasePending =>
      'Ton achat est en attente. Pro sera débloqué une fois le paiement confirmé.';

  @override
  String get purchaseFailed => 'L’achat n’a pas pu aboutir. Réessaie.';

  @override
  String get purchaseNotVerified =>
      'L’achat a abouti, mais Pro n’a pas encore pu être vérifié. Essaie Restaurer les achats.';

  @override
  String get purchasesRestored => 'Achats restaurés, bon retour !';

  @override
  String get noPurchasesFound => 'Aucun achat précédent trouvé';

  @override
  String get restorePurchasesFailed =>
      'Impossible de restaurer les achats. Réessaie.';

  @override
  String get couldNotOpenGooglePlay => 'Impossible d’ouvrir Google Play.';

  @override
  String get subscriptionOtherAccount =>
      'Cet abonnement appartient à un autre compte Glimpse. Connecte-toi avec le compte qui s’est abonné.';

  @override
  String get planYourUsage => 'Ton utilisation';

  @override
  String usageAiSavesFree(int used, int limit) {
    return '$used sur $limit enregistrements IA gratuits utilisés';
  }

  @override
  String usageAiSavesPro(int used, int limit) {
    return '$used sur $limit enregistrements IA ce mois-ci';
  }

  @override
  String usageAsk(int used, int limit) {
    return '$used sur $limit questions ce mois-ci';
  }

  @override
  String usageSearch(int used, int limit) {
    return '$used sur $limit recherches ce mois-ci';
  }

  @override
  String get compareTitle => 'Free et Pro';

  @override
  String get compareAiSaves => 'Enregistrements enrichis par l’IA';

  @override
  String get compareAsk => 'Demander à Glimpse';

  @override
  String get compareSearch => 'Recherche par mots-clés';

  @override
  String get compareFreeAiSaves => '30 pour commencer';

  @override
  String perMonthCount(int count) {
    return '$count / mois';
  }

  @override
  String get unlimitedFairUse => 'Illimité*';

  @override
  String get fairUseNote => '* Dans les limites d’un usage raisonnable.';

  @override
  String get choosePlan => 'Choisis une formule';

  @override
  String get planMonthly => 'Mensuel';

  @override
  String get planYearly => 'Annuel';

  @override
  String pricePerMonth(String price) {
    return '$price / mois';
  }

  @override
  String pricePerYear(String price) {
    return '$price / an';
  }

  @override
  String savePercent(int percent) {
    return 'Économise $percent %';
  }

  @override
  String startProWithPrice(String price) {
    return 'Passer à Pro · $price';
  }

  @override
  String get subscriptionTerms =>
      'Se renouvelle automatiquement jusqu’à résiliation. Résilie à tout moment dans Google Play.';

  @override
  String get hapticsTitle => 'Retour haptique';

  @override
  String get hapticsFull => 'Complet';

  @override
  String get hapticsSubtle => 'Discret';

  @override
  String get hapticsFullDetail => 'Retour riche et texturé';

  @override
  String get hapticsSubtleDetail => 'Seulement les plus légers';

  @override
  String get hapticsOffDetail => 'Aucune vibration';

  @override
  String get defaultMusicApp => 'App de musique par défaut';

  @override
  String get musicAskEachTime => 'Demander à chaque fois';

  @override
  String get notifWhatToSend => 'Quoi envoyer';

  @override
  String get notifKindConnections => 'Connexions';

  @override
  String get notifKindConnectionsDetail =>
      'Quand des enregistrements de périodes différentes parlent de la même chose';

  @override
  String get notifKindIdeas => 'Idées enregistrées';

  @override
  String get notifKindIdeasDetail =>
      'Une idée enregistrée, quand elle vaut un second regard';

  @override
  String get notifKindWeekly => 'Bilan de la semaine';

  @override
  String get notifKindWeeklyDetail => 'Un retour le dimanche sur ta semaine';

  @override
  String get notifKindReminders => 'Rappels pour y revenir';

  @override
  String get notifKindRemindersDetail =>
      'Les enregistrements auxquels tu voulais revenir';

  @override
  String get notifDeliveryHours => 'Heures d’envoi';

  @override
  String get notifDeliveryHoursDetail =>
      'Glimpse ne t’envoie de notifications qu’entre ces heures';

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get notifKindsAll => 'Tout';

  @override
  String get notifKindsNone => 'Rien';

  @override
  String notifKindsSome(int count) {
    return '$count types sur 4';
  }

  @override
  String get binCouldNotLoad => 'Impossible de charger la corbeille';

  @override
  String get askThinking => 'Je parcours vos enregistrements…';

  @override
  String askSourcesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sources',
      one: '1 source',
    );
    return '$_temp0';
  }

  @override
  String get askAddNote => 'Ajouter en note';

  @override
  String get askNoteSaved => 'Enregistré dans les notes';

  @override
  String get askNoteSaveFailed => 'Impossible d\'enregistrer. Réessayez.';

  @override
  String get askRegenerate => 'Régénérer';

  @override
  String get askCopied => 'Copié';

  @override
  String get askAllSaves => 'Tout';

  @override
  String get askAskingAbout => 'Question sur';

  @override
  String get askActionSaveToCollection => 'Enregistrer dans une collection';

  @override
  String get askActionSynthesize => 'Synthétiser';

  @override
  String get askActionBuildPlan => 'Créer un plan';

  @override
  String get askActionSaveItinerary => 'Enregistrer comme itinéraire';

  @override
  String get askEarlier => 'Plus tôt';

  @override
  String get askOpenNow => 'Ouvert';

  @override
  String get askNoChats => 'Aucune conversation';

  @override
  String get askNoChatsHint => 'Vos questions seront conservées ici.';

  @override
  String get askSearchChats => 'Rechercher';

  @override
  String get askNoChatsMatch => 'Aucune conversation trouvée';

  @override
  String get askChatDeleted => 'Conversation supprimée';

  @override
  String get askNewCollectionHint => 'Nommez-la, ils y seront ajoutés';

  @override
  String get askAlreadyInCollection => 'Déjà ici';

  @override
  String askSomeInCollection(int count) {
    return '$count déjà ici';
  }

  @override
  String askAddedToCollection(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements ajoutés à $name',
      one: 'Ajouté à $name',
    );
    return '$_temp0';
  }

  @override
  String get askTryAsking => 'Essayez de demander';

  @override
  String askSuggestBigIdea(String title) {
    return 'Quelle est l’idée principale de $title ?';
  }

  @override
  String askSuggestTopic(String topic) {
    return 'Qu’ai-je appris sur $topic ?';
  }

  @override
  String get askSuggestThisWeek => 'Qu’ai-je enregistré cette semaine ?';

  @override
  String askSuggestRemind(String title) {
    return 'Rappelle-moi de quoi parlait $title';
  }

  @override
  String askSuggestConnect(String topic) {
    return 'Quels liens entre mes enregistrements sur $topic ?';
  }

  @override
  String get askHowToSave => 'Comment enregistrer un lien ?';

  @override
  String get askEditingQuestion => 'Modification de votre question';

  @override
  String get askEditingReplaces =>
      'Modification · les réponses suivantes seront remplacées';

  @override
  String get askAskAgain => 'Redemander';

  @override
  String get askHeadBigIdea => 'L’idée principale';

  @override
  String askHeadTopic(String topic) {
    return 'Faire le point sur $topic';
  }

  @override
  String get askSubTopic => 'Ce que vous avez appris récemment';

  @override
  String get askHeadWeek => 'Cette semaine';

  @override
  String get askSubWeek => 'Un récap rapide';

  @override
  String get askHeadRemind => 'Redécouvrir un ancien';

  @override
  String get askHeadConnect => 'Relier les idées';

  @override
  String askSubConnect(String topic) {
    return 'Dans vos enregistrements $topic';
  }

  @override
  String get askHeadLibrary => 'Votre bibliothèque';

  @override
  String get askHeadStart => 'Commencer';

  @override
  String askAcrossSaves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posez vos questions sur vos $count enregistrements',
      one: 'Posez vos questions sur votre enregistrement',
    );
    return '$_temp0';
  }

  @override
  String get vault => 'Coffre';

  @override
  String get vaultSubtitle =>
      'Enregistrements privés, derrière le verrouillage de ton téléphone';

  @override
  String get vaultLockedTitle => 'Ton coffre est verrouillé';

  @override
  String get vaultLockedBody =>
      'Toi seul peux l\'ouvrir, avec ton empreinte, ton visage ou ton verrouillage d\'écran.';

  @override
  String get vaultUnlock => 'Déverrouiller';

  @override
  String get vaultUnlockPromptTitle => 'Déverrouiller le coffre';

  @override
  String get vaultUnlockPromptSubtitle =>
      'Confirme que c\'est toi pour voir tes enregistrements privés';

  @override
  String get vaultUnlockLockout =>
      'Trop de tentatives. Réessaie dans un moment.';

  @override
  String get vaultUnlockFailed => 'Déverrouillage impossible. Réessaie.';

  @override
  String vaultItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements privés',
      one: '1 enregistrement privé',
      zero: 'Vide',
    );
    return '$_temp0';
  }

  @override
  String get vaultEmptyTitle => 'Rien dans ton coffre pour l\'instant';

  @override
  String get vaultEmptyBody =>
      'Partage un lien et choisis Coffre, ou déplace un enregistrement ici depuis son menu.';

  @override
  String get vaultNoScreenLockTitle =>
      'Configure d\'abord un verrouillage d\'écran';

  @override
  String get vaultNoScreenLockBody =>
      'Le coffre utilise le verrouillage de ton téléphone. Ajoute un code, un schéma ou un mot de passe dans les réglages, puis reviens.';

  @override
  String get vaultInvalidatedTitle => 'Ce coffre ne peut pas être ouvert';

  @override
  String get vaultInvalidatedBody =>
      'Le verrouillage d\'écran a été retiré, ou c\'est un autre téléphone, et Android a détruit la clé du coffre. Réinitialise le coffre pour recommencer.';

  @override
  String get vaultReset => 'Réinitialiser le coffre';

  @override
  String get vaultResetQuestion => 'Réinitialiser le coffre ?';

  @override
  String get vaultResetBody =>
      'Tout le contenu du coffre est supprimé définitivement. Impossible d\'annuler.';

  @override
  String get vaultResetDone => 'Coffre réinitialisé';

  @override
  String get vaultHowItWorks => 'Comment fonctionne le coffre';

  @override
  String get vaultHowLock =>
      'Verrouillé par ton téléphone : seuls ton empreinte, ton visage ou ton verrouillage d\'écran l\'ouvrent.';

  @override
  String get vaultHowLocal =>
      'Reste sur ce téléphone : les liens du coffre ne sont jamais envoyés aux serveurs ni à l\'IA de Glimpse, et ne sont pas sauvegardés.';

  @override
  String get vaultHowHidden =>
      'Hors de vue : rien n\'apparaît dans la recherche, Rediscover, la Bibliothèque ou Ask.';

  @override
  String get vaultHowLoss =>
      'Si tu perds ce téléphone ou retires son verrouillage d\'écran, le contenu du coffre est perdu aussi.';

  @override
  String get vaultMoveTo => 'Déplacer dans le coffre';

  @override
  String get vaultMoveQuestion => 'Déplacer dans ton coffre ?';

  @override
  String get vaultMoveBody =>
      'Le lien, le titre et la note y entrent et ne s\'ouvrent qu\'avec le verrouillage de ton téléphone. Il quitte tes enregistrements, la recherche et la Bibliothèque, et son résumé n\'est pas conservé.';

  @override
  String get vaultMoved => 'Déplacé dans le coffre';

  @override
  String get vaultMoveOut => 'Sortir du coffre';

  @override
  String get vaultMovedOut => 'De retour dans tes enregistrements';

  @override
  String get vaultCouldNotMove => 'Déplacement impossible. Réessaie.';

  @override
  String get vaultProTitle => 'Le coffre fait partie de Glimpse Pro';

  @override
  String get vaultProBody =>
      'Garde tes liens privés derrière le verrouillage de ton téléphone, sur ce téléphone uniquement.';

  @override
  String get vaultSeePro => 'Voir Pro';

  @override
  String get savedToVault => 'Enregistré dans le coffre';

  @override
  String get vaultNeedsPro => 'Le coffre nécessite Glimpse Pro';

  @override
  String get vaultCouldNotSave => 'Enregistrement dans le coffre impossible';

  @override
  String vaultUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments n\'ont pas pu être ouverts cette fois',
      one: '1 élément n\'a pas pu être ouvert cette fois',
    );
    return '$_temp0';
  }

  @override
  String get vaultLock => 'Verrouiller';

  @override
  String get vaultDeleteQuestion => 'Supprimer du coffre ?';

  @override
  String get vaultDeleteBody =>
      'Il est supprimé définitivement. Les éléments du coffre ne passent pas par la corbeille.';

  @override
  String get vaultDeleted => 'Supprimé du coffre';

  @override
  String get vaultEditNote => 'Modifier la note';

  @override
  String get vaultName => 'Nom';

  @override
  String get vaultNamePanelTitle => 'Nomme-le pour le retrouver';

  @override
  String vaultNamedAs(String name) {
    return 'Enregistré comme « $name »';
  }

  @override
  String get vaultRename => 'Renommer';

  @override
  String get vaultSearch => 'Rechercher dans ton coffre';

  @override
  String get vaultNoMatches => 'Rien dans ton coffre ne correspond';

  @override
  String get vaultResetPromptSubtitle =>
      'Confirme que c\'est toi pour tout supprimer';

  @override
  String get vaultFootnote => 'Uniquement sur ce téléphone · jamais envoyé';

  @override
  String get vaultLocksOnLeave => 'Se verrouille quand tu pars';
}
