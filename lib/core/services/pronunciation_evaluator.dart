import 'dart:math';

enum WordAccuracy {
  perfect, // Exact match or >= 90% similarity (Green)
  close,   // Minor difference or >= 65% similarity (Amber)
  missed,  // Missing from speech or < 65% similarity (Red)
  extra,   // Extra word spoken not in target (Purple/Gray)
}

enum PronunciationGrade {
  excellent, // >= 90%
  good,      // 75% - 89%
  fair,      // 50% - 74%
  needsWork, // < 50%
}

class WordEvaluation {
  final String targetWord;
  final String? spokenWord;
  final String? phonetic;
  final WordAccuracy accuracy;
  final double similarity;
  final String? tip;

  const WordEvaluation({
    required this.targetWord,
    this.spokenWord,
    this.phonetic,
    required this.accuracy,
    required this.similarity,
    this.tip,
  });
}

class PronunciationResult {
  final int overallScore; // 0 - 100
  final int accuracyScore;
  final int completenessScore;
  final int fluencyScore;
  final PronunciationGrade grade;
  final String feedbackVi;
  final List<WordEvaluation> words;
  final String originalText;
  final String recognizedText;

  const PronunciationResult({
    required this.overallScore,
    required this.accuracyScore,
    required this.completenessScore,
    required this.fluencyScore,
    required this.grade,
    required this.feedbackVi,
    required this.words,
    required this.originalText,
    required this.recognizedText,
  });

  bool get isPassed => overallScore >= 70;
}

class PronunciationEvaluator {
  static final PronunciationEvaluator instance = PronunciationEvaluator._internal();
  PronunciationEvaluator._internal();

  /// Đánh giá phát âm giữa câu/từ chuẩn [target] và câu/từ người dùng nói [spoken]
  PronunciationResult evaluate({
    required String target,
    required String spoken,
    required String languageCode,
    String? phonetic,
  }) {
    final cleanTarget = _cleanText(target);
    final cleanSpoken = _cleanText(spoken);

    if (cleanSpoken.isEmpty) {
      return PronunciationResult(
        overallScore: 0,
        accuracyScore: 0,
        completenessScore: 0,
        fluencyScore: 0,
        grade: PronunciationGrade.needsWork,
        feedbackVi: 'Không nhận diện được giọng nói. Hãy nói to và rõ hơn gần microphone.',
        words: _buildEmptyEvaluations(cleanTarget, languageCode),
        originalText: target,
        recognizedText: spoken,
      );
    }

    final isZh = languageCode.toUpperCase() == 'ZH';
    final targetTokens = isZh ? _tokenizeChinese(cleanTarget) : _tokenizeEnglish(cleanTarget);
    final spokenTokens = isZh ? _tokenizeChinese(cleanSpoken) : _tokenizeEnglish(cleanSpoken);

    final evaluations = <WordEvaluation>[];
    int matchedCount = 0;
    double totalSim = 0.0;

    // So khớp từng từ / chữ
    int spokenIndex = 0;
    for (int i = 0; i < targetTokens.length; i++) {
      final tWord = targetTokens[i];

      if (spokenIndex >= spokenTokens.length) {
        // Hết từ nói -> những từ còn lại bị bỏ sót
        evaluations.add(WordEvaluation(
          targetWord: tWord,
          spokenWord: null,
          accuracy: WordAccuracy.missed,
          similarity: 0.0,
          tip: 'Chưa phát âm từ này',
        ));
        continue;
      }

      // Tìm từ gần nhất trong cửa sổ nhỏ (+- 2 từ)
      int bestIdx = -1;
      double bestSim = -1.0;
      final maxLookahead = min(spokenTokens.length, spokenIndex + 3);

      for (int s = spokenIndex; s < maxLookahead; s++) {
        final sWord = spokenTokens[s];
        final sim = _calculateSimilarity(tWord, sWord);
        if (sim > bestSim) {
          bestSim = sim;
          bestIdx = s;
        }
      }

      if (bestSim >= 0.85) {
        evaluations.add(WordEvaluation(
          targetWord: tWord,
          spokenWord: spokenTokens[bestIdx],
          accuracy: WordAccuracy.perfect,
          similarity: bestSim,
          tip: 'Phát âm chuẩn',
        ));
        matchedCount++;
        totalSim += bestSim;
        spokenIndex = bestIdx + 1;
      } else if (bestSim >= 0.60) {
        evaluations.add(WordEvaluation(
          targetWord: tWord,
          spokenWord: spokenTokens[bestIdx],
          accuracy: WordAccuracy.close,
          similarity: bestSim,
          tip: 'Gần đúng, cần nhấn rõ âm hơn',
        ));
        matchedCount++;
        totalSim += bestSim;
        spokenIndex = bestIdx + 1;
      } else {
        evaluations.add(WordEvaluation(
          targetWord: tWord,
          spokenWord: spokenTokens[spokenIndex],
          accuracy: WordAccuracy.missed,
          similarity: bestSim.clamp(0.0, 1.0),
          tip: 'Phát âm chưa chính xác',
        ));
        spokenIndex++;
      }
    }

    // Thêm các từ thừa (nếu người dùng nói thừa)
    while (spokenIndex < spokenTokens.length) {
      evaluations.add(WordEvaluation(
        targetWord: '',
        spokenWord: spokenTokens[spokenIndex],
        accuracy: WordAccuracy.extra,
        similarity: 0.0,
        tip: 'Từ thừa không có trong mẫu',
      ));
      spokenIndex++;
    }

    // Tính điểm thành phần
    final completeness = targetTokens.isEmpty
        ? 1.0
        : (matchedCount / targetTokens.length).clamp(0.0, 1.0);
    final accuracy = targetTokens.isEmpty
        ? 1.0
        : (totalSim / targetTokens.length).clamp(0.0, 1.0);
    
    // Fluency tính dựa trên tỷ lệ từ thừa và nhịp độ
    final extraCount = spokenTokens.length - matchedCount;
    final fluencyPenalty = (extraCount > 0 ? extraCount * 0.05 : 0.0).clamp(0.0, 0.3);
    final fluency = (accuracy - fluencyPenalty).clamp(0.2, 1.0);

    final overall = ((accuracy * 0.5 + completeness * 0.3 + fluency * 0.2) * 100).round().clamp(0, 100);
    final accuracyScore = (accuracy * 100).round().clamp(0, 100);
    final completenessScore = (completeness * 100).round().clamp(0, 100);
    final fluencyScore = (fluency * 100).round().clamp(0, 100);

    final grade = _calculateGrade(overall);
    final feedback = _generateFeedbackVi(grade, overall, completenessScore, isZh);

    return PronunciationResult(
      overallScore: overall,
      accuracyScore: accuracyScore,
      completenessScore: completenessScore,
      fluencyScore: fluencyScore,
      grade: grade,
      feedbackVi: feedback,
      words: evaluations,
      originalText: target,
      recognizedText: spoken,
    );
  }

  PronunciationGrade _calculateGrade(int score) {
    if (score >= 90) return PronunciationGrade.excellent;
    if (score >= 75) return PronunciationGrade.good;
    if (score >= 50) return PronunciationGrade.fair;
    return PronunciationGrade.needsWork;
  }

  String _generateFeedbackVi(PronunciationGrade grade, int overall, int completeness, bool isZh) {
    if (grade == PronunciationGrade.excellent) {
      return isZh
          ? '🌟 Xuất sắc! Phát âm và thanh điệu rất chuẩn xác, khẩu hình tự nhiên.'
          : '🌟 Xuất sắc! Phát âm chuẩn người bản xứ, trọng âm và nối từ tuyệt vời.';
    } else if (grade == PronunciationGrade.good) {
      return isZh
          ? '👏 Rất tốt! Nghe hiểu rõ ràng, chú ý thêm thanh 3 và thanh 4 để mượt mà hơn.'
          : '👏 Rất tốt! Phát âm rõ ràng, lưu ý thêm âm đuôi (ending sounds) và trọng âm.';
    } else if (grade == PronunciationGrade.fair) {
      if (completeness < 70) {
        return '💪 Cố gắng nói đầy đủ các từ trong câu, đừng bỏ sót các âm tiết.';
      }
      return '💪 Đã nắm được ý chính! Hãy nghe lại phát âm mẫu và tập đọc chậm hơn một chút.';
    } else {
      return '🎯 Chưa nhận diện tốt. Bạn hãy ấn nút "Nghe phát âm mẫu" rồi thử lại nhé!';
    }
  }

  List<WordEvaluation> _buildEmptyEvaluations(String target, String lang) {
    final isZh = lang.toUpperCase() == 'ZH';
    final tokens = isZh ? _tokenizeChinese(target) : _tokenizeEnglish(target);
    return tokens.map((t) => WordEvaluation(
      targetWord: t,
      spokenWord: null,
      accuracy: WordAccuracy.missed,
      similarity: 0.0,
      tip: 'Chưa phát âm',
    )).toList();
  }

  List<String> _tokenizeEnglish(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _tokenizeChinese(String text) {
    final list = <String>[];
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isNotEmpty && !RegExp(r'[，。！？、“”’‘；：\s]').hasMatch(char)) {
        list.add(char);
      }
    }
    return list;
  }

  String _cleanText(String text) {
    return text.trim().toLowerCase();
  }

  /// Levenshtein distance similarity: 1.0 (exact match) -> 0.0 (completely different)
  double _calculateSimilarity(String s1, String s2) {
    final t1 = s1.trim().toLowerCase();
    final t2 = s2.trim().toLowerCase();
    if (t1 == t2) return 1.0;
    if (t1.isEmpty || t2.isEmpty) return 0.0;

    final distance = _levenshtein(t1, t2);
    final maxLen = max(t1.length, t2.length);
    return (1.0 - (distance / maxLen)).clamp(0.0, 1.0);
  }

  int _levenshtein(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = min(
          d[i - 1][j] + 1, // deletion
          min(
            d[i][j - 1] + 1, // insertion
            d[i - 1][j - 1] + cost, // substitution
          ),
        );
      }
    }
    return d[m][n];
  }
}
