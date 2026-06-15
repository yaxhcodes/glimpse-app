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

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await AppEnvironment.initPackageInfo();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Pre-initialise Isar so the DB is ready before the first frame.
  final isarService = IsarService();
  await isarService.ensureInitialized();

  // Resolve the onboarding decision before the first frame so the root screen
  // renders correctly without a flash. New installs (empty library) see
  // onboarding; existing installs are left untouched.
  final hasSeenOnboarding =
      await OnboardingBootstrap.resolveHasSeenOnboarding(isarService);

  // App attestation protects the no-login AI proxy without putting any
  // shared secret in the Flutter client.
  debugPrint('[Startup] Initializing App Check');
  await AppAttestationService.initialize();
  debugPrint(
    '[Startup] App Check ready=${AppAttestationService.isAvailable} '
    'error=${AppAttestationService.initError}',
  );

  // Generate or load the persistent AI proxy user ID before any
  // service reads AiProxyConfig.enabled. This must complete before
  // GeminiService / EmbeddingService are constructed.
  await AiProxyConfig.initUserId();

  // Initialise RevenueCat SDK. Never throws — falls back to free tier
  // if the platform key is missing or configure() fails.
  await SubscriptionService.init();

  await Workmanager().initialize(digestCallbackDispatcher);
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
