/// User-facing labels for the in-app notification hub (not internal type codes).
class NotificationHubLabels {
  NotificationHubLabels._();

  /// History entries use [type] values: geo, new_interest, collector, streak, resurface, digest.
  static String forHistoryType(String? type) {
    switch (type) {
      case 'geo':
        return 'Travel & Places';
      case 'new_interest':
        return 'New Discovery';
      case 'collector':
        return 'Reading Reminder';
      case 'streak':
        return 'Activity';
      case 'resurface':
        return 'Worth Revisiting';
      case 'digest':
        return 'Weekly Digest';
      default:
        return 'Notification';
    }
  }
}
