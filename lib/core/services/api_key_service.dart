import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores and retrieves API keys using the platform keystore.
class ApiKeyService {
  static const _geminiKey = 'api_key_gemini';
  static const _voyageKey = 'api_key_voyage';

  final FlutterSecureStorage _storage;

  ApiKeyService() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> getGeminiKey() => _storage.read(key: _geminiKey);
  Future<void> setGeminiKey(String key) => _storage.write(key: _geminiKey, value: key);
  Future<void> deleteGeminiKey() => _storage.delete(key: _geminiKey);

  Future<String?> getVoyageKey() => _storage.read(key: _voyageKey);
  Future<void> setVoyageKey(String key) => _storage.write(key: _voyageKey, value: key);
  Future<void> deleteVoyageKey() => _storage.delete(key: _voyageKey);

  Future<bool> hasGeminiKey() async {
    final key = await getGeminiKey();
    return key != null && key.isNotEmpty;
  }

  Future<bool> hasVoyageKey() async {
    final key = await getVoyageKey();
    return key != null && key.isNotEmpty;
  }
}
