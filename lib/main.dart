import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'digest_callback.dart';
import 'core/services/backup_scheduler.dart';
import 'core/config/app_environment.dart';
import 'core/database/isar_service.dart';
import 'core/providers/dev_simulation_providers.dart';
import 'core/providers/service_providers.dart';
import 'features/onboarding/onboarding_bootstrap.dart';
import 'core/services/ai/app_attestation_service.dart';
import 'core/services/ai_proxy_config.dart';
import 'core/services/digest_scheduler.dart';
import 'core/services/subscription_service.dart';
import 'core/services/supabase_auth_service.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Only services required to choose the first screen belong on the native
  // splash path. Everything else starts after Flutter has painted once.
  final isarService = IsarService();
  await Future.wait([
    AppEnvironment.initPackageInfo(),
    isarService.ensureInitialized(),
    AiProxyConfig.initUserId(),
    SupabaseAuthService.initializeSupabaseClient(),
  ]);

  // Resolve the onboarding decision before the first frame so the root screen
  // renders correctly without a flash. New installs (empty library) see
  // onboarding; existing installs are left untouched.
  final onboardingFuture = OnboardingBootstrap.resolveHasSeenOnboarding(
    isarService,
  );

  final hasSeenOnboarding = await onboardingFuture;

  runApp(
    ProviderScope(
      overrides: [
        isarServiceProvider.overrideWithValue(isarService),
        hasSeenOnboardingProvider.overrideWith(
          (ref) => HasSeenOnboardingNotifier(initial: hasSeenOnboarding),
        ),
      ],
      child: const GlimpseApp(),
    ),
  );

  // Delaying SDKs that are irrelevant to capture lets a cold share intent
  // reach the compact save sheet without competing with billing or background
  // workers. The root gate removes the native splash only after the first
  // destination screen has completed a frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredServices());
  });
}

Future<void> _initializeDeferredServices() async {
  await Future<void>.delayed(const Duration(milliseconds: 750));

  unawaited(AppAttestationService.initialize());

  await SubscriptionService.init();
  final currentUser = SupabaseAuthService.instance.currentUser;
  if (currentUser != null) {
    await SubscriptionService.instance.logInWithAuthenticatedUser(
      currentUser.id,
    );
  }

  try {
    await Workmanager().initialize(digestCallbackDispatcher);
    await Future.wait([
      DigestScheduler.ensureScheduled(),
      BackupScheduler.ensureScheduled(),
    ]);
  } catch (error, stackTrace) {
    debugPrint('[Startup] Deferred background services failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
