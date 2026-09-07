import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

/// Shares the expansion controller so restored and programmatic state also
/// updates the glyph, without a second source of expansion state.
class AppExpansionChevron extends StatelessWidget {
  const AppExpansionChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ExpansibleController.of(context);
    final style = ExpansionTileTheme.of(context).expansionAnimationStyle;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AnimatedRotation(
        turns: controller.isExpanded ? 0.5 : 0,
        duration: style?.duration ?? const Duration(milliseconds: 200),
        curve: style?.curve ?? Curves.easeInOut,
        child: const AppIcon(AppIcons.chevronDown),
      ),
    );
  }
}
