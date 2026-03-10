import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/services/link_preview_service.dart';
import 'core/models/saved_url.dart';
import 'features/home/home_screen.dart';
import 'features/add_url/add_url_screen.dart';
import 'features/add_url/add_url_provider.dart';
import 'features/categories/category_screen.dart';
import 'features/search/search_screen.dart';
import 'features/url_detail/url_detail_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/look_and_feel_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/api_keys_screen.dart';
import 'features/ask/ask_screen.dart';
import 'features/recap/recap_screen.dart';
import 'features/synthesis/synthesis_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_provider.dart';

/// Provider that holds a URL received via Android share intent.
final sharedUrlProvider = StateProvider<String?>((ref) => null);

// GoRouter configuration — needs to be accessible for programmatic navigation
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
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
      path: '/settings/api-keys',
      builder: (context, state) => const ApiKeysScreen(),
    ),
    GoRoute(
      path: '/ask',
      builder: (context, state) => const AskScreen(),
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

class _GlimpseAppState extends ConsumerState<GlimpseApp> {
  late StreamSubscription _shareIntentSub;

  @override
  void initState() {
    super.initState();

    // Handle intent that launched the app (cold start)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then(_handleSharedMedia);

    // Handle intents while app is already running (warm start)
    _shareIntentSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleSharedMedia);
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Save URL',
                  style: Theme.of(ctx).textTheme.titleLarge,
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
  void dispose() {
    _shareIntentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Dynamic color: use the platform palette when accent is set to dynamic
        final bool useDynamic =
            accent == AppAccentColor.dynamic &&
            lightDynamic != null &&
            darkDynamic != null;

        final ThemeData lightTheme;
        final ThemeData darkTheme;

        if (useDynamic) {
          lightTheme = AppTheme.fromColorScheme(lightDynamic);
          darkTheme = AppTheme.fromColorScheme(darkDynamic);
        } else {
          final seed = accent.seedColor ?? const Color(0xFF6750A4);
          lightTheme = AppTheme.lightTheme(seed);
          darkTheme = AppTheme.darkTheme(seed);
        }

        return MaterialApp.router(
          title: 'Glimpse',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          routerConfig: _router,
        );
      },
    );
  }
}
