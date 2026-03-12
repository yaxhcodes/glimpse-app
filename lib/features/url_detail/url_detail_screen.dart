import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../home/home_provider.dart';
import 'url_detail_provider.dart';

class UrlDetailScreen extends ConsumerStatefulWidget {
  final int urlId;

  const UrlDetailScreen({super.key, required this.urlId});

  @override
  ConsumerState<UrlDetailScreen> createState() => _UrlDetailScreenState();
}

class _UrlDetailScreenState extends ConsumerState<UrlDetailScreen> {
  late TextEditingController _notesController;
  bool _notesEdited = false;
  bool _descExpanded = false;
  bool _tagsExpanded = false;
  Timer? _notesTimer;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _saveNotes() async {
    final success = await ref
        .read(urlDetailNotifierProvider.notifier)
        .updateNotes(widget.urlId, _notesController.text);
    if (success && mounted) {
      ref.invalidate(urlDetailProvider(widget.urlId));
      setState(() => _notesEdited = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    }
  }

  Future<void> _autoSaveNotes() async {
    await ref
        .read(urlDetailNotifierProvider.notifier)
        .updateNotes(widget.urlId, _notesController.text);
    if (mounted) {
      ref.invalidate(urlDetailProvider(widget.urlId));
      setState(() => _notesEdited = false);
    }
  }

  Future<void> _deleteUrl() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete URL?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(urlDetailNotifierProvider.notifier)
          .deleteUrl(widget.urlId);
      if (success && mounted) {
        context.pop();
      }
    }
  }

  Future<void> _removeTag(SavedUrl url, String tag) async {
    final isarService = ref.read(isarServiceProvider);
    url.tags = url.tags.where((t) => t != tag).toList();
    await isarService.updateUrl(url);
    ref.invalidate(urlDetailProvider(widget.urlId));
  }

  Future<void> _addTag(SavedUrl url) async {
    final controller = TextEditingController();
    final newTag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. design, recipe…'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newTag == null || newTag.isEmpty || !mounted) return;
    if (url.tags.contains(newTag)) return;
    final isarService = ref.read(isarServiceProvider);
    url.tags = [...url.tags, newTag];
    await isarService.updateUrl(url);
    ref.invalidate(urlDetailProvider(widget.urlId));
  }

  Future<void> _changeCategory(SavedUrl url) async {
    final theme = Theme.of(context);
    final isarService = ref.read(isarServiceProvider);

    // Get existing categories to show as suggestions
    final categories = await isarService.getCategories();
    final existingNames =
        categories.map((c) => c['category'] as String).toList();

    if (!mounted) return;

    final customController = TextEditingController();
    final emojiController = TextEditingController(text: '📁');

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Change Category',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Pick an existing one or create your own',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),

              // Existing categories
              if (existingNames.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: existingNames.map((name) {
                    final cat = categories.firstWhere(
                        (c) => c['category'] == name);
                    final emoji = cat['emoji'] as String;
                    final isCurrentCat = name == url.category;
                    final fav = faviconUrl(name);
                    return ActionChip(
                      avatar: fav != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: CachedNetworkImage(
                                imageUrl: fav,
                                width: 18,
                                height: 18,
                                errorWidget: (_, _, _) =>
                                    Text(emoji),
                              ),
                            )
                          : Text(emoji),
                      label: Text(name),
                      side: isCurrentCat
                          ? BorderSide(
                              color: theme.colorScheme.primary, width: 2)
                          : null,
                      onPressed: () => Navigator.pop(ctx, {
                        'category': name,
                        'emoji': emoji,
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or create new',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // New custom category
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: emojiController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                      decoration: const InputDecoration(
                        hintText: '📁',
                        counterText: '',
                      ),
                      maxLength: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: customController,
                      autofocus: existingNames.isEmpty,
                      decoration: const InputDecoration(
                        hintText: 'Category name',
                        labelText: 'New category',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final name = customController.text.trim();
                  if (name.isEmpty) return;
                  final emoji = emojiController.text.trim().isEmpty
                      ? '📁'
                      : emojiController.text.trim();
                  Navigator.pop(ctx, {
                    'category': name,
                    'emoji': emoji,
                  });
                },
                child: const Text('Create & Apply'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    final newCat = result['category']!;
    final newEmoji = result['emoji']!;

    if (newCat == url.category) return;

    final additionalCategories = url.effectiveCategories
        .where((item) => item != url.category)
        .toList();
    url.category = newCat;
    url.categoryEmoji = newEmoji;
    url.categories = CategoryResolver.buildCategories(
      primaryCategory: newCat,
      additionalCategories: additionalCategories,
    );
    await isarService.updateUrl(url);
    ref.invalidate(urlDetailProvider(widget.urlId));
    ref.invalidate(categoriesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to "$newCat"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlAsync = ref.watch(urlDetailProvider(widget.urlId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final url = urlAsync.valueOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Details'),
            actions: [
              if (url != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteUrl,
                ),
            ],
          ),
          if (urlAsync.isLoading)
            const SliverFillRemaining(child: LoadingIndicator())
          else if (urlAsync.hasError)
            SliverFillRemaining(
                child: Center(child: Text('Error: ${urlAsync.error}')))
          else if (url == null)
            const SliverFillRemaining(
                child: Center(child: Text('URL not found')))
          else
            _buildBody(url, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildBody(SavedUrl url, ThemeData theme, ColorScheme colorScheme) {
    if (!_notesEdited) {
      _notesController.text = url.userNotes ?? '';
    }
    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: url.rawUrl,
      fallbackDomain: url.domain,
    );
    final normalizedCategories =
        url.effectiveCategories.map((item) => item.toLowerCase()).toSet();
    final visibleTags = url.tags
        .where((tag) => !normalizedCategories.contains(tag.toLowerCase()))
        .where((tag) => tag.toLowerCase() != displaySourceName.toLowerCase())
        .toList();
    final showImage = url.thumbnailUrl != null && url.thumbnailUrl!.isNotEmpty;
    final hasDescription = url.description.isNotEmpty;
    const collapseTagsAt = 5;
    final showAllTags = _tagsExpanded || visibleTags.length <= collapseTagsAt;
    final displayedTags =
        showAllTags ? visibleTags : visibleTags.take(collapseTagsAt).toList();
    final hiddenTagCount = visibleTags.length - collapseTagsAt;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ───────────────────────────────────────────────────
            if (showImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: url.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Title ───────────────────────────────────────────────────
            Text(
              url.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Metadata: platform · date ────────────────────────────────
            Row(
              children: [
                Icon(Icons.public_outlined,
                    size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  displaySourceName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '·',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _formatDate(url.savedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Category chips ───────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: url.effectiveCategories.map((category) {
                final isPrimary = category == url.category;
                return GestureDetector(
                  onTap: isPrimary ? () => _changeCategory(url) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? colorScheme.secondaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _categoryIcon(
                          category,
                          isPrimary
                              ? url.categoryEmoji
                              : CategoryResolver.emojiForCategory(category),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isPrimary
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: colorScheme.onSecondaryContainer
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Description ─────────────────────────────────────────────
            if (hasDescription) ...[
              const SizedBox(height: 16),
              Text(
                url.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  height: 1.55,
                  color: colorScheme.onSurface,
                ),
                maxLines: _descExpanded ? null : 7,
                overflow: _descExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (_shouldShowReadMore(url.description)) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () =>
                      setState(() => _descExpanded = !_descExpanded),
                  child: Text(
                    _descExpanded ? 'Show less' : 'Read more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],

            // ── Tags ────────────────────────────────────────────────────
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...displayedTags.map((tag) => InputChip(
                      label: Text(tag),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _removeTag(url, tag),
                    )),
                if (!showAllTags && hiddenTagCount > 0)
                  ActionChip(
                    label: Text('+$hiddenTagCount'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _tagsExpanded = true),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add tag'),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addTag(url),
                ),
              ],
            ),

            // ── Actions ─────────────────────────────────────────────────
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _launchUrl(url.rawUrl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Share.share(url.rawUrl),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url.rawUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),

            // ── Notes ───────────────────────────────────────────────────
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sticky_note_2_outlined,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Notes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_notesEdited)
                        TextButton(
                          onPressed: _saveNotes,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Save'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Add personal notes...',
                    ),
                    minLines: 3,
                    maxLines: null,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    onChanged: (_) {
                      if (!_notesEdited) setState(() => _notesEdited = true);
                      _notesTimer?.cancel();
                      _notesTimer = Timer(
                        const Duration(milliseconds: 1500),
                        _autoSaveNotes,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowReadMore(String description) {
    return description.length > 350 ||
        '\n'.allMatches(description).length >= 6;
  }

  Widget _categoryIcon(String category, String emoji) {
    final favicon = faviconUrl(category);
    if (favicon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CachedNetworkImage(
          imageUrl: favicon,
          width: 16,
          height: 16,
          errorWidget: (_, _, _) =>
              Text(emoji, style: const TextStyle(fontSize: 14)),
        ),
      );
    }
    return Text(emoji, style: const TextStyle(fontSize: 14));
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}
