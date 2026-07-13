/// Centralized asset paths to avoid hard-coding strings across the app.
class AppAssets {
  AppAssets._();

  /// Primary brand icon used across all UI surfaces.
  static const String logo = 'assets/glimpse.png';

  /// Exact Android launcher artwork used wherever onboarding shows Glimpse.
  static const String launcherIcon =
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png';

  /// Richer mascot illustration (mascot + content types) for the home hero.
  static const String homeHero = 'assets/home.png';

  /// Original, offline artwork used by the first-run living-memory story.
  static const String onboardingKyoto = 'assets/onboarding_kyoto.webp';

  /// Official Simple Icons brand marks bundled for the Android share mock.
  static const String whatsapp = 'assets/brands/whatsapp.svg';
  static const String gmail = 'assets/brands/gmail.svg';
  static const String googleMessages = 'assets/brands/google_messages.svg';
}
