import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

const _glimpseMaterialSymbolsFamily = 'GlimpseMaterialSymbolsRounded';

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
    assert(
      icon.fontFamily == 'MaterialSymbolsRounded' &&
          icon.fontPackage == 'material_symbols_icons',
      'AppIcon only supports rounded icons from material_symbols_icons.',
    );

    final iconTheme = IconTheme.of(context);
    final tentativeIconSize = size ?? iconTheme.size ?? 24;
    final iconSize = iconTheme.applyTextScaling ?? false
        ? MediaQuery.textScalerOf(context).scale(tentativeIconSize)
        : tentativeIconSize;
    final iconOpacity = iconTheme.opacity ?? 1;
    final baseIconColor = color ?? iconTheme.color;
    final iconColor = iconOpacity == 1
        ? baseIconColor
        : baseIconColor?.withValues(
            alpha: baseIconColor.a * iconOpacity,
          );
    final iconFill = fill ?? (selected ? 1.0 : 0.0);
    final iconWeight = weight ?? (selected ? 550.0 : 400.0);
    final textDirection = Directionality.of(context);

    Widget iconWidget = RichText(
      overflow: TextOverflow.visible,
      textDirection: textDirection,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: iconColor,
          fontSize: iconSize,
          fontFamily: _glimpseMaterialSymbolsFamily,
          shadows: iconTheme.shadows,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
          fontVariations: [
            FontVariation('FILL', iconFill),
            FontVariation('wght', iconWeight),
            if (iconTheme.grade != null)
              FontVariation('GRAD', iconTheme.grade!),
            FontVariation('opsz', iconSize),
          ],
        ),
      ),
    );

    if (icon.matchTextDirection && textDirection == TextDirection.rtl) {
      iconWidget = Transform.flip(
        flipX: true,
        transformHitTests: false,
        child: iconWidget,
      );
    }

    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: iconSize,
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}
