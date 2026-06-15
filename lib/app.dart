import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/providers/backup_provider.dart';
import 'core/providers/dev_simulation_providers.dart';
import 'core/providers/service_providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/guide_detail_screen.dart';
import 'core/services/backup/backup_intent_service.dart';
import 'core/services/backup/backup_models.dart';
import 'core/services/digest_notifications.dart';
import 'core/services/digest_scheduler.dart';
import 'core/services/notification_router.dart';
import 'core/services/tag_analyzer.dart';
import 'core/services/embedding_backfill_service.dart';
import 'core/services/category_repair_service.dart';
import 'core/models/saved_url.dart';
import 'features/ask/ask_empty_suggestions_provider.dart';
import 'features/home/home_provider.dart';
import 'features/shell/main_shell.dart';
import 'features/mindmap/interest_clusters_provider.dart';
import 'features/add_url/add_url_screen.dart';
import 'features/add_url/add_url_provider.dart';
import 'features/categories/category_screen.dart';
import 'features/collections/collection_detail_screen.dart';
import 'features/collections/collections_screen.dart';
import 'features/collections/create_collection_screen.dart';
import 'features/digest/digest_screen.dart';
import 'features/digest/notification_detail_screen.dart';
import 'features/digest/notifications_screen.dart';
import 'features/search/search_screen.dart';
import 'features/url_detail/url_detail_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/look_and_feel_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/subscription_screen.dart';
import 'features/settings/data_backup_screen.dart';
import 'features/settings/backup_preview_screen.dart';
import 'features/ask/ask_screen.dart';
import 'features/mindmap/mindmap_screen.dart';
import 'features/recap/recap_screen.dart';
import 'features/synthesis/synthesis_screen.dart';
import 'features/rediscover/rediscover_screen.dart';
import 'features/sources/sources_screen.dart';
import 'features/batch_save/batch_preview_screen.dart';
import 'core/config/app_environment.dart';
import 'core/services/entitlement_service.dart';
import 'core/services/url_save_notifications.dart';
import 'core/utils/url_extractor.dart';
import 'shared/widgets/app_snackbar.dart';
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
        return AddUrlScreen(initialUrl: initialUrl);
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
      path: '/url/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final siblings = state.extra is List<int> ? state.extra as List<int> : null;
        if (siblings != null && siblings.length > 1) {
          final index = siblings.indexOf(id);
          return UrlDetailPagerScreen(
            urlIds: siblings,
            initialIndex: index < 0 ? 0 : index,
          );
        }
        return UrlDetailScreen(urlId: id);
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
      path: '/settings/data-backup',
      builder: (context, state) => const DataBackupScreen(),
    ),
    GoRoute(
      path: '/settings/data-backup/preview',
      builder: (context, state) => const BackupPreviewScreen(),
    ),
    GoRoute(
      path: '/ask',
      builder: (context, state) {
        final source = state.extra is SavedUrl ? state.extra as SavedUrl : null;
        return AskScreen(initialSource: source);
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
      path: '/sources',
      builder: (context, state) => const SourcesScreen(),
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
  final BackupIntentService _backupIntentService = BackupIntentService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Record peak-hour histogram on cold start.
    unawaited(TagAnalyzer.recordAppOpen());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        DigestNotifications.init(
          onOpenNotification: (payload) {
            NotificationRouter.deliverPayload(rootNavigatorKey, payload);
          },
        ),
      );
      unawaited(DigestScheduler.reschedule());
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isar = ref.read(isarServiceProvider);

      // One-time local cleanup of stale auto-inferred categories (e.g. the
      // bogus "Design" tag on food saves). No network / AI cost.
      unawaited(() async {
        final repaired =
            await CategoryRepairService(isarService: isar).repairIfNeeded();
        if (repaired <= 0) return;
        ref.invalidate(urlStreamProvider);
        ref.invalidate(interestClusterThemesProvider);
      }());

      final embedding = ref.read(embeddingServiceProvider);
      if (embedding == null) return;
      final backfill = EmbeddingBackfillService(
        isarService: isar,
        embeddingService: embedding,
      );
      unawaited(() async {
        final n = await backfill.backfillIfNeeded();
        if (n <= 0) return;
        ref.invalidate(urlStreamProvider);
        ref.invalidate(interestClusterThemesProvider);
        ref.invalidate(askEmptySuggestionsProvider);
      }());
    });
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
      final ctx = _router.routerDelegate.navigatorKey.currentContext;
      if (ctx == null) return;

      if (extracted.hasMultiple) {
        // Multi-share → batch preview
        _router.push('/batch-save', extra: extracted.urls);
      } else {
        // Single share → capture immediately and let notifications carry the result.
        unawaited(
          _quickSave(
            extracted.urls.first,
            notifyCapture: true,
            returnAfterSave: true,
          ),
        );
      }
    });
  }

  Future<void> _quickSave(
    String url, {
    bool notifyCapture = false,
    bool returnAfterSave = false,
  }) async {
    final notifier = ref.read(addUrlProvider.notifier);
    final success = await notifier.saveUrl(url, notifyCapture: notifyCapture);
    final state = ref.read(addUrlProvider);
    final errorMsg = state.errorMessage;
    final aiLimitReached = state.aiLimitReached;
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
    if (state == AppLifecycleState.resumed) {
      unawaited(TagAnalyzer.recordAppOpen());
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
    _shareIntentSub.cancel();
    _backupIntentSub?.cancel();
    unawaited(_backupIntentService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          lightTheme = AppTheme.lightTheme(seed);
          darkTheme = useAmoledPalette
              ? AppTheme.amoledTheme(seed)
              : AppTheme.darkTheme(seed);
        }

        return MaterialApp.router(
          title: AppEnvironment.isDevContext ? 'Glimpse Dev' : 'Glimpse',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          scrollBehavior: const AppScrollBehavior(),
          routerConfig: _router,
          builder: (context, child) {
            if (!AppEnvironment.isDevContext) {
              return child ?? const SizedBox.shrink();
            }
            var content = child ?? const SizedBox.shrink();
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

/// Root screen selector: shows guided onboarding for new users, otherwise the
/// main app. Watches [hasSeenOnboardingProvider] so completing onboarding swaps
/// straight to [MainShell].
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);
    return hasSeenOnboarding ? const MainShell() : const OnboardingScreen();
  }
}
