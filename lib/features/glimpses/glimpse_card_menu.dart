import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:glimpse/shared/widgets/app_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import 'glimpse.dart';
import 'glimpse_service.dart';
import '../../core/services/app_haptics.dart';

class GlimpseCardMenu extends ConsumerStatefulWidget {
  const GlimpseCardMenu({super.key, required this.glimpse});
  final Glimpse glimpse;

  @override
  ConsumerState<GlimpseCardMenu> createState() => _GlimpseCardMenuState();
}

class _GlimpseCardMenuState extends ConsumerState<GlimpseCardMenu> {
  bool _busy = false;

  Future<void> _act(GlimpseAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    AppHaptics.play(AppHaptics.tick);
    try {
      await ref.read(glimpseServiceProvider).act(widget.glimpse, action);
      if (!mounted) return;
      final l = context.l10n;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              action == GlimpseAction.later
                  ? l.glimpsesLaterFeedback
                  : l.seeLessLikeThis,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      ref.invalidate(glimpsesProvider);
    } on Object catch (error, stack) {
      developer.log(
        'Could not update Rediscover feedback',
        name: 'GlimpseCardMenu',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.glimpsesActionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: .82),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<GlimpseAction>(
        enabled: !_busy,
        tooltip: l.rediscoverOptions,
        icon: Icon(AppIcons.moreHorizontal, color: cs.onSurface),
        onSelected: _act,
        itemBuilder: (_) => [
          appMenuItem(
            value: GlimpseAction.later,
            icon: AppIcons.clock,
            label: l.notNow,
            subtitle: l.glimpsesLaterFeedback,
          ),
          appMenuItem(
            value: GlimpseAction.lessLikeThis,
            icon: AppIcons.dislike,
            label: l.lessLikeThis,
            subtitle: l.reduceSimilarTopics,
          ),
        ],
      ),
    );
  }
}
