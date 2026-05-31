import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/config/app_environment.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/category_order_provider.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/services/digest_prefs.dart';
import '../../core/utils/url_extractor.dart';
import '../../shared/widgets/url_card.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../core/constants/app_assets.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../add_url/add_url_provider.dart';
import 'home_provider.dart';
import 'rediscovery_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _InputUiState { idle, processing, success, error }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  final _urlInputController = TextEditingController();
  final _urlInputFocus = FocusNode();
  bool _isScrolled = false;
  int _unreadDigests = 0;
  int _titleTapCount = 0;
  String? _clipboardUrl;
  bool _inputValid = false;
  _InputUiState _inputUiState = _InputUiState.idle;
  String? _inputErrorText;
  Timer? _resetTimer;

  // First-save celebration state
  bool _isCelebratingFirstSave = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refreshUnreadBadge();
    _urlInputController.addListener(_onInputChanged);
    _checkClipboard();
  }

  void _onInputChanged() {
    final text = _urlInputController.text.trim();
    final extracted = UrlExtractor.extract(text);
    final valid = text.isNotEmpty && extracted.urls.isNotEmpty;
    if (valid != _inputValid) setState(() => _inputValid = valid);
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final extracted = UrlExtractor.extract(text);
      if (extracted.urls.isNotEmpty) {
        setState(() => _clipboardUrl = text);
      }
    } catch (_) {
      // Ignore clipboard errors
    }
  }

  Future<void> _saveFromInput() async {
    final raw = _urlInputController.text.trim();
    if (raw.isEmpty || _inputUiState != _InputUiState.idle) return;

    final extracted = UrlExtractor.extract(raw);

    if (extracted.urls.isEmpty) {
      setState(() {
        _inputUiState = _InputUiState.error;
        _inputErrorText = 'Paste a valid link to save it';
      });
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _inputUiState = _InputUiState.idle);
      });
      return;
    }

    // Multi-URL → batch preview
    if (extracted.hasMultiple) {
      _urlInputFocus.unfocus();
      if (mounted) {
        context.push('/batch-save', extra: extracted.urls);
      }
      _urlInputController.clear();
      setState(() => _inputValid = false);
      return;
    }

    // Detect first save BEFORE the save completes.
    final simulateFirstSave = ref.read(simulateFirstSaveProvider);
    final hasSimulatedInSession = ref.read(hasSimulatedFirstSaveInSessionProvider);

    bool isFirstSave;
    if (simulateFirstSave && !hasSimulatedInSession) {
      // Dev simulation: always treat as first save for testing.
      isFirstSave = true;
    } else {
      final currentUrls = ref.read(urlStreamProvider).valueOrNull ?? [];
      isFirstSave = currentUrls.isEmpty &&
          !(ref.read(hasShownFirstSaveCelebrationProvider));
    }

    _urlInputFocus.unfocus();
    setState(() {
      _inputUiState = _InputUiState.processing;
      _isCelebratingFirstSave = isFirstSave;
    });

    await _saveUrl(raw, isFirstSave: isFirstSave);
  }

  Future<void> _saveUrl(String rawUrl, {required bool isFirstSave}) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(addUrlProvider.notifier);
    final success = await notifier.saveUrl(rawUrl);
    final addState = ref.read(addUrlProvider);

    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();

      // Grab the ID of the just-saved URL for potential undo.
      final isar = ref.read(isarServiceProvider);
      final recent = await isar.getAllUrls();
      final justSavedId = recent.isNotEmpty ? recent.first.id : null;

      if (isFirstSave) {
        // ── First-save celebration ──
        final simulateFirstSave = ref.read(simulateFirstSaveProvider);
        final hasSimulatedInSession = ref.read(hasSimulatedFirstSaveInSessionProvider);

        if (simulateFirstSave && !hasSimulatedInSession) {
          ref.read(hasSimulatedFirstSaveInSessionProvider.notifier).state = true;
        }

        setState(() {
          _inputUiState = _InputUiState.success;
        });

        if (!simulateFirstSave) {
          await ref.read(hasShownFirstSaveCelebrationProvider.notifier).set(true);
        }

        // Let the user see the saved card settle, then return to the real Home.
        _resetTimer?.cancel();
        _resetTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) {
            setState(() {
              _isCelebratingFirstSave = false;
              _inputUiState = _InputUiState.idle;
              _inputValid = false;
            });
            _urlInputController.clear();
          }
        });
      } else {
        // ── Normal save flow ──
        setState(() => _inputUiState = _InputUiState.success);

        _resetTimer?.cancel();
        _resetTimer = Timer(const Duration(milliseconds: 900), () {
          if (mounted) {
            setState(() {
              _inputUiState = _InputUiState.idle;
              _inputValid = false;
            });
            _urlInputController.clear();
          }
        });
      }

      // Undo snackbar
      if (justSavedId != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Saved'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  final isarService = ref.read(isarServiceProvider);
                  await isarService.deleteUrl(justSavedId);
                },
              ),
            ),
          );
      }

      // Show share tip on first successful save
      final hasSeenShareTip = ref.read(hasSeenShareTipProvider);
      if (!hasSeenShareTip) {
        ref.read(hasSeenShareTipProvider.notifier).set(true);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Tip: You can share links directly to Glimpse from any app',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
    } else {
      setState(() {
        _inputUiState = _InputUiState.error;
        _inputErrorText = addState.errorMessage ?? 'Failed to save';
        _isCelebratingFirstSave = false;
      });

      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _inputUiState = _InputUiState.idle);
      });
    }

    notifier.reset();
  }

  Future<void> _refreshUnreadBadge() async {
    final count = await DigestPrefs.unreadCount();
    if (mounted && count != _unreadDigests) {
      setState(() => _unreadDigests = count);
    }
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 0;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _urlInputController.removeListener(_onInputChanged);
    _urlInputController.dispose();
    _urlInputFocus.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urlsAsync = ref.watch(displayedUrlsProvider);
    final orderedCategories = ref.watch(orderedCategoriesProvider);
    final addUrlStatus = ref.watch(addUrlProvider.select((s) => s.status));
    final isAddingUrl = addUrlStatus != AddUrlStatus.idle &&
        addUrlStatus != AddUrlStatus.done &&
        addUrlStatus != AddUrlStatus.error;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Rediscovery bug fix: use actual links and simulation flag
    final simulateFirstSave = ref.watch(simulateFirstSaveProvider);
    final forceEmptyLibrary = ref.watch(forceEmptyLibraryProvider);
    final actualUrlsAsync = ref.watch(urlStreamProvider);
    final actualUrls = actualUrlsAsync.valueOrNull ?? [];

    // Keep category order in sync with the DB
    ref.listen(categoriesProvider, (_, next) {
      next.whenData((cats) {
        final names = cats.map((c) => c['category'] as String).toList();
        ref.read(categoryOrderProvider.notifier).sync(names);
      });
    });

    // Auto-complete onboarding when the user adds their first link.
    ref.listen(displayedUrlsProvider, (prev, next) {
      final prevCount = prev?.valueOrNull?.length ?? 0;
      final nextCount = next.valueOrNull?.length ?? 0;
      final onboardingDone = ref.read(hasSeenOnboardingProvider);
      if (prevCount == 0 && nextCount > 0 && !onboardingDone) {
        ref.read(hasSeenOnboardingProvider.notifier).set(true);
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: urlsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading your URLs...'),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_tethering_error_rounded,
                  size: 52,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load your library',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(urlStreamProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (urls) {
          final isEmptyOrCelebrating =
              ((urls.isEmpty && !isAddingUrl) || _isCelebratingFirstSave);

          if (isEmptyOrCelebrating) {
            return _buildEmptyState(
                context, urls, theme, colorScheme, textTheme);
          }

          return _buildContentState(
            context,
            urls,
            orderedCategories,
            theme,
            simulateFirstSave: simulateFirstSave,
            forceEmptyLibrary: forceEmptyLibrary,
            actualUrls: actualUrls,
            isAddingUrl: isAddingUrl,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    List<SavedUrl> urls,
    ThemeData theme,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        // Header
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                _buildGlimpseTitle(context),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LandingIdentity(),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isCelebratingFirstSave && urls.isNotEmpty
                          ? Text(
                              key: const ValueKey('headline_success'),
                              'Saved to your library',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : Text(
                              key: const ValueKey('headline_empty'),
                              'Save something worth keeping',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isCelebratingFirstSave && urls.isNotEmpty
                            ? 'Your first saved item is ready below.'
                            : 'Glimpse organizes it, so you don\'t have to.',
                        key: ValueKey(_isCelebratingFirstSave && urls.isNotEmpty
                            ? 'sub_success'
                            : 'sub_empty'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InlineSaveInput(
                      controller: _urlInputController,
                      focusNode: _urlInputFocus,
                      uiState: _inputUiState,
                      errorText: _inputErrorText,
                      isFirstSaveCelebration: _isCelebratingFirstSave,
                      onSubmitted: (_) => _saveFromInput(),
                    ),
                    if (_clipboardUrl != null &&
                        _inputUiState == _InputUiState.idle) ...[
                      const SizedBox(height: 8),
                      _ClipboardSuggestion(
                        url: _clipboardUrl!,
                        onTap: () {
                          _urlInputController.text = _clipboardUrl!;
                          _onInputChanged();
                          setState(() => _clipboardUrl = null);
                        },
                        onDismiss: () {
                          setState(() => _clipboardUrl = null);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_isCelebratingFirstSave && urls.isNotEmpty)
                      _FirstSaveCelebrationCard(
                        url: urls.first,
                        showGlow: false,
                        onTap: () => context.push('/url/${urls.first.id}'),
                      )
                    else
                      _SaveButton(
                          onPressed: _inputValid ? _saveFromInput : null),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentState(
    BuildContext context,
    List<SavedUrl> urls,
    List<Map<String, dynamic>> orderedCategories,
    ThemeData theme, {
    required bool simulateFirstSave,
    required bool forceEmptyLibrary,
    required List<SavedUrl> actualUrls,
    required bool isAddingUrl,
  }) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(const Duration(days: 7));
    final pinnedIds = ref.watch(pinnedUrlsProvider);
    final existingIds = urls.map((url) => url.id).toSet();
    final stalePinnedIds = pinnedIds.any((id) => !existingIds.contains(id));
    if (stalePinnedIds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(pinnedUrlsProvider.notifier).pruneToExisting(existingIds);
      });
    }
    final byId = {for (final url in urls) url.id: url};
    final pinnedUrls = [
      for (final id in pinnedIds)
        if (byId[id] != null) byId[id]!,
    ];
    final pinnedSet = pinnedUrls.map((url) => url.id).toSet();
    final regularUrls =
        urls.where((url) => !pinnedSet.contains(url.id)).toList();

    final todayUrls =
        regularUrls.where((u) => u.savedAt.isAfter(startOfToday)).toList();
    final weekUrls = regularUrls.where((u) =>
        u.savedAt.isAfter(startOfWeek) && !u.savedAt.isAfter(startOfToday)).toList();
    final earlierUrls =
        regularUrls.where((u) => !u.savedAt.isAfter(startOfWeek)).toList();

    final sections = <_Section>[
      if (pinnedUrls.isNotEmpty) _Section('Pinned', pinnedUrls),
      if (todayUrls.isNotEmpty) _Section('Today', todayUrls),
      if (weekUrls.isNotEmpty) _Section('This Week', weekUrls),
      if (earlierUrls.isNotEmpty) _Section('Earlier', earlierUrls),
    ];

    final isEmpty = urls.isEmpty;

    return Stack(
      children: [
        RefreshIndicator(
          edgeOffset: 60,
          onRefresh: () async {
            ref.invalidate(urlStreamProvider);
            ref.invalidate(categoriesProvider);
            await ref.read(urlStreamProvider.future);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                snap: true,
                centerTitle: false,
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                title: _buildGlimpseTitle(context),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_link_rounded),
                    tooltip: 'Add URL',
                    onPressed: () => context.push('/add'),
                  ),
                  if (!isEmpty)
                    IconButton(
                      icon: Badge.count(
                        count: _unreadDigests,
                        maxCount: 9,
                        isLabelVisible: _unreadDigests > 0,
                        largeSize: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                        child: const Icon(Icons.notifications_outlined),
                      ),
                      tooltip: 'Notifications',
                      onPressed: () async {
                        await context.push('/notifications');
                        _refreshUnreadBadge();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
              if (!simulateFirstSave && !forceEmptyLibrary && actualUrls.isNotEmpty)
                const SliverToBoxAdapter(child: RediscoverySection()),
              if (orderedCategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                        child: InkWell(
                          onTap: () => context.push('/sources'),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Filter by source',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.40),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: orderedCategories.length.clamp(0, 10),
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final cat = orderedCategories[index];
                            final name = cat['category'] as String;
                            final emoji = cat['emoji'] as String;
                            final fav = faviconUrl(name);
                            return GestureDetector(
                              onLongPress: () => _showReorderSheet(context),
                              child: FilterChip(
                                showCheckmark: false,
                                avatar: fav != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: CachedNetworkImage(
                                          imageUrl: fav,
                                          width: 14,
                                          height: 14,
                                          errorWidget: (_, _, _) =>
                                              Text(emoji, style: const TextStyle(fontSize: 10)),
                                        ),
                                      )
                                    : Text(emoji, style: const TextStyle(fontSize: 10)),
                                label: Text(name),
                                color: WidgetStatePropertyAll(
                                  theme.colorScheme.surfaceContainerLow,
                                ),
                                labelStyle: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerLow,
                                side: BorderSide.none,
                                selected: false,
                                onSelected: (_) => context.push(
                                  '/category/${Uri.encodeComponent(name)}',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (isAddingUrl)
                const SliverToBoxAdapter(child: UrlCardSkeleton()),
              for (final section in sections) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      section.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final url = section.urls[index];
                      return SwipeableUrlCard(
                        key: ValueKey(url.id),
                        url: url,
                        onTap: () => context.push('/url/${url.id}'),
                        onViewPinned: () {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      );
                    },
                    childCount: section.urls.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _isScrolled ? 1.0 : 0.0,
              child: Container(
                height: MediaQuery.of(context).padding.top + 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.scrim
                          .withValues(alpha: 0.45),
                      Theme.of(context).colorScheme.surface
                          .withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Hidden dev-only gesture access to Settings.
  /// Long-press or 5 consecutive taps on the title navigate to Settings.
  Widget _buildGlimpseTitle(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );

    final title = Text('Glimpse', style: textStyle);

    final enableGestures = AppEnvironment.isDevContext || kDebugMode;
    if (!enableGestures) return title;

    return GestureDetector(
      onLongPress: () => context.push('/settings'),
      onTap: () {
        _titleTapCount++;
        if (_titleTapCount >= 5) {
          _titleTapCount = 0;
          context.push('/settings');
        }
      },
      child: title,
    );
  }

  void _showReorderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CategoryReorderSheet(),
    );
  }
}

class _CategoryReorderSheet extends ConsumerStatefulWidget {
  const _CategoryReorderSheet();

  @override
  ConsumerState<_CategoryReorderSheet> createState() =>
      _CategoryReorderSheetState();
}

class _CategoryReorderSheetState
    extends ConsumerState<_CategoryReorderSheet> {
  Future<void> _deleteCategory(String name, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: Text(
          'This will permanently delete all $count ${count == 1 ? 'URL' : 'URLs'} in this category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final isarService = ref.read(isarServiceProvider);
    await isarService.deleteUrlsByCategory(name);
    ref.read(categoryOrderProvider.notifier).remove(name);
    ref.invalidate(categoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final orderedCats = ref.watch(orderedCategoriesProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Text('Edit Categories',
                      style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Hold the handle to reorder · Tap 🗑️ to delete',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: orderedCats.isEmpty
                  ? const Center(child: Text('No categories yet'))
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      itemCount: orderedCats.length,
                      onReorder: (oldIndex, newIndex) {
                        ref
                            .read(categoryOrderProvider.notifier)
                            .reorder(oldIndex, newIndex);
                      },
                      itemBuilder: (ctx, index) {
                        final cat = orderedCats[index];
                        final name = cat['category'] as String;
                        final emoji = cat['emoji'] as String;
                        final count = cat['count'] as int;
                        final fav = faviconUrl(name);
                        return ListTile(
                          key: ValueKey(name),
                          leading: fav != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CachedNetworkImage(
                                    imageUrl: fav,
                                    width: 28,
                                    height: 28,
                                    errorWidget: (_, _, _) => Text(
                                        emoji,
                                        style: const TextStyle(
                                            fontSize: 22)),
                                  ),
                                )
                              : Text(emoji,
                                  style:
                                      const TextStyle(fontSize: 22)),
                          title: Text(name),
                          subtitle: Text(
                              '$count ${count == 1 ? 'link' : 'links'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color:
                                        theme.colorScheme.error),
                                onPressed: () =>
                                    _deleteCategory(name, count),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Section {
  final String label;
  final List<SavedUrl> urls;
  const _Section(this.label, this.urls);
}

class _LandingIdentity extends StatelessWidget {
  const _LandingIdentity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        AppAssets.logo,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _SaveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        disabledBackgroundColor:
            colorScheme.onSurface.withValues(alpha: 0.08),
        disabledForegroundColor:
            colorScheme.onSurface.withValues(alpha: 0.35),
      ),
      child: const Text('Save to Glimpse'),
    );
  }
}

/// Subtle chip that suggests pasting a URL detected in the clipboard.
class _ClipboardSuggestion extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ClipboardSuggestion({
    required this.url,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayUrl = url.length > 42 ? '${url.substring(0, 42)}…' : url;

    return Material(
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.secondaryContainer,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paste from clipboard',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayUrl,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color:
                      colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                ),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline input that animates through idle → processing → success → error.
class _InlineSaveInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final _InputUiState uiState;
  final String? errorText;
  final bool isFirstSaveCelebration;
  final ValueChanged<String>? onSubmitted;

  const _InlineSaveInput({
    required this.controller,
    required this.focusNode,
    required this.uiState,
    this.errorText,
    this.isFirstSaveCelebration = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isError = uiState == _InputUiState.error;
    final isProcessing = uiState == _InputUiState.processing;
    final pulse = isFirstSaveCelebration && isProcessing;

    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer.withValues(alpha: 0.6)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pulse
              ? colorScheme.outline
              : (isError
                  ? colorScheme.error
                  : colorScheme.outlineVariant),
          width: isError ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
          child: _buildChild(context, colorScheme, textTheme),
        ),
      ),
    );

    if (pulse) {
      child = _PulseContainer(child: child);
    }

    return child;
  }

  Widget _buildChild(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    switch (uiState) {
      case _InputUiState.processing:
        return _buildProcessingState(colorScheme, textTheme);
      case _InputUiState.success:
        return _buildSuccessState(colorScheme, textTheme);
      case _InputUiState.error:
        return _buildErrorState(colorScheme, textTheme);
      case _InputUiState.idle:
        return _buildIdleState(colorScheme);
    }
  }

  Widget _buildIdleState(ColorScheme colorScheme) {
    return TextField(
      key: const ValueKey('input_idle'),
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: onSubmitted,
      cursorColor: colorScheme.primary,
      cursorWidth: 1.5,
      cursorRadius: const Radius.circular(1),
      decoration: const InputDecoration(
        hintText: 'Paste a link...',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildProcessingState(ColorScheme colorScheme, TextTheme textTheme) {
    final label = isFirstSaveCelebration
        ? 'Fetching your link'
        : 'Fetching preview';
    return Padding(
      key: const ValueKey('input_processing'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          _ProcessingDots(color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildSuccessState(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      key: const ValueKey('input_success'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(
            'Saved',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      key: const ValueKey('input_error'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              errorText ?? 'Invalid link',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three animated dots using [ColorScheme] colors.
class _ProcessingDots extends StatefulWidget {
  final Color color;

  const _ProcessingDots({required this.color});

  @override
  State<_ProcessingDots> createState() => _ProcessingDotsState();
}

class _ProcessingDotsState extends State<_ProcessingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = (_controller.value * 3).floor() % 3;
        final dots = '.' * (phase + 1);
        return Text(
          dots,
          style: TextStyle(
            color: widget.color,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

/// Brief scale pulse (1.0 → 1.05 → 1.0) used during first-save processing.
class _PulseContainer extends StatefulWidget {
  final Widget child;

  const _PulseContainer({required this.child});

  @override
  State<_PulseContainer> createState() => _PulseContainerState();
}

class _PulseContainerState extends State<_PulseContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    if (reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: widget.child,
        );
      },
    );
  }
}

/// The first saved link card with subtle fade, slide, and scale reveal.
class _FirstSaveCelebrationCard extends StatefulWidget {
  final SavedUrl url;
  final bool showGlow;
  final VoidCallback onTap;

  const _FirstSaveCelebrationCard({
    required this.url,
    required this.showGlow,
    required this.onTap,
  });

  @override
  State<_FirstSaveCelebrationCard> createState() =>
      _FirstSaveCelebrationCardState();
}

class _FirstSaveCelebrationCardState extends State<_FirstSaveCelebrationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    final colorScheme = Theme.of(context).colorScheme;

    Widget card = UrlCard(
      savedUrl: widget.url,
      onTap: widget.onTap,
    );

    if (widget.showGlow && !reduceMotion) {
      card = AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: card,
      );
    }

    if (reduceMotion) return card;

    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slide.value),
            child: ScaleTransition(
              scale: _scale,
              child: child,
            ),
          );
        },
        child: card,
      ),
    );
  }
}
