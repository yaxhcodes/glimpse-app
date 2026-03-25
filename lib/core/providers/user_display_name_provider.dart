import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUserDisplayName = 'glimpse_user_display_name';

/// Optional first name / display string for personalized greetings (Settings).
final userDisplayNameProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getString(_kUserDisplayName);
  if (v == null || v.trim().isEmpty) return null;
  return v.trim();
});

Future<void> setUserDisplayName(String? name) async {
  final prefs = await SharedPreferences.getInstance();
  if (name == null || name.trim().isEmpty) {
    await prefs.remove(_kUserDisplayName);
  } else {
    await prefs.setString(_kUserDisplayName, name.trim());
  }
}
