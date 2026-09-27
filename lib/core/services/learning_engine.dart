import 'dart:math';

import '../../models/curriculum_model.dart';
import '../../models/learning_v2.dart';
import '../../models/vocabulary_item.dart';

class DailyPlanGenerator {
  const DailyPlanGenerator();

  DailyPlan generate({
    required LearningProfile profile,
    required int dueCount,
    required int mistakeCount,
    required CurriculumUnit? nextUnit,
    required List<SkillMastery> mastery,
  }) {
    final target = profile.dailyMinutes.clamp(5, 30);
    final tasks = <DailyPlanTask>[];
    var remaining = target;

    if (dueCount > 0) {
      final reservedMinutes = target >= 10 ? (nextUnit == null ? 3 : 6) : 0;
      final reviewBudget = max(1, target - reservedMinutes);
      final minutes = min(
        reviewBudget,
        target <= 5 ? 3 : min(7, max(3, dueCount ~/ 2)),
      );
      tasks.add(
        DailyPlanTask(
          id: 'review_due',
          type: DailyTaskType.review,
          title: 'Ôn từ đến hạn',
          subtitle: '$dueCount từ đang chờ bạn củng cố',
          estimatedMinutes: minutes,
          itemCount: min(dueCount, max(3, minutes * 2)),
        ),
      );
      remaining -= minutes;
    } else if (mistakeCount > 0) {
      final reservedMinutes = target >= 10 ? (nextUnit == null ? 3 : 6) : 0;
      final reviewBudget = max(1, target - reservedMinutes);
      final minutes = min(reviewBudget, target <= 5 ? 3 : 5);
      tasks.add(
        DailyPlanTask(
          id: 'review_mistakes',
          type: DailyTaskType.mistakes,
          title: 'Sửa lỗi gần đây',
          subtitle: '$mistakeCount lỗi sẽ được luyện lại đúng lúc',
          estimatedMinutes: minutes,
          itemCount: min(mistakeCount, max(3, minutes)),
        ),
      );
      remaining -= minutes;
    }

    if (nextUnit != null && remaining > 0) {
      final speakingReserve = target >= 10 ? 3 : 0;
      final lessonBudget = max(1, remaining - speakingReserve);
      final minutes = target <= 5
          ? remaining
          : min(lessonBudget, max(5, target - 7));
      tasks.add(
        DailyPlanTask(
          id: 'lesson_${nextUnit.id}',
          type: DailyTaskType.lesson,
          title: nextUnit.isCompleted
              ? 'Củng cố ${nextUnit.title}'
              : nextUnit.title,
          subtitle:
              '${nextUnit.level} • ${nextUnit.words.length} từ/cụm từ trong ngữ cảnh',
          estimatedMinutes: minutes,
          itemCount: nextUnit.words.length,
        ),
      );
      remaining -= minutes;
    }

    if (remaining >= 3 || tasks.isEmpty) {
      final weakSkill = _weakestSkill(mastery);
      final isListening = weakSkill == LearningSkill.listening;
      final minutes = max(3, remaining);
      tasks.add(
        DailyPlanTask(
          id: isListening ? 'listening_focus' : 'speaking_focus',
          type: isListening ? DailyTaskType.listening : DailyTaskType.speaking,
          title: isListening ? 'Nghe và nhận diện' : 'Nói trong tình huống',
          subtitle: isListening
              ? 'Củng cố kỹ năng đang cần chú ý nhất'
              : 'Đưa những từ vừa học vào lời nói',
          estimatedMinutes: minutes,
          itemCount: max(1, minutes ~/ 2),
        ),
      );
    }

    return DailyPlan(
      courseCode: profile.courseCode,
      targetMinutes: target,
      tasks: tasks,
      generatedAt: DateTime.now(),
    );
  }

  LearningSkill _weakestSkill(List<SkillMastery> mastery) {
    if (mastery.isEmpty) return LearningSkill.speaking;
    final scores = <LearningSkill, List<double>>{};
    for (final item in mastery) {
      scores.putIfAbsent(item.skill, () => []).add(item.mastery);
    }
    LearningSkill weakest = LearningSkill.speaking;
    var lowest = double.infinity;
    for (final skill in LearningSkill.values) {
      final values = scores[skill];
      final average = values == null || values.isEmpty
          ? (skill == LearningSkill.speaking ? 0.0 : 0.5)
          : values.reduce((a, b) => a + b) / values.length;
      if (average < lowest) {
        lowest = average;
        weakest = skill;
      }
    }
    return weakest;
  }
}

class LessonFactory {
  const LessonFactory();

  LessonDefinition fromUnit(CurriculumUnit unit, {int maxExercises = 10}) {
    final exercises = <ExerciseDefinition>[];
    final words = unit.words;
    for (
      var index = 0;
      index < words.length && exercises.length < maxExercises;
      index++
    ) {
      final word = words[index];
      exercises.add(_meaningExercise(unit, word, index));
      if (exercises.length >= maxExercises) break;

      if (index.isEven) {
        exercises.add(_listeningExercise(unit, word, index));
      } else {
        exercises.add(_recallExercise(unit, word, index));
      }
      if (exercises.length >= maxExercises) break;

      if (word.examples.isNotEmpty && exercises.length < maxExercises) {
        final sentence = word.examples.first;
        if (sentence.text.trim().split(RegExp(r'\s+')).length >= 3) {
          exercises.add(
            ExerciseDefinition(
              id: '${unit.id}_${word.id ?? index}_order',
              type: ExerciseType.sentenceOrder,
              skill: LearningSkill.recall,
              vocabularyId: word.id,
              prompt: 'Sắp xếp lại câu hoàn chỉnh',
              correctAnswer: sentence.text,
              choices: sentence.text
                  .trim()
                  .split(RegExp(r'\s+'))
                  .reversed
                  .toList(),
              explanation: sentence.vi,
            ),
          );
        }
      }
    }

    if (words.isNotEmpty && exercises.length < maxExercises) {
      final word = words.first;
      exercises.add(
        ExerciseDefinition(
          id: '${unit.id}_${word.id ?? 0}_speak',
          type: ExerciseType.pronunciation,
          skill: LearningSkill.speaking,
          vocabularyId: word.id,
          prompt: 'Nghe và nói lại',
          correctAnswer: word.examples.firstOrNull?.text ?? word.word,
          audioText: word.examples.firstOrNull?.text ?? word.word,
          explanation: 'Tập trung vào nhịp, trọng âm và độ rõ ràng.',
        ),
      );
    }

    return LessonDefinition(
      id: '${unit.id}_core',
      unitId: unit.id,
      courseCode: unit.languageCode,
      title: unit.title,
      subtitle: 'Học → nghe → nhớ → nói',
      estimatedMinutes: max(5, (exercises.length * 1.5).ceil()),
      exercises: exercises,
    );
  }

  ExerciseDefinition _meaningExercise(
    CurriculumUnit unit,
    VocabularyItem word,
    int index,
  ) {
    final choices = _meaningChoices(unit.words, word);
    return ExerciseDefinition(
      id: '${unit.id}_${word.id ?? index}_meaning',
      type: ExerciseType.meaningChoice,
      skill: LearningSkill.vocabulary,
      vocabularyId: word.id,
      prompt: '“${word.word}” có nghĩa là gì?',
      correctAnswer: word.meaningVi,
      choices: choices,
      explanation: _explanation(word),
      audioText: word.word,
    );
  }

  ExerciseDefinition _listeningExercise(
    CurriculumUnit unit,
    VocabularyItem word,
    int index,
  ) {
    return ExerciseDefinition(
      id: '${unit.id}_${word.id ?? index}_listen',
      type: ExerciseType.listeningChoice,
      skill: LearningSkill.listening,
      vocabularyId: word.id,
      prompt: 'Nghe và chọn nghĩa đúng',
      correctAnswer: word.meaningVi,
      choices: _meaningChoices(unit.words, word),
      explanation: _explanation(word),
      audioText: word.word,
    );
  }

  ExerciseDefinition _recallExercise(
    CurriculumUnit unit,
    VocabularyItem word,
    int index,
  ) {
    return ExerciseDefinition(
      id: '${unit.id}_${word.id ?? index}_recall',
      type: ExerciseType.textInput,
      skill: LearningSkill.recall,
      vocabularyId: word.id,
      prompt: 'Nhập từ phù hợp với nghĩa “${word.meaningVi}”',
      correctAnswer: word.word,
      explanation: _explanation(word),
      audioText: word.word,
    );
  }

  List<String> _meaningChoices(
    List<VocabularyItem> words,
    VocabularyItem correct,
  ) {
    final values = <String>{correct.meaningVi};
    for (final word in words) {
      if (values.length >= 4) break;
      if (word.meaningVi.trim().isNotEmpty) values.add(word.meaningVi);
    }
    const fallbacks = [
      'Một hành động thường ngày',
      'Một địa điểm',
      'Một đặc điểm',
    ];
    for (final fallback in fallbacks) {
      if (values.length >= 4) break;
      values.add(fallback);
    }
    final result = values.toList();
    // Stable rotation keeps tests deterministic while avoiding answer position 1.
    if (result.length > 1) {
      final first = result.removeAt(0);
      result.insert(
        min(1 + (correct.word.length % (result.length)), result.length),
        first,
      );
    }
    return result;
  }

  String _explanation(VocabularyItem word) {
    final phonetic = word.phonetic?.trim();
    final example = word.examples.firstOrNull;
    final parts = <String>[
      if (phonetic != null && phonetic.isNotEmpty) phonetic,
      word.meaningVi,
      if (example != null) '${example.text} — ${example.vi}',
    ];
    return parts.join(' • ');
  }
}
