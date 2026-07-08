import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

const _kUserDisplayName = 'glimpse_user_display_name';

/// Display string for personalized greetings.
///
/// Legacy local overrides are still honored for restored backups and existing
/// installs. New signed-in users naturally fall back to their account name.
final userDisplayNameProvider = FutureProvider<String?>((ref) async {
  final accountName = ref.watch(authControllerProvider).valueOrNull?.displayName;
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getString(_kUserDisplayName);
  final localName = v?.trim();
  if (localName != null && localName.isNotEmpty) return localName;

  if (accountName == null || accountName.trim().isEmpty) return null;
  return accountName.trim();
});
