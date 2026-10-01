import 'package:shared_preferences/shared_preferences.dart';

import 'glimpse.dart';

/// What the person wants to be notified about, and when (Settings ›
/// Notifications). Read at the moment of posting.
class GlimpseNotificationPrefs {
  const GlimpseNotificationPrefs({
    this.disabled = const {},
    this.startHour = defaultStartHour,
    this.endHour = defaultEndHour,
  });

  static const disabledKindsKey = 'notif_disabled_kinds';
  static const startHourKey = 'notif_window_start_hour';
  static const endHourKey = 'notif_window_end_hour';
  static const defaultStartHour = 9;
  static const defaultEndHour = 21;

  /// The kinds that can notify at all (see `Glimpse.canNotify`), in the
  /// order Settings lists them.
  static const notifiableKinds = [
    GlimpseKind.connection,
    GlimpseKind.idea,
    GlimpseKind.weekly,
    GlimpseKind.intention,
  ];

  /// Delivery windows offered in Settings, as start and end hours.
  static const windowChoices = [(7, 11), (8, 20), (9, 21), (10, 22), (18, 22)];

  final Set<GlimpseKind> disabled;
  final int startHour;
  final int endHour;

  bool allows(GlimpseKind kind) => !disabled.contains(kind);

  int get enabledCount =>
      notifiableKinds.where((kind) => !disabled.contains(kind)).length;

  static Future<GlimpseNotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(disabledKindsKey) ?? const [];
    final byName = GlimpseKind.values.asNameMap();
    return GlimpseNotificationPrefs(
      disabled: {for (final name in names) ?byName[name]},
      startHour: prefs.getInt(startHourKey) ?? defaultStartHour,
      endHour: prefs.getInt(endHourKey) ?? defaultEndHour,
    );
  }

  static Future<void> setKindEnabled(GlimpseKind kind, bool enabled) async {
    final current = await load();
    final disabled = {...current.disabled};
    enabled ? disabled.remove(kind) : disabled.add(kind);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(disabledKindsKey, [
      for (final kind in disabled) kind.name,
    ]);
  }

  static Future<void> setWindow(int startHour, int endHour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(startHourKey, startHour);
    await prefs.setInt(endHourKey, endHour);
  }
}
