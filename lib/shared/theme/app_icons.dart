import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

abstract final class AppIcons {
  // Primary navigation.
  static const home = Symbols.home_app_logo_rounded;
  static const collections = Symbols.cards_stack_rounded;
  static const interests = Symbols.bubble_chart_rounded;
  static const search = Symbols.search_rounded;

  // Glimpse features.
  static const rediscover = Symbols.history_edu_rounded;
  static const termMentioned = Symbols.dictionary_rounded;
  static const addLink = Symbols.add_link_rounded;
  static const addToCollection = Symbols.library_add_rounded;
  static const notifications = Symbols.notifications_unread_rounded;
  static const settings = Symbols.settings_rounded;

  // Settings destinations.
  static const appearance = Symbols.colors_rounded;
  static const privacy = Symbols.shield_lock_rounded;
  static const backup = Symbols.cloud_sync_rounded;
  static const clearData = Symbols.delete_sweep_rounded;
  static const about = Symbols.info_rounded;
  static const logout = Symbols.logout_rounded;
  static const deleteAccount = Symbols.person_cancel_rounded;
  static const smartNotifications = Symbols.notifications_unread_rounded;
  static const automaticTheme = Symbols.brightness_auto_rounded;
  static const lightTheme = Symbols.light_mode_rounded;
  static const darkTheme = Symbols.dark_mode_rounded;
  static const amoledTheme = Symbols.contrast_rounded;
  static const terms = Symbols.contract_rounded;
  static const help = Symbols.contact_support_rounded;
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.color,
    this.size,
    this.selected = false,
    this.fill,
    this.weight,
    this.semanticLabel,
  });

  final IconData icon;
  final Color? color;
  final double? size;
  final bool selected;
  final double? fill;
  final double? weight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: color,
      size: size,
      fill: fill ?? (selected ? 1 : 0),
      weight: weight ?? (selected ? 550 : 400),
      opticalSize: size,
      semanticLabel: semanticLabel,
    );
  }
}
