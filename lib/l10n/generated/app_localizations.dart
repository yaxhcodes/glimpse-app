import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('pt'),
  ];

  /// No description provided for @musicDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some song details could not be loaded.'**
  String get musicDetailsUnavailable;

  /// No description provided for @loadingMusicDetails.
  ///
  /// In en, this message translates to:
  /// **'Loading song details…'**
  String get loadingMusicDetails;

  /// No description provided for @couldNotSaveMusicProvider.
  ///
  /// In en, this message translates to:
  /// **'Could not save your music app. Please try again.'**
  String get couldNotSaveMusicProvider;

  /// No description provided for @libraryMusicEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Songs found in your saved links will appear here.'**
  String get libraryMusicEmptyDescription;

  /// No description provided for @libraryMusicDescription.
  ///
  /// In en, this message translates to:
  /// **'Songs found in your saves'**
  String get libraryMusicDescription;

  /// No description provided for @libraryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get libraryMusic;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Glimpse'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @askGlimpse.
  ///
  /// In en, this message translates to:
  /// **'Ask Glimpse'**
  String get askGlimpse;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @accountAndPlan.
  ///
  /// In en, this message translates to:
  /// **'Account & plan'**
  String get accountAndPlan;

  /// No description provided for @personalization.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get personalization;

  /// No description provided for @lookAndFeel.
  ///
  /// In en, this message translates to:
  /// **'Look & Feel'**
  String get lookAndFeel;

  /// No description provided for @themeAndAccent.
  ///
  /// In en, this message translates to:
  /// **'Theme and accent color'**
  String get themeAndAccent;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languagePortugueseBrazil.
  ///
  /// In en, this message translates to:
  /// **'Portuguese (Brazil)'**
  String get languagePortugueseBrazil;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @musicApp.
  ///
  /// In en, this message translates to:
  /// **'Music app'**
  String get musicApp;

  /// No description provided for @chooseWhereSongsOpen.
  ///
  /// In en, this message translates to:
  /// **'Choose where songs open'**
  String get chooseWhereSongsOpen;

  /// No description provided for @loadingPreference.
  ///
  /// In en, this message translates to:
  /// **'Loading preference'**
  String get loadingPreference;

  /// No description provided for @libraryGestures.
  ///
  /// In en, this message translates to:
  /// **'Library gestures'**
  String get libraryGestures;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @privacyAndData.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyAndData;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What stays local and what is uploaded'**
  String get privacySubtitle;

  /// No description provided for @dataAndBackup.
  ///
  /// In en, this message translates to:
  /// **'Data & Backup'**
  String get dataAndBackup;

  /// No description provided for @dataAndBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect and restore your saved knowledge'**
  String get dataAndBackupSubtitle;

  /// No description provided for @bin.
  ///
  /// In en, this message translates to:
  /// **'Bin'**
  String get bin;

  /// No description provided for @binSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted items are kept for 30 days'**
  String get binSubtitle;

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// No description provided for @clearAllDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all saved links'**
  String get clearAllDataSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutGlimpse.
  ///
  /// In en, this message translates to:
  /// **'About Glimpse'**
  String get aboutGlimpse;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, legal & help'**
  String get aboutSubtitle;

  /// No description provided for @accountActions.
  ///
  /// In en, this message translates to:
  /// **'Account actions'**
  String get accountActions;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this device'**
  String get logOutSubtitle;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get deleteAccountSubtitle;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get deletingAccount;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @clearAllDataQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data?'**
  String get clearAllDataQuestion;

  /// No description provided for @clearAllDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all saved URLs. This cannot be undone.'**
  String get clearAllDataWarning;

  /// No description provided for @allDataCleared.
  ///
  /// In en, this message translates to:
  /// **'All data cleared'**
  String get allDataCleared;

  /// No description provided for @logOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutQuestion;

  /// No description provided for @logOutWarning.
  ///
  /// In en, this message translates to:
  /// **'You’ll need to sign in again to access your Glimpse account.'**
  String get logOutWarning;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountQuestion;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get manageSubscription;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @manageYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Manage your plan'**
  String get manageYourPlan;

  /// No description provided for @checkingSaveAllowance.
  ///
  /// In en, this message translates to:
  /// **'Checking save allowance'**
  String get checkingSaveAllowance;

  /// No description provided for @aiSavesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 lifetime AI save left} other{{count} lifetime AI saves left}}'**
  String aiSavesLeft(num count);

  /// No description provided for @captureBody.
  ///
  /// In en, this message translates to:
  /// **'We’ll notify you when it’s ready.'**
  String get captureBody;

  /// No description provided for @captureQueuedWithoutNotifications.
  ///
  /// In en, this message translates to:
  /// **'It’ll be ready in Glimpse.'**
  String get captureQueuedWithoutNotifications;

  /// No description provided for @captureSchedulingFallback.
  ///
  /// In en, this message translates to:
  /// **'Saved. Open Glimpse to finish organizing it.'**
  String get captureSchedulingFallback;

  /// No description provided for @captureCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save this link'**
  String get captureCouldNotSave;

  /// No description provided for @savedToCollection.
  ///
  /// In en, this message translates to:
  /// **'Saved to {collectionName}'**
  String savedToCollection(String collectionName);

  /// No description provided for @savedWithoutAi.
  ///
  /// In en, this message translates to:
  /// **'Saved without AI enrichment'**
  String get savedWithoutAi;

  /// No description provided for @aiLimitBody.
  ///
  /// In en, this message translates to:
  /// **'You’ve used your 30 lifetime AI saves. Tap to upgrade.'**
  String get aiLimitBody;

  /// No description provided for @proAiLimitBody.
  ///
  /// In en, this message translates to:
  /// **'You’ve used 500 AI saves this month. Your link was saved without AI enrichment.'**
  String get proAiLimitBody;

  /// No description provided for @alreadyInYourWorld.
  ///
  /// In en, this message translates to:
  /// **'Already in your world.'**
  String get alreadyInYourWorld;

  /// No description provided for @enrichmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t finish enrichment'**
  String get enrichmentFailed;

  /// No description provided for @tapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry this save.'**
  String get tapToRetry;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @addUrl.
  ///
  /// In en, this message translates to:
  /// **'Add URL'**
  String get addUrl;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// No description provided for @captured.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get captured;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @alreadyInGlimpse.
  ///
  /// In en, this message translates to:
  /// **'Already in Glimpse'**
  String get alreadyInGlimpse;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @exitSelection.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get exitSelection;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @viewAllSources.
  ///
  /// In en, this message translates to:
  /// **'View all sources'**
  String get viewAllSources;

  /// No description provided for @pasteLink.
  ///
  /// In en, this message translates to:
  /// **'Paste a link…'**
  String get pasteLink;

  /// No description provided for @dismissClipboardSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Dismiss clipboard suggestion'**
  String get dismissClipboardSuggestion;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @editCollection.
  ///
  /// In en, this message translates to:
  /// **'Edit collection'**
  String get editCollection;

  /// No description provided for @moveContents.
  ///
  /// In en, this message translates to:
  /// **'Move contents'**
  String get moveContents;

  /// No description provided for @deleteSelectedCollections.
  ///
  /// In en, this message translates to:
  /// **'Delete selected collections'**
  String get deleteSelectedCollections;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @collectionOptions.
  ///
  /// In en, this message translates to:
  /// **'Collection options'**
  String get collectionOptions;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @alphabetical.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get alphabetical;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @capturing.
  ///
  /// In en, this message translates to:
  /// **'Capturing…'**
  String get capturing;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @addToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get addToCollection;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @categoryTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get categoryTechnology;

  /// No description provided for @categoryBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get categoryBusiness;

  /// No description provided for @categoryFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get categoryFinance;

  /// No description provided for @categoryScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get categoryScience;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get categoryNews;

  /// No description provided for @categoryDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get categoryDesign;

  /// No description provided for @categoryHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get categoryHistory;

  /// No description provided for @categoryPhilosophy.
  ///
  /// In en, this message translates to:
  /// **'Philosophy'**
  String get categoryPhilosophy;

  /// No description provided for @categoryNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get categoryNature;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get categoryLifestyle;

  /// No description provided for @categorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categorySports;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(Object count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(Object count);

  /// No description provided for @smartNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Smart notifications about your saved links'**
  String get smartNotificationsDescription;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @notificationFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationFallbackTitle;

  /// No description provided for @newNotificationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new notification} other{{count} new notifications}}'**
  String newNotificationCount(num count);

  /// No description provided for @captureSomethingWorthReturning.
  ///
  /// In en, this message translates to:
  /// **'Capture something worth returning to'**
  String get captureSomethingWorthReturning;

  /// No description provided for @captureContextAfter.
  ///
  /// In en, this message translates to:
  /// **'Glimpse will find the context after you capture it.'**
  String get captureContextAfter;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @detectedFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Detected from clipboard'**
  String get detectedFromClipboard;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @noCollection.
  ///
  /// In en, this message translates to:
  /// **'No Collection'**
  String get noCollection;

  /// No description provided for @savingTo.
  ///
  /// In en, this message translates to:
  /// **'Saving to'**
  String get savingTo;

  /// No description provided for @chooseCollection.
  ///
  /// In en, this message translates to:
  /// **'Choose collection'**
  String get chooseCollection;

  /// No description provided for @chooseACollection.
  ///
  /// In en, this message translates to:
  /// **'Choose a collection'**
  String get chooseACollection;

  /// No description provided for @processingLink.
  ///
  /// In en, this message translates to:
  /// **'Processing link…'**
  String get processingLink;

  /// No description provided for @couldNotLoadCollections.
  ///
  /// In en, this message translates to:
  /// **'Could not load collections.'**
  String get couldNotLoadCollections;

  /// No description provided for @linkCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No links} =1{1 link} other{{count} links}}'**
  String linkCount(num count);

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @addNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get addNoteOptional;

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get pleaseEnterUrl;

  /// No description provided for @couldNotCaptureLink.
  ///
  /// In en, this message translates to:
  /// **'Could not capture this link'**
  String get couldNotCaptureLink;

  /// No description provided for @findingSavedVersion.
  ///
  /// In en, this message translates to:
  /// **'Finding the saved version…'**
  String get findingSavedVersion;

  /// No description provided for @openSavedItem.
  ///
  /// In en, this message translates to:
  /// **'Open saved item'**
  String get openSavedItem;

  /// No description provided for @collectionSelection.
  ///
  /// In en, this message translates to:
  /// **'Collection, {collectionName}'**
  String collectionSelection(String collectionName);

  /// No description provided for @capturedInGlimpse.
  ///
  /// In en, this message translates to:
  /// **'Captured in Glimpse'**
  String get capturedInGlimpse;

  /// No description provided for @firstCapturedReady.
  ///
  /// In en, this message translates to:
  /// **'Your first captured item is ready below.'**
  String get firstCapturedReady;

  /// No description provided for @shareAnyApp.
  ///
  /// In en, this message translates to:
  /// **'Share from any app — Glimpse sorts it for you.'**
  String get shareAnyApp;

  /// No description provided for @howGlimpseWorks.
  ///
  /// In en, this message translates to:
  /// **'How Glimpse works'**
  String get howGlimpseWorks;

  /// No description provided for @capturingWhatCaughtYourEye.
  ///
  /// In en, this message translates to:
  /// **'Capturing what caught your eye'**
  String get capturingWhatCaughtYourEye;

  /// No description provided for @findingContext.
  ///
  /// In en, this message translates to:
  /// **'Finding the context'**
  String get findingContext;

  /// No description provided for @invalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid link'**
  String get invalidLink;

  /// No description provided for @rediscover.
  ///
  /// In en, this message translates to:
  /// **'Rediscover'**
  String get rediscover;

  /// No description provided for @rediscoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Worth picking back up'**
  String get rediscoverSubtitle;

  /// No description provided for @rediscoverTip.
  ///
  /// In en, this message translates to:
  /// **'Rediscover chooses a few memories worth returning to each day.'**
  String get rediscoverTip;

  /// No description provided for @dismissRediscoverTip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss Rediscover tip'**
  String get dismissRediscoverTip;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @recentSaves.
  ///
  /// In en, this message translates to:
  /// **'Recent Saves'**
  String get recentSaves;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String weeksAgo(Object count);

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}mo ago'**
  String monthsAgo(Object count);

  /// No description provided for @yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}y ago'**
  String yearsAgo(Object count);

  /// No description provided for @retrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get retrying;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @processingSavedHeadline.
  ///
  /// In en, this message translates to:
  /// **'Saved to your library'**
  String get processingSavedHeadline;

  /// No description provided for @processingSavedDetail.
  ///
  /// In en, this message translates to:
  /// **'Waiting to understand your save'**
  String get processingSavedDetail;

  /// No description provided for @processingOpeningHeadline.
  ///
  /// In en, this message translates to:
  /// **'Opening the content'**
  String get processingOpeningHeadline;

  /// No description provided for @processingOpeningDetail.
  ///
  /// In en, this message translates to:
  /// **'Checking what this save contains'**
  String get processingOpeningDetail;

  /// No description provided for @processingReadingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Reading the {content}'**
  String processingReadingHeadline(String content);

  /// No description provided for @processingExtractingDetail.
  ///
  /// In en, this message translates to:
  /// **'Pulling out the useful details'**
  String get processingExtractingDetail;

  /// No description provided for @processingUnderstoodHeadline.
  ///
  /// In en, this message translates to:
  /// **'Content understood'**
  String get processingUnderstoodHeadline;

  /// No description provided for @processingUnderstoodDetail.
  ///
  /// In en, this message translates to:
  /// **'Turning content into a useful save'**
  String get processingUnderstoodDetail;

  /// No description provided for @processingFindingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Finding what matters'**
  String get processingFindingHeadline;

  /// No description provided for @processingFindingDetail.
  ///
  /// In en, this message translates to:
  /// **'Finding the ideas that matter most'**
  String get processingFindingDetail;

  /// No description provided for @processingConnectingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Connecting the dots'**
  String get processingConnectingHeadline;

  /// No description provided for @processingConnectingDetail.
  ///
  /// In en, this message translates to:
  /// **'Connecting this with related saves'**
  String get processingConnectingDetail;

  /// No description provided for @processingFinishingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Finishing your save'**
  String get processingFinishingHeadline;

  /// No description provided for @processingFinishingDetail.
  ///
  /// In en, this message translates to:
  /// **'Finishing search and rediscovery'**
  String get processingFinishingDetail;

  /// No description provided for @processingRetryHeadline.
  ///
  /// In en, this message translates to:
  /// **'Trying that step again'**
  String get processingRetryHeadline;

  /// No description provided for @processingRetryDetail.
  ///
  /// In en, this message translates to:
  /// **'Trying this processing step again'**
  String get processingRetryDetail;

  /// No description provided for @processingFailedHeadline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish processing'**
  String get processingFailedHeadline;

  /// No description provided for @processingFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your save is safe. Try processing again'**
  String get processingFailedDetail;

  /// No description provided for @processingDefaultHeadline.
  ///
  /// In en, this message translates to:
  /// **'Understanding this save'**
  String get processingDefaultHeadline;

  /// No description provided for @processingDefaultDetail.
  ///
  /// In en, this message translates to:
  /// **'Finding the ideas worth keeping'**
  String get processingDefaultDetail;

  /// No description provided for @processingContentReel.
  ///
  /// In en, this message translates to:
  /// **'reel'**
  String get processingContentReel;

  /// No description provided for @processingContentVideo.
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get processingContentVideo;

  /// No description provided for @processingContentPin.
  ///
  /// In en, this message translates to:
  /// **'pin'**
  String get processingContentPin;

  /// No description provided for @processingContentPage.
  ///
  /// In en, this message translates to:
  /// **'page'**
  String get processingContentPage;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @openOriginal.
  ///
  /// In en, this message translates to:
  /// **'Open Original'**
  String get openOriginal;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @enrichmentComplete.
  ///
  /// In en, this message translates to:
  /// **'Enrichment complete'**
  String get enrichmentComplete;

  /// No description provided for @couldNotEnrichSave.
  ///
  /// In en, this message translates to:
  /// **'Could not enrich this save'**
  String get couldNotEnrichSave;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get allSources;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @apps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get apps;

  /// No description provided for @websites.
  ///
  /// In en, this message translates to:
  /// **'Websites'**
  String get websites;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @topSources.
  ///
  /// In en, this message translates to:
  /// **'Top sources'**
  String get topSources;

  /// No description provided for @searchSources.
  ///
  /// In en, this message translates to:
  /// **'Search apps, sites, and domains…'**
  String get searchSources;

  /// No description provided for @filterSources.
  ///
  /// In en, this message translates to:
  /// **'Filter sources'**
  String get filterSources;

  /// No description provided for @couldNotLoadSources.
  ///
  /// In en, this message translates to:
  /// **'Could not load sources'**
  String get couldNotLoadSources;

  /// No description provided for @noSourcesMatch.
  ///
  /// In en, this message translates to:
  /// **'No sources match \"{query}\"'**
  String noSourcesMatch(String query);

  /// No description provided for @noSavesFromApps.
  ///
  /// In en, this message translates to:
  /// **'No saves from apps yet'**
  String get noSavesFromApps;

  /// No description provided for @noWebsiteSaves.
  ///
  /// In en, this message translates to:
  /// **'No website saves yet'**
  String get noWebsiteSaves;

  /// No description provided for @noSourcesYet.
  ///
  /// In en, this message translates to:
  /// **'No sources yet'**
  String get noSourcesYet;

  /// No description provided for @noSavesYet.
  ///
  /// In en, this message translates to:
  /// **'No saves yet'**
  String get noSavesYet;

  /// No description provided for @saveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 save} other{{count} saves}}'**
  String saveCount(num count);

  /// No description provided for @savesThisWeek.
  ///
  /// In en, this message translates to:
  /// **'+{count} this week'**
  String savesThisWeek(Object count);

  /// No description provided for @growing.
  ///
  /// In en, this message translates to:
  /// **'Growing'**
  String get growing;

  /// No description provided for @lastSaved.
  ///
  /// In en, this message translates to:
  /// **'Last saved {time}'**
  String lastSaved(String time);

  /// No description provided for @leftSwipe.
  ///
  /// In en, this message translates to:
  /// **'Left swipe'**
  String get leftSwipe;

  /// No description provided for @rightSwipe.
  ///
  /// In en, this message translates to:
  /// **'Right swipe'**
  String get rightSwipe;

  /// No description provided for @chooseSwipeAction.
  ///
  /// In en, this message translates to:
  /// **'Choose swipe action'**
  String get chooseSwipeAction;

  /// No description provided for @markReadUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark Read / Unread'**
  String get markReadUnread;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @smartNotifications.
  ///
  /// In en, this message translates to:
  /// **'Smart notifications'**
  String get smartNotifications;

  /// No description provided for @behaviorBasedAlerts.
  ///
  /// In en, this message translates to:
  /// **'Behavior-based alerts'**
  String get behaviorBasedAlerts;

  /// No description provided for @whereDoYouListen.
  ///
  /// In en, this message translates to:
  /// **'Where do you listen?'**
  String get whereDoYouListen;

  /// No description provided for @chooseMusicProvider.
  ///
  /// In en, this message translates to:
  /// **'Choose the app Glimpse should use for songs you find.'**
  String get chooseMusicProvider;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @brightnessDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose when to use light or dark colors.'**
  String get brightnessDescription;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @amoledBlack.
  ///
  /// In en, this message translates to:
  /// **'AMOLED black'**
  String get amoledBlack;

  /// No description provided for @amoledUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Available when not using light theme.'**
  String get amoledUnavailable;

  /// No description provided for @amoledDescription.
  ///
  /// In en, this message translates to:
  /// **'Pure black backgrounds on OLED — saves power.'**
  String get amoledDescription;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @dynamicAccentDescription.
  ///
  /// In en, this message translates to:
  /// **'Dynamic uses your wallpaper palette on supported devices.'**
  String get dynamicAccentDescription;

  /// No description provided for @selectedAccent.
  ///
  /// In en, this message translates to:
  /// **'Selected: {accent}'**
  String selectedAccent(String accent);

  /// No description provided for @themePreview.
  ///
  /// In en, this message translates to:
  /// **'Theme preview'**
  String get themePreview;

  /// No description provided for @themePreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Accent and surfaces update from your choices below.'**
  String get themePreviewDescription;

  /// No description provided for @accentDynamic.
  ///
  /// In en, this message translates to:
  /// **'Dynamic'**
  String get accentDynamic;

  /// No description provided for @accentPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get accentPurple;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentLime.
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get accentLime;

  /// No description provided for @accentYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get accentYellow;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get accentRed;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// No description provided for @accentSakura.
  ///
  /// In en, this message translates to:
  /// **'Sakura'**
  String get accentSakura;

  /// No description provided for @accentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// No description provided for @accentSlate.
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get accentSlate;

  /// No description provided for @accentMonochrome.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get accentMonochrome;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @notificationsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Travel alerts, new discoveries, reading reminders, and weekly digests will appear here.'**
  String get notificationsEmptyDescription;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get ready;

  /// No description provided for @waitingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 waiting} other{{count} waiting}}'**
  String waitingCount(num count);

  /// No description provided for @backInView.
  ///
  /// In en, this message translates to:
  /// **'Back in view'**
  String get backInView;

  /// No description provided for @couldNotLoadSource.
  ///
  /// In en, this message translates to:
  /// **'Could not load this source'**
  String get couldNotLoadSource;

  /// No description provided for @noSavesFromSource.
  ///
  /// In en, this message translates to:
  /// **'No saves from this source'**
  String get noSavesFromSource;

  /// No description provided for @saves.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get saves;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @opened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get opened;

  /// No description provided for @topThemes.
  ///
  /// In en, this message translates to:
  /// **'Top themes'**
  String get topThemes;

  /// No description provided for @allItems.
  ///
  /// In en, this message translates to:
  /// **'All items'**
  String get allItems;

  /// No description provided for @oldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// No description provided for @recentlyOpened.
  ///
  /// In en, this message translates to:
  /// **'Recently opened'**
  String get recentlyOpened;

  /// No description provided for @showItems.
  ///
  /// In en, this message translates to:
  /// **'Show items'**
  String get showItems;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @noItemsFromSource.
  ///
  /// In en, this message translates to:
  /// **'No items from this source'**
  String get noItemsFromSource;

  /// No description provided for @noUnreadItems.
  ///
  /// In en, this message translates to:
  /// **'No unread items'**
  String get noUnreadItems;

  /// No description provided for @noReadItems.
  ///
  /// In en, this message translates to:
  /// **'No read items'**
  String get noReadItems;

  /// No description provided for @lastSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last saved'**
  String get lastSavedLabel;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @couldNotLoadSubscription.
  ///
  /// In en, this message translates to:
  /// **'Could not load subscription info'**
  String get couldNotLoadSubscription;

  /// No description provided for @coreLibrary.
  ///
  /// In en, this message translates to:
  /// **'Core Library'**
  String get coreLibrary;

  /// No description provided for @unlimitedLinkSaving.
  ///
  /// In en, this message translates to:
  /// **'Unlimited link saving'**
  String get unlimitedLinkSaving;

  /// No description provided for @unlimitedLinkSavingDescription.
  ///
  /// In en, this message translates to:
  /// **'Save as many links as you want'**
  String get unlimitedLinkSavingDescription;

  /// No description provided for @collectionsOrganization.
  ///
  /// In en, this message translates to:
  /// **'Collections & organization'**
  String get collectionsOrganization;

  /// No description provided for @collectionsOrganizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Group and manage bookmarks your way'**
  String get collectionsOrganizationDescription;

  /// No description provided for @smartNotificationsLongDescription.
  ///
  /// In en, this message translates to:
  /// **'Behavior-based alerts and reading reminders'**
  String get smartNotificationsLongDescription;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @aiTaggingCategorization.
  ///
  /// In en, this message translates to:
  /// **'AI tagging & categorization'**
  String get aiTaggingCategorization;

  /// No description provided for @freeSavesProUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Free: 30 lifetime AI saves · Pro: 500 / mo'**
  String get freeSavesProUnlimited;

  /// No description provided for @keywordSearch.
  ///
  /// In en, this message translates to:
  /// **'Keyword search'**
  String get keywordSearch;

  /// No description provided for @freeSearchesProUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Free: 30 searches / mo · Pro: Expanded access'**
  String get freeSearchesProUnlimited;

  /// No description provided for @askYourBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Ask Your Bookmarks'**
  String get askYourBookmarks;

  /// No description provided for @freeQuestionsProUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Free: 30 questions / mo · Pro: Generous fair use'**
  String get freeQuestionsProUnlimited;

  /// No description provided for @proInsights.
  ///
  /// In en, this message translates to:
  /// **'Pro Insights'**
  String get proInsights;

  /// No description provided for @semanticSearch.
  ///
  /// In en, this message translates to:
  /// **'Semantic search'**
  String get semanticSearch;

  /// No description provided for @semanticSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Find links by meaning, not just words'**
  String get semanticSearchDescription;

  /// No description provided for @weeklyRecap.
  ///
  /// In en, this message translates to:
  /// **'Weekly Recap'**
  String get weeklyRecap;

  /// No description provided for @weeklyRecapDescription.
  ///
  /// In en, this message translates to:
  /// **'AI-generated summary of your saved links'**
  String get weeklyRecapDescription;

  /// No description provided for @multiLinkSynthesis.
  ///
  /// In en, this message translates to:
  /// **'Multi-Link Synthesis'**
  String get multiLinkSynthesis;

  /// No description provided for @multiLinkSynthesisDescription.
  ///
  /// In en, this message translates to:
  /// **'Cross-analyze any set of bookmarks'**
  String get multiLinkSynthesisDescription;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @proPlanDescription.
  ///
  /// In en, this message translates to:
  /// **'500 AI-enriched saves each month, plus expanded Ask and search access across your library.'**
  String get proPlanDescription;

  /// No description provided for @proPlanDevDescription.
  ///
  /// In en, this message translates to:
  /// **'500 AI-enriched saves each month, plus expanded Ask and search access. (dev override; store: Free)'**
  String get proPlanDevDescription;

  /// No description provided for @freePlanDescription.
  ///
  /// In en, this message translates to:
  /// **'Save links without limits and explore AI with 30 lifetime enriched saves before upgrading.'**
  String get freePlanDescription;

  /// No description provided for @upgradeToGlimpsePro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Glimpse Pro'**
  String get upgradeToGlimpsePro;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @manageOnGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Manage on Google Play'**
  String get manageOnGooglePlay;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @aiSummaries.
  ///
  /// In en, this message translates to:
  /// **'AI summaries'**
  String get aiSummaries;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get accountInformation;

  /// No description provided for @subscriptionStatus.
  ///
  /// In en, this message translates to:
  /// **'Subscription status'**
  String get subscriptionStatus;

  /// No description provided for @anonymousProductAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Anonymous product analytics'**
  String get anonymousProductAnalytics;

  /// No description provided for @storageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage location'**
  String get storageLocation;

  /// No description provided for @pickAFolder.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder'**
  String get pickAFolder;

  /// No description provided for @chooseBackupFolderDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose where backups are stored'**
  String get chooseBackupFolderDescription;

  /// No description provided for @backupFolderInfo.
  ///
  /// In en, this message translates to:
  /// **'Used for saving your backup files. Pick a folder once and Glimpse will keep writing new backups there.'**
  String get backupFolderInfo;

  /// No description provided for @automaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get automaticBackup;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @backupFrequencyDescription.
  ///
  /// In en, this message translates to:
  /// **'How often to save a backup to your storage location'**
  String get backupFrequencyDescription;

  /// No description provided for @backupSensitiveInfo.
  ///
  /// In en, this message translates to:
  /// **'Keep copies of backups in other places as well. Backups can include your full library — treat them as sensitive if you share files.'**
  String get backupSensitiveInfo;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backupAndRestore;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackup;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {time}'**
  String lastBackup(Object time);

  /// No description provided for @backupLocalInfo.
  ///
  /// In en, this message translates to:
  /// **'Backups contain your full library — links, collections, tags, and metadata. They stay on your device.'**
  String get backupLocalInfo;

  /// No description provided for @deletedItemsRetention.
  ///
  /// In en, this message translates to:
  /// **'Deleted items are kept for 30 days, then removed permanently the next time Glimpse runs cleanup.'**
  String get deletedItemsRetention;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String daysLeft(num count);

  /// No description provided for @expiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get expiresToday;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;

  /// No description provided for @restoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get restoreAll;

  /// No description provided for @emptyBin.
  ///
  /// In en, this message translates to:
  /// **'Empty Bin'**
  String get emptyBin;

  /// No description provided for @binActions.
  ///
  /// In en, this message translates to:
  /// **'Bin actions'**
  String get binActions;

  /// No description provided for @itemActions.
  ///
  /// In en, this message translates to:
  /// **'Item actions'**
  String get itemActions;

  /// No description provided for @binIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Bin is empty'**
  String get binIsEmpty;

  /// No description provided for @binEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Items you delete will appear here for 30 days.'**
  String get binEmptyDescription;

  /// No description provided for @deleteAccountProWarning.
  ///
  /// In en, this message translates to:
  /// **'This removes your Glimpse account metadata but does not cancel store billing. Pro cannot be moved to another Glimpse account, so manage your subscription before deleting. Your on-device library is not uploaded to Supabase.'**
  String get deleteAccountProWarning;

  /// No description provided for @deleteAccountFreeWarning.
  ///
  /// In en, this message translates to:
  /// **'This removes your Glimpse account metadata. Your on-device library is not uploaded to Supabase.'**
  String get deleteAccountFreeWarning;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @openInSource.
  ///
  /// In en, this message translates to:
  /// **'Open in {source}'**
  String openInSource(Object source);

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @inBrief.
  ///
  /// In en, this message translates to:
  /// **'In brief'**
  String get inBrief;

  /// No description provided for @fullExplanation.
  ///
  /// In en, this message translates to:
  /// **'Full explanation'**
  String get fullExplanation;

  /// No description provided for @resourcesAndReferences.
  ///
  /// In en, this message translates to:
  /// **'Resources & references'**
  String get resourcesAndReferences;

  /// No description provided for @searchForResource.
  ///
  /// In en, this message translates to:
  /// **'Search for this resource'**
  String get searchForResource;

  /// No description provided for @rawSourceMaterial.
  ///
  /// In en, this message translates to:
  /// **'Raw source material'**
  String get rawSourceMaterial;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @keyTakeaways.
  ///
  /// In en, this message translates to:
  /// **'Key takeaways'**
  String get keyTakeaways;

  /// No description provided for @fullBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Full breakdown'**
  String get fullBreakdown;

  /// No description provided for @transcriptAndCaption.
  ///
  /// In en, this message translates to:
  /// **'Transcript & Caption'**
  String get transcriptAndCaption;

  /// No description provided for @caption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get caption;

  /// No description provided for @transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcript;

  /// No description provided for @onScreenText.
  ///
  /// In en, this message translates to:
  /// **'On-screen text'**
  String get onScreenText;

  /// No description provided for @peopleMentioned.
  ///
  /// In en, this message translates to:
  /// **'People mentioned'**
  String get peopleMentioned;

  /// No description provided for @peopleMentionedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person mentioned} other{{count} people mentioned}}'**
  String peopleMentionedCount(num count);

  /// No description provided for @alsoMentioned.
  ///
  /// In en, this message translates to:
  /// **'Also mentioned'**
  String get alsoMentioned;

  /// No description provided for @quotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get quotes;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @informationMayBeInaccurate.
  ///
  /// In en, this message translates to:
  /// **'Information may be inaccurate'**
  String get informationMayBeInaccurate;

  /// No description provided for @originalContentAttribution.
  ///
  /// In en, this message translates to:
  /// **'Original content belongs to its creator.'**
  String get originalContentAttribution;

  /// No description provided for @everyHours.
  ///
  /// In en, this message translates to:
  /// **'Every {count} hours'**
  String everyHours(Object count);

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @changeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change category'**
  String get changeCategory;

  /// No description provided for @worthWatching.
  ///
  /// In en, this message translates to:
  /// **'Worth watching'**
  String get worthWatching;

  /// No description provided for @worthReading.
  ///
  /// In en, this message translates to:
  /// **'Worth reading'**
  String get worthReading;

  /// No description provided for @gamesMentioned.
  ///
  /// In en, this message translates to:
  /// **'Games mentioned'**
  String get gamesMentioned;

  /// No description provided for @musicMentioned.
  ///
  /// In en, this message translates to:
  /// **'Music mentioned'**
  String get musicMentioned;

  /// No description provided for @toolsMentioned.
  ///
  /// In en, this message translates to:
  /// **'Tools mentioned'**
  String get toolsMentioned;

  /// No description provided for @worthALook.
  ///
  /// In en, this message translates to:
  /// **'Worth a look'**
  String get worthALook;

  /// No description provided for @appsToTry.
  ///
  /// In en, this message translates to:
  /// **'Apps to try'**
  String get appsToTry;

  /// No description provided for @placesToVisit.
  ///
  /// In en, this message translates to:
  /// **'Places to visit'**
  String get placesToVisit;

  /// No description provided for @websitesMentioned.
  ///
  /// In en, this message translates to:
  /// **'Websites mentioned'**
  String get websitesMentioned;

  /// No description provided for @claimsToRemember.
  ///
  /// In en, this message translates to:
  /// **'Claims to remember'**
  String get claimsToRemember;

  /// No description provided for @termsMentioned.
  ///
  /// In en, this message translates to:
  /// **'Terms mentioned'**
  String get termsMentioned;

  /// No description provided for @notableDetails.
  ///
  /// In en, this message translates to:
  /// **'Notable details'**
  String get notableDetails;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @libraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Books, movies, places & music found in your saves'**
  String get libraryDescription;

  /// No description provided for @buildsQuietly.
  ///
  /// In en, this message translates to:
  /// **'Builds quietly as you save'**
  String get buildsQuietly;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(num count);

  /// No description provided for @addedTime.
  ///
  /// In en, this message translates to:
  /// **'Added · {time}'**
  String addedTime(Object time);

  /// No description provided for @rediscoverIntentTitle.
  ///
  /// In en, this message translates to:
  /// **'A few memories worth using'**
  String get rediscoverIntentTitle;

  /// No description provided for @chosenFromUnopened.
  ///
  /// In en, this message translates to:
  /// **'Chosen from {count} unopened saves and what matters now.'**
  String chosenFromUnopened(Object count);

  /// No description provided for @chosenFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Chosen from what you saved, opened, and left for later.'**
  String get chosenFromSaved;

  /// No description provided for @todayStableSet.
  ///
  /// In en, this message translates to:
  /// **'A stable set for today — no endless feed.'**
  String get todayStableSet;

  /// No description provided for @recaps.
  ///
  /// In en, this message translates to:
  /// **'Recaps'**
  String get recaps;

  /// No description provided for @recapsDescription.
  ///
  /// In en, this message translates to:
  /// **'Weekly and monthly patterns from your own saves.'**
  String get recapsDescription;

  /// No description provided for @dailyRecap.
  ///
  /// In en, this message translates to:
  /// **'Daily recap'**
  String get dailyRecap;

  /// No description provided for @monthlyRecap.
  ///
  /// In en, this message translates to:
  /// **'Monthly recap'**
  String get monthlyRecap;

  /// No description provided for @recapSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 save} other{{count} saves}} · {waiting} waiting'**
  String recapSummary(num count, Object waiting);

  /// No description provided for @yourWeekInSaves.
  ///
  /// In en, this message translates to:
  /// **'Your week in saves'**
  String get yourWeekInSaves;

  /// No description provided for @yourMonthInMemories.
  ///
  /// In en, this message translates to:
  /// **'Your month in memories'**
  String get yourMonthInMemories;

  /// No description provided for @topicKeptShowingUp.
  ///
  /// In en, this message translates to:
  /// **'{topic} kept showing up'**
  String topicKeptShowingUp(Object topic);

  /// No description provided for @queued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get queued;

  /// No description provided for @forgottenGem.
  ///
  /// In en, this message translates to:
  /// **'Forgotten gem'**
  String get forgottenGem;

  /// No description provided for @fromYourPast.
  ///
  /// In en, this message translates to:
  /// **'From your past'**
  String get fromYourPast;

  /// No description provided for @rediscoverOptions.
  ///
  /// In en, this message translates to:
  /// **'Rediscover options'**
  String get rediscoverOptions;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @hideFor7Days.
  ///
  /// In en, this message translates to:
  /// **'Hide for 7 days'**
  String get hideFor7Days;

  /// No description provided for @lessLikeThis.
  ///
  /// In en, this message translates to:
  /// **'Less like this'**
  String get lessLikeThis;

  /// No description provided for @reduceSimilarTopics.
  ///
  /// In en, this message translates to:
  /// **'Reduce similar topics'**
  String get reduceSimilarTopics;

  /// No description provided for @nothingStrongToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing strong enough today'**
  String get nothingStrongToday;

  /// No description provided for @rediscoverQuiet.
  ///
  /// In en, this message translates to:
  /// **'Rediscover will stay quiet until a save is genuinely worth bringing back.'**
  String get rediscoverQuiet;

  /// No description provided for @searchYourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search your library…'**
  String get searchYourLibrary;

  /// No description provided for @findAnythingSaved.
  ///
  /// In en, this message translates to:
  /// **'Find anything you saved'**
  String get findAnythingSaved;

  /// No description provided for @searchEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Search across titles, tags, notes, and summaries — then narrow the view.'**
  String get searchEmptyDescription;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filtersActive.
  ///
  /// In en, this message translates to:
  /// **'Filters active'**
  String get filtersActive;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @hasNotes.
  ///
  /// In en, this message translates to:
  /// **'Has notes'**
  String get hasNotes;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get noNotes;

  /// No description provided for @inCollection.
  ///
  /// In en, this message translates to:
  /// **'In a collection'**
  String get inCollection;

  /// No description provided for @notInCollection.
  ///
  /// In en, this message translates to:
  /// **'Not in a collection'**
  String get notInCollection;

  /// No description provided for @specificCollection.
  ///
  /// In en, this message translates to:
  /// **'Specific collection'**
  String get specificCollection;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @relevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get relevance;

  /// No description provided for @newestSaved.
  ///
  /// In en, this message translates to:
  /// **'Newest saved'**
  String get newestSaved;

  /// No description provided for @oldestSaved.
  ///
  /// In en, this message translates to:
  /// **'Oldest saved'**
  String get oldestSaved;

  /// No description provided for @learningInterests.
  ///
  /// In en, this message translates to:
  /// **'Learning what keeps your attention'**
  String get learningInterests;

  /// No description provided for @readingInterests.
  ///
  /// In en, this message translates to:
  /// **'Reading your interests…'**
  String get readingInterests;

  /// No description provided for @topSignal.
  ///
  /// In en, this message translates to:
  /// **'Top signal'**
  String get topSignal;

  /// No description provided for @growingInterests.
  ///
  /// In en, this message translates to:
  /// **'Growing interests'**
  String get growingInterests;

  /// No description provided for @quieterInterests.
  ///
  /// In en, this message translates to:
  /// **'Quieter interests'**
  String get quieterInterests;

  /// No description provided for @interestStats.
  ///
  /// In en, this message translates to:
  /// **'{patterns, plural, =1{1 pattern} other{{patterns} patterns}} · {saves, plural, =1{1 save} other{{saves} saves}}'**
  String interestStats(num patterns, num saves);

  /// No description provided for @interestGroupedStats.
  ///
  /// In en, this message translates to:
  /// **'{patterns, plural, =1{1 pattern} other{{patterns} patterns}} · {grouped} of {saves} saves grouped'**
  String interestGroupedStats(Object grouped, num patterns, Object saves);

  /// No description provided for @noPatternsScanned.
  ///
  /// In en, this message translates to:
  /// **'No patterns yet · {saves} saves scanned'**
  String noPatternsScanned(Object saves);

  /// No description provided for @rebuildMap.
  ///
  /// In en, this message translates to:
  /// **'Rebuild map'**
  String get rebuildMap;

  /// No description provided for @couldNotBuildClusters.
  ///
  /// In en, this message translates to:
  /// **'Could not build clusters'**
  String get couldNotBuildClusters;

  /// No description provided for @interestMapEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your interest map is empty'**
  String get interestMapEmpty;

  /// No description provided for @interestMapEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Save at least 3 links and Glimpse will connect recurring themes across them.'**
  String get interestMapEmptyDescription;

  /// No description provided for @lastAddedTime.
  ///
  /// In en, this message translates to:
  /// **'Last added: {time}'**
  String lastAddedTime(Object time);

  /// No description provided for @hiddenFor7Days.
  ///
  /// In en, this message translates to:
  /// **'Hidden for 7 days'**
  String get hiddenFor7Days;

  /// No description provided for @seeLessLikeThis.
  ///
  /// In en, this message translates to:
  /// **'You’ll see less like this'**
  String get seeLessLikeThis;

  /// No description provided for @searchingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Searching your library…'**
  String get searchingLibrary;

  /// No description provided for @semanticMatch.
  ///
  /// In en, this message translates to:
  /// **'Semantic match'**
  String get semanticMatch;

  /// No description provided for @noMatchesForFilter.
  ///
  /// In en, this message translates to:
  /// **'No matches for this filter'**
  String get noMatchesForFilter;

  /// No description provided for @broadenSearch.
  ///
  /// In en, this message translates to:
  /// **'Try another time range or broaden your search.'**
  String get broadenSearch;

  /// No description provided for @monthlyLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit reached'**
  String get monthlyLimitReached;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @monthlySearchLimitDescription.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your monthly search limit. Upgrade to Glimpse Pro for expanded search access.'**
  String get monthlySearchLimitDescription;

  /// No description provided for @openingInterest.
  ///
  /// In en, this message translates to:
  /// **'Opening interest…'**
  String get openingInterest;

  /// No description provided for @couldNotOpenInterest.
  ///
  /// In en, this message translates to:
  /// **'Could not open this interest.'**
  String get couldNotOpenInterest;

  /// No description provided for @interestNotFound.
  ///
  /// In en, this message translates to:
  /// **'Interest not found'**
  String get interestNotFound;

  /// No description provided for @interestSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 save in this interest.} other{{count} saves in this interest.}}'**
  String interestSummary(num count);

  /// No description provided for @interestTopicsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} saves across {topics} topics'**
  String interestTopicsSummary(Object count, Object topics);

  /// No description provided for @reorderCollections.
  ///
  /// In en, this message translates to:
  /// **'Reorder collections'**
  String get reorderCollections;

  /// No description provided for @dragToSetManualOrder.
  ///
  /// In en, this message translates to:
  /// **'Drag to set your manual order'**
  String get dragToSetManualOrder;

  /// No description provided for @movedToCollection.
  ///
  /// In en, this message translates to:
  /// **'Moved to {name}'**
  String movedToCollection(Object name);

  /// No description provided for @movedLinksAndDeletedSources.
  ///
  /// In en, this message translates to:
  /// **'Moved {count, plural, =1{1 link} other{{count} links}} to {name} and deleted {sourceCount, plural, =1{the source collection} other{the source collections}}'**
  String movedLinksAndDeletedSources(num count, Object name, num sourceCount);

  /// No description provided for @deleteCollectionNamed.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteCollectionNamed(Object name);

  /// No description provided for @deleteCollectionsCount.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} collections?'**
  String deleteCollectionsCount(Object count);

  /// No description provided for @deleteCollectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Its saved links will stay in your library. Only the collection will be removed.'**
  String get deleteCollectionDescription;

  /// No description provided for @deleteCollectionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Their saved links will stay in your library. Only the collections will be removed.'**
  String get deleteCollectionsDescription;

  /// No description provided for @collectionsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Collection deleted} other{{count} collections deleted}}'**
  String collectionsDeleted(num count);

  /// No description provided for @createFirstCollection.
  ///
  /// In en, this message translates to:
  /// **'Create your first collection'**
  String get createFirstCollection;

  /// No description provided for @collectionEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Group links into calm, focused spaces.'**
  String get collectionEmptyDescription;

  /// No description provided for @libraryBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get libraryBooks;

  /// No description provided for @libraryMoviesShows.
  ///
  /// In en, this message translates to:
  /// **'Movies & Shows'**
  String get libraryMoviesShows;

  /// No description provided for @libraryPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get libraryPlaces;

  /// No description provided for @libraryBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get libraryBook;

  /// No description provided for @libraryMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get libraryMovie;

  /// No description provided for @libraryPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get libraryPlace;

  /// No description provided for @libraryReadingList.
  ///
  /// In en, this message translates to:
  /// **'Reading list'**
  String get libraryReadingList;

  /// No description provided for @libraryWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get libraryWatchlist;

  /// No description provided for @libraryNotInReadingList.
  ///
  /// In en, this message translates to:
  /// **'Not in reading list'**
  String get libraryNotInReadingList;

  /// No description provided for @libraryNotInWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Not in watchlist'**
  String get libraryNotInWatchlist;

  /// No description provided for @libraryNotListed.
  ///
  /// In en, this message translates to:
  /// **'Not listed'**
  String get libraryNotListed;

  /// No description provided for @libraryPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get libraryPlanning;

  /// No description provided for @libraryReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get libraryReading;

  /// No description provided for @libraryWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get libraryWatching;

  /// No description provided for @libraryInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get libraryInProgress;

  /// No description provided for @libraryDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get libraryDropped;

  /// No description provided for @libraryRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get libraryRead;

  /// No description provided for @libraryWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get libraryWatched;

  /// No description provided for @libraryVisited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get libraryVisited;

  /// No description provided for @libraryStatusSemantics.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String libraryStatusSemantics(Object status);

  /// No description provided for @libraryReadingPageStatus.
  ///
  /// In en, this message translates to:
  /// **'Reading · p. {page}'**
  String libraryReadingPageStatus(Object page);

  /// No description provided for @libraryGenreFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get libraryGenreFantasy;

  /// No description provided for @libraryGenreScienceFiction.
  ///
  /// In en, this message translates to:
  /// **'Science Fiction'**
  String get libraryGenreScienceFiction;

  /// No description provided for @libraryGenreMysteryThriller.
  ///
  /// In en, this message translates to:
  /// **'Mystery & Thriller'**
  String get libraryGenreMysteryThriller;

  /// No description provided for @libraryGenreRomance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get libraryGenreRomance;

  /// No description provided for @libraryGenreHorror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get libraryGenreHorror;

  /// No description provided for @libraryGenreBiographyMemoir.
  ///
  /// In en, this message translates to:
  /// **'Biography & Memoir'**
  String get libraryGenreBiographyMemoir;

  /// No description provided for @libraryGenreHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get libraryGenreHistory;

  /// No description provided for @libraryGenrePhilosophy.
  ///
  /// In en, this message translates to:
  /// **'Philosophy'**
  String get libraryGenrePhilosophy;

  /// No description provided for @libraryGenrePsychology.
  ///
  /// In en, this message translates to:
  /// **'Psychology'**
  String get libraryGenrePsychology;

  /// No description provided for @libraryGenreBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get libraryGenreBusiness;

  /// No description provided for @libraryGenreFinanceInvesting.
  ///
  /// In en, this message translates to:
  /// **'Finance & Investing'**
  String get libraryGenreFinanceInvesting;

  /// No description provided for @libraryGenreTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get libraryGenreTechnology;

  /// No description provided for @libraryGenreScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get libraryGenreScience;

  /// No description provided for @libraryGenreSelfDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Self-Development'**
  String get libraryGenreSelfDevelopment;

  /// No description provided for @libraryGenreHealthWellness.
  ///
  /// In en, this message translates to:
  /// **'Health & Wellness'**
  String get libraryGenreHealthWellness;

  /// No description provided for @libraryGenrePoliticsSociety.
  ///
  /// In en, this message translates to:
  /// **'Politics & Society'**
  String get libraryGenrePoliticsSociety;

  /// No description provided for @libraryGenreArtDesign.
  ///
  /// In en, this message translates to:
  /// **'Art & Design'**
  String get libraryGenreArtDesign;

  /// No description provided for @libraryGenreTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get libraryGenreTravel;

  /// No description provided for @libraryGenreComicsGraphicNovels.
  ///
  /// In en, this message translates to:
  /// **'Comics & Graphic Novels'**
  String get libraryGenreComicsGraphicNovels;

  /// No description provided for @libraryGenreFiction.
  ///
  /// In en, this message translates to:
  /// **'Fiction'**
  String get libraryGenreFiction;

  /// No description provided for @libraryGenreAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get libraryGenreAction;

  /// No description provided for @libraryGenreAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get libraryGenreAdventure;

  /// No description provided for @libraryGenreAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get libraryGenreAnimation;

  /// No description provided for @libraryGenreComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get libraryGenreComedy;

  /// No description provided for @libraryGenreCrime.
  ///
  /// In en, this message translates to:
  /// **'Crime'**
  String get libraryGenreCrime;

  /// No description provided for @libraryGenreDocumentary.
  ///
  /// In en, this message translates to:
  /// **'Documentary'**
  String get libraryGenreDocumentary;

  /// No description provided for @libraryGenreDrama.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get libraryGenreDrama;

  /// No description provided for @libraryGenreFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get libraryGenreFamily;

  /// No description provided for @libraryGenreMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get libraryGenreMystery;

  /// No description provided for @libraryGenreThriller.
  ///
  /// In en, this message translates to:
  /// **'Thriller'**
  String get libraryGenreThriller;

  /// No description provided for @libraryGenreWar.
  ///
  /// In en, this message translates to:
  /// **'War'**
  String get libraryGenreWar;

  /// No description provided for @libraryGenreWestern.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get libraryGenreWestern;

  /// No description provided for @libraryGenreMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get libraryGenreMusic;

  /// No description provided for @libraryGenreOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get libraryGenreOther;

  /// No description provided for @librarySubtypeTvShow.
  ///
  /// In en, this message translates to:
  /// **'TV Show'**
  String get librarySubtypeTvShow;

  /// No description provided for @librarySubtypeSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get librarySubtypeSeries;

  /// No description provided for @couldNotOpenLibrary.
  ///
  /// In en, this message translates to:
  /// **'Could not open Library'**
  String get couldNotOpenLibrary;

  /// No description provided for @searchLibraryItems.
  ///
  /// In en, this message translates to:
  /// **'Search {kind}'**
  String searchLibraryItems(Object kind);

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @recentlyDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Recently discovered'**
  String get recentlyDiscovered;

  /// No description provided for @titleAZ.
  ///
  /// In en, this message translates to:
  /// **'Title A–Z'**
  String get titleAZ;

  /// No description provided for @yearNewest.
  ///
  /// In en, this message translates to:
  /// **'Year newest'**
  String get yearNewest;

  /// No description provided for @libraryOptions.
  ///
  /// In en, this message translates to:
  /// **'{kind} options'**
  String libraryOptions(Object kind);

  /// No description provided for @filterLibraryItems.
  ///
  /// In en, this message translates to:
  /// **'Filter {kind}'**
  String filterLibraryItems(Object kind);

  /// No description provided for @readingStatus.
  ///
  /// In en, this message translates to:
  /// **'Reading status'**
  String get readingStatus;

  /// No description provided for @watchStatus.
  ///
  /// In en, this message translates to:
  /// **'Watch status'**
  String get watchStatus;

  /// No description provided for @anyStatus.
  ///
  /// In en, this message translates to:
  /// **'Any status'**
  String get anyStatus;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @allGenres.
  ///
  /// In en, this message translates to:
  /// **'All genres'**
  String get allGenres;

  /// No description provided for @nothingMatchesFilters.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters.'**
  String get nothingMatchesFilters;

  /// No description provided for @nothingRecognizedHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing recognized here yet.'**
  String get nothingRecognizedHere;

  /// No description provided for @couldNotUpdateLibraryItem.
  ///
  /// In en, this message translates to:
  /// **'Could not update this Library item.'**
  String get couldNotUpdateLibraryItem;

  /// No description provided for @foundInYourSaves.
  ///
  /// In en, this message translates to:
  /// **'Found in your saves'**
  String get foundInYourSaves;

  /// No description provided for @recognizedOrganizedByType.
  ///
  /// In en, this message translates to:
  /// **'Automatically organized by type'**
  String get recognizedOrganizedByType;

  /// No description provided for @libraryBookCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 book} other{{count} books}}'**
  String libraryBookCount(num count);

  /// No description provided for @libraryMovieCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 title} other{{count} titles}}'**
  String libraryMovieCount(num count);

  /// No description provided for @libraryPlaceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place} other{{count} places}}'**
  String libraryPlaceCount(num count);

  /// No description provided for @libraryStopCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}}'**
  String libraryStopCount(num count);

  /// No description provided for @nothingRecognizedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing recognized yet'**
  String get nothingRecognizedYet;

  /// No description provided for @recognizedTitlesGatherHere.
  ///
  /// In en, this message translates to:
  /// **'Recognized titles will gather here'**
  String get recognizedTitlesGatherHere;

  /// No description provided for @recognizedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} recognized'**
  String recognizedCount(Object count);

  /// No description provided for @savedPlacesAppearOnMap.
  ///
  /// In en, this message translates to:
  /// **'Saved places will appear on a map'**
  String get savedPlacesAppearOnMap;

  /// No description provided for @addingDetails.
  ///
  /// In en, this message translates to:
  /// **'Adding details'**
  String get addingDetails;

  /// No description provided for @extraDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Extra details are temporarily unavailable'**
  String get extraDetailsUnavailable;

  /// No description provided for @itemsCouldNotRefresh.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item couldn’t be refreshed} other{{count} items couldn’t be refreshed}}'**
  String itemsCouldNotRefresh(num count);

  /// No description provided for @progressOf.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total}'**
  String progressOf(Object completed, Object total);

  /// No description provided for @savedDetailsRemainAvailable.
  ///
  /// In en, this message translates to:
  /// **'Saved details remain available'**
  String get savedDetailsRemainAvailable;

  /// No description provided for @waitingToRetry.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting to retry'**
  String waitingToRetry(Object count);

  /// No description provided for @libraryBuildsAsYouSave.
  ///
  /// In en, this message translates to:
  /// **'It builds as you save'**
  String get libraryBuildsAsYouSave;

  /// No description provided for @libraryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Save recommendations for books, movies, places, and music. Glimpse will organize the things inside them here.'**
  String get libraryEmptyDescription;

  /// No description provided for @libraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Library is unavailable right now'**
  String get libraryUnavailable;

  /// No description provided for @yourPlaces.
  ///
  /// In en, this message translates to:
  /// **'Your places'**
  String get yourPlaces;

  /// No description provided for @placesAreasSummary.
  ///
  /// In en, this message translates to:
  /// **'{places, plural, =1{1 place} other{{places} places}} · {areas, plural, =1{1 area} other{{areas} areas}}'**
  String placesAreasSummary(num areas, num places);

  /// No description provided for @planThisArea.
  ///
  /// In en, this message translates to:
  /// **'Plan this area'**
  String get planThisArea;

  /// No description provided for @planAnItinerary.
  ///
  /// In en, this message translates to:
  /// **'Plan an itinerary'**
  String get planAnItinerary;

  /// No description provided for @searchSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search saved places'**
  String get searchSavedPlaces;

  /// No description provided for @yourPlans.
  ///
  /// In en, this message translates to:
  /// **'Your plans'**
  String get yourPlans;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable;

  /// No description provided for @openNamedItem.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String openNamedItem(Object name);

  /// No description provided for @wantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Want to visit'**
  String get wantToVisit;

  /// No description provided for @savedPlace.
  ///
  /// In en, this message translates to:
  /// **'Saved place'**
  String get savedPlace;

  /// No description provided for @planAVisit.
  ///
  /// In en, this message translates to:
  /// **'Plan a visit'**
  String get planAVisit;

  /// No description provided for @maps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get maps;

  /// No description provided for @noSavedPlacesMatch.
  ///
  /// In en, this message translates to:
  /// **'No saved places match this search.'**
  String get noSavedPlacesMatch;

  /// No description provided for @noPlacesDiscovered.
  ///
  /// In en, this message translates to:
  /// **'No places discovered yet'**
  String get noPlacesDiscovered;

  /// No description provided for @placesMentionedGatherHere.
  ///
  /// In en, this message translates to:
  /// **'Places mentioned in your saves will gather here.'**
  String get placesMentionedGatherHere;

  /// No description provided for @fitAllPlaces.
  ///
  /// In en, this message translates to:
  /// **'Fit all places'**
  String get fitAllPlaces;

  /// No description provided for @noMappedPlaces.
  ///
  /// In en, this message translates to:
  /// **'No mapped places yet'**
  String get noMappedPlaces;

  /// No description provided for @mapUnavailablePlacesListed.
  ///
  /// In en, this message translates to:
  /// **'Map unavailable — your places are still listed below'**
  String get mapUnavailablePlacesListed;

  /// No description provided for @libraryItemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This Library item is unavailable.'**
  String get libraryItemUnavailable;

  /// No description provided for @couldNotUpdateBookmark.
  ///
  /// In en, this message translates to:
  /// **'Could not update your bookmark.'**
  String get couldNotUpdateBookmark;

  /// No description provided for @hiddenFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'{name} hidden from Library'**
  String hiddenFromLibrary(Object name);

  /// No description provided for @libraryItemOptions.
  ///
  /// In en, this message translates to:
  /// **'Library item options'**
  String get libraryItemOptions;

  /// No description provided for @hideFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Hide from Library'**
  String get hideFromLibrary;

  /// No description provided for @addToReadingList.
  ///
  /// In en, this message translates to:
  /// **'Add to your reading list'**
  String get addToReadingList;

  /// No description provided for @addToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Add to your watchlist'**
  String get addToWatchlist;

  /// No description provided for @removeFromReadingList.
  ///
  /// In en, this message translates to:
  /// **'Remove from reading list'**
  String get removeFromReadingList;

  /// No description provided for @removeFromWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Remove from watchlist'**
  String get removeFromWatchlist;

  /// No description provided for @whyItMattered.
  ///
  /// In en, this message translates to:
  /// **'Why it mattered'**
  String get whyItMattered;

  /// No description provided for @plot.
  ///
  /// In en, this message translates to:
  /// **'Plot'**
  String get plot;

  /// No description provided for @yourBookmark.
  ///
  /// In en, this message translates to:
  /// **'Your bookmark'**
  String get yourBookmark;

  /// No description provided for @savePageYouAreOn.
  ///
  /// In en, this message translates to:
  /// **'Save the page you’re on'**
  String get savePageYouAreOn;

  /// No description provided for @savePlaceAboutPages.
  ///
  /// In en, this message translates to:
  /// **'Save your place · about {count} pages'**
  String savePlaceAboutPages(Object count);

  /// No description provided for @pageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageNumber(Object page);

  /// No description provided for @pageAboutPages.
  ///
  /// In en, this message translates to:
  /// **'Page {page} · about {count} pages'**
  String pageAboutPages(Object count, Object page);

  /// No description provided for @setCurrentPage.
  ///
  /// In en, this message translates to:
  /// **'Set current page'**
  String get setCurrentPage;

  /// No description provided for @updatePage.
  ///
  /// In en, this message translates to:
  /// **'Update page'**
  String get updatePage;

  /// No description provided for @updateYourBookmark.
  ///
  /// In en, this message translates to:
  /// **'Update your bookmark'**
  String get updateYourBookmark;

  /// No description provided for @aboutPages.
  ///
  /// In en, this message translates to:
  /// **'about {count} pages'**
  String aboutPages(Object count);

  /// No description provided for @currentPage.
  ///
  /// In en, this message translates to:
  /// **'Current page'**
  String get currentPage;

  /// No description provided for @enterPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a page number'**
  String get enterPageNumber;

  /// No description provided for @saveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Save bookmark'**
  String get saveBookmark;

  /// No description provided for @pageGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Enter a page number greater than zero'**
  String get pageGreaterThanZero;

  /// No description provided for @libraryItemSemantics.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {title}'**
  String libraryItemSemantics(Object kind, Object title);

  /// No description provided for @libraryItemOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to open. Long press to change {list} status.'**
  String libraryItemOpenHint(Object list);

  /// No description provided for @collectionEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refine this saved space.'**
  String get collectionEditSubtitle;

  /// No description provided for @collectionCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a focused space for saved ideas.'**
  String get collectionCreateSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @collectionNameHint.
  ///
  /// In en, this message translates to:
  /// **'Travel & Wanderlust'**
  String get collectionNameHint;

  /// No description provided for @collectionDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional note for this space'**
  String get collectionDescriptionHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @nameCollectionError.
  ///
  /// In en, this message translates to:
  /// **'Name your collection'**
  String get nameCollectionError;

  /// No description provided for @duplicateCollectionError.
  ///
  /// In en, this message translates to:
  /// **'A collection with this name already exists'**
  String get duplicateCollectionError;

  /// No description provided for @deleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get deleteCollection;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get addLink;

  /// No description provided for @noLinksInCollection.
  ///
  /// In en, this message translates to:
  /// **'No links in this collection yet.'**
  String get noLinksInCollection;

  /// No description provided for @notificationTravelPlaces.
  ///
  /// In en, this message translates to:
  /// **'Travel & Places'**
  String get notificationTravelPlaces;

  /// No description provided for @notificationNewDiscovery.
  ///
  /// In en, this message translates to:
  /// **'New Discovery'**
  String get notificationNewDiscovery;

  /// No description provided for @notificationReadingReminder.
  ///
  /// In en, this message translates to:
  /// **'Reading Reminder'**
  String get notificationReadingReminder;

  /// No description provided for @notificationActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get notificationActivity;

  /// No description provided for @notificationWorthRevisiting.
  ///
  /// In en, this message translates to:
  /// **'Worth Revisiting'**
  String get notificationWorthRevisiting;

  /// No description provided for @notificationRevisitReminder.
  ///
  /// In en, this message translates to:
  /// **'Revisit Reminder'**
  String get notificationRevisitReminder;

  /// No description provided for @notificationWeeklyDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly Digest'**
  String get notificationWeeklyDigest;

  /// No description provided for @enrichmentNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Enrichment needs attention'**
  String get enrichmentNeedsAttention;

  /// No description provided for @aiDetailsAvailable.
  ///
  /// In en, this message translates to:
  /// **'AI details available'**
  String get aiDetailsAvailable;

  /// No description provided for @enrich.
  ///
  /// In en, this message translates to:
  /// **'Enrich'**
  String get enrich;

  /// No description provided for @enriching.
  ///
  /// In en, this message translates to:
  /// **'Enriching'**
  String get enriching;

  /// No description provided for @messageGlimpse.
  ///
  /// In en, this message translates to:
  /// **'Message Glimpse...'**
  String get messageGlimpse;

  /// No description provided for @askAboutThisSave.
  ///
  /// In en, this message translates to:
  /// **'Ask about this save...'**
  String get askAboutThisSave;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @askGreetingEarlyMorning.
  ///
  /// In en, this message translates to:
  /// **'Up early?'**
  String get askGreetingEarlyMorning;

  /// No description provided for @askGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning.'**
  String get askGreetingMorning;

  /// No description provided for @askGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'What are we exploring?'**
  String get askGreetingAfternoon;

  /// No description provided for @askGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening.'**
  String get askGreetingEvening;

  /// No description provided for @askGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Still curious tonight?'**
  String get askGreetingNight;

  /// No description provided for @askGreetingLateNight.
  ///
  /// In en, this message translates to:
  /// **'Up late again?'**
  String get askGreetingLateNight;

  /// No description provided for @saveYourFirstLink.
  ///
  /// In en, this message translates to:
  /// **'Save your first link'**
  String get saveYourFirstLink;

  /// No description provided for @moreSelectionActions.
  ///
  /// In en, this message translates to:
  /// **'More selection actions'**
  String get moreSelectionActions;

  /// No description provided for @moveToCollection.
  ///
  /// In en, this message translates to:
  /// **'Move to collection'**
  String get moveToCollection;

  /// No description provided for @markRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markRead;

  /// No description provided for @markUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark unread'**
  String get markUnread;

  /// No description provided for @toggleReadStatus.
  ///
  /// In en, this message translates to:
  /// **'Toggle read status'**
  String get toggleReadStatus;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @yourNote.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get yourNote;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @notePrompt.
  ///
  /// In en, this message translates to:
  /// **'What stood out to you?'**
  String get notePrompt;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAdd;

  /// No description provided for @noteSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get noteSaving;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get noteSaved;

  /// No description provided for @noteCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save'**
  String get noteCouldNotSave;

  /// No description provided for @addYourNote.
  ///
  /// In en, this message translates to:
  /// **'Add your note'**
  String get addYourNote;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showAllCount.
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String showAllCount(Object count);

  /// No description provided for @answerCopied.
  ///
  /// In en, this message translates to:
  /// **'Answer copied'**
  String get answerCopied;

  /// No description provided for @deleteAskNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Ask note?'**
  String get deleteAskNoteQuestion;

  /// No description provided for @deleteAskNoteDescription.
  ///
  /// In en, this message translates to:
  /// **'This removes the saved answer from this link. Your own note is not affected.'**
  String get deleteAskNoteDescription;

  /// No description provided for @askNoteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Ask note deleted'**
  String get askNoteDeleted;

  /// No description provided for @couldNotDeleteAskNote.
  ///
  /// In en, this message translates to:
  /// **'Could not delete Ask note'**
  String get couldNotDeleteAskNote;

  /// No description provided for @askNoteActions.
  ///
  /// In en, this message translates to:
  /// **'Ask note actions'**
  String get askNoteActions;

  /// No description provided for @copyAnswer.
  ///
  /// In en, this message translates to:
  /// **'Copy answer'**
  String get copyAnswer;

  /// No description provided for @quickTryThisWeekend.
  ///
  /// In en, this message translates to:
  /// **'Try This Weekend'**
  String get quickTryThisWeekend;

  /// No description provided for @quickNeedIngredients.
  ///
  /// In en, this message translates to:
  /// **'Need Ingredients'**
  String get quickNeedIngredients;

  /// No description provided for @quickShareWithSomeone.
  ///
  /// In en, this message translates to:
  /// **'Share With Someone'**
  String get quickShareWithSomeone;

  /// No description provided for @quickAlreadyTried.
  ///
  /// In en, this message translates to:
  /// **'Already Tried'**
  String get quickAlreadyTried;

  /// No description provided for @quickWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch Later'**
  String get quickWatchLater;

  /// No description provided for @quickAddToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Watchlist'**
  String get quickAddToWatchlist;

  /// No description provided for @quickAlreadyWatched.
  ///
  /// In en, this message translates to:
  /// **'Already Watched'**
  String get quickAlreadyWatched;

  /// No description provided for @quickAddToReadingList.
  ///
  /// In en, this message translates to:
  /// **'Add to Reading List'**
  String get quickAddToReadingList;

  /// No description provided for @quickReadLater.
  ///
  /// In en, this message translates to:
  /// **'Read Later'**
  String get quickReadLater;

  /// No description provided for @quickResearchThis.
  ///
  /// In en, this message translates to:
  /// **'Research This'**
  String get quickResearchThis;

  /// No description provided for @quickAlreadyRead.
  ///
  /// In en, this message translates to:
  /// **'Already Read'**
  String get quickAlreadyRead;

  /// No description provided for @quickTryThisTool.
  ///
  /// In en, this message translates to:
  /// **'Try This Tool'**
  String get quickTryThisTool;

  /// No description provided for @quickCompareAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Compare Alternatives'**
  String get quickCompareAlternatives;

  /// No description provided for @quickUseInProject.
  ///
  /// In en, this message translates to:
  /// **'Use in Project'**
  String get quickUseInProject;

  /// No description provided for @quickShareWithTeam.
  ///
  /// In en, this message translates to:
  /// **'Share With Team'**
  String get quickShareWithTeam;

  /// No description provided for @quickPlanItinerary.
  ///
  /// In en, this message translates to:
  /// **'Plan Itinerary'**
  String get quickPlanItinerary;

  /// No description provided for @quickCheckBestSeason.
  ///
  /// In en, this message translates to:
  /// **'Check Best Season'**
  String get quickCheckBestSeason;

  /// No description provided for @quickSaveRoute.
  ///
  /// In en, this message translates to:
  /// **'Save Route'**
  String get quickSaveRoute;

  /// No description provided for @quickPracticeLater.
  ///
  /// In en, this message translates to:
  /// **'Practice Later'**
  String get quickPracticeLater;

  /// No description provided for @quickMakeChecklist.
  ///
  /// In en, this message translates to:
  /// **'Make Checklist'**
  String get quickMakeChecklist;

  /// No description provided for @quickRevisitNotes.
  ///
  /// In en, this message translates to:
  /// **'Revisit Notes'**
  String get quickRevisitNotes;

  /// No description provided for @quickRevisitLater.
  ///
  /// In en, this message translates to:
  /// **'Revisit Later'**
  String get quickRevisitLater;

  /// No description provided for @quickWorthTrying.
  ///
  /// In en, this message translates to:
  /// **'Worth Trying'**
  String get quickWorthTrying;

  /// No description provided for @quickAlreadyChecked.
  ///
  /// In en, this message translates to:
  /// **'Already Checked'**
  String get quickAlreadyChecked;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Save something worth keeping'**
  String get aboutTagline;

  /// No description provided for @versionBuild.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (Build {build})'**
  String versionBuild(Object build, Object version);

  /// No description provided for @loadingVersion.
  ///
  /// In en, this message translates to:
  /// **'Loading version…'**
  String get loadingVersion;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// No description provided for @rateOnPlayStore.
  ///
  /// In en, this message translates to:
  /// **'Rate on Play Store'**
  String get rateOnPlayStore;

  /// No description provided for @shareGlimpse.
  ///
  /// In en, this message translates to:
  /// **'Share Glimpse'**
  String get shareGlimpse;

  /// No description provided for @feedbackEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Glimpse feedback'**
  String get feedbackEmailSubject;

  /// No description provided for @shareGlimpseText.
  ///
  /// In en, this message translates to:
  /// **'Glimpse helps you save links worth returning to. Try it: {url}'**
  String shareGlimpseText(Object url);

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open this link.'**
  String get couldNotOpenLink;

  /// No description provided for @couldNotShareGlimpse.
  ///
  /// In en, this message translates to:
  /// **'Could not share Glimpse.'**
  String get couldNotShareGlimpse;

  /// No description provided for @keepsakeQuoteCuriosity.
  ///
  /// In en, this message translates to:
  /// **'Keep the things that keep you curious.'**
  String get keepsakeQuoteCuriosity;

  /// No description provided for @keepsakeQuoteIdea.
  ///
  /// In en, this message translates to:
  /// **'A small glimpse can become a lasting idea.'**
  String get keepsakeQuoteIdea;

  /// No description provided for @keepsakeQuoteSpark.
  ///
  /// In en, this message translates to:
  /// **'Save the spark. Return when it matters.'**
  String get keepsakeQuoteSpark;

  /// No description provided for @keepsakeQuoteFutureSelf.
  ///
  /// In en, this message translates to:
  /// **'Your future self might be looking for this.'**
  String get keepsakeQuoteFutureSelf;

  /// No description provided for @keepsakeQuoteNoticing.
  ///
  /// In en, this message translates to:
  /// **'Worth noticing. Worth keeping.'**
  String get keepsakeQuoteNoticing;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @shareBackup.
  ///
  /// In en, this message translates to:
  /// **'Share backup'**
  String get shareBackup;

  /// No description provided for @shareBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a backup to another app or cloud service'**
  String get shareBackupDescription;

  /// No description provided for @backupSavedLinksTo.
  ///
  /// In en, this message translates to:
  /// **'Saved {count, plural, =1{1 link} other{{count} links}} to {location}'**
  String backupSavedLinksTo(num count, Object location);

  /// No description provided for @backupSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to {location}'**
  String backupSavedTo(Object location);

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get errorDetails;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @couldNotReadSelectedFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected file.'**
  String get couldNotReadSelectedFile;

  /// No description provided for @folderSelected.
  ///
  /// In en, this message translates to:
  /// **'Folder selected'**
  String get folderSelected;

  /// No description provided for @couldNotSaveFolderPermission.
  ///
  /// In en, this message translates to:
  /// **'Could not save folder permission. Please try again.'**
  String get couldNotSaveFolderPermission;

  /// No description provided for @permanentBackupFolderAndroid.
  ///
  /// In en, this message translates to:
  /// **'Permanent backup folder is available on Android'**
  String get permanentBackupFolderAndroid;

  /// No description provided for @tapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get tapToChange;

  /// No description provided for @forgetFolder.
  ///
  /// In en, this message translates to:
  /// **'Forget folder'**
  String get forgetFolder;

  /// No description provided for @autoBackupAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Auto backup runs on Android when a storage folder is set'**
  String get autoBackupAndroidOnly;

  /// No description provided for @lastAutomaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Last automatic backup: {time}'**
  String lastAutomaticBackup(Object time);

  /// No description provided for @lastBackupAttemptFailed.
  ///
  /// In en, this message translates to:
  /// **'Last attempt failed {time}. Glimpse will retry automatically.'**
  String lastBackupAttemptFailed(Object time);

  /// No description provided for @setStorageBeforeAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Set a storage location above before automatic backups can run.'**
  String get setStorageBeforeAutoBackup;

  /// No description provided for @folderBackup.
  ///
  /// In en, this message translates to:
  /// **'Folder backup'**
  String get folderBackup;

  /// No description provided for @lastSavedToFolder.
  ///
  /// In en, this message translates to:
  /// **'Last saved to folder: {time}'**
  String lastSavedToFolder(Object time);

  /// No description provided for @noBackupFileInFolder.
  ///
  /// In en, this message translates to:
  /// **'No backup file in this folder yet. Use Create backup above after picking this location.'**
  String get noBackupFileInFolder;

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlight;

  /// No description provided for @removeHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove highlight'**
  String get removeHighlight;

  /// No description provided for @highlightAdded.
  ///
  /// In en, this message translates to:
  /// **'Highlight saved'**
  String get highlightAdded;

  /// No description provided for @highlightRemoved.
  ///
  /// In en, this message translates to:
  /// **'Highlight removed'**
  String get highlightRemoved;

  /// No description provided for @highlightFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the highlight.'**
  String get highlightFailed;

  /// No description provided for @readerOverviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Only a brief overview is available for this save. Open the source for the full content.'**
  String get readerOverviewOnly;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
