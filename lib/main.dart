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
import 'core/services/subscription_service.dart';
import 'core/services/supabase_auth_service.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Package metadata and the local database are independent native calls.
  // Starting them together shortens the native-splash critical path.
  final isarService = IsarService();
  await Future.wait([
    AppEnvironment.initPackageInfo(),
    isarService.ensureInitialized(),
  ]);

  // Resolve the onboarding decision before the first frame so the root screen
  // renders correctly without a flash. New installs (empty library) see
  // onboarding; existing installs are left untouched.
  final onboardingFuture = OnboardingBootstrap.resolveHasSeenOnboarding(
    isarService,
  );

  // Generate/load the persistent proxy identity while the local onboarding
  // decision is being resolved. Both must finish before providers are built.
  final userIdFuture = AiProxyConfig.initUserId();
  final hasSeenOnboarding = await onboardingFuture;
  await userIdFuture;

  // These SDKs are independent once environment and proxy identity are ready.
  // Initialize them concurrently instead of serially blocking the first frame.
  debugPrint('[Startup] Initializing App Check');
  await Future.wait([
    AppAttestationService.initialize(),
    SupabaseAuthService.initializeSupabaseClient(),
    SubscriptionService.init(),
    Workmanager().initialize(digestCallbackDispatcher),
  ]);
  debugPrint(
    '[Startup] App Check ready=${AppAttestationService.isAvailable} '
    'error=${AppAttestationService.initError}',
  );

  unawaited(BackupScheduler.reschedule());

  FlutterNativeSplash.remove();

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
}
