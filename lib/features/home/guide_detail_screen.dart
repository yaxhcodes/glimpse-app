import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/app_assets.dart';
import '../../shared/theme/app_icons.dart';

/// Exact capture instructions shown after the value-led onboarding story.
class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isAndroid = Platform.isAndroid;
    final steps = isAndroid
        ? const [
            (
              Symbols.bookmark_rounded,
              'Find something worth keeping',
              'A reel, video, article, recipe or any useful link.',
            ),
            (
              Symbols.ios_share_rounded,
              'Tap Share',
              'Use the same Share button you already use in that app.',
            ),
            (
              Symbols.visibility_rounded,
              'Choose Glimpse',
              'The link is saved immediately. Glimpse understands it in the background.',
            ),
          ]
        : const [
            (
              Symbols.bookmark_rounded,
              'Find something worth keeping',
              'A video, article, recipe or any useful link.',
            ),
            (
              Symbols.content_copy_rounded,
              'Copy its link',
              'Use Copy Link from the app or browser you are viewing.',
            ),
            (
              Symbols.add_link_rounded,
              'Paste it on Home',
              'Glimpse saves it immediately and understands it in the background.',
            ),
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('Save your first find')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Center(
            child: Container(
              width: 112,
              height: 112,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Image.asset(AppAssets.logo),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isAndroid ? 'Share → Glimpse' : 'Copy → Glimpse',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'No folders to choose and nothing to file.',
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          for (var index = 0; index < steps.length; index++)
            _GuideStep(index: index + 1, step: steps[index]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  Symbols.auto_awesome_rounded,
                  size: 21,
                  color: cs.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI enrichment happens after capture and degrades gracefully. Your link is kept even when enrichment is unavailable.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.index, required this.step});

  final int index;
  final (IconData, String, String) step;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: AppIcon(step.$1, size: 23, color: cs.onPrimaryContainer),
              ),
              Positioned(
                right: -5,
                bottom: -5,
                child: Container(
                  width: 21,
                  height: 21,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Text(
                    '$index',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.$2, style: tt.titleSmall),
                const SizedBox(height: 4),
                Text(
                  step.$3,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
