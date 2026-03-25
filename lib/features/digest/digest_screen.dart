import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/isar_service.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/digest_prefs.dart';
import '../../shared/widgets/loading_indicator.dart';

/// Shows the last digest payload (from notification) or loads URLs by id.
class DigestScreen extends ConsumerStatefulWidget {
  const DigestScreen({super.key});

  @override
  ConsumerState<DigestScreen> createState() => _DigestScreenState();
}

class _DigestScreenState extends ConsumerState<DigestScreen> {
  Map<String, dynamic>? _cached;

  @override
  void initState() {
    super.initState();
    DigestPrefs.loadLastDigest().then((m) {
      if (mounted) setState(() => _cached = m ?? {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_cached == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Digest')),
        body: const LoadingIndicator(message: 'Loading digest…'),
      );
    }

    final ids = (_cached?['ids'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const <int>[];
    final summaries = (_cached?['summaries'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    if (ids.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Digest')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No digest yet. When your weekly roundup is ready, it will show here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your digest'),
      ),
      body: FutureBuilder<List<SavedUrl?>>(
        key: ValueKey(ids.join(',')),
        future: _loadUrls(ref.read(isarServiceProvider), ids),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const LoadingIndicator(message: 'Loading links…');
          }
          final urls = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Here are a few links you saved but haven’t opened yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < urls.length; i++) ...[
                if (urls[i] != null) _DigestTile(
                  url: urls[i]!,
                  summary: i < summaries.length ? summaries[i] : '',
                  onOpen: () => _open(urls[i]!),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<List<SavedUrl?>> _loadUrls(IsarService isar, List<int> ids) async {
    final out = <SavedUrl?>[];
    for (final id in ids) {
      out.add(await isar.getUrlById(id));
    }
    return out;
  }

  Future<void> _open(SavedUrl url) async {
    await ref.read(isarServiceProvider).updateOpenedAt(url.id, DateTime.now());
    final uri = Uri.parse(url.rawUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _DigestTile extends StatelessWidget {
  const _DigestTile({
    required this.url,
    required this.summary,
    required this.onOpen,
  });

  final SavedUrl url;
  final String summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              url.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: onOpen,
                  child: const Text('Open'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/url/${url.id}'),
                  child: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
