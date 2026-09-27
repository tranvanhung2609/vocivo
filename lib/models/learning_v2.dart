import 'dart:convert';

enum LearningSkill { vocabulary, listening, recall, speaking }

enum ExerciseType {
  meaningChoice,
  listeningChoice,
  sentenceOrder,
  textInput,
  pronunciation,
}

enum LearningSessionType { daily, lesson, review, speaking, quickPractice }

enum LearningSessionStatus { inProgress, completed, abandoned }

enum DailyTaskType { review, lesson, listening, speaking, mistakes }

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  return values.where((value) => value.name == name).firstOrNull ?? fallback;
}

class LearningProfile {
  final String courseCode;
  final String goal;
  final String level;
  final int dailyMinutes;
  final List<int> studyDays;
  final String? reminderTime;
  final DateTime updatedAt;

  const LearningProfile({
    required this.courseCode,
    this.goal = 'Giao tiếp thực tế',
    this.level = 'A1',
    this.dailyMinutes = 15,
    this.studyDays = const [1, 2, 3, 4, 5, 6, 7],
    this.reminderTime,
    required this.updatedAt,
  });

  factory LearningProfile.defaults(String courseCode) => LearningProfile(
    courseCode: courseCode.toUpperCase(),
    level: courseCode.toUpperCase() == 'ZH' ? 'HSK 1' : 'A1',
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'course_code': courseCode.toUpperCase(),
    'goal': goal,
    'level': level,
    'daily_minutes': dailyMinutes,
    'study_days': jsonEncode(studyDays),
    'reminder_time': reminderTime,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory LearningProfile.fromMap(Map<String, dynamic> map) {
    final rawDays = map['study_days']?.toString();
    List<int> days = const [1, 2, 3, 4, 5, 6, 7];
    if (rawDays != null) {
      try {
        days = (jsonDecode(rawDays) as List)
            .map((e) => (e as num).toInt())
            .toList();
      } catch (_) {}
    }
    return LearningProfile(
      courseCode: map['course_code']?.toString().toUpperCase() ?? 'EN',
      goal: map['goal']?.toString() ?? 'Giao tiếp thực tế',
      level: map['level']?.toString() ?? 'A1',
      dailyMinutes: (map['daily_minutes'] as num?)?.toInt() ?? 15,
      studyDays: days,
      reminderTime: map['reminder_time']?.toString(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  LearningProfile copyWith({
    String? goal,
    String? level,
    int? dailyMinutes,
    List<int>? studyDays,
    String? reminderTime,
  }) => LearningProfile(
    courseCode: courseCode,
    goal: goal ?? this.goal,
    level: level ?? this.level,
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    studyDays: studyDays ?? this.studyDays,
    reminderTime: reminderTime ?? this.reminderTime,
    updatedAt: DateTime.now(),
  );
}

class ExerciseDefinition {
  final String id;
  final ExerciseType type;
  final LearningSkill skill;
  final int? vocabularyId;
  final String prompt;
  final String correctAnswer;
  final List<String> choices;
  final String explanation;
  final String? audioText;

  const ExerciseDefinition({
    required this.id,
    required this.type,
    required this.skill,
    this.vocabularyId,
    required this.prompt,
    required this.correctAnswer,
    this.choices = const [],
    this.explanation = '',
    this.audioText,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'skill': skill.name,
    'vocabulary_id': vocabularyId,
    'prompt': prompt,
    'correct_answer': correctAnswer,
    'choices': choices,
    'explanation': explanation,
    'audio_text': audioText,
  };

  factory ExerciseDefinition.fromMap(Map<String, dynamic> map) =>
      ExerciseDefinition(
        id: map['id']?.toString() ?? '',
        type: _enumByName(
          ExerciseType.values,
          map['type']?.toString(),
          ExerciseType.meaningChoice,
        ),
        skill: _enumByName(
          LearningSkill.values,
          map['skill']?.toString(),
          LearningSkill.vocabulary,
        ),
        vocabularyId: (map['vocabulary_id'] as num?)?.toInt(),
        prompt: map['prompt']?.toString() ?? '',
        correctAnswer: map['correct_answer']?.toString() ?? '',
        choices:
            (map['choices'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
        explanation: map['explanation']?.toString() ?? '',
        audioText: map['audio_text']?.toString(),
      );
}

class LessonDefinition {
  final String id;
  final String unitId;
  final String courseCode;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
  final List<ExerciseDefinition> exercises;

  const LessonDefinition({
    required this.id,
    required this.unitId,
    required this.courseCode,
    required this.title,
    required this.subtitle,
    required this.estimatedMinutes,
    required this.exercises,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'unit_id': unitId,
    'course_code': courseCode.toUpperCase(),
    'title': title,
    'subtitle': subtitle,
    'estimated_minutes': estimatedMinutes,
    'exercises_json': jsonEncode(
      exercises.map((exercise) => exercise.toMap()).toList(),
    ),
    'updated_at': DateTime.now().toIso8601String(),
  };

  factory LessonDefinition.fromMap(Map<String, dynamic> map) {
    final raw = map['exercises_json']?.toString() ?? '[]';
    List<ExerciseDefinition> exercises = const [];
    try {
      exercises = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(ExerciseDefinition.fromMap)
          .toList();
    } catch (_) {}
    return LessonDefinition(
      id: map['id']?.toString() ?? '',
      unitId: map['unit_id']?.toString() ?? '',
      courseCode: map['course_code']?.toString().toUpperCase() ?? 'EN',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt() ?? 5,
      exercises: exercises,
    );
  }
}

class LearningSession {
  final String id;
  final String courseCode;
  final LearningSessionType type;
  final LearningSessionStatus status;
  final String? unitId;
  final String? lessonId;
  final int currentStep;
  final int totalSteps;
  final int score;
  final int xpEarned;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const LearningSession({
    required this.id,
    required this.courseCode,
    required this.type,
    required this.status,
    this.unitId,
    this.lessonId,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.score = 0,
    this.xpEarned = 0,
    required this.startedAt,
    required this.updatedAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'course_code': courseCode.toUpperCase(),
    'session_type': type.name,
    'status': status.name,
    'unit_id': unitId,
    'lesson_id': lessonId,
    'current_step': currentStep,
    'total_steps': totalSteps,
    'score': score,
    'xp_earned': xpEarned,
    'started_at': startedAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  factory LearningSession.fromMap(Map<String, dynamic> map) => LearningSession(
    id: map['id']?.toString() ?? '',
    courseCode: map['course_code']?.toString().toUpperCase() ?? 'EN',
    type: _enumByName(
      LearningSessionType.values,
      map['session_type']?.toString(),
      LearningSessionType.daily,
    ),
    status: _enumByName(
      LearningSessionStatus.values,
      map['status']?.toString(),
      LearningSessionStatus.inProgress,
    ),
    unitId: map['unit_id']?.toString(),
    lessonId: map['lesson_id']?.toString(),
    currentStep: (map['current_step'] as num?)?.toInt() ?? 0,
    totalSteps: (map['total_steps'] as num?)?.toInt() ?? 0,
    score: (map['score'] as num?)?.toInt() ?? 0,
    xpEarned: (map['xp_earned'] as num?)?.toInt() ?? 0,
    startedAt:
        DateTime.tryParse(map['started_at']?.toString() ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
        DateTime.now(),
    completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? ''),
  );

  LearningSession copyWith({
    LearningSessionStatus? status,
    int? currentStep,
    int? totalSteps,
    int? score,
    int? xpEarned,
    DateTime? completedAt,
  }) => LearningSession(
    id: id,
    courseCode: courseCode,
    type: type,
    status: status ?? this.status,
    unitId: unitId,
    lessonId: lessonId,
    currentStep: currentStep ?? this.currentStep,
    totalSteps: totalSteps ?? this.totalSteps,
    score: score ?? this.score,
    xpEarned: xpEarned ?? this.xpEarned,
    startedAt: startedAt,
    updatedAt: DateTime.now(),
    completedAt: completedAt ?? this.completedAt,
  );
}

class ExerciseAttempt {
  final String id;
  final String sessionId;
  final String exerciseId;
  final int? vocabularyId;
  final LearningSkill skill;
  final String response;
  final bool isCorrect;
  final int score;
  final String? feedback;
  final DateTime createdAt;

  const ExerciseAttempt({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    this.vocabularyId,
    required this.skill,
    required this.response,
    required this.isCorrect,
    required this.score,
    this.feedback,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'exercise_id': exerciseId,
    'vocab_id': vocabularyId,
    'skill': skill.name,
    'response': response,
    'is_correct': isCorrect ? 1 : 0,
    'score': score,
    'feedback': feedback,
    'created_at': createdAt.toIso8601String(),
  };
}

class SkillMastery {
  final String courseCode;
  final LearningSkill skill;
  final int? vocabularyId;
  final double mastery;
  final int attempts;
  final DateTime updatedAt;

  const SkillMastery({
    required this.courseCode,
    required this.skill,
    this.vocabularyId,
    required this.mastery,
    required this.attempts,
    required this.updatedAt,
  });

  factory SkillMastery.fromMap(Map<String, dynamic> map) => SkillMastery(
    courseCode: map['course_code']?.toString().toUpperCase() ?? 'EN',
    skill: _enumByName(
      LearningSkill.values,
      map['skill']?.toString(),
      LearningSkill.vocabulary,
    ),
    vocabularyId: (map['vocab_id'] as num?)?.toInt(),
    mastery: ((map['mastery'] as num?)?.toDouble() ?? 0).clamp(0, 1),
    attempts: (map['attempts'] as num?)?.toInt() ?? 0,
    updatedAt:
        DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

class DailyPlanTask {
  final String id;
  final DailyTaskType type;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
  final int itemCount;
  final bool isCompleted;

  const DailyPlanTask({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.estimatedMinutes,
    required this.itemCount,
    this.isCompleted = false,
  });
}

class DailyPlan {
  final String courseCode;
  final int targetMinutes;
  final List<DailyPlanTask> tasks;
  final DateTime generatedAt;

  const DailyPlan({
    required this.courseCode,
    required this.targetMinutes,
    required this.tasks,
    required this.generatedAt,
  });

  int get estimatedMinutes =>
      tasks.fold(0, (sum, task) => sum + task.estimatedMinutes);
  int get completedCount => tasks.where((task) => task.isCompleted).length;
  double get progress => tasks.isEmpty ? 0 : completedCount / tasks.length;
}
