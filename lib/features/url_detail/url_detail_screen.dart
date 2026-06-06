import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
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
import '../../core/services/category_taxonomy.dart';
import '../../core/services/summary_rewriter.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/text_cleaner.dart';
import '../../core/services/title_resolver.dart';
import '../../core/services/transcript_enrichment_service.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl, platformColors;
import '../../shared/widgets/content_recommendation_section.dart';
import '../../shared/widgets/creator_profile_link.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/metadata_pill.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/tag_group.dart';
import '../collections/add_to_collection_sheet.dart';
import '../home/home_provider.dart';
import 'url_detail_provider.dart';

class UrlDetailScreen extends ConsumerStatefulWidget {
  final int urlId;

  const UrlDetailScreen({super.key, required this.urlId});

  @override
  ConsumerState<UrlDetailScreen> createState() => _UrlDetailScreenState();
}

class _DetailMetadata {
  const _DetailMetadata({
    this.likesLabel,
    this.commentsLabel,
    this.creatorUsername,
  });

  final String? likesLabel;
  final String? commentsLabel;
  final String? creatorUsername;

  bool get hasStats => likesLabel != null || commentsLabel != null;
  bool get hasSocialRow => hasStats || creatorUsername != null;
}

class _GlimpseSavedNote {
  const _GlimpseSavedNote({
    required this.answer,
    this.asked,
    this.question,
  });

  final String answer;
  final String? asked;
  final String? question;
}

class _GlimpseSavedNoteCard extends StatelessWidget {
  const _GlimpseSavedNoteCard({
    required this.note,
    required this.theme,
    required this.colorScheme,
  });

  final _GlimpseSavedNote note;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Ask Glimpse',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              if ((note.asked ?? '').isNotEmpty)
                Text(
                  note.asked!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.66),
                    height: 1,
                  ),
                ),
            ],
          ),
          if ((note.question ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              note.question!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if (note.answer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.answer,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteSuggestionChip extends StatelessWidget {
  const _NoteSuggestionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.78),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadStatePill extends StatelessWidget {
  const _ReadStatePill({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isRead ? 'Read' : 'Unread',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _UrlDetailScreenState extends ConsumerState<UrlDetailScreen> {
  /// Layouts narrower than this use stacked action buttons (small display / dense phones).
  static const double _narrowLayoutWidth = 360;

  late TextEditingController _notesController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _descriptionSectionKey = GlobalKey();
  final FocusNode _notesFocusNode = FocusNode();
  bool _notesEdited = false;
  bool _descExpanded = false;
  bool _tagsExpanded = false;
  bool _showFullUrl = false;
  bool _showExactSavedDate = false;
  String? _localNotesOverride;
  Timer? _notesTimer;

  @override
  void didUpdateWidget(covariant UrlDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlId != widget.urlId) {
      _showFullUrl = false;
      _descExpanded = false;
      _tagsExpanded = false;
      _showExactSavedDate = false;
      _localNotesOverride = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _notesFocusNode.addListener(_handleNotesFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repaired = await ref
          .read(urlDetailNotifierProvider.notifier)
          .refreshContentIfLikelyTruncated(widget.urlId);
      if (repaired && mounted) {
        ref.invalidate(urlDetailProvider(widget.urlId));
      }
    });
  }

  @override
  void dispose() {
    _notesTimer?.cancel();
    if (_notesEdited) {
      ref
          .read(urlDetailNotifierProvider.notifier)
          .updateNotes(widget.urlId, _notesController.text);
    }
    _notesFocusNode.removeListener(_handleNotesFocusChange);
    _notesFocusNode.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleNotesFocusChange() {
    if (!_notesFocusNode.hasFocus && _notesEdited) {
      _notesTimer?.cancel();
      _autoSaveNotes();
    }
  }

  Future<void> _toggleDescription() async {
    final anchorContext = _descriptionSectionKey.currentContext;
    final beforeTop = _globalTop(anchorContext);
    final previousOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    setState(() => _descExpanded = !_descExpanded);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final afterTop = _globalTop(_descriptionSectionKey.currentContext);
      final delta = beforeTop != null && afterTop != null ? afterTop - beforeTop : 0.0;
      final targetOffset = (previousOffset + delta).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      if ((targetOffset - _scrollController.offset).abs() < 1) return;

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showAddToCollection(SavedUrl url) {
    showAddToCollectionSheet(context, url);
  }

  void _copyUrlToClipboard(String raw) {
    Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Link copied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
  }

  Future<void> _launchUrl(String url) async {
    await ref
        .read(isarServiceProvider)
        .updateOpenedAt(widget.urlId, DateTime.now());
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
      setState(() {
        _localNotesOverride = _notesController.text;
        _notesEdited = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Notes saved'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  /// Persists notes without invalidating [urlDetailProvider] — a refetch shows
  /// loading and replaces the whole body, which disposed the field and dropped focus.
  Future<void> _autoSaveNotes() async {
    final success = await ref
        .read(urlDetailNotifierProvider.notifier)
        .updateNotes(widget.urlId, _notesController.text);
    if (success && mounted) {
      setState(() {
        _localNotesOverride = _notesController.text;
        _notesEdited = false;
      });
    }
  }

  void _scheduleNotesAutosave() {
    if (!_notesEdited) {
      setState(() => _notesEdited = true);
    }
    _notesTimer?.cancel();
    _notesTimer = Timer(
      const Duration(milliseconds: 1500),
      _autoSaveNotes,
    );
  }

  void _applyNoteSuggestion(String suggestion) {
    final current = _notesController.text.trim();
    final next = current.isEmpty
        ? suggestion
        : current
                .toLowerCase()
                .split('\n')
                .map((line) => line.trim())
                .contains(suggestion.toLowerCase())
            ? current
            : '$current\n$suggestion';

    _notesController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _localNotesOverride = next;
    _scheduleNotesAutosave();
    _notesFocusNode.requestFocus();
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Moved to "$newCat"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlAsync = ref.watch(urlDetailProvider(widget.urlId));
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final url = urlAsync.valueOrNull;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurfaceVariant,
            title: const Text('Details'),
            actions: [
              if (url != null) ...[
                IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  tooltip: 'Add to collection',
                  onPressed: () => _showAddToCollection(url),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More',
                  onSelected: (value) {
                    if (value == 'change_category') {
                      _changeCategory(url);
                    } else if (value == 'delete') {
                      _deleteUrl();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'change_category',
                      child: Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          const Text('Change category'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
            _buildBody(url, theme, colorScheme, tagFreq),
        ],
      ),
    );
  }

  Widget _buildBody(
    SavedUrl url,
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, int> tagFreq,
  ) {
    if (!_notesEdited && !_notesFocusNode.hasFocus) {
      _notesController.text = _localNotesOverride ?? url.userNotes ?? '';
    }
    final live = _savedEnrichment(url);
    final metadata = _extractDetailMetadata(
      description: url.description,
      creator: live?.creator,
      likeCount: live?.likeCount,
      commentCount: live?.commentCount,
      rawUrl: url.rawUrl,
    );
    final formattedDescription = _formatDescription(url.description);
    final captionText = _stripHashtagsFromCaption(formattedDescription);
    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: url.rawUrl,
      fallbackDomain: url.domain,
    );
    final normalizedCategories =
        url.effectiveCategories.map((item) => item.toLowerCase()).toSet();
    final mentionTitles = (live?.mentions ?? const <EnrichedMention>[])
        .map((item) => TagNoiseFilter.cleanTag(item.title))
        .where((item) => item.isNotEmpty)
        .toSet();
    final sourceTags = url.tags;
    final rawTagPool = sourceTags
        .where((tag) => !normalizedCategories.contains(tag.toLowerCase()))
        .where((tag) => tag.toLowerCase() != displaySourceName.toLowerCase())
        .where((tag) => !mentionTitles.contains(TagNoiseFilter.cleanTag(tag)))
        .toList();
    final visibleTags = TagNoiseFilter.orderByRarity(
      TagNoiseFilter.filterTags(rawTagPool),
      tagFreq,
    );
    final showImage = url.thumbnailUrl != null && url.thumbnailUrl!.isNotEmpty;
    final categoryLabels = _displayCategories(url);
    final hasCaption = captionText.isNotEmpty;
    const collapseTagsAt = 5;
    final showAllTags = _tagsExpanded || visibleTags.length <= collapseTagsAt;
    final displayedTags =
        showAllTags ? visibleTags : visibleTags.take(collapseTagsAt).toList();
    final hiddenTagCount = visibleTags.length - collapseTagsAt;
    final summaryText = TextCleaner.clean(
      url.summary?.trim() ?? '',
    );
    final showSummary = summaryText.isNotEmpty &&
        summaryText.toLowerCase() != captionText.trim().toLowerCase();
    final displayTitle = TitleResolver.resolveStableDisplayTitle(
      url,
      tagFrequency: tagFreq,
    );
    final cleanedSummary = SummaryRewriter.clean(summaryText);
    final summaryDisplayText =
        cleanedSummary.isNotEmpty ? cleanedSummary : summaryText;
    final noteSuggestions = _buildNoteSuggestions(
      url: url,
      live: live,
      tags: visibleTags,
      caption: captionText,
      summary: summaryDisplayText,
    );
    final bottomPad = MediaQuery.paddingOf(context).bottom + 28;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ───────────────────────────────────────────────────
            _buildDetailMedia(
              url: url,
              showImage: showImage,
              categoryLabels: categoryLabels,
              displaySourceName: displaySourceName,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),

            // ── Title ───────────────────────────────────────────────────
            Text(
              displayTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: colorScheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Source ──────────────────────────────────────────────────
            _buildSourceSavedRow(
              url: url,
              displaySourceName: displaySourceName,
              colorScheme: colorScheme,
              theme: theme,
            ),

            if (metadata.hasSocialRow) ...[
              const SizedBox(height: 10),
              _buildSocialMetricsRow(
                metadata: metadata,
                displaySourceName: displaySourceName,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],

            SizedBox(height: metadata.hasSocialRow ? 8 : 10),
            _buildUrlAddressBlock(url, theme, colorScheme),

            if (hasCaption) ...[
              const SizedBox(height: 16),
              _buildDescriptionSection(
                description: captionText,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],

            if (showSummary) ...[
              const SizedBox(height: 16),
              _buildSummarySection(
                summary: summaryDisplayText,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],

            ..._buildEnrichmentSections(
              live: live,
              theme: theme,
              colorScheme: colorScheme,
            ),

            // ── Description ─────────────────────────────────────────────
            // ── Tags ────────────────────────────────────────────────────
            const SizedBox(height: 16),
            TagGroup(
              tags: displayedTags,
              hiddenCount: !showAllTags && hiddenTagCount > 0
                  ? hiddenTagCount
                  : 0,
              onShowMore: () => setState(() => _tagsExpanded = true),
              onDelete: (tag) => _removeTag(url, tag),
              onAdd: () => _addTag(url),
            ),

            // ── Open / share (copy is on the URL row) ───────────────────
            const SizedBox(height: 16),
            _buildOpenShareActions(url),

            // ── Notes ───────────────────────────────────────────────────
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SectionHeader(title: 'Notes', accent: colorScheme.primary),
                    const Spacer(),
                    if (_notesEdited)
                      TextButton(
                        onPressed: _saveNotes,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Save'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNotesComposer(
                  theme: theme,
                  colorScheme: colorScheme,
                  suggestions: noteSuggestions,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _urlDisplayLine(Uri? uri, String raw) {
    if (uri == null || uri.host.isEmpty) {
      return raw.length > 140 ? '${raw.substring(0, 137)}…' : raw;
    }
    final host = uri.host;
    final path = uri.path;
    final q = uri.hasQuery ? '?${uri.query}' : '';
    var s = host;
    if (path.isNotEmpty && path != '/') s += path;
    s += q;
    if (s.length > 140) return '${s.substring(0, 137)}…';
    return s;
  }

  Widget _buildDetailMedia({
    required SavedUrl url,
    required bool showImage,
    required List<String> categoryLabels,
    required String displaySourceName,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _launchUrl(url.rawUrl),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showImage)
                CachedNetworkImage(
                  imageUrl: url.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _buildMediaPlaceholder(
                    url: url,
                    displaySourceName: displaySourceName,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                )
              else
                _buildMediaPlaceholder(
                  url: url,
                  displaySourceName: displaySourceName,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.26),
                      ],
                    ),
                  ),
                ),
              ),
              if (categoryLabels.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categoryLabels.take(3).map((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder({
    required SavedUrl url,
    required String displaySourceName,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final favicon = _faviconUrlForSource(url, displaySourceName);
    final accent = _sourceAccentColor(url, displaySourceName, colorScheme);
    final base = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      colorScheme.surfaceContainerHigh,
    );
    final glow = Color.alphaBlend(
      accent.withValues(alpha: 0.16),
      colorScheme.secondaryContainer,
    );
    final label = displaySourceName.trim().isNotEmpty
        ? displaySourceName.trim()
        : url.domain.trim();
    final initial = _placeholderInitial(label);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glow,
            base,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.58),
            ),
          ),
          alignment: Alignment.center,
          child: favicon != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: favicon,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Text(
                  initial,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  String _placeholderInitial(String value) {
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z0-9]').hasMatch(char)) {
        return char.toUpperCase();
      }
    }
    return 'G';
  }

  List<String> _displayCategories(SavedUrl url) {
    final content = <String>[];
    for (final category in url.effectiveCategories) {
      final trimmed = category.trim();
      if (trimmed.isEmpty || trimmed == 'Web') continue;
      if (trimmed == 'Other') continue;
      if (CategoryTaxonomy.tryByName(trimmed) == null) continue;
      if (trimmed == 'Technology' && !_hasTechnologySignal(url)) continue;
      if (!content.contains(trimmed)) content.add(trimmed);
    }
    for (final category in CategoryTaxonomy.inferAdditionalCategories(
      tags: url.tags,
      text: '${url.title} ${url.summary ?? ''} ${url.description}',
    )) {
      if (!content.contains(category)) content.add(category);
    }
    return content.isEmpty ? ['Other'] : content;
  }

  bool _hasTechnologySignal(SavedUrl url) {
    final text = [
      url.title,
      url.summary ?? '',
      url.description,
      url.tags.join(' '),
      url.rawUrl,
    ].join(' ').toLowerCase();
    return RegExp(
      r'\b(ai|llm|ml|code|coding|software|developer|github|gitlab|programming|react|flutter|dart|javascript|typescript|api|model|agent|agentic)\b',
    ).hasMatch(text);
  }

  Widget _buildUrlAddressBlock(
    SavedUrl url,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final raw = url.rawUrl.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    final uri = Uri.tryParse(raw);
    final display = _urlDisplayLine(uri, raw);
    final canToggle = raw != display;

    final subtleIconStyle = IconButton.styleFrom(
      foregroundColor:
          colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(34, 34),
      padding: const EdgeInsets.all(6),
    );
    final copyIconStyle = IconButton.styleFrom(
      foregroundColor: colorScheme.primary,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(34, 34),
      padding: const EdgeInsets.all(6),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: _showFullUrl
                    ? SelectableText(
                        raw,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      )
                    : GestureDetector(
                        onTap: () {
                          if (canToggle) {
                            setState(() => _showFullUrl = true);
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          display,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ),
            if (canToggle) ...[
              IconButton(
                icon: Icon(
                  _showFullUrl
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                ),
                tooltip: _showFullUrl ? 'Show less' : 'Show full URL',
                style: subtleIconStyle,
                onPressed: () => setState(() => _showFullUrl = !_showFullUrl),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 19),
              tooltip: 'Copy link',
              style: copyIconStyle,
              onPressed: () => _copyUrlToClipboard(raw),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection({
    required String summary,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Summary', accent: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          summary,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesComposer({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required List<String> suggestions,
  }) {
    final glimpseNotes = _parseGlimpseNoteBlocks(_notesController.text);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (glimpseNotes.isNotEmpty) ...[
              ...glimpseNotes.map(
                (note) => _GlimpseSavedNoteCard(
                  note: note,
                  theme: theme,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: colorScheme.outlineVariant),
              const SizedBox(height: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: TextField(
                controller: _notesController,
                focusNode: _notesFocusNode,
                minLines: 2,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Add your thoughts…',
                  hintStyle: TextStyle(color: colorScheme.outline),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                ),
                onChanged: (_) => _scheduleNotesAutosave(),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: suggestions
                    .map(
                      (suggestion) => _NoteSuggestionChip(
                        label: suggestion,
                        onTap: () => _applyNoteSuggestion(suggestion),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMetricsRow({
    required _DetailMetadata metadata,
    required String displaySourceName,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final pills = <Widget>[
      if (metadata.likesLabel != null)
        MetadataPill(
          value: metadata.likesLabel!,
          icon: Icons.favorite_border_rounded,
        ),
      if (metadata.commentsLabel != null)
        MetadataPill(
          value: metadata.commentsLabel!,
          icon: Icons.chat_bubble_outline_rounded,
        ),
      if (metadata.creatorUsername != null)
        CreatorProfileLink(
          username: metadata.creatorUsername!,
          platform: displaySourceName,
          accent: colorScheme.onSurfaceVariant,
          compact: true,
        ),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: pills);
  }

  Widget _buildSourceSavedRow({
    required SavedUrl url,
    required String displaySourceName,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final savedLabel = _showExactSavedDate
        ? _formatExactSavedDate(url.savedAt)
        : _formatDate(url.savedAt);
    return Row(
      children: [
        _buildSourceLeadingIcon(url, displaySourceName, colorScheme),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            displaySourceName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '•',
            style: TextStyle(
              color: colorScheme.outline,
              fontSize: 12,
            ),
          ),
        ),
        Flexible(
          flex: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() => _showExactSavedDate = !_showExactSavedDate);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                savedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ReadStatePill(isRead: url.openedAt != null),
      ],
    );
  }

  List<Widget> _buildEnrichmentSections({
    required TranscriptEnrichmentResult? live,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    if (live == null) return const [];
    final sections = <Widget>[];
    final grouped = <String, List<EnrichedMention>>{};
    for (final mention in live.mentions) {
      final key = _mentionSectionKey(mention.type);
      grouped.putIfAbsent(key, () => []).add(mention);
    }

    for (final key in _mentionSectionOrder) {
      final items = grouped[key] ?? const <EnrichedMention>[];
      if (items.isEmpty) continue;
      sections.addAll([
        const SizedBox(height: 18),
        ContentRecommendationSection<EnrichedMention>(
          title: _mentionSectionTitle(key),
          accent: _sectionAccent(key, colorScheme),
          items: items,
          itemBuilder: (context, mention) => _buildMentionRow(
            mention: mention,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
      ]);
    }

    final recipe = live.recipe;
    if (recipe?.hasUsefulContent ?? false) {
      sections.addAll([
        const SizedBox(height: 18),
        ContentRecommendationSection<EnrichedRecipe>(
          title: 'Recipes',
          accent: _sectionAccent('recipe', colorScheme),
          items: [recipe!],
          itemBuilder: (context, item) => _buildRecipeItem(
            recipe: item,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
      ]);
    }
    return sections;
  }

  TranscriptEnrichmentResult? _savedEnrichment(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final result = TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return result?.hasUsefulContent == true ? result : null;
    } catch (_) {
      return null;
    }
  }

  static const _mentionSectionOrder = [
    'movie',
    'book',
    'product',
    'person',
    'place',
    'other',
  ];

  String _mentionSectionKey(String type) {
    final lower = type.toLowerCase().trim();
    if (_mentionSectionOrder.contains(lower)) return lower;
    if (lower == 'show' || lower == 'anime' || lower == 'documentary') {
      return 'movie';
    }
    return 'other';
  }

  String _mentionSectionTitle(String type) {
    return switch (type) {
      'movie' => 'Movie recommendations',
      'book' => 'Book recommendations',
      'product' => 'Products',
      'person' => 'People',
      'place' => 'Places',
      _ => 'Mentions',
    };
  }

  Color _sectionAccent(String type, ColorScheme colorScheme) {
    return colorScheme.primary;
  }

  Widget _buildRecipeItem({
    required EnrichedRecipe recipe,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final image = recipe.image?.trim() ?? '';
    final metadata = [
      if ((recipe.cuisine ?? '').isNotEmpty) recipe.cuisine!,
      if ((recipe.category ?? '').isNotEmpty) recipe.category!,
      if ((recipe.prepTime ?? '').isNotEmpty) recipe.prepTime!,
    ];

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        title: Text(
          recipe.title.isNotEmpty ? recipe.title : 'Recipe',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        subtitle: metadata.isNotEmpty
            ? Text(
                metadata.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              )
            : null,
        children: [
          if (image.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (recipe.ingredients.isNotEmpty) ...[
            _buildRecipeSubheading('Ingredients', theme, colorScheme),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 560;
                final itemWidth = useTwoColumns
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recipe.ingredients.take(18).map((ingredient) {
                    return SizedBox(
                      width: itemWidth,
                      child: _buildIngredientRow(
                        ingredient: ingredient,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
          if ((recipe.instructions ?? '').trim().isNotEmpty) ...[
            _buildRecipeSubheading('Instructions', theme, colorScheme),
            const SizedBox(height: 8),
            ..._recipeInstructionSteps(recipe.instructions!)
                .asMap()
                .entries
                .map(
                  (entry) => _buildInstructionStep(
                    number: entry.key + 1,
                    text: entry.value,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _launchRecipeSearch(recipe),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Search recipe'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow({
    required EnrichedRecipeIngredient ingredient,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final measure = ingredient.measure?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 17,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ingredient.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (measure.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                measure,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_GlimpseSavedNote> _parseGlimpseNoteBlocks(String raw) {
    final blocks = <_GlimpseSavedNote>[];
    final matches = RegExp(
      r'(?:^|\n)## Ask Glimpse\n([\s\S]*?)(?=\n## Ask Glimpse\n|$)',
    ).allMatches(raw);
    for (final match in matches) {
      final block = match.group(1)?.trim() ?? '';
      if (block.isEmpty) continue;
      final lines = block.split('\n').map((line) => line.trimRight()).toList();
      String? asked;
      String? question;
      final body = <String>[];
      for (final line in lines) {
        if (line.startsWith('Asked:')) {
          asked = line.substring('Asked:'.length).trim();
        } else if (line.startsWith('Question:')) {
          question = line.substring('Question:'.length).trim();
        } else {
          body.add(line);
        }
      }
      final answer = body.join('\n').trim();
      if ((question ?? '').isEmpty && answer.isEmpty) continue;
      blocks.add(
        _GlimpseSavedNote(
          asked: asked,
          question: question,
          answer: answer,
        ),
      );
    }
    return blocks.reversed.take(3).toList();
  }

  Widget _buildInstructionStep({
    required int number,
    required String text,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _recipeInstructionSteps(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return const [];
    final parts = cleaned
        .split(RegExp(r'\r?\n+|(?:^|\s)(?:step\s*)?\d+\.\s+', caseSensitive: false))
        .map((part) => part.trim())
        .where((part) => part.length > 2)
        .toList();
    return parts.isEmpty ? [cleaned] : parts.take(12).toList();
  }

  Widget _buildRecipeSubheading(
    String label,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMentionRow({
    required EnrichedMention mention,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final reason = mention.whyMentioned?.trim() ?? '';
    final posterUrl = mention.posterUrl?.trim() ?? '';
    final metadata = _mentionMetadataLine(mention);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _launchMentionSearch(mention),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 54,
                  height: 72,
                  child: posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _mentionPlaceholder(mention, colorScheme),
                        )
                      : _mentionPlaceholder(mention, colorScheme),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mention.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          metadata,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          _sentenceCase(reason),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mentionMetadataLine(EnrichedMention mention) {
    final type = mention.type.toLowerCase();
    final year = mention.year?.trim() ?? '';
    if (type == 'movie' && year.isNotEmpty) return year;
    return '';
  }

  Future<void> _launchMentionSearch(EnrichedMention mention) async {
    final suffix = switch (mention.type) {
      'movie' => 'movie',
      'book' => 'book',
      'place' => 'place',
      'product' => 'product',
      _ => '',
    };
    final query = [mention.title, suffix]
        .where((item) => item.isNotEmpty)
        .join(' ');
    final uri = Uri.https('www.google.com', '/search', {'q': query});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchRecipeSearch(EnrichedRecipe recipe) async {
    final query = [recipe.title, 'recipe']
        .where((item) => item.trim().isNotEmpty)
        .join(' ');
    final uri = Uri.https('www.google.com', '/search', {'q': query});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _mentionPlaceholder(
    EnrichedMention mention,
    ColorScheme colorScheme,
  ) {
    final initial = mention.title.trim().isEmpty
        ? 'M'
        : mention.title.trim().substring(0, 1).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  String _sentenceCase(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.substring(0, 1).toUpperCase() + trimmed.substring(1);
  }

  _DetailMetadata _extractDetailMetadata({
    required String description,
    required String? creator,
    required int? likeCount,
    required int? commentCount,
    required String rawUrl,
  }) {
    final text = TextCleaner.cleanLoose(description);
    String? matchFirst(String pattern) {
      return RegExp(pattern, caseSensitive: false).firstMatch(text)?.group(1);
    }

    final likes = matchFirst(r'\b([\d,.]+[KMBkmb]?)\s+likes?\b');
    final comments = matchFirst(r'\b([\d,.]+[KMBkmb]?)\s+comments?\b');
    final fromDescription = matchFirst(r'-\s*@?([A-Za-z0-9._]+)\s+on\s+');
    final parsedUsername = _supportsProfileUsername(rawUrl)
        ? _cleanUsername(creator) ??
            _cleanUsername(fromDescription) ??
            _usernameFromUrl(rawUrl)
        : null;

    return _DetailMetadata(
      likesLabel: likeCount != null
          ? _compactCountLabel(likeCount.toString())
          : likes == null
              ? null
              : _compactCountLabel(likes),
      commentsLabel: commentCount != null
          ? _compactCountLabel(commentCount.toString())
          : comments == null
              ? null
              : _compactCountLabel(comments),
      creatorUsername: parsedUsername,
    );
  }

  String? _cleanUsername(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceFirst('@', '').trim();
    if (!RegExp(r'^[A-Za-z0-9._]{2,}$').hasMatch(cleaned)) return null;
    return cleaned;
  }

  String? _usernameFromUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return null;
    if (!_supportsProfileUsername(rawUrl)) return null;
    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    if (segments.length >= 2 &&
        !{'reel', 'reels', 'p', 'tv'}.contains(segments.first.toLowerCase())) {
      return _cleanUsername(segments.first);
    }
    return null;
  }

  bool _supportsProfileUsername(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    return host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'x.com' ||
        host.endsWith('.x.com') ||
        host == 'twitter.com' ||
        host.endsWith('.twitter.com') ||
        host == 'tiktok.com' ||
        host.endsWith('.tiktok.com') ||
        host == 'threads.net' ||
        host.endsWith('.threads.net');
  }

  String _compactCountLabel(String raw) {
    final clean = raw.replaceAll(',', '').trim();
    if (RegExp(r'[KMBkmb]$').hasMatch(clean)) {
      return clean.toUpperCase();
    }
    final value = double.tryParse(clean);
    if (value == null) return raw.trim();
    if (value >= 1000000) return '${_trimDecimal(value / 1000000)}M';
    if (value >= 1000) return '${_trimDecimal(value / 1000)}K';
    return value.round().toString();
  }

  String _trimDecimal(double value) {
    return value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  List<String> _buildNoteSuggestions({
    required SavedUrl url,
    required TranscriptEnrichmentResult? live,
    required List<String> tags,
    required String caption,
    required String summary,
  }) {
    final mentionTypes = (live?.mentions ?? const <EnrichedMention>[])
        .map((mention) => mention.type.toLowerCase())
        .toSet();
    final text = [
      url.title,
      url.category,
      url.description,
      url.summary ?? '',
      caption,
      summary,
      ...url.tags,
      ...tags,
      if (live != null) ...[
        live.meaningfulTitle,
        live.category,
        live.summary,
        ...live.tags,
        ...live.mentions.map((mention) => mention.title),
        if (live.recipe != null) live.recipe!.title,
      ],
    ].join(' ').toLowerCase();

    if (live?.recipe?.hasUsefulContent == true ||
        _hasAny(text, const [
          'recipe',
          'cook',
          'ingredient',
          'meal',
          'protein',
          'vegan',
          'paneer',
          'pasta',
          'ramen',
          'smoothie',
          'dessert',
          'food',
          'dairy',
        ])) {
      return const [
        'try this weekend',
        'need ingredients',
        'share with someone',
        'already tried',
      ];
    }

    if (mentionTypes.contains('movie') ||
        _hasAny(text, const [
          'movie',
          'film',
          'cinema',
          'watchlist',
          'sci-fi',
          'series',
          'anime',
        ])) {
      return const [
        'watch this weekend',
        'add to watchlist',
        'share with someone',
        'already watched',
      ];
    }

    if (mentionTypes.contains('book') ||
        _hasAny(text, const [
          'book',
          'reading',
          'author',
          'novel',
          'essay',
          'newsletter',
        ])) {
      return const [
        'add to reading list',
        'read later',
        'summarize later',
        'already read',
      ];
    }

    if (mentionTypes.contains('product') ||
        _hasAny(text, const [
          'tool',
          'app',
          'software',
          'github',
          'repo',
          'agent',
          'workflow',
          'design system',
          'product',
        ])) {
      return const [
        'try this tool',
        'compare alternatives',
        'use in project',
        'share with team',
      ];
    }

    if (mentionTypes.contains('place') ||
        _hasAny(text, const [
          'travel',
          'trek',
          'route',
          'hike',
          'trip',
          'itinerary',
          'hotel',
          'restaurant',
          'destination',
        ])) {
      return const [
        'plan itinerary',
        'check best season',
        'save route',
        'share with someone',
      ];
    }

    if (_hasAny(text, const [
      'tutorial',
      'guide',
      'framework',
      'learn',
      'course',
      'productivity',
      'strategy',
    ])) {
      return const [
        'practice later',
        'make checklist',
        'use in project',
        'revisit notes',
      ];
    }

    return const [
      'revisit later',
      'share with someone',
      'worth trying',
      'already checked',
    ];
  }

  bool _hasAny(String text, List<String> needles) {
    return needles.any((needle) => text.contains(needle));
  }

  Widget _buildOpenShareActions(SavedUrl url) {
    final narrow =
        MediaQuery.sizeOf(context).width < _narrowLayoutWidth;

    final compact = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );

    final openBtn = SizedBox(
      width: narrow ? double.infinity : null,
      child: FilledButton.tonalIcon(
        style: compact.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.primary,
          ),
          foregroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        onPressed: () => _launchUrl(url.rawUrl),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text('Open'),
      ),
    );
    final shareBtn = SizedBox(
      width: narrow ? double.infinity : null,
      child: OutlinedButton.icon(
        style: compact.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.secondaryContainer,
          ),
          foregroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
          ),
        ),
        onPressed: () => Share.share(url.rawUrl),
        icon: const Icon(Icons.share_outlined, size: 18),
        label: const Text('Share'),
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          openBtn,
          const SizedBox(height: 8),
          shareBtn,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: openBtn),
        const SizedBox(width: 10),
        Expanded(child: shareBtn),
      ],
    );
  }

  Widget _buildDescriptionSection({
    required String description,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 16,
      height: 1.55,
      color: colorScheme.onSurface,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        key: _descriptionSectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggleDescription,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: SectionHeader(
                      title: 'Description',
                      accent: colorScheme.primary,
                    ),
                  ),
                  Icon(
                    _descExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_descExpanded) ...[
            const SizedBox(height: 8),
            Text.rich(
                TextSpan(
                  style: textStyle,
                  children: _linkifiedTextSpans(
                    description,
                    textStyle,
                    colorScheme,
                  ),
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _linkifiedTextSpans(
    String text,
    TextStyle? baseStyle,
    ColorScheme colorScheme,
  ) {
    final spans = <InlineSpan>[];
    final linkPattern = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+|(?:[a-z0-9-]+\.)+[a-z]{2,}(?:\/[^\s]*)?)',
      caseSensitive: false,
    );
    var index = 0;
    for (final match in linkPattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final raw = match.group(0) ?? '';
      final trailing = RegExp(r'[),.;:!?]+$').stringMatch(raw) ?? '';
      final clean = trailing.isEmpty
          ? raw
          : raw.substring(0, raw.length - trailing.length);
      spans.add(
        TextSpan(
          text: clean,
          style: baseStyle?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.primary.withValues(alpha: 0.7),
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _launchInlineLink(clean),
        ),
      );
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing));
      }
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  Future<void> _launchInlineLink(String raw) async {
    final value = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDescription(String description) {
    var text = TextCleaner.clean(description)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (text.isEmpty) return '';

    text = _stripScrapedMetadataPrefix(text);
    text = text.replaceFirst(RegExp(r'^@[A-Za-z0-9_]+:\s*'), '');
    text = text
        .replaceFirst(RegExp(r'^["“]+'), '')
        .replaceFirst(RegExp(r'["”]+\s*\.?$'), '')
        .trim();

    final lines = text.split('\n');
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    if (lines.isNotEmpty && _isRedundantMetadataLine(lines.last)) {
      lines.removeLast();
    }

    final normalizedLines = lines.map(_normalizeDescriptionLine).toList();
    text = normalizedLines.join('\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text;
  }

  String _stripScrapedMetadataPrefix(String text) {
    return text
        .replaceFirst(
          RegExp(
            r'^[\d,.]+[KMBkmb]?\s+likes?,\s*[\d,.]+[KMBkmb]?\s+comments?\s*-\s*[A-Za-z0-9._]+\s+on\s+[^:"]+:\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'^[\d,.]+[KMBkmb]?\s+likes?,\s*[\d,.]+[KMBkmb]?\s+comments?\s*-\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  String _stripHashtagsFromCaption(String text) {
    final lines = text
        .split('\n')
        .map((line) {
          final kept = line
              .split(RegExp(r'\s+'))
              .where((token) => token.trim().isNotEmpty)
              .where((token) => !token.trimLeft().startsWith('#'))
              .join(' ')
              .trim();
          return kept;
        })
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.join('\n').trim();
  }

  String _normalizeDescriptionLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return '';

    final numbered = RegExp(r'^(\d+)\s*\\\.?\s*(.+)$').firstMatch(trimmed);
    if (numbered != null) {
      final number = numbered.group(1)!;
      final content = numbered.group(2)!.trim();
      return '$number. $content';
    }

    return trimmed.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  }

  bool _isRedundantMetadataLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    final hasHandle = RegExp(r'\(@[A-Za-z0-9_]+\)').hasMatch(trimmed);
    final hasDate = RegExp(
      r'(?:\b\d{4}\b|\b\d{1,2}:\d{2}\b|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\b|\b(?:today|yesterday|ago)\b)',
      caseSensitive: false,
    ).hasMatch(trimmed);

    return hasHandle && hasDate;
  }

  double? _globalTop(BuildContext? context) {
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    return renderObject.localToGlobal(Offset.zero).dy;
  }

  /// Favicon for the byline: known platform name, else URL host, else globe.
  String? _faviconUrlForSource(SavedUrl url, String displaySourceName) {
    final byName = faviconUrl(displaySourceName);
    if (byName != null) return byName;
    final parsed = Uri.tryParse(url.rawUrl.trim());
    final host = (parsed?.host.isNotEmpty ?? false)
        ? parsed!.host
        : url.domain.trim();
    if (host.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=$host&sz=64';
  }

  Color _sourceAccentColor(
    SavedUrl url,
    String displaySourceName,
    ColorScheme colorScheme,
  ) {
    final byName = platformColors[displaySourceName.trim()];
    if (byName != null) return byName;
    final parsed = Uri.tryParse(url.rawUrl.trim());
    final seed = ((parsed?.host.isNotEmpty ?? false)
            ? parsed!.host
            : url.domain.trim())
        .toLowerCase();
    if (seed.isEmpty) return colorScheme.primary;
    final hue = seed.codeUnits.fold<int>(0, (sum, item) => sum + item) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.42, 0.56).toColor();
  }

  Widget _buildSourceLeadingIcon(
    SavedUrl url,
    String displaySourceName,
    ColorScheme colorScheme,
  ) {
    final variant = colorScheme.onSurfaceVariant;
    final fav = _faviconUrlForSource(url, displaySourceName);
    if (fav != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CachedNetworkImage(
          imageUrl: fav,
          width: 14,
          height: 14,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Icon(
            Icons.public_outlined,
            size: 14,
            color: variant,
          ),
        ),
      );
    }
    return Icon(Icons.public_outlined, size: 14, color: variant);
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String _formatExactSavedDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $hour12:$minute $period';
  }
}
