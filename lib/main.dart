import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app.dart';
import 'core/database/isar_service.dart';
import 'core/providers/service_providers.dart';
import 'core/services/subscription_service.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Pre-initialise Isar so the DB is ready before the first frame.
  final isarService = IsarService();
  await isarService.ensureInitialized();

  // Initialise RevenueCat SDK.
  await SubscriptionService.init();

  FlutterNativeSplash.remove();

  runApp(
    ProviderScope(
      overrides: [
        isarServiceProvider.overrideWithValue(isarService),
      ],
      child: const GlimpseApp(),
    ),
  );
}
