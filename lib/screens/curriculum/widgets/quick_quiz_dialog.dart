import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/curriculum_provider.dart';

class QuickQuizDialog extends ConsumerStatefulWidget {
  final String unitId;
  final String unitTitle;
  final List<VocabularyItem> words;

  const QuickQuizDialog({
    super.key,
    required this.unitId,
    required this.unitTitle,
    required this.words,
  });

  static Future<void> show(
    BuildContext context, {
    required String unitId,
    required String unitTitle,
    required List<VocabularyItem> words,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuickQuizDialog(
        unitId: unitId,
        unitTitle: unitTitle,
        words: words,
      ),
    );
  }

  @override
  ConsumerState<QuickQuizDialog> createState() => _QuickQuizDialogState();
}

class _QuizQuestion {
  final VocabularyItem targetWord;
  final String questionText;
  final List<String> options;
  final int correctIndex;

  _QuizQuestion({
    required this.targetWord,
    required this.questionText,
    required this.options,
    required this.correctIndex,
  });
}

class _QuickQuizDialogState extends ConsumerState<QuickQuizDialog> {
  late List<_QuizQuestion> _questions;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _answered = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _buildQuestions();
  }

  void _buildQuestions() {
    final rng = Random();
    final wordsList = List<VocabularyItem>.from(widget.words)..shuffle(rng);
    final count = min(5, wordsList.length);

    _questions = [];
    for (int i = 0; i < count; i++) {
      final target = wordsList[i];
      final isMeaningQuestion = rng.nextBool();

      // Collect distractors
      final otherWords = widget.words.where((w) => w.word != target.word).toList()..shuffle(rng);

      final List<String> options = [];
      final int correctIdx = rng.nextInt(min(4, otherWords.length + 1));

      if (isMeaningQuestion) {
        // Question: what does this word mean?
        final distractors = otherWords.map((w) => w.meaningVi).take(3).toList();
        for (int j = 0; j < 4; j++) {
          if (j == correctIdx || distractors.isEmpty) {
            options.add(target.meaningVi);
          } else {
            options.add(distractors.removeAt(0));
          }
        }
        _questions.add(_QuizQuestion(
          targetWord: target,
          questionText: 'Nghĩa của từ "${target.word}" là gì?',
          options: options,
          correctIndex: correctIdx,
        ));
      } else {
        // Question: what word matches this meaning?
        final distractors = otherWords.map((w) => w.word).take(3).toList();
        for (int j = 0; j < 4; j++) {
          if (j == correctIdx || distractors.isEmpty) {
            options.add(target.word);
          } else {
            options.add(distractors.removeAt(0));
          }
        }
        _questions.add(_QuizQuestion(
          targetWord: target,
          questionText: 'Từ nào có nghĩa là:\n"${target.meaningVi}"?',
          options: options,
          correctIndex: correctIdx,
        ));
      }
    }
  }

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswerIndex = index;
      _answered = true;
      if (index == _questions[_currentIndex].correctIndex) {
        _score++;
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _answered = false;
      });
    } else {
      // Completed quiz
      final percent = ((_score / _questions.length) * 100).round();
      if (percent >= 60) {
        ref.read(curriculumProvider.notifier).markUnitCompleted(
              widget.unitId,
              score: percent,
            );
      }
      setState(() => _isFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isFinished ? _buildResultView(isDark) : _buildQuestionView(isDark),
        ),
      ),
    );
  }

  Widget _buildQuestionView(bool isDark) {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top header & progress bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu ${_currentIndex + 1}/${_questions.length}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.primaryEnglish,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            color: AppColors.primaryEnglish,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 24),

        // Question Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Text(
              q.questionText,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Options
        ...List.generate(q.options.length, (idx) {
          final optionText = q.options[idx];
          Color? bgColor;
          Color? borderColor;
          Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

          if (_answered) {
            if (idx == q.correctIndex) {
              bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
              borderColor = const Color(0xFF10B981);
              textColor = const Color(0xFF10B981);
            } else if (idx == _selectedAnswerIndex) {
              bgColor = Colors.red.withValues(alpha: 0.12);
              borderColor = Colors.redAccent;
              textColor = Colors.redAccent;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _selectOption(idx),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: bgColor ?? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor ??
                        (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: borderColor != null ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                      child: Text(
                        String.fromCharCode(65 + idx), // A, B, C, D
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        optionText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),

        // Next Button
        if (_answered)
          ElevatedButton(
            onPressed: _nextQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEnglish,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _currentIndex < _questions.length - 1 ? 'Câu tiếp theo' : 'Xem kết quả',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultView(bool isDark) {
    final percent = ((_score / _questions.length) * 100).round();
    final isPassed = percent >= 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Icon(
          isPassed ? Icons.emoji_events : Icons.refresh,
          color: isPassed ? const Color(0xFFF59E0B) : Colors.blueGrey,
          size: 64,
        ),
        const SizedBox(height: 14),
        Text(
          isPassed ? 'Chúc Mừng Bạn Đã Vượt Ải!' : 'Cố Lên, Hãy Thử Lại Nhé!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPassed
              ? 'Bạn đã trả lời đúng $_score/${_questions.length} câu ($percent%). Bài học đã được ghi nhận hoàn thành!'
              : 'Bạn đạt $_score/${_questions.length} câu ($percent%). Hãy ôn lại flashcard và thử sức lại nhé!',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: isPassed ? const Color(0xFF10B981) : AppColors.primaryEnglish,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            'Hoàn Tất',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
