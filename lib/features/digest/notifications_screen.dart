import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_icons.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../shared/widgets/premium_swipe_card.dart';
import '../../shared/widgets/notifications/curated_notification_media.dart';
import '../home/home_provider.dart';

import '../../core/services/digest_prefs.dart';
import '../../core/services/notification_hub_labels.dart';
import '../../core/services/notification_router.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../l10n/l10n.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  StreamSubscription<void>? _historySubscription;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _historySubscription = DigestPrefs.historyChanges.listen((_) {
      unawaited(_load());
    });
    _load();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final history = await DigestPrefs.loadHistory();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _deleteWithUndo(Map<String, dynamic> entry, int index) async {
    await DigestPrefs.deleteDigest(entry['id'] as String);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.glimpsesNotificationCleared),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () async {
              await DigestPrefs.restoreDigest(entry, index: index);
              await _load();
            },
          ),
        ),
      );
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final id = entry['id'] as String;
    await DigestPrefs.markDigestRead(id);

    if (!mounted) return;

    await _load();
    if (!mounted) return;

    await NotificationRouter.openFromHub(
      context,
      notifId: entry['notifId'] as String?,
      historyEntry: entry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urls = {
      for (final url
          in ref.watch(urlStreamProvider).valueOrNull ?? <SavedUrl>[])
        url.id: url,
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        title: Text(context.l10n.notifications),
      ),
      body: _loading
          ? const Center(child: ExpressiveLoadingIndicator())
          : _history.isEmpty
          ? _EmptyNotifications(theme: theme)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                final rawIds = entry['linkIds'] ?? entry['ids'];
                final ids = rawIds is List
                    ? rawIds.whereType<num>().map((id) => id.toInt()).toSet()
                    : <int>{};
                return _StaggerReveal(
                  key: ValueKey(entry['id']),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: CuratedNotificationListTile(
                      entry: entry,
                      sources: ids.length > 1
                          ? ids
                                .map((id) => urls[id])
                                .whereType<SavedUrl>()
                                .toList()
                          : const [],
                      onTap: () => _openEntry(entry),
                      onClear: () => _deleteWithUndo(entry, index),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.notifications,
              size: 64,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noNotificationsYet,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.notificationsEmptyDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggerReveal extends StatefulWidget {
  const _StaggerReveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<_StaggerReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    final delay = Duration(milliseconds: 40 * widget.index.clamp(0, 12));
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class CuratedNotificationListTile extends StatelessWidget {
  const CuratedNotificationListTile({
    super.key,
    required this.entry,
    required this.onClear,
    required this.onTap,
    this.sources = const [],
  });

  final Map<String, dynamic> entry;
  final FutureOr<void> Function() onClear;
  final VoidCallback onTap;
  final List<SavedUrl> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(entry['date']?.toString() ?? '');
    Color mutedAccent(Color color) {
      final hsl = HSLColor.fromColor(color);
      return hsl.withSaturation(hsl.saturation * .5).toColor();
    }

    final label = NotificationHubLabels.forHistoryType(
      context.l10n,
      entry['type'] as String?,
    );
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: context.l10n.glimpsesClear): () {
          unawaited(Future<void>.sync(onClear));
        },
      },
      child: PremiumSwipeCard(
        leftSwipeAction: SwipeActionType.delete,
        rightSwipeAction: SwipeActionType.delete,
        actionLabel: context.l10n.glimpsesClear,
        borderRadius: BorderRadius.circular(20),
        onDismissed: (_) => onClear(),
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry['topic']?.toString() ??
                              context.l10n.notification,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: entry['read'] == true
                                ? FontWeight.w500
                                : FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (entry['read'] != true) ...[
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Semantics(
                            label: context.l10n.unread,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: mutedAccent(theme.colorScheme.primary),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((entry['body']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry['body'].toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (sources.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ExcludeSemantics(
                      child: CuratedNotificationThumbStack(
                        urls: sources,
                        size: 40,
                        overlap: 8,
                        squareRadius: 8,
                        maxVisible: 2,
                        gapColor: theme.colorScheme.surfaceContainerLow,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: ShapeDecoration(
                            color: mutedAccent(
                              theme.colorScheme.primaryContainer,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (date != null)
                          Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(date),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
