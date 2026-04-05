import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/digest_prefs.dart';
import '../../core/services/notification_hub_labels.dart';
import '../../core/services/notification_router.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await DigestPrefs.loadHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _delete(String digestId) async {
    await DigestPrefs.deleteDigest(digestId);
    await _load();
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
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 64, color: cs.onSurfaceVariant),
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
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    return _NotificationTile(
                      entry: entry,
                      onTap: () => _openEntry(entry),
                      onDelete: () => _delete(entry['id'] as String),
                    );
                  },
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return _days[d.weekday - 1];

    final day = _days[d.weekday - 1];
    final month = _months[d.month - 1];
    return '$day, $month ${d.day}';
  }

  static IconData _iconForType(String? type) {
    switch (type) {
      case 'digest':
        return Icons.summarize_outlined;
      case 'geo':
        return Icons.flight_outlined;
      case 'new_interest':
        return Icons.auto_awesome_outlined;
      case 'collector':
        return Icons.library_books_outlined;
      case 'resurface':
        return Icons.history_outlined;
      case 'streak':
        return Icons.local_fire_department_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dateStr = entry['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr);
    final formatted = date != null ? _formatDate(date) : '';
    final topic = entry['topic'] as String? ?? 'Notification';
    final type = entry['type'] as String?;
    final isRead = entry['read'] == true;
    final body = entry['body'] as String?;
    final summaries = (entry['summaries'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final preview = (body != null && body.isNotEmpty)
        ? body
        : (summaries.isNotEmpty ? summaries.first : '');
    final channelLabel = NotificationHubLabels.forHistoryType(type);

    return Dismissible(
      key: ValueKey(entry['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: cs.error,
        child: Icon(Icons.delete_outline, color: cs.onError),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isRead ? cs.surfaceContainerHighest : cs.primaryContainer,
          child: Icon(
            _iconForType(type),
            color: isRead ? cs.onSurfaceVariant : cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          topic,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.isNotEmpty)
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  channelLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatted,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}
