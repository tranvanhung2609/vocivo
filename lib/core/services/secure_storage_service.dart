import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();
  SecureStorageService._internal();

  final _secureStorage = const FlutterSecureStorage();

  static const _kGeminiApiKey = 'gemini_api_key';
  static const _kOpenAiApiKey = 'openai_api_key';
  static const _kActiveAiProvider = 'active_ai_provider';
  static const _kGeminiModel = 'gemini_model';

  Future<void> saveGeminiKey(String key) async {
    try {
      await _secureStorage.write(key: _kGeminiApiKey, value: key.trim());
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kGeminiApiKey, key.trim());
    }
  }

  Future<String?> getGeminiKey() async {
    try {
      final key = await _secureStorage.read(key: _kGeminiApiKey);
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kGeminiApiKey);
  }

  Future<void> saveOpenAiKey(String key) async {
    try {
      await _secureStorage.write(key: _kOpenAiApiKey, value: key.trim());
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOpenAiApiKey, key.trim());
    }
  }

  Future<String?> getOpenAiKey() async {
    try {
      final key = await _secureStorage.read(key: _kOpenAiApiKey);
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kOpenAiApiKey);
  }

  Future<String> getActiveProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveAiProvider) ?? 'gemini';
  }

  Future<void> setActiveProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveAiProvider, provider);
  }

  Future<String> getGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    final model = prefs.getString(_kGeminiModel) ?? 'gemini-flash-latest';
    // Migrate deprecated gemini-1.5 models to gemini-flash-latest
    if (model.contains('1.5') || model.isEmpty) {
      await prefs.setString(_kGeminiModel, 'gemini-flash-latest');
      return 'gemini-flash-latest';
    }
    return model;
  }

  Future<void> setGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGeminiModel, model);
  }
}
