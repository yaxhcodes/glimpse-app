import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_layout.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    final localItems = [
      strings.bookmarks,
      strings.notes,
      strings.collections,
      strings.tags,
      strings.aiSummaries,
    ];
    final uploadedItems = [
      strings.accountInformation,
      strings.subscriptionStatus,
      strings.anonymousProductAnalytics,
    ];
    final pagePadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
      compactPadding: 20,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(strings.privacy),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 32),
        children: [
          _PrivacySection(title: strings.local, items: localItems),
          const SizedBox(height: 24),
          _PrivacySection(title: strings.uploaded, items: uploadedItems),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _PrivacyRow(label: items[i]),
                if (i != items.length - 1)
                  Divider(height: 1, color: cs.outlineVariant),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
