import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/dev_auth_service.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import 'auth_backdrop.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.isOnboardingEntry = false});

  final bool isOnboardingEntry;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _introVisible = false;
  bool _exiting = false;
  bool _submitting = false;
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://www.getglimpse.xyz/privacy',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _introVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() => _exiting = true);
    });

    final darkScheme = cs.brightness == Brightness.dark
        ? cs
        : ColorScheme.fromSeed(
            seedColor: cs.primary,
            brightness: Brightness.dark,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
      ),
      child: Theme(
        data: theme.copyWith(
          colorScheme: darkScheme.copyWith(
            primary: const Color(0xFFB8CBB0),
            onSurface: const Color(0xFFF3EEDC),
            onSurfaceVariant: const Color(0xFFC4C5BA),
          ),
        ),
        child: Builder(
          builder: (context) {
            final localTheme = Theme.of(context);
            final localCs = localTheme.colorScheme;
            return Scaffold(
              backgroundColor: const Color(0xFF050505),
              body: AnimatedOpacity(
                opacity: _exiting ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Stack(
                  children: [
                    const Positioned.fill(child: AuthBackdrop()),
                    SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 390;
                          final identity = _IdentityBlock(
                            logo: _animatedLogo(size: compact ? 112 : 128),
                            isOnboardingEntry: widget.isOnboardingEntry,
                          );
                          final actions = _ActionBlock(
                            accountHint: accountHint,
                            isConfigured: isConfigured,
                            isLoading: isLoading,
                            isLocalDevAuth: isLocalDevAuth,
                            onContinueHint: () => unawaited(
                              _startAuthentication(
                                ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogleHint,
                              ),
                            ),
                            onContinueGoogle: () => unawaited(
                              _startAuthentication(
                                ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogle,
                              ),
                            ),
                            onContinueApple: () => unawaited(
                              _startAuthentication(
                                ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithApple,
                              ),
                            ),
                            onPrivacyPolicy: _openPrivacyPolicy,
                          );

                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 478),
                              child: CustomScrollView(
                                slivers: [
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        compact ? 24 : 32,
                                        24,
                                        compact ? 24 : 32,
                                        12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Glimpse',
                                            style: localTheme
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: localCs.onSurface,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.6,
                                                ),
                                          ),
                                          const Spacer(),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 32,
                                            ),
                                            child: identity,
                                          ),
                                          const Spacer(),
                                          actions,
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _animatedLogo({required double size}) {
    return AnimatedOpacity(
      opacity: _introVisible ? 1 : 0,
      duration: const Duration(milliseconds: 330),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: _introVisible ? 1 : 0.96,
        duration: const Duration(milliseconds: 330),
        curve: Curves.easeOutCubic,
        child: Semantics(
          image: true,
          label: 'Glimpse logo',
          child: Image.asset(
            AppAssets.logo,
            width: size,
            height: size,
            fit: BoxFit.contain,
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
        const SnackBar(
          content: Text('Could not open Privacy Policy.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _startAuthentication(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await action();
    if (!mounted || ref.read(authControllerProvider).valueOrNull != null) {
      return;
    }
    setState(() => _submitting = false);
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.logo, required this.isOnboardingEntry});

  final Widget logo;
  final bool isOnboardingEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        logo,
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Good finds.\n'),
                TextSpan(
                  text: 'Never forgotten.',
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
            style: theme.textTheme.displaySmall?.copyWith(
              color: cs.onSurface,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
              height: 1.12,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          isOnboardingEntry
              ? 'Save links. Find the ideas inside.\nBuild a library that stays with you.'
              : 'Save links. Find the ideas inside.\nCome back to what matters.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ActionBlock extends StatelessWidget {
  const _ActionBlock({
    required this.accountHint,
    required this.isConfigured,
    required this.isLoading,
    required this.isLocalDevAuth,
    required this.onContinueHint,
    required this.onContinueGoogle,
    required this.onContinueApple,
    required this.onPrivacyPolicy,
  });

  final GoogleAccountHint? accountHint;
  final bool isConfigured;
  final bool isLoading;
  final bool isLocalDevAuth;
  final VoidCallback onContinueHint;
  final VoidCallback onContinueGoogle;
  final VoidCallback onContinueApple;
  final VoidCallback onPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthActions(
          accountHint: accountHint,
          isConfigured: isConfigured,
          isLoading: isLoading,
          isLocalDevAuth: isLocalDevAuth,
          onContinueHint: onContinueHint,
          onContinueGoogle: onContinueGoogle,
          onContinueApple: onContinueApple,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onPrivacyPolicy,
          style: TextButton.styleFrom(
            foregroundColor: cs.primary.withValues(alpha: 0.9),
            textStyle: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          child: const Text('Privacy Policy'),
        ),
        if (isLocalDevAuth) ...[
          const SizedBox(height: 10),
          Text(
            'Local dev session. Supabase is not configured for this build.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        if (!isConfigured && !isLocalDevAuth) ...[
          const SizedBox(height: 12),
          Text(
            'Authentication is not configured for this build.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
          ),
        ],
      ],
    );
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
    final canSubmit = isConfigured && !isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accountHint != null && !isLocalDevAuth) ...[
          _AccountHintButton(
            hint: accountHint!,
            enabled: canSubmit,
            loading: isLoading,
            onPressed: onContinueHint,
          ),
          const SizedBox(height: 4),
        ],
        if (accountHint != null && !isLocalDevAuth)
          TextButton(
            onPressed: canSubmit ? onContinueGoogle : null,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: const Text('Use another Google account'),
          )
        else
          _AuthPillButton(
            label: isLocalDevAuth
                ? 'Continue in local dev'
                : 'Continue with Google',
            leading: isLocalDevAuth
                ? const Icon(AppIcons.code, size: 22)
                : SvgPicture.asset('assets/brands/google.svg', width: 24),
            enabled: canSubmit,
            loading: isLoading && (accountHint == null || isLocalDevAuth),
            onPressed: onContinueGoogle,
            primary: true,
          ),
        if (Platform.isIOS || Platform.isMacOS) ...[
          const SizedBox(height: 12),
          _AuthPillButton(
            label: 'Continue with Apple',
            leading: const Icon(AppIcons.apple, size: 22),
            enabled: canSubmit,
            loading: false,
            onPressed: onContinueApple,
          ),
        ],
      ],
    );
  }
}

class _AccountHintButton extends StatelessWidget {
  const _AccountHintButton({
    required this.hint,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final GoogleAccountHint hint;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = hint.displayName?.trim();
    final accountName = name == null || name.isEmpty ? null : name;
    final title = accountName == null
        ? 'Continue with Google'
        : 'Continue as $accountName';
    final accountLine = hint.email;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Continue with ${hint.email}',
      child: _PressScale(
        enabled: enabled,
        child: Material(
          color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            canRequestFocus: enabled,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _GoogleAvatar(hint: hint),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.surface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.surface.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loading) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: ExpressiveLoadingIndicator(
                          size: 18,
                          color: cs.surface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPillButton extends StatelessWidget {
  const _AuthPillButton({
    required this.label,
    required this.leading,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    this.primary = false,
  });

  final bool primary;
  final String label;
  final Widget leading;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: _PressScale(
        enabled: enabled,
        child: OutlinedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: ExpressiveLoadingIndicator(
                    size: 18,
                    color: primary ? cs.surface : cs.onSurface,
                  ),
                )
              : leading,
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(60),
            backgroundColor: primary ? cs.onSurface : null,
            foregroundColor: primary ? cs.surface : cs.onSurface,
            disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.38)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }
}

class _GoogleAvatar extends StatelessWidget {
  const _GoogleAvatar({required this.hint});

  final GoogleAccountHint hint;

  @override
  Widget build(BuildContext context) {
    final photoUrl = hint.photoUrl;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: photoUrl == null
                  ? ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Center(
                        child: Text(
                          _initial(hint),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Center(
                          child: Text(
                            _initial(hint),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                border: Border.all(color: cs.onSurface, width: 1.4),
              ),
              child: Center(
                child: SvgPicture.asset('assets/brands/google.svg', width: 13),
              ),
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
