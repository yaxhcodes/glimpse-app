import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/providers/service_providers.dart';
import 'core/services/digest_notifications.dart';
import 'core/services/digest_scheduler.dart';
import 'core/services/notification_router.dart';
import 'core/services/tag_analyzer.dart';
import 'digest_callback.dart' show notificationActionCallback;
import 'core/services/embedding_backfill_service.dart';
import 'core/services/link_preview_service.dart';
import 'core/models/saved_url.dart';
import 'features/ask/ask_empty_suggestions_provider.dart';
import 'features/home/home_provider.dart';
import 'features/home/home_screen.dart';
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
import 'features/ask/ask_screen.dart';
import 'features/mindmap/mindmap_screen.dart';
import 'features/recap/recap_screen.dart';
import 'features/synthesis/synthesis_screen.dart';
import 'core/config/app_environment.dart';
import 'core/services/entitlement_service.dart';
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
    GoRoute(
      path: '/',
      builder: (context, state) => const MainShell(),
    ),
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
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/digest',
      builder: (context, state) => const DigestScreen(),
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
      path: '/ask',
      builder: (context, state) => const AskScreen(),
    ),
    GoRoute(
      path: '/mindmap',
      builder: (context, state) => const MindmapScreen(),
    ),
    GoRoute(
      path: '/recap',
      builder: (context, state) => const RecapScreen(),
    ),
    GoRoute(
      path: '/synthesis',
      builder: (context, state) {
        final urls = (state.extra as List<SavedUrl>?) ?? [];
        return SynthesisScreen(initialUrls: urls);
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
            final ctx = rootNavigatorKey.currentContext;
            if (ctx == null) return;
            NotificationRouter.openFromPayload(ctx, payload);
          },
          onAction: (action, payload) {
            final ctx = rootNavigatorKey.currentContext;
            if (ctx == null) return;
            if (action == 'open_link') {
              NotificationRouter.openFromPayload(ctx, payload);
            } else {
              unawaited(notificationActionCallback(action, payload));
            }
          },
        ),
      );
      unawaited(DigestScheduler.reschedule());
    });

    // Handle intent that launched the app (cold start)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then(_handleSharedMedia);

    // Handle intents while app is already running (warm start)
    _shareIntentSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleSharedMedia);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isar = ref.read(isarServiceProvider);
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

  void _handleSharedMedia(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final sharedText = files.first.path;
    final url = _extractUrl(sharedText);
    if (url == null) return;

    final normalizedUrl = LinkPreviewService.normalizeUrl(url);

    // Show a choice bottom sheet after a brief delay to let the UI settle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _router.routerDelegate.navigatorKey.currentContext;
      if (ctx == null) return;
      _showShareChoiceSheet(ctx, normalizedUrl);
    });
  }

  void _showShareChoiceSheet(BuildContext context, String url) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/unown_bookmark_transparent.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Save URL',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  url,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _quickSave(url);
                  },
                  icon: const Icon(Icons.bolt),
                  label: const Text('Quick Save'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _router.go('/add?url=${Uri.encodeComponent(url)}');
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Add Note & Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _quickSave(String url) async {
    final notifier = ref.read(addUrlProvider.notifier);
    final success = await notifier.saveUrl(url);
    final errorMsg = ref.read(addUrlProvider).errorMessage;
    notifier.reset();

    if (!mounted) return;
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'URL saved!'
            : errorMsg ?? 'Failed to save URL'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Pulls the first http(s) URL from a block of shared text.
  String? _extractUrl(String text) {
    final match = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0) ?? (text.contains('.') ? text.trim() : null);
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
        // Dynamic color: use the platform palette when accent is set to dynamic
        final bool useDynamic =
            accent == AppAccentColor.dynamic &&
            lightDynamic != null &&
            darkDynamic != null;

        final ThemeData lightTheme;
        final ThemeData darkTheme;

        final useAmoledPalette =
            amoledSurfaces && themeMode != ThemeMode.light;

        if (useDynamic) {
          lightTheme = AppTheme.fromColorScheme(lightDynamic);
          darkTheme = useAmoledPalette
              ? AppTheme.fromColorSchemeAmoled(darkDynamic)
              : AppTheme.fromColorScheme(darkDynamic);
        } else {
          final seed = accent.seedColor ?? const Color(0xFF6750A4);
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
