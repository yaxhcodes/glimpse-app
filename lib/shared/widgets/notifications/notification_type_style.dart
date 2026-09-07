import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';

/// Subtle surface / accent tokens for notification history [type] strings.
class NotificationTypeStyle {
  const NotificationTypeStyle({
    required this.accent,
    required this.icon,
    required this.labelColorWeight,
    this.isDigestHighlight = false,
  });

  final Color accent;
  final IconData icon;
  final double labelColorWeight;
  final bool isDigestHighlight;

  static NotificationTypeStyle forHistoryType(String? type, ColorScheme cs) {
    switch (type) {
      case 'digest':
        return NotificationTypeStyle(
          accent: cs.tertiaryContainer,
          icon: AppIcons.bookOpen,
          labelColorWeight: 1,
          isDigestHighlight: true,
        );
      case 'geo':
        return NotificationTypeStyle(
          accent: cs.primaryContainer,
          icon: AppIcons.flight,
          labelColorWeight: 0.85,
        );
      case 'new_interest':
        return NotificationTypeStyle(
          accent: cs.secondaryContainer,
          icon: AppIcons.interests,
          labelColorWeight: 0.9,
        );
      case 'collector':
        return NotificationTypeStyle(
          accent: cs.surfaceContainerHigh,
          icon: AppIcons.bookOpen,
          labelColorWeight: 0.75,
        );
      case 'resurface':
        return NotificationTypeStyle(
          accent: cs.surfaceContainerHighest,
          icon: AppIcons.rediscover,
          labelColorWeight: 0.7,
        );
      case 'revisit':
        return NotificationTypeStyle(
          accent: cs.primaryContainer,
          icon: AppIcons.bookmarkSaved,
          labelColorWeight: 1,
        );
      case 'streak':
        return NotificationTypeStyle(
          accent: Color.alphaBlend(
            cs.errorContainer.withValues(alpha: 0.35),
            cs.surfaceContainerLow,
          ),
          icon: AppIcons.fire,
          labelColorWeight: 0.95,
        );
      default:
        return NotificationTypeStyle(
          accent: cs.surfaceContainerLow,
          icon: AppIcons.notifications,
          labelColorWeight: 0.65,
        );
    }
  }
}
