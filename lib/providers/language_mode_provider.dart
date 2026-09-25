import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageModeNotifier extends Notifier<String> {
  static const _kPrefKey = 'selected_language_mode';

  @override
  String build() {
    _loadSavedMode();
    return 'ZH'; // Default to Chinese as per dual focus or English
  }

  Future<void> _loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefKey);
    if (saved != null && (saved == 'EN' || saved == 'ZH')) {
      state = saved;
    }
  }

  Future<void> setLanguage(String code) async {
    if (state == code) return;
    state = code.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, state);
  }

  void toggle() {
    setLanguage(state == 'ZH' ? 'EN' : 'ZH');
  }
}

final languageModeProvider = NotifierProvider<LanguageModeNotifier, String>(() {
  return LanguageModeNotifier();
});
