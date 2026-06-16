import 'package:flutter/material.dart';

/// Subtle surface / accent tokens for notification history [type] strings.
class NotificationTypeStyle {
  const NotificationTypeStyle({
    required this.accent,
    required this.icon,
    required this.labelColorWeight,
  });

  final Color accent;
  final IconData icon;
  final double labelColorWeight;

  static NotificationTypeStyle forHistoryType(String? type, ColorScheme cs) {
    switch (type) {
      case 'digest':
        return NotificationTypeStyle(
          accent: cs.tertiaryContainer,
          icon: Icons.auto_stories_rounded,
          labelColorWeight: 1,
        );
      case 'geo':
        return NotificationTypeStyle(
          accent: cs.primaryContainer,
          icon: Icons.flight_rounded,
          labelColorWeight: 0.85,
        );
      case 'new_interest':
        return NotificationTypeStyle(
          accent: cs.secondaryContainer,
          icon: Icons.auto_awesome_rounded,
          labelColorWeight: 0.9,
        );
      case 'collector':
        return NotificationTypeStyle(
          accent: cs.surfaceContainerHigh,
          icon: Icons.menu_book_rounded,
          labelColorWeight: 0.75,
        );
      case 'resurface':
        return NotificationTypeStyle(
          accent: cs.surfaceContainerHighest,
          icon: Icons.history_rounded,
          labelColorWeight: 0.7,
        );
      case 'revisit':
        return NotificationTypeStyle(
          accent: cs.primaryContainer,
          icon: Icons.bookmark_added_rounded,
          labelColorWeight: 1,
        );
      case 'streak':
        return NotificationTypeStyle(
          accent: Color.alphaBlend(
            cs.errorContainer.withValues(alpha: 0.35),
            cs.surfaceContainerLow,
          ),
          icon: Icons.local_fire_department_rounded,
          labelColorWeight: 0.95,
        );
      default:
        return NotificationTypeStyle(
          accent: cs.surfaceContainerLow,
          icon: Icons.notifications_rounded,
          labelColorWeight: 0.65,
        );
    }
  }

  bool get isDigestHighlight => icon == Icons.auto_stories_rounded;
}
