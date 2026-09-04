// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get musicDetailsUnavailable =>
      'Some song details could not be loaded.';

  @override
  String get loadingMusicDetails => 'Loading song details…';

  @override
  String get couldNotSaveMusicProvider =>
      'Could not save your music app. Please try again.';

  @override
  String get libraryMusicEmptyDescription =>
      'Songs found in your saved links will appear here.';

  @override
  String get libraryMusicDescription => 'Songs found in your saves';

  @override
  String get libraryMusic => 'Music';

  @override
  String get appName => 'Glimpse';

  @override
  String get home => 'Home';

  @override
  String get collections => 'Collections';

  @override
  String get interests => 'Interests';

  @override
  String get search => 'Search';

  @override
  String get askGlimpse => 'Ask Glimpse';

  @override
  String get settings => 'Settings';

  @override
  String get accountAndPlan => 'Account & plan';

  @override
  String get personalization => 'Personalization';

  @override
  String get lookAndFeel => 'Look & Feel';

  @override
  String get themeAndAccent => 'Theme and accent color';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageFrench => 'French';

  @override
  String get languagePortugueseBrazil => 'Portuguese (Brazil)';

  @override
  String get languageGerman => 'German';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get musicApp => 'Music app';

  @override
  String get chooseWhereSongsOpen => 'Choose where songs open';

  @override
  String get loadingPreference => 'Loading preference';

  @override
  String get libraryGestures => 'Library gestures';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacyAndData => 'Privacy & data';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacySubtitle => 'What stays local and what is uploaded';

  @override
  String get dataAndBackup => 'Data & Backup';

  @override
  String get dataAndBackupSubtitle =>
      'Protect and restore your saved knowledge';

  @override
  String get bin => 'Bin';

  @override
  String get binSubtitle => 'Deleted items are kept for 30 days';

  @override
  String get clearAllData => 'Clear All Data';

  @override
  String get clearAllDataSubtitle => 'Permanently delete all saved links';

  @override
  String get about => 'About';

  @override
  String get aboutGlimpse => 'About Glimpse';

  @override
  String get aboutSubtitle => 'Version, legal & help';

  @override
  String get accountActions => 'Account actions';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutSubtitle => 'Sign out of this device';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSubtitle => 'Request account deletion';

  @override
  String get deletingAccount => 'Deleting your account…';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteAll => 'Delete All';

  @override
  String get clearAllDataQuestion => 'Clear All Data?';

  @override
  String get clearAllDataWarning =>
      'This will permanently delete all saved URLs. This cannot be undone.';

  @override
  String get allDataCleared => 'All data cleared';

  @override
  String get logOutQuestion => 'Log out?';

  @override
  String get logOutWarning =>
      'You’ll need to sign in again to access your Glimpse account.';

  @override
  String get deleteAccountQuestion => 'Delete account?';

  @override
  String get manageSubscription => 'Manage subscription';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get manageYourPlan => 'Manage your plan';

  @override
  String get checkingSaveAllowance => 'Checking save allowance';

  @override
  String aiSavesLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lifetime AI saves left',
      one: '1 lifetime AI save left',
    );
    return '$_temp0';
  }

  @override
  String get captureBody => 'We’ll notify you when it’s ready.';

  @override
  String get captureQueuedWithoutNotifications => 'It’ll be ready in Glimpse.';

  @override
  String get captureSchedulingFallback =>
      'Saved. Open Glimpse to finish organizing it.';

  @override
  String get captureCouldNotSave => 'Couldn’t save this link';

  @override
  String savedToCollection(String collectionName) {
    return 'Saved to $collectionName';
  }

  @override
  String get savedWithoutAi => 'Saved without AI enrichment';

  @override
  String get aiLimitBody =>
      'You’ve used your 30 lifetime AI saves. Tap to upgrade.';

  @override
  String get proAiLimitBody =>
      'You’ve used 500 AI saves this month. Your link was saved without AI enrichment.';

  @override
  String get alreadyInYourWorld => 'Already in your world.';

  @override
  String get enrichmentFailed => 'Couldn’t finish enrichment';

  @override
  String get tapToRetry => 'Tap to retry this save.';

  @override
  String get notification => 'Notification';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get addUrl => 'Add URL';

  @override
  String get newCollection => 'New collection';

  @override
  String get captured => 'Captured';

  @override
  String get undo => 'Undo';

  @override
  String get alreadyInGlimpse => 'Already in Glimpse';

  @override
  String get open => 'Open';

  @override
  String get tryAgain => 'Try again';

  @override
  String get exitSelection => 'Exit selection';

  @override
  String get sources => 'Sources';

  @override
  String get viewAllSources => 'View all sources';

  @override
  String get pasteLink => 'Paste a link…';

  @override
  String get dismissClipboardSuggestion => 'Dismiss clipboard suggestion';

  @override
  String get selectAll => 'Select all';

  @override
  String get editCollection => 'Edit collection';

  @override
  String get moveContents => 'Move contents';

  @override
  String get deleteSelectedCollections => 'Delete selected collections';

  @override
  String get delete => 'Delete';

  @override
  String get collectionOptions => 'Collection options';

  @override
  String get grid => 'Grid';

  @override
  String get list => 'List';

  @override
  String get manual => 'Manual';

  @override
  String get newest => 'Newest';

  @override
  String get alphabetical => 'A–Z';

  @override
  String get reorder => 'Reorder';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get reset => 'Reset';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get newChat => 'New chat';

  @override
  String get capture => 'Capture';

  @override
  String get capturing => 'Capturing…';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get addToCollection => 'Add to collection';

  @override
  String get more => 'More';

  @override
  String get notes => 'Notes';

  @override
  String get categoryTechnology => 'Technology';

  @override
  String get categoryBusiness => 'Business';

  @override
  String get categoryFinance => 'Finance';

  @override
  String get categoryScience => 'Science';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryNews => 'News';

  @override
  String get categoryDesign => 'Design';

  @override
  String get categoryHistory => 'History';

  @override
  String get categoryPhilosophy => 'Philosophy';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryOther => 'Other';

  @override
  String minutesAgo(Object count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(Object count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(Object count) {
    return '${count}d ago';
  }

  @override
  String get smartNotificationsDescription =>
      'Smart notifications about your saved links';

  @override
  String get done => 'Done';

  @override
  String get later => 'Later';

  @override
  String get notificationFallbackTitle => 'Notification';

  @override
  String newNotificationCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new notifications',
      one: '1 new notification',
    );
    return '$_temp0';
  }

  @override
  String get captureSomethingWorthReturning =>
      'Capture something worth returning to';

  @override
  String get captureContextAfter =>
      'Glimpse will find the context after you capture it.';

  @override
  String get link => 'Link';

  @override
  String get detectedFromClipboard => 'Detected from clipboard';

  @override
  String get collection => 'Collection';

  @override
  String get noCollection => 'No Collection';

  @override
  String get savingTo => 'Saving to';

  @override
  String get chooseCollection => 'Choose collection';

  @override
  String get chooseACollection => 'Choose a collection';

  @override
  String get processingLink => 'Processing link…';

  @override
  String get couldNotLoadCollections => 'Could not load collections.';

  @override
  String linkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
      zero: 'No links',
    );
    return '$_temp0';
  }

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get addNoteOptional => 'Add a note (optional)';

  @override
  String get pleaseEnterUrl => 'Please enter a URL';

  @override
  String get couldNotCaptureLink => 'Could not capture this link';

  @override
  String get findingSavedVersion => 'Finding the saved version…';

  @override
  String get openSavedItem => 'Open saved item';

  @override
  String collectionSelection(String collectionName) {
    return 'Collection, $collectionName';
  }

  @override
  String get capturedInGlimpse => 'Captured in Glimpse';

  @override
  String get firstCapturedReady => 'Your first captured item is ready below.';

  @override
  String get shareAnyApp => 'Share from any app — Glimpse sorts it for you.';

  @override
  String get howGlimpseWorks => 'How Glimpse works';

  @override
  String get capturingWhatCaughtYourEye => 'Capturing what caught your eye';

  @override
  String get findingContext => 'Finding the context';

  @override
  String get invalidLink => 'Invalid link';

  @override
  String get rediscover => 'Rediscover';

  @override
  String get rediscoverSubtitle => 'Worth picking back up';

  @override
  String get rediscoverTip =>
      'Rediscover chooses a few memories worth returning to each day.';

  @override
  String get dismissRediscoverTip => 'Dismiss Rediscover tip';

  @override
  String get pinned => 'Pinned';

  @override
  String get recentSaves => 'Recent Saves';

  @override
  String get justNow => 'just now';

  @override
  String weeksAgo(Object count) {
    return '${count}w ago';
  }

  @override
  String monthsAgo(Object count) {
    return '${count}mo ago';
  }

  @override
  String yearsAgo(Object count) {
    return '${count}y ago';
  }

  @override
  String get retrying => 'Retrying';

  @override
  String get processing => 'Processing';

  @override
  String get processingSavedHeadline => 'Saved to your library';

  @override
  String get processingSavedDetail => 'Waiting to understand your save';

  @override
  String get processingOpeningHeadline => 'Opening the content';

  @override
  String get processingOpeningDetail => 'Checking what this save contains';

  @override
  String processingReadingHeadline(String content) {
    return 'Reading the $content';
  }

  @override
  String get processingExtractingDetail => 'Pulling out the useful details';

  @override
  String get processingUnderstoodHeadline => 'Content understood';

  @override
  String get processingUnderstoodDetail => 'Turning content into a useful save';

  @override
  String get processingFindingHeadline => 'Finding what matters';

  @override
  String get processingFindingDetail => 'Finding the ideas that matter most';

  @override
  String get processingConnectingHeadline => 'Connecting the dots';

  @override
  String get processingConnectingDetail => 'Connecting this with related saves';

  @override
  String get processingFinishingHeadline => 'Finishing your save';

  @override
  String get processingFinishingDetail => 'Finishing search and rediscovery';

  @override
  String get processingRetryHeadline => 'Trying that step again';

  @override
  String get processingRetryDetail => 'Trying this processing step again';

  @override
  String get processingFailedHeadline => 'Couldn\'t finish processing';

  @override
  String get processingFailedDetail =>
      'Your save is safe. Try processing again';

  @override
  String get processingDefaultHeadline => 'Understanding this save';

  @override
  String get processingDefaultDetail => 'Finding the ideas worth keeping';

  @override
  String get processingContentReel => 'reel';

  @override
  String get processingContentVideo => 'video';

  @override
  String get processingContentPin => 'pin';

  @override
  String get processingContentPage => 'page';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get read => 'Read';

  @override
  String get unread => 'Unread';

  @override
  String get copyLink => 'Copy Link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get openOriginal => 'Open Original';

  @override
  String get share => 'Share';

  @override
  String get enrichmentComplete => 'Enrichment complete';

  @override
  String get couldNotEnrichSave => 'Could not enrich this save';

  @override
  String get allSources => 'All sources';

  @override
  String get all => 'All';

  @override
  String get apps => 'Apps';

  @override
  String get websites => 'Websites';

  @override
  String get results => 'Results';

  @override
  String get topSources => 'Top sources';

  @override
  String get searchSources => 'Search apps, sites, and domains…';

  @override
  String get filterSources => 'Filter sources';

  @override
  String get couldNotLoadSources => 'Could not load sources';

  @override
  String noSourcesMatch(String query) {
    return 'No sources match \"$query\"';
  }

  @override
  String get noSavesFromApps => 'No saves from apps yet';

  @override
  String get noWebsiteSaves => 'No website saves yet';

  @override
  String get noSourcesYet => 'No sources yet';

  @override
  String get noSavesYet => 'No saves yet';

  @override
  String saveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saves',
      one: '1 save',
    );
    return '$_temp0';
  }

  @override
  String savesThisWeek(Object count) {
    return '+$count this week';
  }

  @override
  String get growing => 'Growing';

  @override
  String lastSaved(String time) {
    return 'Last saved $time';
  }

  @override
  String get leftSwipe => 'Left swipe';

  @override
  String get rightSwipe => 'Right swipe';

  @override
  String get chooseSwipeAction => 'Choose swipe action';

  @override
  String get markReadUnread => 'Mark Read / Unread';

  @override
  String get pin => 'Pin';

  @override
  String get none => 'None';

  @override
  String get smartNotifications => 'Smart notifications';

  @override
  String get behaviorBasedAlerts => 'Behavior-based alerts';

  @override
  String get whereDoYouListen => 'Where do you listen?';

  @override
  String get chooseMusicProvider =>
      'Choose the app Glimpse should use for songs you find.';

  @override
  String get brightness => 'Brightness';

  @override
  String get brightnessDescription =>
      'Choose when to use light or dark colors.';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get amoledBlack => 'AMOLED black';

  @override
  String get amoledUnavailable => 'Available when not using light theme.';

  @override
  String get amoledDescription =>
      'Pure black backgrounds on OLED — saves power.';

  @override
  String get accentColor => 'Accent color';

  @override
  String get dynamicAccentDescription =>
      'Dynamic uses your wallpaper palette on supported devices.';

  @override
  String selectedAccent(String accent) {
    return 'Selected: $accent';
  }

  @override
  String get themePreview => 'Theme preview';

  @override
  String get themePreviewDescription =>
      'Accent and surfaces update from your choices below.';

  @override
  String get accentDynamic => 'Dynamic';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentLime => 'Lime';

  @override
  String get accentYellow => 'Yellow';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRed => 'Red';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentSakura => 'Sakura';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentSlate => 'Slate';

  @override
  String get accentMonochrome => 'Monochrome';

  @override
  String get deleted => 'Deleted';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get notificationsEmptyDescription =>
      'Travel alerts, new discoveries, reading reminders, and weekly digests will appear here.';

  @override
  String get ready => 'ready';

  @override
  String waitingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waiting',
      one: '1 waiting',
    );
    return '$_temp0';
  }

  @override
  String get backInView => 'Back in view';

  @override
  String get couldNotLoadSource => 'Could not load this source';

  @override
  String get noSavesFromSource => 'No saves from this source';

  @override
  String get saves => 'Saves';

  @override
  String get thisWeek => 'This week';

  @override
  String get opened => 'Opened';

  @override
  String get topThemes => 'Top themes';

  @override
  String get allItems => 'All items';

  @override
  String get oldest => 'Oldest';

  @override
  String get recentlyOpened => 'Recently opened';

  @override
  String get showItems => 'Show items';

  @override
  String get sortBy => 'Sort by';

  @override
  String get noItemsFromSource => 'No items from this source';

  @override
  String get noUnreadItems => 'No unread items';

  @override
  String get noReadItems => 'No read items';

  @override
  String get lastSavedLabel => 'Last saved';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get back => 'Back';

  @override
  String get subscription => 'Subscription';

  @override
  String get couldNotLoadSubscription => 'Could not load subscription info';

  @override
  String get coreLibrary => 'Core Library';

  @override
  String get unlimitedLinkSaving => 'Unlimited link saving';

  @override
  String get unlimitedLinkSavingDescription => 'Save as many links as you want';

  @override
  String get collectionsOrganization => 'Collections & organization';

  @override
  String get collectionsOrganizationDescription =>
      'Group and manage bookmarks your way';

  @override
  String get smartNotificationsLongDescription =>
      'Behavior-based alerts and reading reminders';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get aiTaggingCategorization => 'AI tagging & categorization';

  @override
  String get freeSavesProUnlimited =>
      'Free: 30 lifetime AI saves · Pro: 500 / mo';

  @override
  String get keywordSearch => 'Keyword search';

  @override
  String get freeSearchesProUnlimited =>
      'Free: 30 searches / mo · Pro: Expanded access';

  @override
  String get askYourBookmarks => 'Ask Your Bookmarks';

  @override
  String get freeQuestionsProUnlimited =>
      'Free: 30 questions / mo · Pro: Generous fair use';

  @override
  String get proInsights => 'Pro Insights';

  @override
  String get semanticSearch => 'Semantic search';

  @override
  String get semanticSearchDescription =>
      'Find links by meaning, not just words';

  @override
  String get weeklyRecap => 'Weekly Recap';

  @override
  String get weeklyRecapDescription =>
      'AI-generated summary of your saved links';

  @override
  String get multiLinkSynthesis => 'Multi-Link Synthesis';

  @override
  String get multiLinkSynthesisDescription =>
      'Cross-analyze any set of bookmarks';

  @override
  String get active => 'Active';

  @override
  String get free => 'Free';

  @override
  String get proPlanDescription =>
      '500 AI-enriched saves each month, plus expanded Ask and search access across your library.';

  @override
  String get proPlanDevDescription =>
      '500 AI-enriched saves each month, plus expanded Ask and search access. (dev override; store: Free)';

  @override
  String get freePlanDescription =>
      'Save links without limits and explore AI with 30 lifetime enriched saves before upgrading.';

  @override
  String get upgradeToGlimpsePro => 'Upgrade to Glimpse Pro';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get manageOnGooglePlay => 'Manage on Google Play';

  @override
  String get local => 'Local';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get aiSummaries => 'AI summaries';

  @override
  String get accountInformation => 'Account information';

  @override
  String get subscriptionStatus => 'Subscription status';

  @override
  String get anonymousProductAnalytics => 'Anonymous product analytics';

  @override
  String get storageLocation => 'Storage location';

  @override
  String get pickAFolder => 'Pick a folder';

  @override
  String get chooseBackupFolderDescription =>
      'Tap to choose where backups are stored';

  @override
  String get backupFolderInfo =>
      'Used for saving your backup files. Pick a folder once and Glimpse will keep writing new backups there.';

  @override
  String get automaticBackup => 'Automatic backup';

  @override
  String get off => 'Off';

  @override
  String get backupFrequencyDescription =>
      'How often to save a backup to your storage location';

  @override
  String get backupSensitiveInfo =>
      'Keep copies of backups in other places as well. Backups can include your full library — treat them as sensitive if you share files.';

  @override
  String get backupAndRestore => 'Backup and restore';

  @override
  String get createBackup => 'Create backup';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String lastBackup(Object time) {
    return 'Last backup: $time';
  }

  @override
  String get backupLocalInfo =>
      'Backups contain your full library — links, collections, tags, and metadata. They stay on your device.';

  @override
  String get deletedItemsRetention =>
      'Deleted items are kept for 30 days, then removed permanently the next time Glimpse runs cleanup.';

  @override
  String daysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get expiresToday => 'Expires today';

  @override
  String get restore => 'Restore';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get restoreAll => 'Restore all';

  @override
  String get emptyBin => 'Empty Bin';

  @override
  String get binActions => 'Bin actions';

  @override
  String get itemActions => 'Item actions';

  @override
  String get binIsEmpty => 'Bin is empty';

  @override
  String get binEmptyDescription =>
      'Items you delete will appear here for 30 days.';

  @override
  String get deleteAccountProWarning =>
      'This removes your Glimpse account metadata but does not cancel store billing. Pro cannot be moved to another Glimpse account, so manage your subscription before deleting. Your on-device library is not uploaded to Supabase.';

  @override
  String get deleteAccountFreeWarning =>
      'This removes your Glimpse account metadata. Your on-device library is not uploaded to Supabase.';

  @override
  String get details => 'Details';

  @override
  String openInSource(Object source) {
    return 'Open in $source';
  }

  @override
  String get summary => 'Summary';

  @override
  String get inBrief => 'In brief';

  @override
  String get fullExplanation => 'Full explanation';

  @override
  String get resourcesAndReferences => 'Resources & references';

  @override
  String get searchForResource => 'Search for this resource';

  @override
  String get rawSourceMaterial => 'Raw source material';

  @override
  String get addNote => 'Add note';

  @override
  String get keyTakeaways => 'Key Takeaways';

  @override
  String get fullBreakdown => 'Full breakdown';

  @override
  String get transcriptAndCaption => 'Transcript & Caption';

  @override
  String get caption => 'Caption';

  @override
  String get transcript => 'Transcript';

  @override
  String get onScreenText => 'On-screen text';

  @override
  String get peopleMentioned => 'People mentioned';

  @override
  String peopleMentionedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people mentioned',
      one: '1 person mentioned',
    );
    return '$_temp0';
  }

  @override
  String get alsoMentioned => 'Also mentioned';

  @override
  String get quotes => 'Quotes';

  @override
  String get tags => 'Tags';

  @override
  String get informationMayBeInaccurate => 'Information may be inaccurate';

  @override
  String get originalContentAttribution =>
      'Original content belongs to its creator.';

  @override
  String everyHours(Object count) {
    return 'Every $count hours';
  }

  @override
  String get weekly => 'Weekly';

  @override
  String get addTag => 'Add tag';

  @override
  String get changeCategory => 'Change category';

  @override
  String get worthWatching => 'Worth watching';

  @override
  String get worthReading => 'Worth reading';

  @override
  String get gamesMentioned => 'Games mentioned';

  @override
  String get musicMentioned => 'Music mentioned';

  @override
  String get toolsMentioned => 'Tools mentioned';

  @override
  String get worthALook => 'Worth a look';

  @override
  String get appsToTry => 'Apps to try';

  @override
  String get placesToVisit => 'Places to visit';

  @override
  String get websitesMentioned => 'Websites mentioned';

  @override
  String get claimsToRemember => 'Claims to remember';

  @override
  String get termsMentioned => 'Terms mentioned';

  @override
  String get notableDetails => 'Notable details';

  @override
  String get library => 'Library';

  @override
  String get libraryDescription =>
      'Books, movies, places & music found in your saves';

  @override
  String get buildsQuietly => 'Builds quietly as you save';

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String addedTime(Object time) {
    return 'Added · $time';
  }

  @override
  String get rediscoverIntentTitle => 'A few memories worth using';

  @override
  String chosenFromUnopened(Object count) {
    return 'Chosen from $count unopened saves and what matters now.';
  }

  @override
  String get chosenFromSaved =>
      'Chosen from what you saved, opened, and left for later.';

  @override
  String get todayStableSet => 'A stable set for today — no endless feed.';

  @override
  String get recaps => 'Recaps';

  @override
  String get recapsDescription =>
      'Weekly and monthly patterns from your own saves.';

  @override
  String get dailyRecap => 'Daily recap';

  @override
  String get monthlyRecap => 'Monthly recap';

  @override
  String recapSummary(num count, Object waiting) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saves',
      one: '1 save',
    );
    return '$_temp0 · $waiting waiting';
  }

  @override
  String get yourWeekInSaves => 'Your week in saves';

  @override
  String get yourMonthInMemories => 'Your month in memories';

  @override
  String topicKeptShowingUp(Object topic) {
    return '$topic kept showing up';
  }

  @override
  String get queued => 'Queued';

  @override
  String get forgottenGem => 'Forgotten gem';

  @override
  String get fromYourPast => 'From your past';

  @override
  String get rediscoverOptions => 'Rediscover options';

  @override
  String get notNow => 'Not now';

  @override
  String get hideFor7Days => 'Hide for 7 days';

  @override
  String get lessLikeThis => 'Less like this';

  @override
  String get reduceSimilarTopics => 'Reduce similar topics';

  @override
  String get nothingStrongToday => 'Nothing strong enough today';

  @override
  String get rediscoverQuiet =>
      'Rediscover will stay quiet until a save is genuinely worth bringing back.';

  @override
  String get searchYourLibrary => 'Search your library…';

  @override
  String get findAnythingSaved => 'Find anything you saved';

  @override
  String get searchEmptyDescription =>
      'Search across titles, tags, notes, and summaries — then narrow the view.';

  @override
  String get filters => 'Filters';

  @override
  String get filtersActive => 'Filters active';

  @override
  String get time => 'Time';

  @override
  String get allTime => 'All time';

  @override
  String get thisMonth => 'This month';

  @override
  String get status => 'Status';

  @override
  String get hasNotes => 'Has notes';

  @override
  String get noNotes => 'No notes';

  @override
  String get inCollection => 'In a collection';

  @override
  String get notInCollection => 'Not in a collection';

  @override
  String get specificCollection => 'Specific collection';

  @override
  String get sort => 'Sort';

  @override
  String get relevance => 'Relevance';

  @override
  String get newestSaved => 'Newest saved';

  @override
  String get oldestSaved => 'Oldest saved';

  @override
  String get learningInterests => 'Learning what keeps your attention';

  @override
  String get readingInterests => 'Reading your interests…';

  @override
  String get topSignal => 'Top signal';

  @override
  String get growingInterests => 'Growing interests';

  @override
  String get quieterInterests => 'Quieter interests';

  @override
  String interestStats(num patterns, num saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns patterns',
      one: '1 pattern',
    );
    String _temp1 = intl.Intl.pluralLogic(
      saves,
      locale: localeName,
      other: '$saves saves',
      one: '1 save',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String interestGroupedStats(Object grouped, num patterns, Object saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns patterns',
      one: '1 pattern',
    );
    return '$_temp0 · $grouped of $saves saves grouped';
  }

  @override
  String noPatternsScanned(Object saves) {
    return 'No patterns yet · $saves saves scanned';
  }

  @override
  String get rebuildMap => 'Rebuild map';

  @override
  String get couldNotBuildClusters => 'Could not build clusters';

  @override
  String get interestMapEmpty => 'Your interest map is empty';

  @override
  String get interestMapEmptyDescription =>
      'Save at least 3 links and Glimpse will connect recurring themes across them.';

  @override
  String lastAddedTime(Object time) {
    return 'Last added: $time';
  }

  @override
  String get hiddenFor7Days => 'Hidden for 7 days';

  @override
  String get seeLessLikeThis => 'You’ll see less like this';

  @override
  String get searchingLibrary => 'Searching your library…';

  @override
  String get semanticMatch => 'Semantic match';

  @override
  String get noMatchesForFilter => 'No matches for this filter';

  @override
  String get broadenSearch => 'Try another time range or broaden your search.';

  @override
  String get monthlyLimitReached => 'Monthly limit reached';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get monthlySearchLimitDescription =>
      'You\'ve reached your monthly search limit. Upgrade to Glimpse Pro for expanded search access.';

  @override
  String get openingInterest => 'Opening interest…';

  @override
  String get couldNotOpenInterest => 'Could not open this interest.';

  @override
  String get interestNotFound => 'Interest not found';

  @override
  String interestSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saves in this interest.',
      one: '1 save in this interest.',
    );
    return '$_temp0';
  }

  @override
  String interestTopicsSummary(Object count, Object topics) {
    return '$count saves across $topics topics';
  }

  @override
  String get reorderCollections => 'Reorder collections';

  @override
  String get dragToSetManualOrder => 'Drag to set your manual order';

  @override
  String movedToCollection(Object name) {
    return 'Moved to $name';
  }

  @override
  String movedLinksAndDeletedSources(num count, Object name, num sourceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sourceCount,
      locale: localeName,
      other: 'the source collections',
      one: 'the source collection',
    );
    return 'Moved $_temp0 to $name and deleted $_temp1';
  }

  @override
  String deleteCollectionNamed(Object name) {
    return 'Delete “$name”?';
  }

  @override
  String deleteCollectionsCount(Object count) {
    return 'Delete $count collections?';
  }

  @override
  String get deleteCollectionDescription =>
      'Its saved links will stay in your library. Only the collection will be removed.';

  @override
  String get deleteCollectionsDescription =>
      'Their saved links will stay in your library. Only the collections will be removed.';

  @override
  String collectionsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections deleted',
      one: 'Collection deleted',
    );
    return '$_temp0';
  }

  @override
  String get createFirstCollection => 'Create your first collection';

  @override
  String get collectionEmptyDescription =>
      'Group links into calm, focused spaces.';

  @override
  String get libraryBooks => 'Books';

  @override
  String get libraryMoviesShows => 'Movies & Shows';

  @override
  String get libraryPlaces => 'Places';

  @override
  String get libraryBook => 'Book';

  @override
  String get libraryMovie => 'Movie';

  @override
  String get libraryPlace => 'Place';

  @override
  String get libraryReadingList => 'Reading list';

  @override
  String get libraryWatchlist => 'Watchlist';

  @override
  String get libraryNotInReadingList => 'Not in reading list';

  @override
  String get libraryNotInWatchlist => 'Not in watchlist';

  @override
  String get libraryNotListed => 'Not listed';

  @override
  String get libraryPlanning => 'Planning';

  @override
  String get libraryReading => 'Reading';

  @override
  String get libraryWatching => 'Watching';

  @override
  String get libraryInProgress => 'In progress';

  @override
  String get libraryDropped => 'Dropped';

  @override
  String get libraryRead => 'Read';

  @override
  String get libraryWatched => 'Watched';

  @override
  String get libraryVisited => 'Visited';

  @override
  String libraryStatusSemantics(Object status) {
    return 'Status: $status';
  }

  @override
  String libraryReadingPageStatus(Object page) {
    return 'Reading · p. $page';
  }

  @override
  String get libraryGenreFantasy => 'Fantasy';

  @override
  String get libraryGenreScienceFiction => 'Science Fiction';

  @override
  String get libraryGenreMysteryThriller => 'Mystery & Thriller';

  @override
  String get libraryGenreRomance => 'Romance';

  @override
  String get libraryGenreHorror => 'Horror';

  @override
  String get libraryGenreBiographyMemoir => 'Biography & Memoir';

  @override
  String get libraryGenreHistory => 'History';

  @override
  String get libraryGenrePhilosophy => 'Philosophy';

  @override
  String get libraryGenrePsychology => 'Psychology';

  @override
  String get libraryGenreBusiness => 'Business';

  @override
  String get libraryGenreFinanceInvesting => 'Finance & Investing';

  @override
  String get libraryGenreTechnology => 'Technology';

  @override
  String get libraryGenreScience => 'Science';

  @override
  String get libraryGenreSelfDevelopment => 'Self-Development';

  @override
  String get libraryGenreHealthWellness => 'Health & Wellness';

  @override
  String get libraryGenrePoliticsSociety => 'Politics & Society';

  @override
  String get libraryGenreArtDesign => 'Art & Design';

  @override
  String get libraryGenreTravel => 'Travel';

  @override
  String get libraryGenreComicsGraphicNovels => 'Comics & Graphic Novels';

  @override
  String get libraryGenreFiction => 'Fiction';

  @override
  String get libraryGenreAction => 'Action';

  @override
  String get libraryGenreAdventure => 'Adventure';

  @override
  String get libraryGenreAnimation => 'Animation';

  @override
  String get libraryGenreComedy => 'Comedy';

  @override
  String get libraryGenreCrime => 'Crime';

  @override
  String get libraryGenreDocumentary => 'Documentary';

  @override
  String get libraryGenreDrama => 'Drama';

  @override
  String get libraryGenreFamily => 'Family';

  @override
  String get libraryGenreMystery => 'Mystery';

  @override
  String get libraryGenreThriller => 'Thriller';

  @override
  String get libraryGenreWar => 'War';

  @override
  String get libraryGenreWestern => 'Western';

  @override
  String get libraryGenreMusic => 'Music';

  @override
  String get libraryGenreOther => 'Other';

  @override
  String get librarySubtypeTvShow => 'TV Show';

  @override
  String get librarySubtypeSeries => 'Series';

  @override
  String get couldNotOpenLibrary => 'Could not open Library';

  @override
  String searchLibraryItems(Object kind) {
    return 'Search $kind';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get clearAll => 'Clear all';

  @override
  String get recentlyDiscovered => 'Recently discovered';

  @override
  String get titleAZ => 'Title A–Z';

  @override
  String get yearNewest => 'Year newest';

  @override
  String libraryOptions(Object kind) {
    return '$kind options';
  }

  @override
  String filterLibraryItems(Object kind) {
    return 'Filter $kind';
  }

  @override
  String get readingStatus => 'Reading status';

  @override
  String get watchStatus => 'Watch status';

  @override
  String get anyStatus => 'Any status';

  @override
  String get genre => 'Genre';

  @override
  String get allGenres => 'All genres';

  @override
  String get nothingMatchesFilters => 'Nothing matches these filters.';

  @override
  String get nothingRecognizedHere => 'Nothing recognized here yet.';

  @override
  String get couldNotUpdateLibraryItem => 'Could not update this Library item.';

  @override
  String get foundInYourSaves => 'Found in your saves';

  @override
  String get recognizedOrganizedByType => 'Automatically organized by type';

  @override
  String libraryBookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String libraryMovieCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titles',
      one: '1 title',
    );
    return '$_temp0';
  }

  @override
  String libraryPlaceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String libraryStopCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String get nothingRecognizedYet => 'Nothing recognized yet';

  @override
  String get recognizedTitlesGatherHere => 'Recognized titles will gather here';

  @override
  String recognizedCount(Object count) {
    return '$count recognized';
  }

  @override
  String get savedPlacesAppearOnMap => 'Saved places will appear on a map';

  @override
  String get addingDetails => 'Adding details';

  @override
  String get extraDetailsUnavailable =>
      'Extra details are temporarily unavailable';

  @override
  String itemsCouldNotRefresh(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items couldn’t be refreshed',
      one: '1 item couldn’t be refreshed',
    );
    return '$_temp0';
  }

  @override
  String progressOf(Object completed, Object total) {
    return '$completed of $total';
  }

  @override
  String get savedDetailsRemainAvailable => 'Saved details remain available';

  @override
  String waitingToRetry(Object count) {
    return '$count waiting to retry';
  }

  @override
  String get libraryBuildsAsYouSave => 'It builds as you save';

  @override
  String get libraryEmptyDescription =>
      'Save recommendations for books, movies, places, and music. Glimpse will organize the things inside them here.';

  @override
  String get libraryUnavailable => 'Library is unavailable right now';

  @override
  String get yourPlaces => 'Your places';

  @override
  String placesAreasSummary(num areas, num places) {
    String _temp0 = intl.Intl.pluralLogic(
      places,
      locale: localeName,
      other: '$places places',
      one: '1 place',
    );
    String _temp1 = intl.Intl.pluralLogic(
      areas,
      locale: localeName,
      other: '$areas areas',
      one: '1 area',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get planThisArea => 'Plan this area';

  @override
  String get planAnItinerary => 'Plan an itinerary';

  @override
  String get searchSavedPlaces => 'Search saved places';

  @override
  String get yourPlans => 'Your plans';

  @override
  String get plan => 'Plan';

  @override
  String get locationUnavailable => 'Location unavailable';

  @override
  String openNamedItem(Object name) {
    return 'Open $name';
  }

  @override
  String get wantToVisit => 'Want to visit';

  @override
  String get savedPlace => 'Saved place';

  @override
  String get planAVisit => 'Plan a visit';

  @override
  String get maps => 'Maps';

  @override
  String get noSavedPlacesMatch => 'No saved places match this search.';

  @override
  String get noPlacesDiscovered => 'No places discovered yet';

  @override
  String get placesMentionedGatherHere =>
      'Places mentioned in your saves will gather here.';

  @override
  String get fitAllPlaces => 'Fit all places';

  @override
  String get noMappedPlaces => 'No mapped places yet';

  @override
  String get mapUnavailablePlacesListed =>
      'Map unavailable — your places are still listed below';

  @override
  String get libraryItemUnavailable => 'This Library item is unavailable.';

  @override
  String get couldNotUpdateBookmark => 'Could not update your bookmark.';

  @override
  String hiddenFromLibrary(Object name) {
    return '$name hidden from Library';
  }

  @override
  String get libraryItemOptions => 'Library item options';

  @override
  String get hideFromLibrary => 'Hide from Library';

  @override
  String get addToReadingList => 'Add to your reading list';

  @override
  String get addToWatchlist => 'Add to your watchlist';

  @override
  String get removeFromReadingList => 'Remove from reading list';

  @override
  String get removeFromWatchlist => 'Remove from watchlist';

  @override
  String get whyItMattered => 'Why it mattered';

  @override
  String get plot => 'Plot';

  @override
  String get yourBookmark => 'Your bookmark';

  @override
  String get savePageYouAreOn => 'Save the page you’re on';

  @override
  String savePlaceAboutPages(Object count) {
    return 'Save your place · about $count pages';
  }

  @override
  String pageNumber(Object page) {
    return 'Page $page';
  }

  @override
  String pageAboutPages(Object count, Object page) {
    return 'Page $page · about $count pages';
  }

  @override
  String get setCurrentPage => 'Set current page';

  @override
  String get updatePage => 'Update page';

  @override
  String get updateYourBookmark => 'Update your bookmark';

  @override
  String aboutPages(Object count) {
    return 'about $count pages';
  }

  @override
  String get currentPage => 'Current page';

  @override
  String get enterPageNumber => 'Enter a page number';

  @override
  String get saveBookmark => 'Save bookmark';

  @override
  String get pageGreaterThanZero => 'Enter a page number greater than zero';

  @override
  String libraryItemSemantics(Object kind, Object title) {
    return '$kind: $title';
  }

  @override
  String libraryItemOpenHint(Object list) {
    return 'Double tap to open. Long press to change $list status.';
  }

  @override
  String get collectionEditSubtitle => 'Refine this saved space.';

  @override
  String get collectionCreateSubtitle =>
      'Create a focused space for saved ideas.';

  @override
  String get nameLabel => 'Name';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get collectionNameHint => 'Travel & Wanderlust';

  @override
  String get collectionDescriptionHint => 'Optional note for this space';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get nameCollectionError => 'Name your collection';

  @override
  String get duplicateCollectionError =>
      'A collection with this name already exists';

  @override
  String get deleteCollection => 'Delete collection';

  @override
  String get addLink => 'Add link';

  @override
  String get noLinksInCollection => 'No links in this collection yet.';

  @override
  String get notificationTravelPlaces => 'Travel & Places';

  @override
  String get notificationNewDiscovery => 'New Discovery';

  @override
  String get notificationReadingReminder => 'Reading Reminder';

  @override
  String get notificationActivity => 'Activity';

  @override
  String get notificationWorthRevisiting => 'Worth Revisiting';

  @override
  String get notificationRevisitReminder => 'Revisit Reminder';

  @override
  String get notificationWeeklyDigest => 'Weekly Digest';

  @override
  String get enrichmentNeedsAttention => 'Enrichment needs attention';

  @override
  String get aiDetailsAvailable => 'AI details available';

  @override
  String get enrich => 'Enrich';

  @override
  String get enriching => 'Enriching';

  @override
  String get messageGlimpse => 'Message Glimpse...';

  @override
  String get askAboutThisSave => 'Ask about this save...';

  @override
  String get sending => 'Sending...';

  @override
  String get send => 'Send';

  @override
  String get askGreetingEarlyMorning => 'Up early?';

  @override
  String get askGreetingMorning => 'Good morning.';

  @override
  String get askGreetingAfternoon => 'What are we exploring?';

  @override
  String get askGreetingEvening => 'Good evening.';

  @override
  String get askGreetingNight => 'Still curious tonight?';

  @override
  String get askGreetingLateNight => 'Up late again?';

  @override
  String get saveYourFirstLink => 'Save your first link';

  @override
  String get moreSelectionActions => 'More selection actions';

  @override
  String get moveToCollection => 'Move to collection';

  @override
  String get markRead => 'Mark read';

  @override
  String get markUnread => 'Mark unread';

  @override
  String get toggleReadStatus => 'Toggle read status';

  @override
  String get unpin => 'Unpin';

  @override
  String get yourNote => 'Your note';

  @override
  String get edit => 'Edit';

  @override
  String get notePrompt => 'What stood out to you?';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get noteSaving => 'Saving…';

  @override
  String get noteSaved => 'Saved';

  @override
  String get noteCouldNotSave => 'Couldn’t save';

  @override
  String get addYourNote => 'Add your note';

  @override
  String get showLess => 'Show less';

  @override
  String get showMore => 'Show more';

  @override
  String showAllCount(Object count) {
    return 'Show all $count';
  }

  @override
  String get answerCopied => 'Answer copied';

  @override
  String get deleteAskNoteQuestion => 'Delete Ask note?';

  @override
  String get deleteAskNoteDescription =>
      'This removes the saved answer from this link. Your own note is not affected.';

  @override
  String get askNoteDeleted => 'Ask note deleted';

  @override
  String get couldNotDeleteAskNote => 'Could not delete Ask note';

  @override
  String get askNoteActions => 'Ask note actions';

  @override
  String get copyAnswer => 'Copy answer';

  @override
  String get quickTryThisWeekend => 'Try This Weekend';

  @override
  String get quickNeedIngredients => 'Need Ingredients';

  @override
  String get quickShareWithSomeone => 'Share With Someone';

  @override
  String get quickAlreadyTried => 'Already Tried';

  @override
  String get quickWatchLater => 'Watch Later';

  @override
  String get quickAddToWatchlist => 'Add to Watchlist';

  @override
  String get quickAlreadyWatched => 'Already Watched';

  @override
  String get quickAddToReadingList => 'Add to Reading List';

  @override
  String get quickReadLater => 'Read Later';

  @override
  String get quickResearchThis => 'Research This';

  @override
  String get quickAlreadyRead => 'Already Read';

  @override
  String get quickTryThisTool => 'Try This Tool';

  @override
  String get quickCompareAlternatives => 'Compare Alternatives';

  @override
  String get quickUseInProject => 'Use in Project';

  @override
  String get quickShareWithTeam => 'Share With Team';

  @override
  String get quickPlanItinerary => 'Plan Itinerary';

  @override
  String get quickCheckBestSeason => 'Check Best Season';

  @override
  String get quickSaveRoute => 'Save Route';

  @override
  String get quickPracticeLater => 'Practice Later';

  @override
  String get quickMakeChecklist => 'Make Checklist';

  @override
  String get quickRevisitNotes => 'Revisit Notes';

  @override
  String get quickRevisitLater => 'Revisit Later';

  @override
  String get quickWorthTrying => 'Worth Trying';

  @override
  String get quickAlreadyChecked => 'Already Checked';

  @override
  String get aboutTagline => 'Save something worth keeping';

  @override
  String versionBuild(Object build, Object version) {
    return 'Version $version (Build $build)';
  }

  @override
  String get loadingVersion => 'Loading version…';

  @override
  String get legal => 'Legal';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get help => 'Help';

  @override
  String get faq => 'FAQ';

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String get rateOnPlayStore => 'Rate on Play Store';

  @override
  String get shareGlimpse => 'Share Glimpse';

  @override
  String get feedbackEmailSubject => 'Glimpse feedback';

  @override
  String shareGlimpseText(Object url) {
    return 'Glimpse helps you save links worth returning to. Try it: $url';
  }

  @override
  String get couldNotOpenLink => 'Could not open this link.';

  @override
  String get couldNotShareGlimpse => 'Could not share Glimpse.';

  @override
  String get keepsakeQuoteCuriosity => 'Keep the things that keep you curious.';

  @override
  String get keepsakeQuoteIdea => 'A small glimpse can become a lasting idea.';

  @override
  String get keepsakeQuoteSpark => 'Save the spark. Return when it matters.';

  @override
  String get keepsakeQuoteFutureSelf =>
      'Your future self might be looking for this.';

  @override
  String get keepsakeQuoteNoticing => 'Worth noticing. Worth keeping.';

  @override
  String get other => 'Other';

  @override
  String get shareBackup => 'Share backup';

  @override
  String get shareBackupDescription =>
      'Send a backup to another app or cloud service';

  @override
  String backupSavedLinksTo(num count, Object location) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    return 'Saved $_temp0 to $location';
  }

  @override
  String backupSavedTo(Object location) {
    return 'Backup saved to $location';
  }

  @override
  String get errorDetails => 'Error details';

  @override
  String get copy => 'Copy';

  @override
  String get couldNotReadSelectedFile => 'Could not read the selected file.';

  @override
  String get folderSelected => 'Folder selected';

  @override
  String get couldNotSaveFolderPermission =>
      'Could not save folder permission. Please try again.';

  @override
  String get permanentBackupFolderAndroid =>
      'Permanent backup folder is available on Android';

  @override
  String get tapToChange => 'Tap to change';

  @override
  String get forgetFolder => 'Forget folder';

  @override
  String get autoBackupAndroidOnly =>
      'Auto backup runs on Android when a storage folder is set';

  @override
  String lastAutomaticBackup(Object time) {
    return 'Last automatic backup: $time';
  }

  @override
  String lastBackupAttemptFailed(Object time) {
    return 'Last attempt failed $time. Glimpse will retry automatically.';
  }

  @override
  String get setStorageBeforeAutoBackup =>
      'Set a storage location above before automatic backups can run.';

  @override
  String get folderBackup => 'Folder backup';

  @override
  String lastSavedToFolder(Object time) {
    return 'Last saved to folder: $time';
  }

  @override
  String get noBackupFileInFolder =>
      'No backup file in this folder yet. Use Create backup above after picking this location.';
}
