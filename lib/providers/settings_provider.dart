import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/secure_storage_service.dart';

@immutable
class SettingsState {
  final String geminiApiKey;
  final String openAiApiKey;
  final String activeProvider; // 'gemini' or 'openai'
  final String geminiModel;
  final ThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final bool isLoaded;

  const SettingsState({
    this.geminiApiKey = '',
    this.openAiApiKey = '',
    this.activeProvider = 'gemini',
    this.geminiModel = 'gemini-flash-latest',
    this.themeMode = ThemeMode.system,
    this.hasCompletedOnboarding = false,
    this.isLoaded = false,
  });

  bool get hasGeminiKey => geminiApiKey.isNotEmpty;
  bool get hasOpenAiKey => openAiApiKey.isNotEmpty;

  SettingsState copyWith({
    String? geminiApiKey,
    String? openAiApiKey,
    String? activeProvider,
    String? geminiModel,
    ThemeMode? themeMode,
    bool? hasCompletedOnboarding,
    bool? isLoaded,
  }) {
    return SettingsState(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      activeProvider: activeProvider ?? this.activeProvider,
      geminiModel: geminiModel ?? this.geminiModel,
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _kThemeModeKey = 'app_theme_mode';
  static const _kOnboardingKey = 'app_has_completed_onboarding';

  @override
  SettingsState build() {
    Future.microtask(() => loadSettings());
    return const SettingsState();
  }

  Future<void> loadSettings() async {
    final geminiKey = await SecureStorageService.instance.getGeminiKey() ?? '';
    final openAiKey = await SecureStorageService.instance.getOpenAiKey() ?? '';
    final provider = await SecureStorageService.instance.getActiveProvider();
    final model = await SecureStorageService.instance.getGeminiModel();

    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_kThemeModeKey);
    final onboardingDone = prefs.getBool(_kOnboardingKey) ?? false;

    ThemeMode mode = ThemeMode.system;
    if (themeString == 'light') mode = ThemeMode.light;
    if (themeString == 'dark') mode = ThemeMode.dark;

    state = SettingsState(
      geminiApiKey: geminiKey,
      openAiApiKey: openAiKey,
      activeProvider: provider,
      geminiModel: model,
      themeMode: mode,
      hasCompletedOnboarding: onboardingDone,
      isLoaded: true,
    );
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
    state = state.copyWith(hasCompletedOnboarding: true);
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, false);
    state = state.copyWith(hasCompletedOnboarding: false);
  }

  Future<void> setGeminiApiKey(String key) async {
    await SecureStorageService.instance.saveGeminiKey(key);
    state = state.copyWith(geminiApiKey: key);
  }

  Future<void> setOpenAiApiKey(String key) async {
    await SecureStorageService.instance.saveOpenAiKey(key);
    state = state.copyWith(openAiApiKey: key);
  }

  Future<void> setActiveProvider(String provider) async {
    await SecureStorageService.instance.setActiveProvider(provider);
    state = state.copyWith(activeProvider: provider);
  }

  Future<void> setGeminiModel(String model) async {
    await SecureStorageService.instance.setGeminiModel(model);
    state = state.copyWith(geminiModel: model);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
    state = state.copyWith(themeMode: mode);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
