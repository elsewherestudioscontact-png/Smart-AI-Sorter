import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AiProvider { gemini, claude }

class SecureStorageService {
  static const _geminiKeyKey = 'gemini_api_key';
  static const _claudeKeyKey = 'claude_api_key';
  static const _providerKey = 'ai_provider';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveGeminiKey(String key) async =>
      _storage.write(key: _geminiKeyKey, value: key);

  Future<String?> getGeminiKey() async =>
      _storage.read(key: _geminiKeyKey);

  Future<bool> hasGeminiKey() async {
    final k = await getGeminiKey();
    return k != null && k.isNotEmpty;
  }

  Future<void> saveClaudeKey(String key) async =>
      _storage.write(key: _claudeKeyKey, value: key);

  Future<String?> getClaudeKey() async =>
      _storage.read(key: _claudeKeyKey);

  Future<bool> hasClaudeKey() async {
    final k = await getClaudeKey();
    return k != null && k.isNotEmpty;
  }

  Future<void> saveProvider(AiProvider provider) async =>
      _storage.write(key: _providerKey, value: provider.name);

  Future<AiProvider> getProvider() async {
    final val = await _storage.read(key: _providerKey);
    return val == AiProvider.claude.name ? AiProvider.claude : AiProvider.gemini;
  }

  // Legacy single-key used by old screens
  Future<String?> getApiKey() => getGeminiKey();
  Future<void> saveApiKey(String key) => saveGeminiKey(key);
  Future<void> deleteApiKey() => _storage.delete(key: _geminiKeyKey);

  Future<bool> hasApiKey() async =>
      (await hasGeminiKey()) || (await hasClaudeKey());

  Future<void> deleteAllKeys() async {
    await _storage.delete(key: _geminiKeyKey);
    await _storage.delete(key: _claudeKeyKey);
    await _storage.delete(key: _providerKey);
  }
}
