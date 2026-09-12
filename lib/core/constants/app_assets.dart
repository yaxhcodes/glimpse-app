/// Centralized asset paths to avoid hard-coding strings across the app.
class AppAssets {
  AppAssets._();

  /// Primary brand icon used across all UI surfaces.
  static const String logo = 'assets/mascot/home.webp';
  static const String homeIcon = 'assets/icons/home.svg';
  static const String homeSelectedIcon = 'assets/icons/home-selected.svg';
  static const String searchIcon = 'assets/icons/search.svg';
  static const String searchSelectedIcon = 'assets/icons/search-selected.svg';
  static const String collectionsIcon = 'assets/icons/collections.svg';
  static const String collectionsSelectedIcon =
      'assets/icons/collections-selected.svg';
  static const String interestsIcon = 'assets/icons/interests.svg';
  static const String interestsSelectedIcon =
      'assets/icons/interests-selected.svg';
  static const String brandMark = 'assets/mascot/brand-mark.svg';
  static const String addLinkIcon = 'assets/icons/add-link.svg';
  static const String addToCollectionIcon =
      'assets/icons/add-to-collection.svg';
  static const String addToCollectionFilledIcon =
      'assets/icons/add-to-collection-selected.svg';

  /// Exact Android launcher artwork used wherever onboarding shows Glimpse.
  static const String launcherIcon =
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png';

  static const String homeHero = 'assets/mascot/home.webp';
  static const String emptyCollections = 'assets/mascot/collections.webp';
  static const String emptyInterests = 'assets/mascot/interests.webp';
  static const String emptySearch = 'assets/mascot/search.webp';

  /// Original, offline artwork used by the first-run living-memory story.
  static const String onboardingKyoto = 'assets/onboarding_kyoto.webp';

  /// Official Simple Icons brand marks bundled for the Android share mock.
  static const String whatsapp = 'assets/brands/whatsapp.svg';
  static const String gmail = 'assets/brands/gmail.svg';
  static const String googleMessages = 'assets/brands/google_messages.svg';
}
