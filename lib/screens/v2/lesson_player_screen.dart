import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/pronunciation_evaluator.dart';
import '../../core/services/stt_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/learning_v2.dart';
import '../../providers/daily_learning_provider.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({super.key});

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  final TextEditingController _answerController = TextEditingController();
  int? _stepIndex;
  String? _selectedAnswer;
  final List<String> _orderedWords = [];
  bool _feedbackVisible = false;
  bool _lastCorrect = false;
  bool _isSubmitting = false;
  bool _isListening = false;
  bool _completed = false;
  PronunciationResult? _pronunciationResult;
  String _recognizedText = '';
  int _finalScore = 0;
  int _finalXp = 0;

  @override
  void dispose() {
    _answerController.dispose();
    SttService.instance.cancelListening();
    TtsService.instance.stop();
    super.dispose();
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\u00C0-\u024F\u4E00-\u9FFF]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _submit(
    ExerciseDefinition exercise,
    String response, {
    int? score,
    String? feedback,
  }) async {
    if (_isSubmitting || _feedbackVisible || response.trim().isEmpty) return;
    final isCorrect = score != null
        ? score >= 70
        : _normalize(response) == _normalize(exercise.correctAnswer);
    setState(() => _isSubmitting = true);
    try {
      final inserted = await ref
          .read(dailyLearningProvider.notifier)
          .submitAttempt(
            exercise: exercise,
            response: response,
            isCorrect: isCorrect,
            score: score,
            feedback: feedback,
          );
      if (!mounted) return;
      if (!inserted) {
        await ref.read(dailyLearningProvider.notifier).refresh();
        if (!mounted) return;
        setState(() {
          _stepIndex = ref
              .read(dailyLearningProvider)
              .activeSession
              ?.currentStep;
        });
        return;
      }
      setState(() {
        _feedbackVisible = true;
        _lastCorrect = isCorrect;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được câu trả lời. Hãy thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _next(LessonDefinition lesson) async {
    final session = ref.read(dailyLearningProvider).activeSession;
    if (session == null) return;
    if (session.currentStep >= lesson.exercises.length) {
      _finalScore = session.totalSteps == 0
          ? 0
          : (session.score / session.totalSteps).round();
      _finalXp = session.xpEarned;
      await ref.read(dailyLearningProvider.notifier).completeActiveSession();
      if (mounted) setState(() => _completed = true);
      return;
    }
    setState(() {
      _stepIndex = session.currentStep;
      _selectedAnswer = null;
      _orderedWords.clear();
      _answerController.clear();
      _feedbackVisible = false;
      _lastCorrect = false;
      _pronunciationResult = null;
      _recognizedText = '';
    });
  }

  Future<void> _listen(
    ExerciseDefinition exercise,
    String languageCode, {
    double rate = 0.45,
  }) {
    return TtsService.instance.speak(
      text: exercise.audioText ?? exercise.correctAnswer,
      languageCode: languageCode,
      rate: rate,
    );
  }

  Future<void> _toggleRecording(
    ExerciseDefinition exercise,
    String languageCode,
  ) async {
    if (_isListening) {
      await SttService.instance.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final available = await SttService.instance.startListening(
      languageCode: languageCode,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _recognizedText = text);
        if (isFinal && text.trim().isNotEmpty) {
          final result = PronunciationEvaluator.instance.evaluate(
            target: exercise.correctAnswer,
            spoken: text,
            languageCode: languageCode,
          );
          setState(() {
            _isListening = false;
            _pronunciationResult = result;
          });
          _submit(
            exercise,
            text,
            score: result.overallScore,
            feedback: result.feedbackVi,
          );
        }
      },
    );
    if (!mounted) return;
    setState(() => _isListening = available);
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể dùng microphone. Kiểm tra quyền truy cập hoặc luyện bằng nút nghe mẫu.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final learning = ref.watch(dailyLearningProvider);
    final lesson = learning.activeLesson;
    final session = learning.activeSession;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_completed) return _buildCompletion(isDark);
    if (lesson == null || session == null || lesson.exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: _EmptyLesson(onBack: () => Navigator.pop(context))),
      );
    }

    _stepIndex ??= session.currentStep.clamp(0, lesson.exercises.length - 1);
    final index = _stepIndex!.clamp(0, lesson.exercises.length - 1);
    final exercise = lesson.exercises[index];
    final progress =
        (index + (_feedbackVisible ? 1 : 0)) / lesson.exercises.length;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF6F8FB),
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Tạm dừng và quay lại',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                'Tiến độ được lưu tự động',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? AppColors.surfaceDark3
                  : AppColors.borderLight,
              color: AppColors.primaryEnglish,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  '${index + 1}/${lesson.exercises.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SkillLabel(skill: exercise.skill),
                    const SizedBox(height: 16),
                    Text(
                      exercise.prompt,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildExercise(
                          exercise,
                          lesson.courseCode,
                          isDark,
                        ),
                      ),
                    ),
                    if (_feedbackVisible) ...[
                      const SizedBox(height: 16),
                      _FeedbackPanel(
                        isCorrect: _lastCorrect,
                        explanation:
                            _pronunciationResult?.feedbackVi ??
                            exercise.explanation,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _next(lesson),
                        child: Text(
                          index == lesson.exercises.length - 1
                              ? 'Xem kết quả'
                              : 'Tiếp tục',
                        ),
                      ),
                    ] else if (exercise.type != ExerciseType.pronunciation) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _canSubmit(exercise)
                            ? () =>
                                  _submit(exercise, _currentResponse(exercise))
                            : null,
                        child: Text(_isSubmitting ? 'Đang lưu…' : 'Kiểm tra'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExercise(
    ExerciseDefinition exercise,
    String languageCode,
    bool isDark,
  ) {
    switch (exercise.type) {
      case ExerciseType.meaningChoice:
      case ExerciseType.listeningChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (exercise.type == ExerciseType.listeningChoice)
              Center(
                child: _AudioButton(
                  onPressed: () => _listen(exercise, languageCode),
                ),
              ),
            if (exercise.type == ExerciseType.listeningChoice)
              const SizedBox(height: 24),
            for (var i = 0; i < exercise.choices.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChoiceTile(
                  shortcut: '${i + 1}',
                  label: exercise.choices[i],
                  selected: _selectedAnswer == exercise.choices[i],
                  enabled: !_feedbackVisible,
                  onTap: () =>
                      setState(() => _selectedAnswer = exercise.choices[i]),
                ),
              ),
          ],
        );
      case ExerciseType.textInput:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _answerController,
              autofocus: true,
              enabled: !_feedbackVisible,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSubmit(exercise)) {
                  _submit(exercise, _answerController.text);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Câu trả lời của bạn',
                hintText: 'Nhập từ hoặc cụm từ…',
                prefixIcon: Icon(Icons.keyboard_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Không phân biệt chữ hoa/thường và dấu câu.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case ExerciseType.sentenceOrder:
        final remaining = List<String>.from(exercise.choices);
        for (final word in _orderedWords) {
          remaining.remove(word);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark1 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _orderedWords
                    .map(
                      (word) => InputChip(
                        label: Text(word),
                        onPressed: _feedbackVisible
                            ? null
                            : () => setState(() => _orderedWords.remove(word)),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: remaining
                  .map(
                    (word) => ActionChip(
                      label: Text(word),
                      onPressed: _feedbackVisible
                          ? null
                          : () => setState(() => _orderedWords.add(word)),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case ExerciseType.pronunciation:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    exercise.correctAnswer,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _listen(exercise, languageCode),
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('Nghe chuẩn'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _listen(exercise, languageCode, rate: 0.3),
                        icon: const Icon(Icons.slow_motion_video_rounded),
                        label: const Text('Nghe chậm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _feedbackVisible
                  ? null
                  : () => _toggleRecording(exercise, languageCode),
              icon: Icon(
                _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
              ),
              label: Text(_isListening ? 'Dừng ghi âm' : 'Bắt đầu nói'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 56),
                backgroundColor: _isListening
                    ? AppColors.errorRed
                    : AppColors.primaryEnglish,
              ),
            ),
            if (_recognizedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Đã nghe: “$_recognizedText”', textAlign: TextAlign.center),
            ],
            if (_pronunciationResult != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Metric(
                    label: 'Độ chuẩn',
                    value: _pronunciationResult!.accuracyScore,
                  ),
                  _Metric(
                    label: 'Hoàn thiện',
                    value: _pronunciationResult!.completenessScore,
                  ),
                  _Metric(
                    label: 'Lưu loát',
                    value: _pronunciationResult!.fluencyScore,
                  ),
                ],
              ),
            ],
          ],
        );
    }
  }

  bool _canSubmit(ExerciseDefinition exercise) {
    if (_feedbackVisible || _isSubmitting) return false;
    return switch (exercise.type) {
      ExerciseType.meaningChoice ||
      ExerciseType.listeningChoice => _selectedAnswer != null,
      ExerciseType.textInput => _answerController.text.trim().isNotEmpty,
      ExerciseType.sentenceOrder => _orderedWords.isNotEmpty,
      ExerciseType.pronunciation => false,
    };
  }

  String _currentResponse(ExerciseDefinition exercise) =>
      switch (exercise.type) {
        ExerciseType.meaningChoice ||
        ExerciseType.listeningChoice => _selectedAnswer ?? '',
        ExerciseType.textInput => _answerController.text,
        ExerciseType.sentenceOrder => _orderedWords.join(' '),
        ExerciseType.pronunciation => _recognizedText,
      };

  Widget _buildCompletion(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryEnglishLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: AppColors.primaryEnglishDeep,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Hoàn thành phiên học',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bạn vừa biến kiến thức thành một bước tiến có thể đo được.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _ResultCard(
                          label: 'Chính xác',
                          value: '$_finalScore%',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ResultCard(
                          label: 'Kinh nghiệm',
                          value: '+$_finalXp XP',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Về Hôm nay'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillLabel extends StatelessWidget {
  const _SkillLabel({required this.skill});
  final LearningSkill skill;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (skill) {
      LearningSkill.vocabulary => (Icons.menu_book_rounded, 'TỪ VỰNG'),
      LearningSkill.listening => (Icons.headphones_rounded, 'NGHE'),
      LearningSkill.recall => (Icons.psychology_rounded, 'GHI NHỚ'),
      LearningSkill.speaking => (Icons.mic_rounded, 'PHÁT ÂM'),
    };
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primaryEnglish),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryEnglishDeep,
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.shortcut,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String shortcut;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryEnglish.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primaryEnglish
                  : Theme.of(context).colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryEnglish
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryEnglish
                        : AppColors.borderLight,
                  ),
                ),
                child: Text(
                  shortcut,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryEnglish,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.isCorrect, required this.explanation});
  final bool isCorrect;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.successGreen : AppColors.streakOrange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? 'Chính xác' : 'Mình cùng sửa lại',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(explanation),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioButton extends StatelessWidget {
  const _AudioButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    onPressed: onPressed,
    tooltip: 'Phát âm thanh',
    iconSize: 38,
    padding: const EdgeInsets.all(22),
    icon: const Icon(Icons.volume_up_rounded),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      children: [
        Text(
          '$value%',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _EmptyLesson extends StatelessWidget {
  const _EmptyLesson({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.menu_book_outlined, size: 56),
      const SizedBox(height: 16),
      const Text('Chưa có nội dung cho phiên học này.'),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: onBack, child: const Text('Quay lại')),
    ],
  );
}
