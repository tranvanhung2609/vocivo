import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocivo/core/constants/curriculum_seed_data.dart';
import 'package:vocivo/core/database/app_database.dart';
import 'package:vocivo/core/services/learning_engine.dart';
import 'package:vocivo/models/learning_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyPlanGenerator', () {
    const generator = DailyPlanGenerator();

    test('prioritizes due reviews before lesson and speaking', () {
      final profile = LearningProfile.defaults('EN').copyWith(dailyMinutes: 15);
      final plan = generator.generate(
        profile: profile,
        dueCount: 12,
        mistakeCount: 3,
        nextUnit: CurriculumSeedData.englishStages.first.units.first,
        mastery: const [],
      );

      expect(plan.tasks.first.type, DailyTaskType.review);
      expect(
        plan.tasks.any((task) => task.type == DailyTaskType.lesson),
        isTrue,
      );
      expect(
        plan.tasks.any((task) => task.type == DailyTaskType.speaking),
        isTrue,
      );
      expect(plan.estimatedMinutes, greaterThanOrEqualTo(15));
    });

    test('creates a useful five minute plan', () {
      final profile = LearningProfile.defaults('ZH').copyWith(dailyMinutes: 5);
      final plan = generator.generate(
        profile: profile,
        dueCount: 4,
        mistakeCount: 0,
        nextUnit: CurriculumSeedData.chineseStages.first.units.first,
        mastery: const [],
      );

      expect(plan.targetMinutes, 5);
      expect(plan.tasks.first.type, DailyTaskType.review);
      expect(plan.tasks.length, greaterThanOrEqualTo(2));
      expect(plan.estimatedMinutes, 5);
    });

    test('keeps lesson and speaking time in a ten minute plan', () {
      final plan = generator.generate(
        profile: LearningProfile(
          courseCode: 'EN',
          dailyMinutes: 10,
          updatedAt: DateTime(2026),
        ),
        dueCount: 100,
        mistakeCount: 0,
        nextUnit: CurriculumSeedData.englishStages.first.units.first,
        mastery: const [],
      );

      expect(plan.estimatedMinutes, lessThanOrEqualTo(plan.targetMinutes));
      expect(
        plan.tasks.map((task) => task.type),
        contains(DailyTaskType.review),
      );
      expect(
        plan.tasks.map((task) => task.type),
        contains(DailyTaskType.lesson),
      );
      expect(
        plan.tasks.map((task) => task.type),
        contains(DailyTaskType.speaking),
      );
    });
  });

  group('LessonFactory', () {
    test('builds a mixed, bounded session from an existing unit', () {
      final unit = CurriculumSeedData.englishStages.first.units.first;
      const factory = LessonFactory();
      final lesson = factory.fromUnit(unit, maxExercises: 8);

      expect(lesson.unitId, unit.id);
      expect(lesson.exercises, isNotEmpty);
      expect(lesson.exercises.length, lessThanOrEqualTo(8));
      expect(
        lesson.exercises.map((exercise) => exercise.skill).toSet(),
        containsAll([LearningSkill.vocabulary, LearningSkill.listening]),
      );
      expect(
        lesson.exercises.every((exercise) => exercise.correctAnswer.isNotEmpty),
        isTrue,
      );

      final restored = LessonDefinition.fromMap(lesson.toMap());
      expect(restored.id, lesson.id);
      expect(restored.exercises.length, lesson.exercises.length);
      expect(restored.exercises.first.type, lesson.exercises.first.type);
    });
  });

  group('SQLite v4 migration', () {
    late Database database;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDown(() async {
      await database.close();
    });

    test('keeps v3 rows and adds resumable-learning tables', () async {
      database = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await database.execute('''
        CREATE TABLE vocabulary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          language_code TEXT NOT NULL,
          word TEXT NOT NULL,
          meaning_vi TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE unit_progress (
          unit_id TEXT PRIMARY KEY,
          is_completed INTEGER DEFAULT 0,
          completed_at DATETIME,
          last_score INTEGER DEFAULT 0
        )
      ''');
      await database.insert('vocabulary', {
        'language_code': 'EN',
        'word': 'confidence',
        'meaning_vi': 'sự tự tin',
      });
      await database.insert('unit_progress', {
        'unit_id': 'en_intro',
        'is_completed': 1,
        'last_score': 92,
      });

      await AppDatabase.instance.migrateForTest(database, 3, 4);
      // Running a second time must be safe.
      await AppDatabase.instance.migrateForTest(database, 3, 4);

      final words = await database.query('vocabulary');
      final progress = await database.query('unit_progress');
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = tables.map((row) => row['name']).toSet();

      expect(words.single['word'], 'confidence');
      expect(progress.single['is_completed'], 1);
      expect(progress.single['last_score'], 92);
      expect(progress.single['current_lesson'], 0);
      expect(
        tableNames,
        containsAll([
          'learning_profiles',
          'lesson_definitions',
          'learning_sessions',
          'exercise_attempts',
          'skill_mastery',
        ]),
      );
    });

    test('completes a session and records activity exactly once', () async {
      database = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await database.execute('''
        CREATE TABLE vocabulary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          language_code TEXT NOT NULL,
          word TEXT NOT NULL,
          meaning_vi TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE unit_progress (
          unit_id TEXT PRIMARY KEY,
          is_completed INTEGER DEFAULT 0,
          completed_at DATETIME,
          last_score INTEGER DEFAULT 0
        )
      ''');
      await database.execute('''
        CREATE TABLE daily_activities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          cards_reviewed INTEGER DEFAULT 0,
          speaking_practiced INTEGER DEFAULT 0,
          words_added INTEGER DEFAULT 0,
          xp_gained INTEGER DEFAULT 0
        )
      ''');
      await AppDatabase.instance.migrateForTest(database, 3, 4);

      final startedAt = DateTime(2026, 9, 27, 8);
      final session = LearningSession(
        id: 'session_once',
        courseCode: 'EN',
        type: LearningSessionType.daily,
        status: LearningSessionStatus.inProgress,
        unitId: 'en_intro',
        lessonId: 'en_intro_core',
        totalSteps: 2,
        startedAt: startedAt,
        updatedAt: startedAt,
      );
      await database.insert('learning_sessions', session.toMap());
      final completed = session.copyWith(
        status: LearningSessionStatus.completed,
        currentStep: 2,
        score: 180,
        xpEarned: 20,
        completedAt: startedAt.add(const Duration(minutes: 5)),
      );

      final first = await AppDatabase.instance.completeLearningSessionForTest(
        database,
        completed,
        averageScore: 90,
        speakingPracticed: 1,
      );
      final second = await AppDatabase.instance.completeLearningSessionForTest(
        database,
        completed,
        averageScore: 90,
        speakingPracticed: 1,
      );

      final activity = (await database.query('daily_activities')).single;
      final savedSession = (await database.query('learning_sessions')).single;
      expect(first, isTrue);
      expect(second, isFalse);
      expect(activity['cards_reviewed'], 2);
      expect(activity['speaking_practiced'], 1);
      expect(activity['xp_gained'], 20);
      expect(savedSession['status'], LearningSessionStatus.completed.name);
    });
  });
}
