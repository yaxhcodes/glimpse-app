import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/dev_auth_service.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final authState = ref.watch(authControllerProvider);
    final authService = ref.watch(authServiceProvider);
    final isLoading = authState.isLoading;
    final isConfigured = authService.isConfigured;
    final isLocalDevAuth = authService is DevAuthService;

    ref.listen(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SvgPicture.asset(
                      'assets/glimpse.svg',
                      width: 54,
                      height: 54,
                      colorFilter: ColorFilter.mode(
                        cs.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Sign in to Glimpse',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your saved knowledge stays on this device.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: isConfigured && !isLoading
                        ? () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle()
                        : null,
                    icon: isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : Icon(
                            isLocalDevAuth
                                ? Icons.developer_mode_rounded
                                : Icons.g_mobiledata_rounded,
                            size: isLocalDevAuth ? 20 : 28,
                          ),
                    label: Text(
                      isLocalDevAuth
                          ? 'Continue in local dev'
                          : 'Continue with Google',
                    ),
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
                  if (Platform.isIOS || Platform.isMacOS) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isConfigured && !isLoading
                          ? () => ref
                                .read(authControllerProvider.notifier)
                                .signInWithApple()
                          : null,
                      icon: const Icon(Icons.apple_rounded),
                      label: const Text('Continue with Apple'),
                    ),
                  ],
                  if (!isConfigured && !isLocalDevAuth) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Authentication is not configured for this build.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
