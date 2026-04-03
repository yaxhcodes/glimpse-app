import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/digest_prefs.dart';

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

  Future<void> _openDigest(Map<String, dynamic> entry) async {
    final id = entry['id'] as String;
    await DigestPrefs.markDigestRead(id);

    final ids = (entry['ids'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];
    final summaries = (entry['summaries'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    await DigestPrefs.saveLastDigest(ids: ids, summaries: summaries);
    await _load();
    if (!mounted) return;
    context.push('/digest');
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
                          'Your weekly digest roundups will appear here.',
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
                    return _DigestHistoryTile(
                      entry: entry,
                      onTap: () => _openDigest(entry),
                      onDelete: () => _delete(entry['id'] as String),
                    );
                  },
                ),
    );
  }
}

class _DigestHistoryTile extends StatelessWidget {
  const _DigestHistoryTile({
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
    final day = _days[d.weekday - 1];
    final month = _months[d.month - 1];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final amPm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '$day, $month ${d.day} · $hour:$min $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dateStr = entry['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr);
    final formatted = date != null ? _formatDate(date) : '';
    final topic = entry['topic'] as String? ?? 'Weekly digest';
    final isRead = entry['read'] == true;
    final linkCount =
        (entry['ids'] as List<dynamic>?)?.length ?? 0;
    final summaries = (entry['summaries'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final preview =
        summaries.isNotEmpty ? summaries.first : '$linkCount links';

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
            isRead
                ? Icons.mark_email_read_outlined
                : Icons.mark_email_unread_outlined,
            color: isRead ? cs.onSurfaceVariant : cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          topic,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatted,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.outline,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}
