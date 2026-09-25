import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _initTts() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setSpeechRate(0.45); // slightly slower for language learners
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> speak({
    required String text,
    required String languageCode,
    double rate = 0.45,
  }) async {
    try {
      await _initTts();
      final lang = languageCode.toUpperCase() == 'ZH' ? 'zh-CN' : 'en-US';
      await _flutterTts.setLanguage(lang);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
