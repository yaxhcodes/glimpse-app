import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/config/app_environment.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/category_order_provider.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/services/demo_seed_service.dart';
import '../../core/services/digest_prefs.dart';
import '../../core/utils/url_extractor.dart';
import '../../shared/widgets/url_card.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../core/constants/app_assets.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/upgrade_gate.dart';
import '../add_url/add_url_provider.dart';
import 'home_provider.dart';
import 'rediscovery_section.dart';
import 'guide_card.dart';

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
  Timer? _introFadeTimer;

  // First-save celebration state
  bool _isCelebratingFirstSave = false;
  // During the first-save celebration, fades the empty-state chrome away after
  // the magic plays so the saved card is what's left before the home settles.
  bool _dismissingIntro = false;

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
        if (extracted.urls.length == 1 &&
            _urlInputController.text.trim().isEmpty) {
          _urlInputController.text = extracted.urls.first;
          setState(() => _clipboardUrl = null);
        } else {
          setState(() => _clipboardUrl = text);
        }
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
    final hasSimulatedInSession = ref.read(
      hasSimulatedFirstSaveInSessionProvider,
    );

    bool isFirstSave;
    if (simulateFirstSave && !hasSimulatedInSession) {
      // Dev simulation: always treat as first save for testing.
      isFirstSave = true;
    } else {
      final currentUrls = ref.read(urlStreamProvider).valueOrNull ?? [];
      isFirstSave =
          currentUrls.isEmpty &&
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

    if (success && addState.aiLimitReached) {
      showAiLimitSnackBar(context);
    }

    if (success) {
      HapticFeedback.lightImpact();

      // Grab the ID of the just-saved URL for potential undo.
      final isar = ref.read(isarServiceProvider);
      final recent = await isar.getAllUrls();
      final justSavedId = recent.isNotEmpty ? recent.first.id : null;

      if (isFirstSave) {
        // ── First-save celebration ──
        final simulateFirstSave = ref.read(simulateFirstSaveProvider);
        final hasSimulatedInSession = ref.read(
          hasSimulatedFirstSaveInSessionProvider,
        );

        if (simulateFirstSave && !hasSimulatedInSession) {
          ref.read(hasSimulatedFirstSaveInSessionProvider.notifier).state =
              true;
        }

        setState(() {
          _inputUiState = _InputUiState.success;
        });
        HapticFeedback.mediumImpact();

        if (!simulateFirstSave) {
          await ref
              .read(hasShownFirstSaveCelebrationProvider.notifier)
              .set(true);
        }

        // Once the magic has played, melt the empty-state chrome away so the
        // saved card is what's left on screen.
        _introFadeTimer?.cancel();
        _introFadeTimer = Timer(const Duration(milliseconds: 1300), () {
          if (mounted) setState(() => _dismissingIntro = true);
        });

        // Then settle into the populated home (card now at the top).
        _resetTimer?.cancel();
        _resetTimer = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) {
            setState(() {
              _isCelebratingFirstSave = false;
              _dismissingIntro = false;
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
        showAutoDismissSnackBarVia(
          messenger,
          SnackBar(
            content: const Text('Captured'),
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

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _introFadeTimer?.cancel();
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
    final isAddingUrl =
        addUrlStatus != AddUrlStatus.idle &&
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

    ref.listen(homeScrollToTopSignalProvider, (previous, next) {
      if (previous == null || next == previous) return;
      _scrollToTop();
    });

    // Keep category order in sync with the DB
    ref.listen(categoriesProvider, (_, next) {
      next.whenData((cats) {
        final names = cats.map((c) => c['category'] as String).toList();
        ref.read(categoryOrderProvider.notifier).sync(names);
      });
    });

    // Auto-complete onboarding when the user adds their first link, and clear
    // the onboarding demo seed once a real save arrives.
    ref.listen(displayedUrlsProvider, (prev, next) {
      final prevCount = prev?.valueOrNull?.length ?? 0;
      final nextCount = next.valueOrNull?.length ?? 0;
      final onboardingDone = ref.read(hasSeenOnboardingProvider);
      if (prevCount == 0 && nextCount > 0 && !onboardingDone) {
        ref.read(hasSeenOnboardingProvider.notifier).set(true);
      }
      _maybeClearDemoSeed(next.valueOrNull ?? const []);
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

          final child = isEmptyOrCelebrating
              ? _buildEmptyState(
                  context,
                  urls,
                  theme,
                  colorScheme,
                  textTheme,
                )
              : _buildContentState(
                  context,
                  urls,
                  orderedCategories,
                  theme,
                  simulateFirstSave: simulateFirstSave,
                  forceEmptyLibrary: forceEmptyLibrary,
                  actualUrls: actualUrls,
                  isAddingUrl: isAddingUrl,
                );

          // Cross-fade the empty→home swap so the first save flows into the
          // populated feed instead of hard-cutting.
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            // Tight, full-size constraints so neither layout reflows (which
            // caused the input to overflow) mid cross-fade.
            child: SizedBox.expand(
              key: ValueKey(isEmptyOrCelebrating ? 'empty' : 'content'),
              child: child,
            ),
          );
        },
      ),
    );
  }

  bool _clearingDemoSeed = false;

  /// Removes the onboarding demo seed the first time a real (non-demo) save
  /// appears, so it never lingers once the library has genuine content.
  Future<void> _maybeClearDemoSeed(List<SavedUrl> urls) async {
    if (_clearingDemoSeed) return;
    final demoId = await DemoSeedService.demoId();
    if (demoId == null) return;
    final hasRealSave = urls.any((url) => url.id != demoId);
    if (!hasRealSave) return;
    _clearingDemoSeed = true;
    await DemoSeedService(ref.read(isarServiceProvider)).clear();
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
          child: Align(
            alignment: const Alignment(0, -0.18),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedOpacity(
                      opacity: _dismissingIntro ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                                const _LandingIdentity(),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isCelebratingFirstSave &&
                                          urls.isNotEmpty
                                      ? Text(
                                          key: const ValueKey(
                                              'headline_success'),
                                          'Captured in Glimpse',
                                          style: textTheme.headlineSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        )
                                      : Text(
                                          key: const ValueKey('headline_empty'),
                                          'Capture something worth returning to',
                                          style: textTheme.headlineSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isCelebratingFirstSave &&
                                          urls.isNotEmpty
                                      ? Text(
                                          'Your first captured item is ready below.',
                                          key: const ValueKey('sub_success'),
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            height: 1.45,
                                          ),
                                          textAlign: TextAlign.center,
                                        )
                                      : Text(
                                          'Share from any app — Glimpse sorts it for you.',
                                          key: const ValueKey('sub_empty'),
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
                                  isFirstSaveCelebration:
                                      _isCelebratingFirstSave,
                                  onSubmitted: (_) => _saveFromInput(),
                                  canCapture: _inputValid,
                                  onCapture: _saveFromInput,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isCelebratingFirstSave && urls.isNotEmpty)
                      _FirstSaveCelebrationCard(
                        url: urls.first,
                        onTap: () => context.push('/url/${urls.first.id}'),
                      )
                    else
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/guide'),
                          child: Text(
                            'How Glimpse works',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
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
    const selectionScope = 'home';
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(const Duration(days: 7));
    final selectionState = ref.watch(bulkSelectionProvider(selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(selectionScope).notifier,
    );
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
    final regularUrls = urls
        .where((url) => !pinnedSet.contains(url.id))
        .toList();

    final todayUrls = regularUrls
        .where((u) => u.savedAt.isAfter(startOfToday))
        .toList();
    final weekUrls = regularUrls
        .where(
          (u) =>
              u.savedAt.isAfter(startOfWeek) &&
              !u.savedAt.isAfter(startOfToday),
        )
        .toList();
    final earlierUrls = regularUrls
        .where((u) => !u.savedAt.isAfter(startOfWeek))
        .toList();

    final sections = <_Section>[
      if (pinnedUrls.isNotEmpty) _Section('Pinned', pinnedUrls),
      if (todayUrls.isNotEmpty) _Section('Today', todayUrls),
      if (weekUrls.isNotEmpty) _Section('This Week', weekUrls),
      if (earlierUrls.isNotEmpty) _Section('Earlier', earlierUrls),
    ];

    // Post-onboarding guide card: shows on a populated home until the user
    // dismisses it (a persistent how-to, robust to the demo card being
    // deleted). Hidden under the dev empty/simulate overrides.
    final showGuideCard = !ref.watch(hasSeenGuideCardProvider) &&
        !simulateFirstSave &&
        !forceEmptyLibrary &&
        actualUrls.isNotEmpty;

    final isEmpty = urls.isEmpty;
    final selectedUrls = urls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList();
    if (selectionState.enabled && selectedUrls.length != selectionState.count) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        selectionNotifier.pruneToVisible(urls.map((url) => url.id));
      });
    }

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) {
          selectionNotifier.clear();
        }
      },
      child: Stack(
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
                  leading: selectionState.isActive
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Exit selection',
                          onPressed: selectionNotifier.clear,
                        )
                      : null,
                  title: selectionState.isActive
                      ? BulkSelectionTitle(count: selectedUrls.length)
                      : _buildGlimpseTitle(context),
                  actions: selectionState.isActive
                      ? [
                          BulkSelectionActionButtons(
                            scope: selectionScope,
                            selectedUrls: selectedUrls,
                            visibleUrls: urls,
                            onDone: selectionNotifier.clear,
                            onViewPinned: () {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                              );
                            },
                          ),
                        ]
                      : [
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
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
                if (showGuideCard)
                  const SliverToBoxAdapter(child: GuideCard()),
                if (!simulateFirstSave &&
                    !forceEmptyLibrary &&
                    actualUrls.isNotEmpty)
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
                                horizontal: 0,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Filter by source',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
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
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: fav,
                                            width: 14,
                                            height: 14,
                                            errorWidget: (_, _, _) => Text(
                                              emoji,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                  label: Text(name),
                                  color: WidgetStatePropertyAll(
                                    theme.colorScheme.surfaceContainerLow,
                                  ),
                                  labelStyle: theme.textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.1,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final url = section.urls[index];
                      final sectionIds =
                          section.urls.map((u) => u.id).toList();
                      return SwipeableUrlCard(
                        key: ValueKey(url.id),
                        url: url,
                        selectionMode: selectionState.isActive,
                        isSelected: selectionState.isSelected(url.id),
                        onSelectionStart: () =>
                            selectionNotifier.startWith(url.id),
                        onSelectionToggle: () =>
                            selectionNotifier.toggle(url.id),
                        onTap: () => context.push(
                          '/url/${url.id}',
                          extra: sectionIds,
                        ),
                        onViewPinned: () {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      );
                    }, childCount: section.urls.length),
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
                        Theme.of(
                          context,
                        ).colorScheme.scrim.withValues(alpha: 0.45),
                        Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

class _CategoryReorderSheetState extends ConsumerState<_CategoryReorderSheet> {
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
                  Text('Edit Categories', style: theme.textTheme.titleLarge),
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                )
                              : Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                          title: Text(name),
                          subtitle: Text(
                            '$count ${count == 1 ? 'link' : 'links'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                                onPressed: () => _deleteCategory(name, count),
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

class _LandingIdentity extends StatefulWidget {
  const _LandingIdentity();

  @override
  State<_LandingIdentity> createState() => _LandingIdentityState();
}

class _LandingIdentityState extends State<_LandingIdentity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: 220,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft glow so the hero reads as a composed focal point rather
            // than floating in empty space.
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.16),
                    cs.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final dy = (Curves.easeInOut.transform(_c.value) * 6) - 3;
                return Transform.translate(offset: Offset(0, dy), child: child);
              },
              child: Image.asset(
                AppAssets.homeHero,
                width: 156,
                height: 156,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular capture action embedded at the end of the save input —
/// muted when there's nothing to capture, primary when the link is valid.
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? cs.primary : cs.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: enabled
                ? cs.onPrimary
                : cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
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
        side: BorderSide(color: colorScheme.secondaryContainer),
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
                        color: colorScheme.onSecondaryContainer.withValues(
                          alpha: 0.7,
                        ),
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
                  color: colorScheme.onSecondaryContainer.withValues(
                    alpha: 0.7,
                  ),
                ),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
  final bool canCapture;
  final VoidCallback? onCapture;

  const _InlineSaveInput({
    required this.controller,
    required this.focusNode,
    required this.uiState,
    this.errorText,
    this.isFirstSaveCelebration = false,
    this.onSubmitted,
    this.canCapture = false,
    this.onCapture,
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
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
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

  /// Extracts a clean host (e.g. `open.spotify.com`) from partial input, or
  /// null when there isn't a recognisable domain yet.
  static String? _hostFromText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final candidate =
        trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final host = Uri.tryParse(candidate)?.host ?? '';
    if (host.isEmpty || !host.contains('.')) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  Widget _buildIdleState(ColorScheme colorScheme) {
    return Padding(
      key: const ValueKey('input_idle'),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          // Leading icon reflects the source of the pasted link (e.g. Spotify,
          // YouTube). Updates live as the field changes.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final host = _hostFromText(value.text);
              if (host == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://www.google.com/s2/favicons?domain=$host&sz=64',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => Icon(Icons.public,
                        size: 18, color: colorScheme.onSurfaceVariant),
                    errorWidget: (_, _, _) => Icon(Icons.public,
                        size: 18, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: TextField(
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
                hintText: 'Paste a link…',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CaptureButton(enabled: canCapture, onTap: onCapture),
        ],
      ),
    );
  }

  Widget _buildProcessingState(ColorScheme colorScheme, TextTheme textTheme) {
    final label = isFirstSaveCelebration
        ? 'Capturing what caught your eye'
        : 'Finding the context';
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
            'Captured',
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
          style: TextStyle(color: widget.color, fontWeight: FontWeight.w600),
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
        tween: Tween(
          begin: 1.0,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
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
        return Transform.scale(scale: _scale.value, child: widget.child);
      },
    );
  }
}

/// The first saved link card with subtle fade, slide, and scale reveal.
class _FirstSaveCelebrationCard extends StatefulWidget {
  final SavedUrl url;
  final VoidCallback onTap;

  const _FirstSaveCelebrationCard({
    required this.url,
    required this.onTap,
  });

  @override
  State<_FirstSaveCelebrationCard> createState() =>
      _FirstSaveCelebrationCardState();
}

class _FirstSaveCelebrationCardState extends State<_FirstSaveCelebrationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final Animation<double> _scale = Tween<double>(begin: 0.88, end: 1.0)
      .animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
  ));

  late final Animation<double> _opacity = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
  ));

  late final Animation<double> _slide = Tween<double>(begin: 14.0, end: 0.0)
      .animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
  ));

  @override
  void initState() {
    super.initState();
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
    final cs = Theme.of(context).colorScheme;
    final card = UrlCard(savedUrl: widget.url, onTap: widget.onTap);
    if (reduceMotion) return card;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Glow flashes in then fades, like the save sparking to life.
        final glow = 0.5 * (1 - Curves.easeOut.transform(t));
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: Transform.scale(
              scale: _scale.value,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: glow),
                          blurRadius: 26,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SparkleBurstPainter(
                          progress: t,
                          color: cs.primary,
                          accent: cs.tertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: card,
    );
  }
}

/// A one-shot burst of sparks radiating outward as the first save lands.
class _SparkleBurstPainter extends CustomPainter {
  _SparkleBurstPainter({
    required this.progress,
    required this.color,
    required this.accent,
  });

  final double progress;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOut.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    const count = 16;
    final maxDist = size.width * 0.42;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (i.isEven ? 0.0 : 0.22);
      final dist = size.shortestSide * 0.12 + maxDist * eased;
      // Flatten vertically to suit the wide, short card.
      final pos = center +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.5);
      final radius = (i % 3 == 0 ? 3.2 : 2.0) * (0.5 + 0.5 * fade);
      final paint = Paint()
        ..color = (i.isEven ? color : accent).withValues(alpha: 0.85 * fade);
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleBurstPainter old) =>
      old.progress != progress;
}
