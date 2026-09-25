import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService {
  static final SttService instance = SttService._internal();
  SttService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  double _lastSoundLevel = 0.0;

  // Stream controllers for sound level and listening status
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> _wordsController =
      StreamController<String>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();

  Stream<double> get soundLevelStream => _soundLevelController.stream;
  Stream<String> get wordsStream => _wordsController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get lastRecognizedWords => _lastRecognizedWords;
  double get lastSoundLevel => _lastSoundLevel;

  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;

    try {
      _isAvailable = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: kDebugMode,
      );
      _isInitialized = true;
      return _isAvailable;
    } catch (e) {
      debugPrint('STT initialize error (likely unsupported desktop platform): $e');
      _isAvailable = false;
      _isInitialized = true;
      return false;
    }
  }

  void _handleStatus(String status) {
    debugPrint('STT status: $status');
    final listening = status == 'listening';
    if (_isListening != listening) {
      _isListening = listening;
      _listeningController.add(_isListening);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint('STT error: ${error.errorMsg} - permanent: ${error.permanent}');
    _isListening = false;
    _listeningController.add(false);
  }

  /// Bắt đầu lắng nghe giọng nói với ngôn ngữ xác định:
  /// - `zh-CN` cho Tiếng Trung
  /// - `en-US` cho Tiếng Anh
  Future<bool> startListening({
    required String languageCode,
    required void Function(String recognizedText, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevel,
  }) async {
    final available = await initialize();
    if (!available) {
      debugPrint('STT not available on this platform or permission denied');
      return false;
    }

    try {
      final localeId = languageCode.toUpperCase() == 'ZH' ? 'zh_CN' : 'en_US';
      _lastRecognizedWords = '';

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastRecognizedWords = result.recognizedWords;
          _wordsController.add(_lastRecognizedWords);
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          localeId: localeId,
          cancelOnError: true,
          partialResults: true,
        ),
        onSoundLevelChange: (level) {
          // Normalize sound level from -100..10 to 0.0..1.0
          final normalized = ((level + 10) / 20.0).clamp(0.0, 1.0);
          _lastSoundLevel = normalized;
          _soundLevelController.add(normalized);
          onSoundLevel?.call(normalized);
        },
      );

      _isListening = true;
      _listeningController.add(true);
      return true;
    } catch (e) {
      debugPrint('STT startListening error: $e');
      _isListening = false;
      _listeningController.add(false);
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      if (_isListening) {
        await _speech.stop();
        _isListening = false;
        _listeningController.add(false);
      }
    } catch (e) {
      debugPrint('STT stopListening error: $e');
    }
  }

  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
      _isListening = false;
      _listeningController.add(false);
    } catch (e) {
      debugPrint('STT cancelListening error: $e');
    }
  }
}
