import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_icons.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/digest_prefs.dart';
import '../../core/services/notification_hub_labels.dart';
import '../../core/services/notification_router.dart';
import '../../shared/widgets/notifications/curated_notification_media.dart';
import '../../shared/widgets/notifications/notification_type_style.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../shared/widgets/premium_swipe_card.dart';
import '../../shared/widgets/expressive_tap_scale.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _history = [];
  Map<int, SavedUrl> _urlById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// First id = hero; up to three more for strip (`take(3)` downstream).
  List<int> _idsFromEntry(Map<String, dynamic> entry) {
    final raw = entry['ids'] as List<dynamic>? ?? [];
    return raw.map((e) => (e as num).toInt()).take(4).toList();
  }

  Future<void> _load() async {
    final history = await DigestPrefs.loadHistory();
    final isar = ref.read(isarServiceProvider);
    final idSet = <int>{};
    for (final e in history) {
      for (final id in _idsFromEntry(e)) {
        idSet.add(id);
      }
    }
    final urls = await isar.getUrlsByIds(idSet);
    if (!mounted) return;
    setState(() {
      _history = history;
      _urlById = urls;
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
          content: const Text('Deleted'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        title: const Text('Notifications'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? _EmptyNotifications(theme: theme)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                final ids = _idsFromEntry(entry);
                final heroUrl = ids.isNotEmpty ? _urlById[ids.first] : null;
                final stripUrls = ids
                    .skip(1)
                    .take(3)
                    .map((id) => _urlById[id])
                    .whereType<SavedUrl>()
                    .toList();

                return _StaggerReveal(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: PremiumSwipeCard(
                      key: ValueKey(entry['id']),
                      leftSwipeAction: SwipeActionType.delete,
                      rightSwipeAction: SwipeActionType.none,
                      borderRadius: BorderRadius.circular(20),
                      onAction: (_) => true,
                      onDismissed: (_) => _deleteWithUndo(entry, index),
                      child: CuratedNotificationListTile(
                        entry: entry,
                        heroUrl: heroUrl,
                        stripUrls: stripUrls,
                        onTap: () => _openEntry(entry),
                      ),
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
              'No notifications yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Travel alerts, new discoveries, reading reminders,\nand weekly digests will appear here.',
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
  const _StaggerReveal({required this.index, required this.child});

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
    required this.heroUrl,
    required this.stripUrls,
    required this.onTap,
  });

  final Map<String, dynamic> entry;
  final SavedUrl? heroUrl;
  final List<SavedUrl> stripUrls;
  final VoidCallback onTap;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final day = _days[d.weekday - 1];
    final month = _months[d.month - 1];
    return '$day, $month ${d.day}';
  }

  static String _fallbackContext(String topic, SavedUrl? hero) {
    if (hero == null) return '';
    final snippet = hero.summary?.trim();
    if (snippet != null && snippet.isNotEmpty && snippet != topic) {
      return snippet.length > 140 ? '${snippet.substring(0, 137)}…' : snippet;
    }
    final d = hero.description.trim();
    if (d.isNotEmpty && d != topic) {
      return d.length > 140 ? '${d.substring(0, 137)}…' : d;
    }
    final platform = hero.domain.trim();
    if (platform.isNotEmpty) return 'From $platform';
    return '';
  }

  /// One bundle-level line when several links are grouped (no tag pills).
  static String? _bundleHintLine(List<SavedUrl> urls) {
    if (urls.length < 2) return null;
    final catCounts = <String, int>{};
    for (final u in urls) {
      for (final c in u.effectiveCategories) {
        final trimmed = c.trim();
        if (trimmed.isEmpty) continue;
        // Domains only — keep platform/source names out of this line.
        // See title-and-copy-consistency-spec.md §5.
        if (CategoryResolver.isPlatformName(trimmed)) continue;
        catCounts[trimmed] = (catCounts[trimmed] ?? 0) + 1;
      }
    }
    if (catCounts.isEmpty) return null;
    final sorted = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final primary = sorted.first.key;
    if (sorted.length >= 2 &&
        sorted[1].value >= 2 &&
        sorted[1].key != primary) {
      final second = sorted[1].key;
      return 'Mostly $primary and $second.';
    }
    return 'Mostly about $primary.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dateStr = entry['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr);
    final formatted = date != null ? _formatDate(date) : '';

    final topic = entry['topic'] as String? ?? 'Notification';
    final body = entry['body'] as String?;
    final type = entry['type'] as String?;
    final isRead = entry['read'] == true;
    final typeStyle = NotificationTypeStyle.forHistoryType(
      type,
      Theme.of(context).colorScheme,
    );

    final channelLabel = NotificationHubLabels.forHistoryType(type);
    final contextLine = (body != null && body.trim().isNotEmpty)
        ? body.trim()
        : _fallbackContext(topic, heroUrl);

    final bundleUrls = <SavedUrl>[
      ...[heroUrl].whereType<SavedUrl>(),
      ...stripUrls,
    ];
    final rawHint = _bundleHintLine(bundleUrls);
    String? bundleHint;
    if (rawHint != null) {
      final a = rawHint.trim().toLowerCase();
      final b = contextLine.trim().toLowerCase();
      final redundant =
          b.isNotEmpty && (a == b || b.contains(a) || a.contains(b));
      bundleHint = redundant ? null : rawHint;
    }

    const kStateAnim = Duration(milliseconds: 180);

    final cardColor = cs.surfaceContainerLow;

    final titleWeight = isRead ? FontWeight.w400 : FontWeight.w600;

    late final Widget hero;
    if (heroUrl != null) {
      hero = CuratedNotificationHero(
        url: heroUrl!,
        radius: 14,
        blendBottomEdge: true,
        showUnreadIndicator: !isRead,
      );
    } else {
      hero = const CuratedMissingLinkHero(radius: 14);
    }

    final paddingOuter = EdgeInsets.fromLTRB(
      14,
      typeStyle.isDigestHighlight ? 15 : 13,
      14,
      13,
    );

    final secondaryMuted = theme.brightness == Brightness.light ? 0.88 : 0.84;

    return ExpressiveTapScale(
      child: AnimatedContainer(
        duration: kStateAnim,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isRead
              ? const []
              : [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.1),
                    blurRadius: 9,
                    offset: const Offset(0, 2),
                    spreadRadius: -1,
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: paddingOuter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: kStateAnim,
                          curve: Curves.easeOutCubic,
                          style:
                              (theme.textTheme.titleMedium ?? const TextStyle())
                                  .copyWith(
                                    fontWeight: titleWeight,
                                    height: 1.22,
                                    color: cs.onSurface,
                                    fontSize:
                                        (theme
                                            .textTheme
                                            .titleMedium
                                            ?.fontSize ??
                                        16),
                                  ),
                          child: Text(
                            topic,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (contextLine.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AnimatedOpacity(
                      duration: kStateAnim,
                      curve: Curves.easeOut,
                      opacity: isRead ? secondaryMuted : 1.0,
                      child: Text(
                        contextLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(
                            alpha: isRead ? 0.78 : 1,
                          ),
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                  if (bundleHint != null) ...[
                    const SizedBox(height: 4),
                    AnimatedOpacity(
                      duration: kStateAnim,
                      curve: Curves.easeOut,
                      opacity: isRead ? 0.82 : 1.0,
                      child: Text(
                        bundleHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                          fontSize:
                              (theme.textTheme.bodySmall?.fontSize ?? 12) +
                              0.75,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                  ],
                  if (stripUrls.isNotEmpty) ...[
                    SizedBox(
                      height: bundleHint != null
                          ? 8
                          : (contextLine.isNotEmpty ? 10 : 11),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < stripUrls.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          CuratedNotificationThumbStripItem(
                            url: stripUrls[i],
                            size: 50,
                            squareRadius: 9,
                            emphasized: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.outlineVariant.withValues(alpha: 0.32),
                    ),
                    const SizedBox(height: 11),
                  ] else ...[
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TypeBadge(label: channelLabel),
                      const Spacer(),
                      if (formatted.isNotEmpty)
                        AnimatedOpacity(
                          duration: kStateAnim,
                          curve: Curves.easeOut,
                          opacity: isRead ? 0.78 : 0.92,
                          child: Text(
                            formatted,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.12,
                              color: cs.outline,
                            ),
                          ),
                        ),
                    ],
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

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = cs.secondaryContainer;
    final fg = cs.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: ShapeDecoration(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: 11.75,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.12,
          height: 1.1,
          color: fg,
        ),
      ),
    );
  }
}
