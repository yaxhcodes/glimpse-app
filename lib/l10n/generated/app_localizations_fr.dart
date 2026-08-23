// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

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
  String get libraryGestures => 'Gestes de la bibliothèque';

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
  String get captureTitle =>
      'Nous enregistrons ce qui a retenu votre attention.';

  @override
  String get captureBody => 'Nous vous préviendrons lorsque ce sera prêt.';

  @override
  String savedToCollection(String collectionName) {
    return 'Enregistré dans $collectionName';
  }

  @override
  String get makingSense => 'Glimpse analyse ce qui a retenu votre attention.';

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
  String get savingTo => 'Enregistrement dans';

  @override
  String get chooseCollection => 'Choisir une collection';

  @override
  String get chooseACollection => 'Choisissez une collection';

  @override
  String get processingLink => 'Traitement du lien…';

  @override
  String get couldNotLoadCollections =>
      'Impossible de charger les collections.';

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
  String get processingSavedHeadline => 'Enregistré dans votre bibliothèque';

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
      other: '$count en attente',
      one: '1 en attente',
    );
    return '$_temp0';
  }

  @override
  String get backInView => 'De retour';

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
  String get summary => 'Résumé';

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
      'Livres, films et lieux trouvés dans vos sauvegardes';

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
  String interestGroupedStats(Object grouped, num patterns, Object saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns tendances',
      one: '1 tendance',
    );
    return '$_temp0 · $grouped sauvegardes sur $saves regroupées';
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
  String get recognizedOrganizedByType => 'Reconnu et organisé par type';

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
      other: '$count films',
      one: '1 film',
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
      'Sauvegardez des recommandations de livres, films et lieux. Glimpse organisera ici ce qu’elles contiennent.';

  @override
  String get libraryUnavailable =>
      'La Bibliothèque est indisponible pour le moment';

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
      other: '$areas zones',
      one: '1 zone',
    );
    return '$_temp0 · $_temp1';
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
  String openNamedItem(Object name) {
    return 'Ouvrir $name';
  }

  @override
  String get wantToVisit => 'À visiter';

  @override
  String get savedPlace => 'Lieu sauvegardé';

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
}
