import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';

/// A quiet, responsive waiting state that keeps the saved source accessible.
class ReaderEnrichmentProgress extends StatelessWidget {
  const ReaderEnrichmentProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: MediaQuery.disableAnimationsOf(context)
                  ? Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: colors.primary,
                    )
                  : ExpressiveLoadingIndicator(size: 24, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.readerEnrichingTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.readerEnrichingBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
