import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _audioCache = {};
  bool _isTtsInitialized = false;

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _flutterTts.awaitSpeakCompletion(true);
      }
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('TTS init warning: $e');
    }
  }

  /// Phát âm văn bản (Hỗ trợ kép: Native TTS + Cloud Audio Fallback)
  Future<void> speak({
    required String text,
    required String languageCode,
    double rate = 0.45,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    await stop();

    final isChinese = languageCode.toUpperCase() == 'ZH';
    final targetLang = isChinese ? 'zh-CN' : 'en-US';
    final isDesktopWindows = !kIsWeb && Platform.isWindows;

    // Trên Windows, hệ điều hành mặc định không cài đặt sẵn giọng đọc tiếng Trung (SAPI5/OneCore).
    // Vì vậy với tiếng Trung trên Windows (hoặc khi cần phát âm tự nhiên), ưu tiên phát âm chuẩn chất lượng cao.
    if (isChinese && isDesktopWindows) {
      final playedOnline = await _speakOnline(
        text: cleanText,
        lang: 'zh-CN',
        slow: rate < 0.4,
      );
      if (playedOnline) return;
    }

    // Thử phát âm qua Native TTS
    try {
      await _initTts();
      await _flutterTts.setLanguage(targetLang);
      await _flutterTts.setSpeechRate(rate);
      final result = await _flutterTts.speak(cleanText);
      
      // Nếu flutter_tts trả về mã không thành công (hoặc silent trên desktop)
      if (result != 1 && isDesktopWindows) {
        await _speakOnline(
          text: cleanText,
          lang: isChinese ? 'zh-CN' : 'en',
          slow: rate < 0.4,
        );
      }
    } catch (e) {
      debugPrint('Native TTS error ($e), trying online fallback...');
      await _speakOnline(
        text: cleanText,
        lang: isChinese ? 'zh-CN' : 'en',
        slow: rate < 0.4,
      );
    }
  }

  /// Phát âm trực tuyến tự nhiên với bộ đệm bộ nhớ (in-memory cache)
  Future<bool> _speakOnline({
    required String text,
    required String lang,
    bool slow = false,
  }) async {
    try {
      final cacheKey = '${lang}_${slow}_$text';
      Uint8List? audioBytes = _audioCache[cacheKey];

      if (audioBytes == null) {
        // Cắt bớt văn bản nếu quá dài (Google TTS hỗ trợ tối đa ~200 ký tự cho mỗi cụm từ)
        final trimmedText = text.length > 200 ? text.substring(0, 200) : text;
        final url = Uri.parse(
          'https://translate.google.com/translate_tts?ie=UTF-8&q=${Uri.encodeComponent(trimmedText)}&tl=$lang&client=tw-ob',
        );

        final response = await http
            .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          audioBytes = response.bodyBytes;
          _audioCache[cacheKey] = audioBytes;
        }
      }

      if (audioBytes != null) {
        if (slow) {
          await _audioPlayer.setPlaybackRate(0.75);
        } else {
          await _audioPlayer.setPlaybackRate(1.0);
        }
        await _audioPlayer.play(
          BytesSource(audioBytes, mimeType: 'audio/mpeg'),
        );
        return true;
      }
    } catch (e) {
      debugPrint('Online TTS fallback error: $e');
    }
    return false;
  }

  /// Dừng mọi âm thanh đang phát
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }
}
