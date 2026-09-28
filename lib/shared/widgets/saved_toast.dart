import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../l10n/l10n.dart';
import '../theme/app_icons.dart';
import 'app_snackbar.dart';

/// The app icon that marks a save landing in Glimpse.
class SavedToastIcon extends StatelessWidget {
  const SavedToastIcon({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(AppAssets.launcherIcon, width: size, height: size),
    );
  }
}

/// "Saved to Glimpse ✓": the pill onboarding promises and every save shows.
class SavedToast extends StatelessWidget {
  const SavedToast({super.key, this.label});

  /// Defaults to "Saved to Glimpse".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      decoration: savedToastDecoration(cs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SavedToastIcon(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label ?? context.l10n.savedToGlimpse,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onInverseSurface),
            ),
          ),
          const SizedBox(width: 8),
          AppIcon(AppIcons.checkCircle, size: 16, color: cs.inversePrimary),
        ],
      ),
    );
  }
}

BoxDecoration savedToastDecoration(
  ColorScheme cs, {
  Color? color,
  double radius = 99,
}) {
  return BoxDecoration(
    color: color ?? cs.inverseSurface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .3),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// Confirms an in-app save with the same pill, as a snackbar. [onUndo] is
/// only for a save that just created the item.
void showSavedSnackBar(
  ScaffoldMessengerState messenger,
  AppLocalizations strings, {
  String? label,
  VoidCallback? onUndo,
}) {
  showAutoDismissSnackBarVia(
    messenger,
    SnackBar(
      content: Row(
        children: [
          const SavedToastIcon(size: 24),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label ?? strings.savedToGlimpse,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      shape: const StadiumBorder(),
      padding: EdgeInsetsDirectional.fromSTEB(8, 6, onUndo == null ? 20 : 8, 6),
      duration: const Duration(seconds: 3),
      action: onUndo == null
          ? null
          : SnackBarAction(label: strings.undo, onPressed: onUndo),
    ),
  );
}
