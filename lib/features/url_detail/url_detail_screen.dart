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
import '../../core/services/category_taxonomy.dart';
import '../../core/services/summary_rewriter.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/text_cleaner.dart';
import '../../core/services/title_resolver.dart';
import '../../core/services/transcript_enrichment_service.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../shared/widgets/loading_indicator.dart';
import '../collections/add_to_collection_sheet.dart';
import '../home/home_provider.dart';
import 'url_detail_provider.dart';

class UrlDetailScreen extends ConsumerStatefulWidget {
  final int urlId;

  const UrlDetailScreen({super.key, required this.urlId});

  @override
  ConsumerState<UrlDetailScreen> createState() => _UrlDetailScreenState();
}

class _UrlDetailScreenState extends ConsumerState<UrlDetailScreen> {
  static const int _collapsedDescriptionLines = 7;
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
  String? _localNotesOverride;
  String? _transcriptEnrichmentUrl;
  DateTime? _lastTranscriptEnrichmentAttempt;
  bool _loadingTranscriptEnrichment = false;
  TranscriptEnrichmentResult? _transcriptEnrichment;
  Timer? _notesTimer;

  @override
  void didUpdateWidget(covariant UrlDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlId != widget.urlId) {
      _showFullUrl = false;
      _descExpanded = false;
      _tagsExpanded = false;
      _localNotesOverride = null;
      _transcriptEnrichmentUrl = null;
      _lastTranscriptEnrichmentAttempt = null;
      _loadingTranscriptEnrichment = false;
      _transcriptEnrichment = null;
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

  Future<void> _loadTranscriptEnrichment(SavedUrl url) async {
    if (!TranscriptEnrichmentService.supportsUrl(url.rawUrl)) return;
    if (_loadingTranscriptEnrichment) {
      return;
    }
    if (_transcriptEnrichmentUrl == url.rawUrl &&
        _transcriptEnrichment?.hasUsefulContent == true) {
      return;
    }
    final lastAttempt = _lastTranscriptEnrichmentAttempt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < const Duration(seconds: 20)) {
      return;
    }

    _transcriptEnrichmentUrl = url.rawUrl;
    _lastTranscriptEnrichmentAttempt = DateTime.now();
    setState(() => _loadingTranscriptEnrichment = true);

    final service = ref.read(transcriptEnrichmentServiceProvider);
    final result = await service.enrichUrl(
      rawUrl: url.rawUrl,
      title: url.title,
      description: url.description,
      thumbnailUrl: url.thumbnailUrl,
      domain: url.domain,
    );

    if (!mounted || _transcriptEnrichmentUrl != url.rawUrl) return;
    setState(() {
      _transcriptEnrichment = result;
      _loadingTranscriptEnrichment = false;
    });
    if (result != null && result.hasUsefulContent) {
      await _persistTranscriptFields(url, result);
    }
  }

  Future<void> _persistTranscriptFields(
    SavedUrl url,
    TranscriptEnrichmentResult result,
  ) async {
    final title = result.meaningfulTitle.trim();
    final summary = result.summary.trim();
    final tags = TagNoiseFilter.filterTags(result.tags);
    final normalized = CategoryTaxonomy.normalize(
      category: result.category,
      tags: tags,
    );

    var changed = false;
    if (title.isNotEmpty && url.title != title) {
      url.title = title;
      changed = true;
    }
    if (summary.isNotEmpty && url.summary != summary) {
      url.summary = summary;
      changed = true;
    }
    if (tags.isNotEmpty && !_sameStringList(url.tags, tags)) {
      url.tags = tags;
      changed = true;
    }
    if (url.category != normalized.name) {
      url.category = normalized.name;
      url.categoryEmoji = normalized.emoji;
      url.categories = CategoryResolver.buildCategories(
        primaryCategory: normalized.name,
        additionalCategories: url.effectiveCategories
            .where((item) => item != url.category)
            .toList(),
      );
      changed = true;
    }
    final thumbnail = result.thumbnailUrl?.trim();
    if (thumbnail != null && thumbnail.isNotEmpty && url.thumbnailUrl != thumbnail) {
      url.thumbnailUrl = thumbnail;
      changed = true;
    }
    if (!changed) return;

    await ref.read(isarServiceProvider).updateUrl(url);
    if (!mounted) return;
    ref.invalidate(urlDetailProvider(widget.urlId));
    ref.invalidate(tagOccurrenceMapProvider);
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTranscriptEnrichment(url);
    });

    if (!_notesEdited && !_notesFocusNode.hasFocus) {
      _notesController.text = _localNotesOverride ?? url.userNotes ?? '';
    }
    final live = _transcriptEnrichmentUrl == url.rawUrl
        ? _transcriptEnrichment
        : null;
    final liveTitle = live?.meaningfulTitle.trim() ?? '';
    final formattedDescription = _formatDescription(url.description);
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
    final sourceTags = (live?.tags.isNotEmpty ?? false) ? live!.tags : url.tags;
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
    final categoryLabel = url.category.trim();
    final hasDescription = formattedDescription.isNotEmpty;
    const collapseTagsAt = 5;
    final showAllTags = _tagsExpanded || visibleTags.length <= collapseTagsAt;
    final displayedTags =
        showAllTags ? visibleTags : visibleTags.take(collapseTagsAt).toList();
    final hiddenTagCount = visibleTags.length - collapseTagsAt;
    final summaryText = TextCleaner.clean(
      (live?.summary.trim().isNotEmpty ?? false)
          ? live!.summary.trim()
          : url.summary?.trim() ?? '',
    );
    final showSummary = summaryText.isNotEmpty &&
        summaryText.toLowerCase() != formattedDescription.trim().toLowerCase();
    final cleanedSummary = SummaryRewriter.clean(summaryText);
    final summaryDisplayText =
        cleanedSummary.isNotEmpty ? cleanedSummary : summaryText;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 28;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ───────────────────────────────────────────────────
            if (showImage) ...[
              Material(
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
                        CachedNetworkImage(
                          imageUrl: url.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                        if (categoryLabel.isNotEmpty)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surface
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    categoryLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Title ───────────────────────────────────────────────────
            Text(
              liveTitle.isNotEmpty
                  ? liveTitle
                  : TitleResolver.resolve(url, tagFrequency: tagFreq),
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

            // ── Metadata: source (favicon) · date — source not repeated in chips
            Row(
              children: [
                _buildSourceLeadingIcon(url, displaySourceName, colorScheme),
                const SizedBox(width: 6),
                Text(
                  displaySourceName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '·',
                    style: TextStyle(
                      color: colorScheme.outline,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _formatDate(url.savedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildUrlAddressBlock(url, theme, colorScheme),

            if (live?.recipe?.hasUsefulContent ?? false) ...[
              const SizedBox(height: 16),
              _buildRecipeSection(
                recipe: live!.recipe!,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],

            if (live?.mentions.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _buildMentionsSection(
                mentions: live!.mentions,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],

            // ── Description ─────────────────────────────────────────────
            if (hasDescription) ...[
              const SizedBox(height: 16),
              _buildDescriptionSection(
                description: formattedDescription,
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

            // ── Tags ────────────────────────────────────────────────────
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...displayedTags.map((tag) => InputChip(
                      label: Text(tag),
                      backgroundColor: colorScheme.secondaryContainer,
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                      deleteIconColor: colorScheme.onSecondaryContainer,
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _removeTag(url, tag),
                    )),
                if (!showAllTags && hiddenTagCount > 0)
                  ActionChip(
                    label: Text('+$hiddenTagCount'),
                    backgroundColor: colorScheme.secondaryContainer,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _tagsExpanded = true),
                  ),
                ActionChip(
                  avatar: Icon(
                    Icons.add,
                    size: 16,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  label: const Text('Add tag'),
                  backgroundColor: colorScheme.secondaryContainer,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                  side: BorderSide(color: colorScheme.outline),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addTag(url),
                ),
              ],
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
                    Text(
                      'Notes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: TextField(
                    controller: _notesController,
                    focusNode: _notesFocusNode,
                    minLines: 3,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add personal notes…',
                      hintStyle: TextStyle(color: colorScheme.outline),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      if (!_notesEdited) {
                        setState(() => _notesEdited = true);
                      }
                      _notesTimer?.cancel();
                      _notesTimer = Timer(
                        const Duration(milliseconds: 1500),
                        _autoSaveNotes,
                      );
                    },
                  ),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeSection({
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 0.7,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 10, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Detected recipe',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          subtitle: recipe.title.isNotEmpty
              ? Text(
                  [
                    recipe.title,
                    if (metadata.isNotEmpty) metadata.join(' · '),
                  ].join('\n'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                )
              : null,
          children: [
            if (image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recipe.ingredients.take(18).map((ingredient) {
                  final measure = ingredient.measure?.trim() ?? '';
                  final label = measure.isEmpty
                      ? ingredient.name
                      : '${ingredient.name} · $measure';
                  return Chip(
                    label: Text(label),
                    backgroundColor: colorScheme.secondaryContainer,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if ((recipe.instructions ?? '').trim().isNotEmpty) ...[
              _buildRecipeSubheading('Instructions', theme, colorScheme),
              const SizedBox(height: 6),
              Text(
                recipe.instructions!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  Widget _buildMentionsSection({
    required List<EnrichedMention> mentions,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final movieCount = mentions.where((item) => item.type == 'movie').length;
    final bookCount = mentions.where((item) => item.type == 'book').length;
    final title = movieCount == mentions.length && movieCount > 0
        ? 'Movie recommendations'
        : bookCount == mentions.length && bookCount > 0
            ? 'Book recommendations'
            : 'Mentions';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 0.7,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...mentions.take(12).map(
                (mention) => _buildMentionRow(
                  mention: mention,
                  theme: theme,
                  colorScheme: colorScheme,
                ),
              ),
        ],
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
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
                          [
                            mention.title,
                            if ((mention.year ?? '').isNotEmpty) mention.year!,
                          ].join(' · '),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
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
      ),
    );
  }

  Future<void> _launchMentionSearch(EnrichedMention mention) async {
    final suffix = switch (mention.type) {
      'movie' => 'movie',
      'book' => 'book',
      'place' => 'place',
      _ => '',
    };
    final query = [mention.title, suffix]
        .where((item) => item.isNotEmpty)
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = _descriptionExceedsPreview(
          context: context,
          text: description,
          style: textStyle,
          maxWidth: constraints.maxWidth,
        );

        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            key: _descriptionSectionKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: textStyle,
                softWrap: true,
                maxLines: _descExpanded ? null : _collapsedDescriptionLines,
                overflow: _descExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (canExpand) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _toggleDescription,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colorScheme.primary,
                  ),
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
          ),
        );
      },
    );
  }

  bool _descriptionExceedsPreview({
    required BuildContext context,
    required String text,
    required TextStyle? style,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: _collapsedDescriptionLines,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }

  String _formatDescription(String description) {
    var text = TextCleaner.clean(description)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (text.isEmpty) return '';

    text = text.replaceFirst(RegExp(r'^@[A-Za-z0-9_]+:\s*'), '');

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
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}
