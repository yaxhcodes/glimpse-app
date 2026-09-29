import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/dev_auth_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../onboarding/onboarding_stages.dart';

/// Sign-in, drawn as the closing chapter of onboarding: the same painted
/// stage, editorial headline and primary button, in the app's own theme.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.isOnboardingEntry = false});

  /// True when the user arrives straight from onboarding; otherwise they
  /// are coming back after signing out.
  final bool isOnboardingEntry;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _submitting = false;
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://www.getglimpse.xyz/privacy',
  );

  /// How far the painting runs on under the headline before it has fully
  /// faded, matching the onboarding welcome chapter.
  static const _artOverlap = 96.0;

  /// The least of the painting that stays visible before the text scrolls
  /// instead (small phones, large text).
  static const _minArt = 120.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final authState = ref.watch(authControllerProvider);
    final accountHint = ref.watch(googleAccountHintProvider).valueOrNull;
    final authService = ref.watch(authServiceProvider);
    final isLoading = authState.isLoading || _submitting;
    final isConfigured = authService.isConfigured;
    final isLocalDevAuth = authService is DevAuthService;

    ref.listen(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null) return;
      if (_submitting && mounted) {
        setState(() => _submitting = false);
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
    ref.listen(authControllerProvider, (previous, next) {
      final signedIn = next.valueOrNull != null;
      final wasLoading = previous?.isLoading ?? false;
      if (!signedIn || !wasLoading) return;
      AppHaptics.play(AppHaptics.success);
    });

    final bodyStyle = tt.bodyLarge?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.45,
    );
    final controller = ref.read(authControllerProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The painting sits under the status bar: light icons there.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
      ),
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: LayoutBuilder(
              builder: (context, c) {
                final padding = MediaQuery.paddingOf(context);
                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            bottom: -_artOverlap,
                            // The example reel's still life: the story
                            // ends on the thing the user just learned to save.
                            child: const OnboardingWelcomeArt(
                              active: true,
                              image: OnboardingArt.reel,
                              alignment: Alignment(-.2, 0),
                              swell: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(
                          0,
                          c.maxHeight - padding.top - _minArt,
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          24,
                          24,
                          8 + padding.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                widget.isOnboardingEntry
                                    ? l.authTitleFirstRun
                                    : l.authTitleReturning,
                                style: AppTypography.editorial(
                                  tt.headlineLarge,
                                  color: cs.onSurface,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -.6,
                                  height: 1.08,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(l.authBody, style: bodyStyle),
                            const SizedBox(height: 28),
                            _AuthActions(
                              accountHint: isLocalDevAuth ? null : accountHint,
                              isConfigured: isConfigured,
                              isLoading: isLoading,
                              isLocalDevAuth: isLocalDevAuth,
                              onContinueHint: () => unawaited(
                                _startAuthentication(
                                  controller.signInWithGoogleHint,
                                ),
                              ),
                              onContinueGoogle: () => unawaited(
                                _startAuthentication(
                                  controller.signInWithGoogle,
                                ),
                              ),
                              onContinueApple: () => unawaited(
                                _startAuthentication(
                                  controller.signInWithApple,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: TextButton(
                                onPressed: _openPrivacyPolicy,
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.onSurfaceVariant,
                                  textStyle: tt.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(l.authPrivacy),
                              ),
                            ),
                            if (isLocalDevAuth)
                              Text(
                                'Local dev session. Supabase is not configured for this build.',
                                textAlign: TextAlign.center,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            if (!isConfigured && !isLocalDevAuth)
                              Text(
                                'Authentication is not configured for this build.',
                                textAlign: TextAlign.center,
                                style: tt.bodySmall?.copyWith(color: cs.error),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final launched = await launchUrl(
      _privacyPolicyUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.authPrivacyError),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _startAuthentication(Future<void> Function() action) async {
    if (_submitting) return;
    unawaited(AppHaptics.play(AppHaptics.confirm));
    setState(() => _submitting = true);
    await action();
    if (!mounted || ref.read(authControllerProvider).valueOrNull != null) {
      return;
    }
    setState(() => _submitting = false);
  }
}

class _AuthActions extends StatelessWidget {
  const _AuthActions({
    required this.accountHint,
    required this.isConfigured,
    required this.isLoading,
    required this.isLocalDevAuth,
    required this.onContinueHint,
    required this.onContinueGoogle,
    required this.onContinueApple,
  });

  final GoogleAccountHint? accountHint;
  final bool isConfigured;
  final bool isLoading;
  final bool isLocalDevAuth;
  final VoidCallback onContinueHint;
  final VoidCallback onContinueGoogle;
  final VoidCallback onContinueApple;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final hint = accountHint;
    // While a sign-in runs the primary button keeps its colour and shows
    // progress; repeat taps are ignored upstream.
    final secondaryEnabled = isConfigured && !isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null) ...[
          _AccountHintButton(
            hint: hint,
            loading: isLoading,
            onPressed: isConfigured ? onContinueHint : null,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: secondaryEnabled ? onContinueGoogle : null,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: cs.onSurfaceVariant,
            ),
            child: Text(l.authAnotherGoogle),
          ),
        ] else
          FilledButton.icon(
            key: const ValueKey('auth-primary-cta'),
            onPressed: isConfigured ? onContinueGoogle : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: isLoading
                ? _Progress(color: cs.onPrimary)
                : isLocalDevAuth
                ? const AppIcon(AppIcons.code, size: 20)
                : const _GoogleMark(),
            label: Text(
              isLocalDevAuth ? 'Continue in local dev' : l.authContinueGoogle,
            ),
          ),
        if (Platform.isIOS || Platform.isMacOS) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: secondaryEnabled ? onContinueApple : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const AppIcon(AppIcons.apple, size: 20),
            label: Text(l.authContinueApple),
          ),
        ],
      ],
    );
  }
}

/// The one-tap path for the Google account last used on this phone: the
/// onboarding CTA, carrying who it will sign in as.
class _AccountHintButton extends StatelessWidget {
  const _AccountHintButton({
    required this.hint,
    required this.loading,
    required this.onPressed,
  });

  final GoogleAccountHint hint;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = hint.displayName?.trim();
    final title = name == null || name.isEmpty
        ? l.authContinueGoogle
        : l.authContinueAs(name);
    return FilledButton(
      key: const ValueKey('auth-primary-cta'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      ),
      child: Row(
        children: [
          _GoogleAvatar(hint: hint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  hint.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: .72),
                  ),
                ),
              ],
            ),
          ),
          if (loading) ...[
            const SizedBox(width: 12),
            _Progress(color: cs.onPrimary),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: ExpressiveLoadingIndicator(size: 18, color: color),
    );
  }
}

/// Google's mark always sits on white, whatever the button colour.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset('assets/brands/google.svg', width: size * .6),
    );
  }
}

class _GoogleAvatar extends StatelessWidget {
  const _GoogleAvatar({required this.hint});

  final GoogleAccountHint hint;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final photoUrl = hint.photoUrl;
    final cs = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: cs.onPrimary.withValues(alpha: .12),
      child: Center(
        child: Text(
          _initial(hint),
          style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700),
        ),
      ),
    );
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: photoUrl == null
                  ? fallback
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: DecoratedBox(
              // A ring in the button colour cuts the badge out of the photo.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 1.5),
              ),
              child: const _GoogleMark(size: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _initial(GoogleAccountHint hint) {
    final source = hint.displayName?.trim().isNotEmpty == true
        ? hint.displayName!.trim()
        : hint.email.trim();
    return source.isEmpty ? 'G' : source.substring(0, 1).toUpperCase();
  }
}
