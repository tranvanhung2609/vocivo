import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/services/learning_engine.dart';
import '../models/curriculum_model.dart';
import '../models/learning_v2.dart';
import 'language_mode_provider.dart';

@immutable
class DailyLearningState {
  final LearningProfile? profile;
  final DailyPlan? plan;
  final CurriculumUnit? nextUnit;
  final LearningSession? activeSession;
  final LessonDefinition? activeLesson;
  final List<SkillMastery> mastery;
  final int dueCount;
  final int mistakeCount;
  final bool isLoading;
  final String? errorMessage;

  const DailyLearningState({
    this.profile,
    this.plan,
    this.nextUnit,
    this.activeSession,
    this.activeLesson,
    this.mastery = const [],
    this.dueCount = 0,
    this.mistakeCount = 0,
    this.isLoading = true,
    this.errorMessage,
  });

  DailyLearningState copyWith({
    LearningProfile? profile,
    DailyPlan? plan,
    CurriculumUnit? nextUnit,
    bool clearNextUnit = false,
    LearningSession? activeSession,
    bool clearSession = false,
    LessonDefinition? activeLesson,
    bool clearLesson = false,
    List<SkillMastery>? mastery,
    int? dueCount,
    int? mistakeCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DailyLearningState(
      profile: profile ?? this.profile,
      plan: plan ?? this.plan,
      nextUnit: clearNextUnit ? null : (nextUnit ?? this.nextUnit),
      activeSession: clearSession
          ? null
          : (activeSession ?? this.activeSession),
      activeLesson: clearLesson ? null : (activeLesson ?? this.activeLesson),
      mastery: mastery ?? this.mastery,
      dueCount: dueCount ?? this.dueCount,
      mistakeCount: mistakeCount ?? this.mistakeCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DailyLearningNotifier extends Notifier<DailyLearningState> {
  final DailyPlanGenerator _planGenerator = const DailyPlanGenerator();
  final LessonFactory _lessonFactory = const LessonFactory();
  int _generation = 0;
  bool _isCompleting = false;

  @override
  DailyLearningState build() {
    ref.listen(languageModeProvider, (previous, next) {
      if (previous != next) Future.microtask(refresh);
    });
    Future.microtask(refresh);
    return const DailyLearningState();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, errorMessage: null);
    final language = ref.read(languageModeProvider);
    try {
      final results = await Future.wait<dynamic>([
        AppDatabase.instance.getLearningProfile(language),
        AppDatabase.instance.getDueCount(languageCode: language),
        AppDatabase.instance.getRecentMistakeCount(language),
        AppDatabase.instance.getLearningUnits(language),
        AppDatabase.instance.getSkillMastery(language),
        AppDatabase.instance.getActiveLearningSession(language),
      ]);
      if (generation != _generation) return;

      final profile = results[0] as LearningProfile;
      final dueCount = results[1] as int;
      final mistakeCount = results[2] as int;
      final units = results[3] as List<CurriculumUnit>;
      final mastery = results[4] as List<SkillMastery>;
      final activeSession = results[5] as LearningSession?;
      final nextUnit =
          units.where((unit) => !unit.isCompleted).firstOrNull ??
          units.firstOrNull;
      CurriculumUnit? sessionUnit;
      if (activeSession?.unitId != null) {
        sessionUnit = units
            .where((unit) => unit.id == activeSession!.unitId)
            .firstOrNull;
      }
      LessonDefinition? activeLesson;
      if (activeSession?.lessonId != null) {
        activeLesson = await AppDatabase.instance.getLessonDefinition(
          activeSession!.lessonId!,
        );
      }
      if (activeLesson == null && sessionUnit != null) {
        activeLesson = _lessonFactory.fromUnit(sessionUnit);
      }
      final plan = _planGenerator.generate(
        profile: profile,
        dueCount: dueCount,
        mistakeCount: mistakeCount,
        nextUnit: nextUnit,
        mastery: mastery,
      );

      state = DailyLearningState(
        profile: profile,
        plan: plan,
        nextUnit: nextUnit,
        activeSession: activeSession,
        activeLesson: activeLesson,
        mastery: mastery,
        dueCount: dueCount,
        mistakeCount: mistakeCount,
        isLoading: false,
      );
    } catch (error, stack) {
      debugPrint('DailyLearningNotifier.refresh: $error\n$stack');
      if (generation == _generation) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Chưa thể tạo kế hoạch hôm nay. Hãy thử tải lại.',
        );
      }
    }
  }

  Future<void> setDailyMinutes(int minutes) async {
    final profile = state.profile;
    if (profile == null) return;
    final updated = profile.copyWith(dailyMinutes: minutes.clamp(5, 30));
    await AppDatabase.instance.saveLearningProfile(updated);
    await refresh();
  }

  Future<LearningSession?> startOrResumeDailySession() async {
    if (state.activeSession != null && state.activeLesson != null) {
      return state.activeSession;
    }
    final unit = state.nextUnit;
    if (unit == null || unit.words.isEmpty) return null;
    return startUnitSession(unit);
  }

  Future<LearningSession?> startUnitSession(CurriculumUnit unit) async {
    final current = state.activeSession;
    if (current?.unitId == unit.id && state.activeLesson != null) {
      return current;
    }
    if (current != null) {
      await AppDatabase.instance.saveLearningSession(
        current.copyWith(status: LearningSessionStatus.abandoned),
      );
    }
    if (unit.words.isEmpty) return null;
    final lesson = _lessonFactory.fromUnit(unit);
    final now = DateTime.now();
    final session = LearningSession(
      id: '${unit.languageCode}_${now.microsecondsSinceEpoch}',
      courseCode: unit.languageCode,
      type: LearningSessionType.daily,
      status: LearningSessionStatus.inProgress,
      unitId: unit.id,
      lessonId: lesson.id,
      totalSteps: lesson.exercises.length,
      startedAt: now,
      updatedAt: now,
    );
    await AppDatabase.instance.saveLessonDefinition(lesson);
    await AppDatabase.instance.saveLearningSession(session);
    state = state.copyWith(activeSession: session, activeLesson: lesson);
    return session;
  }

  Future<bool> submitAttempt({
    required ExerciseDefinition exercise,
    required String response,
    required bool isCorrect,
    int? score,
    String? feedback,
  }) async {
    final session = state.activeSession;
    if (session == null) return false;
    final attempt = ExerciseAttempt(
      id: '${session.id}_${exercise.id}',
      sessionId: session.id,
      exerciseId: exercise.id,
      vocabularyId: exercise.vocabularyId,
      skill: exercise.skill,
      response: response,
      isCorrect: isCorrect,
      score: score ?? (isCorrect ? 100 : 0),
      feedback: feedback,
      createdAt: DateTime.now(),
    );
    final nextStep = (session.currentStep + 1).clamp(0, session.totalSteps);
    final totalScore = session.score + attempt.score;
    final updated = session.copyWith(
      currentStep: nextStep,
      score: totalScore,
      xpEarned: session.xpEarned + (isCorrect ? 10 : 4),
    );
    final inserted = await AppDatabase.instance.recordExerciseAttempt(
      attempt,
      courseCode: session.courseCode,
      advancedSession: updated,
    );
    if (!inserted) return false;
    state = state.copyWith(activeSession: updated);
    return true;
  }

  Future<void> completeActiveSession() async {
    if (_isCompleting) return;
    final session = state.activeSession;
    if (session == null) return;
    _isCompleting = true;
    final average = session.totalSteps == 0
        ? 0
        : (session.score / session.totalSteps).round();
    final completed = session.copyWith(
      status: LearningSessionStatus.completed,
      currentStep: session.totalSteps,
      completedAt: DateTime.now(),
    );
    try {
      final didComplete = await AppDatabase.instance.completeLearningSession(
        completed,
        averageScore: average,
        speakingPracticed:
            state.activeLesson?.exercises
                .where((exercise) => exercise.skill == LearningSkill.speaking)
                .length ??
            0,
      );
      if (didComplete) {
        state = state.copyWith(clearSession: true, clearLesson: true);
      }
      await refresh();
    } finally {
      _isCompleting = false;
    }
  }
}

final dailyLearningProvider =
    NotifierProvider<DailyLearningNotifier, DailyLearningState>(
      DailyLearningNotifier.new,
    );
