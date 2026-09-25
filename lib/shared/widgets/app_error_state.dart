import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_icons.dart';

/// Calm, localized error state for screens and sheets.
///
/// Shows a human message and an optional retry. The underlying [error] is
/// logged for debugging, never rendered: raw exception text is meaningless to
/// people and leaks internals into the UI.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  /// Inline variant for sheets and small regions (no large icon).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      developer.log(
        message,
        name: 'AppErrorState',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final retry = onRetry == null
        ? null
        : FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh),
            label: Text(context.l10n.tryAgain),
          );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (retry != null) ...[const SizedBox(height: 12), retry],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (retry != null) ...[const SizedBox(height: 20), retry],
          ],
        ),
      ),
    );
  }
}
