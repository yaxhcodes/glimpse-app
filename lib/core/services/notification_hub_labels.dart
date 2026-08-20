import '../../l10n/generated/app_localizations.dart';

/// User-facing labels for the in-app notification hub (not internal type codes).
class NotificationHubLabels {
  NotificationHubLabels._();

  /// History entries use [type] values: geo, new_interest, collector, streak, resurface, digest.
  static String forHistoryType(AppLocalizations strings, String? type) {
    switch (type) {
      case 'geo':
        return strings.notificationTravelPlaces;
      case 'new_interest':
        return strings.notificationNewDiscovery;
      case 'collector':
        return strings.notificationReadingReminder;
      case 'streak':
        return strings.notificationActivity;
      case 'resurface':
        return strings.notificationWorthRevisiting;
      case 'revisit':
        return strings.notificationRevisitReminder;
      case 'digest':
        return strings.notificationWeeklyDigest;
      default:
        return strings.notification;
    }
  }
}
