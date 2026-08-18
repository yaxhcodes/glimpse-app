import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/providers/analytics_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/backup_provider.dart';
import 'core/providers/dev_simulation_providers.dart';
import 'core/providers/pinned_urls_provider.dart';
import 'core/providers/service_providers.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/guide_detail_screen.dart';
import 'core/services/backup/backup_intent_service.dart';
import 'core/services/backup/backup_models.dart';
import 'core/services/app_update_service.dart';
import 'core/services/digest_notifications.dart';
import 'core/services/notification_router.dart';
import 'core/services/tag_analyzer.dart';
import 'core/services/embedding_backfill_service.dart';
import 'core/services/category_repair_service.dart';
import 'core/models/saved_url.dart';
import 'core/models/user_collection.dart';
import 'features/ask/ask_empty_suggestions_provider.dart';
import 'features/ask/ask_launch_request.dart';
import 'features/home/home_provider.dart';
import 'features/shell/main_shell.dart';
import 'features/mindmap/interest_clusters_provider.dart';
import 'features/add_url/add_url_screen.dart';
import 'features/add_url/add_url_provider.dart';
import 'features/categories/category_screen.dart';
import 'features/collections/collection_detail_screen.dart';
import 'features/collections/collections_provider.dart';
import 'features/collections/collections_screen.dart';
import 'features/collections/create_collection_screen.dart';
import 'features/collections/share_capture_sheet.dart';
import 'features/library/library_browser_screen.dart';
import 'features/library/library_entity.dart';
import 'features/library/library_entity_detail_screen.dart';
import 'features/library/library_home.dart';
import 'features/library/library_places_screen.dart';
import 'features/library/place_itinerary_editor_screen.dart';
import 'features/digest/digest_screen.dart';
import 'features/digest/notification_detail_screen.dart';
import 'features/digest/notifications_screen.dart';
import 'features/search/search_screen.dart';
import 'features/url_detail/url_detail_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/bin_screen.dart';
import 'features/settings/look_and_feel_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/privacy_screen.dart';
import 'features/settings/subscription_screen.dart';
import 'features/settings/data_backup_screen.dart';
import 'features/settings/backup_preview_screen.dart';
import 'features/ask/ask_screen.dart';
import 'features/mindmap/mindmap_screen.dart';
import 'features/recap/recap_screen.dart';
import 'features/synthesis/synthesis_screen.dart';
import 'features/rediscover/rediscover_journey_detail_screen.dart';
import 'features/rediscover/rediscover_journey_provider.dart';
import 'features/rediscover/rediscover_open_context.dart';
import 'features/rediscover/rediscover_provider.dart';
import 'features/rediscover/rediscover_recap_detail_screen.dart';
import 'features/rediscover/rediscover_screen.dart';
import 'features/sources/archive_screen.dart';
import 'features/sources/source_detail_screen.dart';
import 'features/sources/sources_screen.dart';
import 'features/batch_save/batch_preview_screen.dart';
import 'core/config/app_environment.dart';
import 'core/services/entitlement_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/url_save_notifications.dart';
import 'core/utils/url_extractor.dart';
import 'shared/widgets/app_snackbar.dart';
import 'shared/widgets/expressive_loading_indicator.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_provider.dart';

/// Provider that holds a URL received via Android share intent.
final sharedUrlProvider = StateProvider<String?>((ref) => null);

/// Root navigator for notification deep links.
final rootNavigatorKey = GlobalKey<NavigatorState>();

// GoRouter configuration — needs to be accessible for programmatic navigation
final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _RootGate()),
    GoRoute(
      path: '/add',
      builder: (context, state) {
        final initialUrl = state.uri.queryParameters['url'];
        final arguments = state.extra is ManualAddArguments
            ? state.extra as ManualAddArguments
            : null;
        return AddUrlScreen(
          initialUrl: initialUrl,
          initialCollection: arguments?.initialCollection,
        );
      },
    ),
    GoRoute(
      path: '/category/:name',
      builder: (context, state) {
        final name = Uri.decodeComponent(state.pathParameters['name']!);
        return CategoryScreen(categoryName: name);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) {
        final query = state.uri.queryParameters['q'];
        return SearchScreen(initialQuery: query);
      },
    ),
    GoRoute(path: '/digest', builder: (context, state) => const DigestScreen()),
    GoRoute(
      path: '/archive',
      builder: (context, state) => const ArchiveScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/notification_detail',
      builder: (context, state) {
        final extra = state.extra as NotificationDetailExtra?;
        return NotificationDetailScreen(
          title: extra?.title ?? 'Notification',
          linkIds: extra?.linkIds ?? const [],
          insightLine: extra?.insightLine,
        );
      },
    ),
    GoRoute(
      path: '/collections',
      builder: (context, state) => const CollectionsScreen(),
    ),
    GoRoute(
      path: '/collections/new',
      builder: (context, state) => const CreateCollectionScreen(),
    ),
    GoRoute(
      path: '/collections/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return CollectionDetailScreen(collectionId: id);
      },
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/library/books',
      builder: (context, state) =>
          const LibraryBrowserScreen(kind: LibraryEntityKind.book),
    ),
    GoRoute(
      path: '/library/movies',
      builder: (context, state) =>
          const LibraryBrowserScreen(kind: LibraryEntityKind.movie),
    ),
    GoRoute(
      path: '/library/places',
      builder: (context, state) => const LibraryPlacesScreen(),
    ),
    GoRoute(
      path: '/library/places/itinerary/new',
      builder: (context, state) => PlaceItineraryEditorScreen(
        draft: state.extra as PlaceItineraryDraft?,
      ),
    ),
    GoRoute(
      path: '/library/places/itinerary/:id',
      builder: (context, state) => PlaceItineraryEditorScreen(
        itineraryId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/library/entity/:key',
      builder: (context, state) => LibraryEntityDetailScreen(
        entityKey: Uri.decodeComponent(state.pathParameters['key']!),
      ),
    ),
    GoRoute(
      path: '/url/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final args = state.extra is UrlDetailRouteArgs
            ? state.extra as UrlDetailRouteArgs
            : null;
        final siblings =
            args?.siblingIds ??
            (state.extra is List<int> ? state.extra as List<int> : null);
        if (siblings != null && siblings.length > 1) {
          final index = siblings.indexOf(id);
          return UrlDetailPagerScreen(
            urlIds: siblings,
            initialIndex: index < 0 ? 0 : index,
            rediscoverContext: args?.rediscoverContext,
          );
        }
        return UrlDetailScreen(
          urlId: id,
          rediscoverContext: args?.rediscoverContext,
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/look-and-feel',
      builder: (context, state) => const LookAndFeelScreen(),
    ),
    GoRoute(
      path: '/settings/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/settings/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/settings/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/settings/data-backup',
      builder: (context, state) => const DataBackupScreen(),
    ),
    GoRoute(
      path: '/settings/bin',
      builder: (context, state) => const BinScreen(),
    ),
    GoRoute(
      path: '/settings/data-backup/preview',
      builder: (context, state) => const BackupPreviewScreen(),
    ),
    GoRoute(
      path: '/ask',
      builder: (context, state) {
        final extra = state.extra;
        final request = extra is AskLaunchRequest ? extra : null;
        return AskScreen(
          initialSource: request?.source ?? (extra is SavedUrl ? extra : null),
          initialPrompt: request?.initialPrompt,
        );
      },
    ),
    GoRoute(
      path: '/mindmap',
      builder: (context, state) => const MindmapScreen(),
    ),
    GoRoute(
      path: '/mindmap/cluster/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return MindmapClusterScreen(clusterId: id);
      },
    ),
    GoRoute(path: '/recap', builder: (context, state) => const RecapScreen()),
    GoRoute(
      path: '/synthesis',
      builder: (context, state) {
        final urls = (state.extra as List<SavedUrl>?) ?? [];
        return SynthesisScreen(initialUrls: urls);
      },
    ),
    GoRoute(
      path: '/rediscover',
      builder: (context, state) => const RediscoverScreen(),
    ),
    GoRoute(
      path: '/rediscover/journey',
      builder: (context, state) {
        final args = state.extra is RediscoverJourneyRouteArgs
            ? state.extra as RediscoverJourneyRouteArgs
            : null;
        final journey =
            args?.journey ??
            (state.extra is RediscoverJourney
                ? state.extra as RediscoverJourney
                : null);
        if (journey == null) return const RediscoverScreen();
        return RediscoverJourneyDetailScreen(
          journey: journey,
          openContext: args?.openContext,
        );
      },
    ),
    GoRoute(
      path: '/rediscover/recap',
      builder: (context, state) {
        final recap = state.extra is RediscoverRecap
            ? state.extra as RediscoverRecap
            : null;
        if (recap == null) return const RediscoverScreen();
        return RediscoverRecapDetailScreen(recap: recap);
      },
    ),
    GoRoute(
      path: '/sources',
      builder: (context, state) => const SourcesScreen(),
    ),
    GoRoute(
      path: '/sources/:name',
      builder: (context, state) {
        final name = Uri.decodeComponent(state.pathParameters['name'] ?? '');
        return SourceDetailScreen(sourceName: name);
      },
    ),
    GoRoute(
      path: '/guide',
      builder: (context, state) => const GuideDetailScreen(),
    ),
    GoRoute(
      path: '/batch-save',
      builder: (context, state) {
        final urls = (state.extra as List<String>?) ?? [];
        return BatchPreviewScreen(urls: urls);
      },
    ),
  ],
);

class GlimpseApp extends ConsumerStatefulWidget {
  const GlimpseApp({super.key});

  @override
  ConsumerState<GlimpseApp> createState() => _GlimpseAppState();
}

class _GlimpseAppState extends ConsumerState<GlimpseApp>
    with WidgetsBindingObserver {
  late StreamSubscription _shareIntentSub;
  StreamSubscription<String>? _backupIntentSub;
  StreamSubscription<void>? _appUpdateReadySub;
  final BackupIntentService _backupIntentService = BackupIntentService();
  Timer? _analyticsStartupTimer;
  Timer? _maintenanceStartupTimer;
  Timer? _appUpdateStartupTimer;
  List<String>? _pendingSharedUrls;
  bool _processingSharedUrls = false;
  bool _hasCompletedInitialResume = false;
  String? _lastTrackedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router.routerDelegate.addListener(_trackRouteOpen);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        DigestNotifications.init(
          onOpenNotification: (payload) {
            NotificationRouter.deliverPayload(rootNavigatorKey, payload);
          },
        ),
      );
    });

    // Handle intent that launched the app (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedMedia);

    // Handle intents while app is already running (warm start)
    _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
    );

    // Backup files opened via "Open with..." from a file manager.
    _backupIntentSub = _backupIntentService.incoming.listen(_handleBackupFile);
    unawaited(_backupIntentService.start());

    final appUpdateService = ref.read(appUpdateServiceProvider);
    _appUpdateReadySub = appUpdateService.flexibleUpdateReady.listen((_) {
      _showAppUpdateReadyPrompt();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleNonCriticalStartupWork(appUpdateService);
    });
  }

  void _scheduleNonCriticalStartupWork(AppUpdateService appUpdateService) {
    _analyticsStartupTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      unawaited(ref.read(analyticsServiceProvider).initialize());
      unawaited(TagAnalyzer.recordAppOpen());
      _trackRouteOpen();
    });

    _maintenanceStartupTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      unawaited(_runDeferredLocalMaintenance());
    });

    _appUpdateStartupTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      unawaited(appUpdateService.checkForUpdateOnLaunch());
    });
  }

  Future<void> _runDeferredLocalMaintenance() async {
    final isar = ref.read(isarServiceProvider);
    final purgedIds = await isar.purgeExpiredBinItems();
    if (!mounted) return;
    if (purgedIds.isNotEmpty) {
      await ref.read(pinnedUrlsProvider.notifier).unpinAll(purgedIds);
    }
    final repaired = await CategoryRepairService(
      isarService: isar,
    ).repairIfNeeded();
    if (!mounted) return;
    if (repaired > 0) {
      ref.invalidate(urlStreamProvider);
      ref.invalidate(interestClusterThemesProvider);
    }

    final embedding = ref.read(embeddingServiceProvider);
    if (embedding == null) return;
    final backfill = EmbeddingBackfillService(
      isarService: isar,
      embeddingService: embedding,
    );
    final backfilled = await backfill.backfillIfNeeded();
    if (!mounted || backfilled <= 0) return;
    ref.invalidate(urlStreamProvider);
    ref.invalidate(interestClusterThemesProvider);
    ref.invalidate(askEmptySuggestionsProvider);
  }

  Future<void> _handleBackupFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      _showBackupOpenError('Could not read the backup file.');
      return;
    }

    // Defer until the navigator is ready (cold start fires before the
    // first frame).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Validate via the backup notifier so the BackupPreviewScreen can
      // pick it up directly from `state.previewData`.
      await ref.read(backupProvider.notifier).validateBackupContent(content);
      if (!mounted) return;

      final state = ref.read(backupProvider);
      if (state.status == BackupStatus.previewing &&
          state.previewData != null) {
        // Make sure we land somewhere visible before opening the preview
        // (e.g. cold start may still be on '/').
        _router.push('/settings/data-backup/preview');
      } else if (state.status == BackupStatus.error && state.error != null) {
        _showBackupOpenError(state.error!.message);
        ref.read(backupProvider.notifier).reset();
      }
    });
  }

  void _showBackupOpenError(String message) {
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final sharedText = files.first.path;
    final extracted = UrlExtractor.extract(sharedText);

    if (extracted.urls.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleSharedUrls(extracted.urls));
    });
  }

  Future<void> _handleSharedUrls(List<String> urls) async {
    if (urls.isEmpty || _processingSharedUrls) return;
    _processingSharedUrls = true;

    try {
      final user =
          ref.read(authServiceProvider).currentUser ??
          await ref.read(authControllerProvider.future);
      if (!mounted) return;

      if (user == null) {
        _pendingSharedUrls = List.unmodifiable(urls);
        _router.go('/');
        _showSignInToSaveMessage();
        return;
      }

      _pendingSharedUrls = null;
      if (urls.length > 1) {
        // Multi-share → batch preview
        _router.push('/batch-save', extra: urls);
      } else {
        final collection = await _showShareCapturePrompt();
        if (!mounted) return;
        await _quickSave(
          urls.first,
          notifyCapture: true,
          returnAfterSave: true,
          collection: collection,
        );
      }
    } catch (e, st) {
      developer.log(
        'Shared URL auth gate failed; preserving pending share.',
        name: 'ShareIntent',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      _pendingSharedUrls = List.unmodifiable(urls);
      _router.go('/');
      _showSignInToSaveMessage();
    } finally {
      _processingSharedUrls = false;
    }
  }

  Future<UserCollection?> _showShareCapturePrompt() async {
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return null;
    return showShareCaptureSheet(context);
  }

  void _showSignInToSaveMessage() {
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sign in to save links.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
  }

  Future<void> _quickSave(
    String url, {
    bool notifyCapture = false,
    bool returnAfterSave = false,
    UserCollection? collection,
  }) async {
    final notifier = ref.read(addUrlProvider.notifier);
    final success = await notifier.saveUrl(
      url,
      notifyCapture: notifyCapture,
      showCaptureAcknowledgement: false,
    );
    final state = ref.read(addUrlProvider);
    final errorMsg = state.errorMessage;
    final aiLimitReached = state.aiLimitReached;
    final savedUrlId = state.savedUrlId;

    if (savedUrlId != null) {
      if (collection == null) {
        await UrlSaveNotifications.showCaptureStarted();
      } else {
        try {
          await ref
              .read(isarServiceProvider)
              .addUrlToCollection(
                collectionId: collection.id,
                urlId: savedUrlId,
              );
          ref.invalidate(collectionsListProvider);
          ref.invalidate(collectionsSummaryProvider);
          ref.invalidate(collectionUrlsProvider(collection.id));
          await UrlSaveNotifications.showSavedToCollection(collection.name);
        } catch (error, stackTrace) {
          developer.log(
            'The URL was saved, but could not be added to the selected collection.',
            name: 'ShareIntent',
            error: error,
            stackTrace: stackTrace,
          );
          await UrlSaveNotifications.showCaptureStarted();
        }
      }
    }

    notifier.reset();

    // Out of free AI saves: the bookmark is kept but won't be AI-enriched.
    // The share flow has no UI to host a snackbar (it pops the app), so the
    // upgrade prompt is delivered as a tappable notification instead.
    if (success && aiLimitReached) {
      await UrlSaveNotifications.showAiLimitReached();
    }

    if (returnAfterSave && (success || state.savedUrlId != null)) {
      await SystemNavigator.pop();
      return;
    }

    if (!mounted) return;
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    if (!ctx.mounted) return;

    final message = success
        ? 'Capturing what caught your eye.'
        : (errorMsg ?? 'Failed to save URL');

    showAutoDismissSnackBar(
      ctx,
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: success ? 3 : 4),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(ref.read(analyticsServiceProvider).handleLifecycleState(state));
    if (state == AppLifecycleState.resumed) {
      if (!_hasCompletedInitialResume) {
        _hasCompletedInitialResume = true;
        return;
      }
      unawaited(TagAnalyzer.recordAppOpen());
      unawaited(ref.read(appUpdateServiceProvider).checkForUpdateOnResume());
      // No subscription re-sync on resume:
      //   * RC auto-fetches CustomerInfo when the app foregrounds
      //   * any change fires `addCustomerInfoUpdateListener`
      //   * the notifier's listener writes the new tier into Riverpod
      // Previously we called `.refresh()` here — that tore down the
      // CustomerInfo cache on every resume and caused the "loader flash
      // over a correct Pro badge" symptom.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_trackRouteOpen);
    _shareIntentSub.cancel();
    _backupIntentSub?.cancel();
    _appUpdateReadySub?.cancel();
    _analyticsStartupTimer?.cancel();
    _maintenanceStartupTimer?.cancel();
    _appUpdateStartupTimer?.cancel();
    unawaited(_backupIntentService.dispose());
    super.dispose();
  }

  void _showAppUpdateReadyPrompt() {
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('A fresh Glimpse is ready.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(days: 1),
          action: SnackBarAction(
            label: 'Restart',
            onPressed: () {
              unawaited(
                ref.read(appUpdateServiceProvider).completeFlexibleUpdate(),
              );
            },
          ),
        ),
      );
  }

  void _trackRouteOpen() {
    final location = _router.routeInformationProvider.value.uri.path;
    if (location == _lastTrackedLocation) return;
    _lastTrackedLocation = location;
    final screen = _screenForPath(location);
    if (screen == null) return;
    unawaited(ref.read(analyticsServiceProvider).trackScreen(screen));
  }

  AnalyticsScreen? _screenForPath(String path) {
    if (path == '/add') return AnalyticsScreen.addUrl;
    if (path == '/search') return AnalyticsScreen.search;
    if (path == '/settings') return AnalyticsScreen.settings;
    if (path == '/settings/subscription') return AnalyticsScreen.subscription;
    if (path == '/settings/privacy') return AnalyticsScreen.privacy;
    if (path.startsWith('/settings/data-backup')) {
      return AnalyticsScreen.dataBackup;
    }
    if (path == '/ask') return AnalyticsScreen.askGlimpse;
    if (path.startsWith('/rediscover')) return AnalyticsScreen.rediscover;
    if (path.startsWith('/url/')) return AnalyticsScreen.urlDetail;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final wasSignedIn = previous?.valueOrNull != null;
      final isSignedOut = next.valueOrNull == null && !next.isLoading;
      final pendingSharedUrls = _pendingSharedUrls;
      if (next.valueOrNull != null &&
          pendingSharedUrls != null &&
          pendingSharedUrls.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_handleSharedUrls(pendingSharedUrls));
        });
      }
      if (!wasSignedIn || !isSignedOut) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_router.routeInformationProvider.value.uri.path != '/') {
          _router.go('/');
        }
      });
    });

    final themeMode = ref.watch(themeModeProvider);
    final amoledSurfaces = ref.watch(amoledSurfacesProvider);
    final accent = ref.watch(accentColorProvider);
    final devProOverrideActive = ref.watch(devProOverrideActiveProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Dynamic color: use each platform palette when available. Some
        // devices/emulators may return only one brightness palette.
        final bool useDynamic = accent == AppAccentColor.dynamic;

        final ThemeData lightTheme;
        final ThemeData darkTheme;

        final useAmoledPalette = amoledSurfaces && themeMode != ThemeMode.light;

        if (useDynamic) {
          final dynamicSeed =
              lightDynamic?.primary ??
              darkDynamic?.primary ??
              const Color(0xFF1D9E75);
          final lightScheme = ColorScheme.fromSeed(
            seedColor: dynamicSeed,
            brightness: Brightness.light,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          );
          final darkScheme = ColorScheme.fromSeed(
            seedColor: dynamicSeed,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          );
          lightTheme = AppTheme.fromColorScheme(lightScheme);
          darkTheme = useAmoledPalette
              ? AppTheme.fromColorSchemeAmoled(darkScheme)
              : AppTheme.fromColorScheme(darkScheme);
        } else {
          final seed = accent.seedColor ?? const Color(0xFF1D9E75);
          lightTheme = AppTheme.lightTheme(
            seed,
            schemeVariant: accent.schemeVariant,
          );
          darkTheme = useAmoledPalette
              ? AppTheme.amoledTheme(seed, schemeVariant: accent.schemeVariant)
              : AppTheme.darkTheme(seed, schemeVariant: accent.schemeVariant);
        }

        return MaterialApp.router(
          title: AppEnvironment.isDevContext ? 'Glimpse Dev' : 'Glimpse',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          themeAnimationStyle: AppTheme.transitionStyle,
          scrollBehavior: const AppScrollBehavior(),
          routerConfig: _router,
          builder: (context, child) {
            var content = child ?? const SizedBox.shrink();
            if (!AppEnvironment.isDevContext) {
              return content;
            }
            content = Banner(
              message: 'DEV',
              location: BannerLocation.topStart,
              color: const Color(0xFFE65100),
              textStyle: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
              child: content,
            );
            if (devProOverrideActive) {
              content = Stack(
                clipBehavior: Clip.none,
                children: [
                  content,
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xFF4A148C),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(6),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              'DEV PRO MODE',
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return content;
          },
        );
      },
    );
  }
}

/// Root screen selector: shows guided onboarding for new users, then routes to
/// authentication or the main app. Watches [hasSeenOnboardingProvider] so the
/// next destination appears as soon as onboarding is recorded.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  bool _splashRemovalScheduled = false;

  void _removeSplashAfterDestinationFrame() {
    if (_splashRemovalScheduled) return;
    _splashRemovalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FlutterNativeSplash.remove();
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);
    final destinationReady = !hasSeenOnboarding || !authState.isLoading;
    if (destinationReady) {
      _removeSplashAfterDestinationFrame();
    }
    final child = !hasSeenOnboarding
        ? const OnboardingScreen(key: ValueKey('onboarding'))
        : authState.when(
            data: (user) {
              if (user == null) {
                return const AuthScreen(key: ValueKey('auth'));
              }
              if (!user.onboardingCompleted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(authControllerProvider.notifier)
                      .markOnboardingCompleted();
                });
              }
              return const MainShell(key: ValueKey('main-shell'));
            },
            loading: () => const _StartupProgress(key: ValueKey('startup')),
            error: (_, _) => const AuthScreen(key: ValueKey('auth-error')),
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: child,
    );
  }
}

class _StartupProgress extends StatelessWidget {
  const _StartupProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: ExpressiveLoadingIndicator(size: 28, color: cs.primary),
        ),
      ),
    );
  }
}
