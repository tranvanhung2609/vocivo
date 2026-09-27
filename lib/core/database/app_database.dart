import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../models/vocabulary_item.dart';
import '../../models/srs_progress.dart';
import '../../models/tag_model.dart';
import '../../models/curriculum_model.dart';
import '../../models/learning_v2.dart';
import '../constants/seed_data.dart';
import '../constants/curriculum_seed_data.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;
  bool _useInMemoryFallback = false;

  // In-memory fallback storage
  final List<VocabularyItem> _inMemoryVocab = [];
  final Map<int, SrsProgress> _inMemorySrs = {};
  final List<TagModel> _inMemoryTags = [
    const TagModel(id: 1, name: 'Từ vựng cốt lõi'),
    const TagModel(id: 2, name: 'Giao tiếp hàng ngày'),
    const TagModel(id: 3, name: 'Công việc & Kinh tế'),
  ];
  final Map<String, String> _inMemorySettings = {
    'streak_count': '1',
    'last_active_date': DateTime.now().toIso8601String(),
  };
  final List<CurriculumUnit> _inMemoryUnits = [];
  final Map<String, bool> _inMemoryUnitProgress = {};
  final Map<String, int> _inMemoryUnitScores = {};
  final Map<String, LearningProfile> _inMemoryProfiles = {};
  final Map<String, LearningSession> _inMemorySessions = {};
  final Map<String, LessonDefinition> _inMemoryLessons = {};
  final List<ExerciseAttempt> _inMemoryAttempts = [];
  final Map<String, SkillMastery> _inMemoryMastery = {};

  void _initInMemoryFallback() {
    if (_inMemoryVocab.isNotEmpty) return;
    int idCounter = 1;
    for (final item in SeedData.initialVocabulary) {
      final vocabWithId = item.copyWith(id: idCounter);
      _inMemoryVocab.add(vocabWithId);
      _inMemorySrs[idCounter] = SrsProgress(
        vocabId: idCounter,
        repetitionCount: 0,
        intervalDays: 1,
        easeFactor: 2.5,
        nextReviewDate: DateTime.now(),
      );
      idCounter++;
    }

    final allStages = [
      ...CurriculumSeedData.englishStages,
      ...CurriculumSeedData.chineseStages,
    ];
    for (final stage in allStages) {
      for (final unit in stage.units) {
        final wordsWithIds = <VocabularyItem>[];
        for (final word in unit.words) {
          final wordWithId = word.copyWith(id: idCounter);
          _inMemoryVocab.add(wordWithId);
          _inMemorySrs[idCounter] = SrsProgress(
            vocabId: idCounter,
            repetitionCount: 0,
            intervalDays: 1,
            easeFactor: 2.5,
            nextReviewDate: DateTime.now(),
          );
          wordsWithIds.add(wordWithId);
          idCounter++;
        }
        _inMemoryUnits.add(unit.copyWith(words: wordsWithIds));
      }
    }
  }

  Future<Database?> get database async {
    if (kIsWeb) {
      _useInMemoryFallback = true;
      _initInMemoryFallback();
      return null;
    }
    if (_useInMemoryFallback) return null;
    if (_db != null) return _db!;
    try {
      _db = await _initDatabase();
      return _db!;
    } catch (e) {
      debugPrint('Fallback to in-memory database: $e');
      _useInMemoryFallback = true;
      _initInMemoryFallback();
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        'vocivo_web.db',
        version: 4,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    // NOTE: sqfliteFfiInit() đã được gọi trong main() — không cần gọi lại ở đây
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      databaseFactory = databaseFactoryFfi;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, 'vocivo', 'vocivo.db');
    final dbFile = File(dbPath);
    if (!await dbFile.parent.exists()) {
      await dbFile.parent.create(recursive: true);
    }

    // Auto-migrate legacy lingocraft.db if user already had data
    final legacyPath = p.join(docDir.path, 'lingo_craft', 'lingocraft.db');
    final legacyFile = File(legacyPath);
    if (!await dbFile.exists() && await legacyFile.exists()) {
      try {
        await legacyFile.copy(dbPath);
        debugPrint(
          'Vocivo: Successfully migrated database from $legacyPath to $dbPath',
        );
      } catch (e) {
        debugPrint('Vocivo: Legacy db copy note: $e');
      }
    }

    return await openDatabase(
      dbPath,
      version: 4,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) =>
      db.execute('PRAGMA foreign_keys = ON');

  /// Migration handler — chạy khi user upgrade từ version cũ
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('DB upgrade: v$oldVersion → v$newVersion');
    // v1 → v2: thêm bảng daily_activities để lưu lịch sử học thực tế
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_activities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          cards_reviewed INTEGER DEFAULT 0,
          speaking_practiced INTEGER DEFAULT 0,
          words_added INTEGER DEFAULT 0,
          xp_gained INTEGER DEFAULT 0,
          UNIQUE(date)
        )
      ''');
    }
    // v2 → v3: thêm bảng lộ trình học (learning_units, unit_vocabulary, unit_progress)
    if (oldVersion < 3) {
      await _createCurriculumTables(db);
      await _seedDefaultCurriculum(db);
    }
    // v3 → v4: hồ sơ học, phiên học, kết quả từng bài và mastery theo kỹ năng.
    // onUpgrade của sqflite chạy trong transaction; các CREATE/ALTER dưới đây
    // được viết idempotent để có thể phục hồi an toàn sau một migration dở dang.
    if (oldVersion < 4) {
      await _createLearningV2Tables(db);
      await _ensureColumn(
        db,
        'unit_progress',
        'current_lesson',
        'INTEGER DEFAULT 0',
      );
      await _ensureColumn(
        db,
        'unit_progress',
        'checkpoint_score',
        'INTEGER DEFAULT 0',
      );
    }
  }

  @visibleForTesting
  Future<void> migrateForTest(Database db, int oldVersion, int newVersion) =>
      _onUpgrade(db, oldVersion, newVersion);

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vocabulary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        language_code TEXT NOT NULL,
        word TEXT NOT NULL,
        phonetic TEXT,
        han_viet TEXT,
        meaning_vi TEXT NOT NULL,
        word_type TEXT,
        level TEXT,
        examples_json TEXT,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE srs_progress (
        vocab_id INTEGER PRIMARY KEY,
        repetition_count INTEGER DEFAULT 0,
        interval_days INTEGER DEFAULT 1,
        ease_factor REAL DEFAULT 2.5,
        next_review_date DATETIME NOT NULL,
        last_reviewed_at DATETIME,
        FOREIGN KEY (vocab_id) REFERENCES vocabulary (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE vocab_tags (
        vocab_id INTEGER,
        tag_id INTEGER,
        PRIMARY KEY (vocab_id, tag_id),
        FOREIGN KEY (vocab_id) REFERENCES vocabulary (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    // Bảng lưu lịch sử hoạt động học mỗi ngày (dùng cho Progress screen)
    await db.execute('''
      CREATE TABLE daily_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        cards_reviewed INTEGER DEFAULT 0,
        speaking_practiced INTEGER DEFAULT 0,
        words_added INTEGER DEFAULT 0,
        xp_gained INTEGER DEFAULT 0,
        UNIQUE(date)
      )
    ''');

    await db.insert('tags', {'name': 'Từ vựng cốt lõi'});
    await db.insert('tags', {'name': 'Giao tiếp hàng ngày'});
    await db.insert('tags', {'name': 'Công việc & Kinh tế'});

    for (final item in SeedData.initialVocabulary) {
      final vocabId = await db.insert('vocabulary', item.toMap());
      await db.insert('srs_progress', {
        'vocab_id': vocabId,
        'repetition_count': 0,
        'interval_days': 1,
        'ease_factor': 2.5,
        'next_review_date': DateTime.now().toIso8601String(),
        'last_reviewed_at': null,
      });
      await db.insert('vocab_tags', {'vocab_id': vocabId, 'tag_id': 1});
    }

    await db.insert('settings', {'key': 'streak_count', 'value': '1'});
    await db.insert('settings', {
      'key': 'last_active_date',
      'value': DateTime.now().toIso8601String(),
    });

    await _createCurriculumTables(db);
    await _seedDefaultCurriculum(db);
    await _createLearningV2Tables(db);
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _createLearningV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_profiles (
        course_code TEXT PRIMARY KEY,
        goal TEXT NOT NULL,
        level TEXT NOT NULL,
        daily_minutes INTEGER NOT NULL DEFAULT 15,
        study_days TEXT NOT NULL,
        reminder_time TEXT,
        updated_at DATETIME NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_definitions (
        id TEXT PRIMARY KEY,
        unit_id TEXT NOT NULL,
        course_code TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        estimated_minutes INTEGER NOT NULL DEFAULT 5,
        exercises_json TEXT NOT NULL,
        updated_at DATETIME NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_sessions (
        id TEXT PRIMARY KEY,
        course_code TEXT NOT NULL,
        session_type TEXT NOT NULL,
        status TEXT NOT NULL,
        unit_id TEXT,
        lesson_id TEXT,
        current_step INTEGER NOT NULL DEFAULT 0,
        total_steps INTEGER NOT NULL DEFAULT 0,
        score INTEGER NOT NULL DEFAULT 0,
        xp_earned INTEGER NOT NULL DEFAULT 0,
        started_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        completed_at DATETIME
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_learning_sessions_resume
      ON learning_sessions(course_code, status, updated_at)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_attempts (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        vocab_id INTEGER,
        skill TEXT NOT NULL,
        response TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        score INTEGER NOT NULL DEFAULT 0,
        feedback TEXT,
        created_at DATETIME NOT NULL,
        UNIQUE(session_id, exercise_id),
        FOREIGN KEY (session_id) REFERENCES learning_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (vocab_id) REFERENCES vocabulary(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercise_attempts_mistakes
      ON exercise_attempts(skill, is_correct, created_at)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS skill_mastery (
        id TEXT PRIMARY KEY,
        course_code TEXT NOT NULL,
        skill TEXT NOT NULL,
        vocab_id INTEGER,
        mastery REAL NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        updated_at DATETIME NOT NULL,
        FOREIGN KEY (vocab_id) REFERENCES vocabulary(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createCurriculumTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_units (
        id TEXT PRIMARY KEY,
        stage_id TEXT NOT NULL,
        stage_title TEXT NOT NULL,
        language_code TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        icon_name TEXT,
        level TEXT,
        is_ai_generated INTEGER DEFAULT 0,
        order_index INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS unit_vocabulary (
        unit_id TEXT NOT NULL,
        vocab_id INTEGER NOT NULL,
        PRIMARY KEY (unit_id, vocab_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS unit_progress (
        unit_id TEXT PRIMARY KEY,
        is_completed INTEGER DEFAULT 0,
        completed_at DATETIME,
        last_score INTEGER DEFAULT 0,
        current_lesson INTEGER DEFAULT 0,
        checkpoint_score INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _seedDefaultCurriculum(Database db) async {
    final countRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM learning_units',
    );
    final count = (countRes.first['count'] as int?) ?? 0;
    if (count > 0) return;

    final allStages = [
      ...CurriculumSeedData.englishStages,
      ...CurriculumSeedData.chineseStages,
    ];

    for (final stage in allStages) {
      for (final unit in stage.units) {
        await db.insert(
          'learning_units',
          unit.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        for (final word in unit.words) {
          final vocabId = await db.insert(
            'vocabulary',
            word.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (vocabId > 0) {
            await db.insert('srs_progress', {
              'vocab_id': vocabId,
              'repetition_count': 0,
              'interval_days': 1,
              'ease_factor': 2.5,
              'next_review_date': DateTime.now().toIso8601String(),
              'last_reviewed_at': null,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await db.insert('unit_vocabulary', {
              'unit_id': unit.id,
              'vocab_id': vocabId,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }
    }
  }

  // -------------------------------------------------------------
  // VOCABULARY CRUD
  // -------------------------------------------------------------

  Future<int> insertVocabulary(VocabularyItem item, {List<int>? tagIds}) async {
    final db = await database;
    if (db == null) {
      final nextId = _inMemoryVocab.isEmpty
          ? 1
          : (_inMemoryVocab
                    .map((e) => e.id ?? 0)
                    .reduce((a, b) => a > b ? a : b) +
                1);
      final newItem = item.copyWith(id: nextId);
      _inMemoryVocab.insert(0, newItem);
      _inMemorySrs[nextId] = SrsProgress(
        vocabId: nextId,
        nextReviewDate: DateTime.now(),
      );
      return nextId;
    }

    return db.transaction((txn) async {
      final id = await txn.insert('vocabulary', item.toMap());
      await txn.insert('srs_progress', {
        'vocab_id': id,
        'repetition_count': 0,
        'interval_days': 1,
        'ease_factor': 2.5,
        'next_review_date': DateTime.now().toIso8601String(),
        'last_reviewed_at': null,
      });

      if (tagIds != null) {
        for (final tagId in tagIds) {
          await txn.insert('vocab_tags', {'vocab_id': id, 'tag_id': tagId});
        }
      }
      return id;
    });
  }

  Future<bool> isWordSaved(String word, String languageCode) async {
    final db = await database;
    if (db == null) {
      return _inMemoryVocab.any(
        (e) =>
            e.word.trim().toLowerCase() == word.trim().toLowerCase() &&
            e.languageCode == languageCode.toUpperCase(),
      );
    }

    final res = await db.query(
      'vocabulary',
      where: 'LOWER(word) = ? AND language_code = ?',
      whereArgs: [word.toLowerCase().trim(), languageCode.toUpperCase()],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<int> deleteVocabulary(int id) async {
    final db = await database;
    if (db == null) {
      _inMemoryVocab.removeWhere((e) => e.id == id);
      _inMemorySrs.remove(id);
      _inMemoryMastery.removeWhere((_, value) => value.vocabularyId == id);
      return 1;
    }

    // Wrap trong transaction để đảm bảo atomicity.
    // ON DELETE CASCADE đã xử lý srs_progress và vocab_tags tự động,
    // nhưng ta vẫn wrap để bắt lỗi toàn bộ.
    return await db.transaction((txn) async {
      // Xóa bảng liên kết trước (safe nếu CASCADE chưa được enable)
      await txn.delete('srs_progress', where: 'vocab_id = ?', whereArgs: [id]);
      await txn.delete('vocab_tags', where: 'vocab_id = ?', whereArgs: [id]);
      await txn.delete(
        'unit_vocabulary',
        where: 'vocab_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'exercise_attempts',
        {'vocab_id': null},
        where: 'vocab_id = ?',
        whereArgs: [id],
      );
      await txn.delete('skill_mastery', where: 'vocab_id = ?', whereArgs: [id]);
      return await txn.delete('vocabulary', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> updateVocabularyNotes(int id, String notes) async {
    final db = await database;
    if (db == null) {
      final idx = _inMemoryVocab.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _inMemoryVocab[idx] = _inMemoryVocab[idx].copyWith(notes: notes);
      }
      return;
    }
    await db.update(
      'vocabulary',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<VocabularyItem>> searchVocabulary({
    required String query,
    required String languageCode,
    int? tagId,
    String? level,
  }) async {
    final db = await database;
    if (db == null) {
      final trimmed = query.trim().toLowerCase();
      return _inMemoryVocab.where((v) {
        if (v.languageCode != languageCode.toUpperCase()) return false;
        if (level != null && level.isNotEmpty && v.level != level) return false;
        if (trimmed.isEmpty) return true;
        return v.word.toLowerCase().contains(trimmed) ||
            v.meaningVi.toLowerCase().contains(trimmed) ||
            (v.phonetic != null &&
                v.phonetic!.toLowerCase().contains(trimmed)) ||
            (v.hanViet != null && v.hanViet!.toLowerCase().contains(trimmed));
      }).toList();
    }

    // Build query với parameterized args để tránh SQL injection
    String sql = 'SELECT v.* FROM vocabulary v';
    final List<dynamic> args = [];

    if (tagId != null) {
      // tagId dùng ? placeholder thay vì string interpolation
      sql += ' INNER JOIN vocab_tags vt ON v.id = vt.vocab_id WHERE vt.tag_id = ? AND ';
      args.add(tagId);
    } else {
      sql += ' WHERE ';
    }

    sql += ' v.language_code = ?';
    args.add(languageCode.toUpperCase());

    final trimmed = query.trim().toLowerCase();

    if (level != null && level.isNotEmpty) {
      sql += ' AND v.level = ?';
      args.add(level);
    }

    if (trimmed.isNotEmpty) {
      sql += ' AND (LOWER(v.word) LIKE ? OR LOWER(v.meaning_vi) LIKE ? OR LOWER(v.phonetic) LIKE ? OR LOWER(v.han_viet) LIKE ?)';
      args.addAll(['%$trimmed%', '%$trimmed%', '%$trimmed%', '%$trimmed%']);
    }

    sql += ' ORDER BY v.id DESC';
    final rows = await db.rawQuery(sql, args);
    return rows.map((e) => VocabularyItem.fromMap(e)).toList();
  }

  /// Lấy tất cả từ vựng. Hỗ trợ pagination qua [limit] và [offset].
  /// - [limit] = null → lấy toàn bộ (backward compat)
  /// - [limit] = 50, [offset] = 0 → trang đầu tiên
  Future<List<VocabularyItem>> getAllVocabulary({
    String? languageCode,
    int? limit,
    int offset = 0,
  }) async {
    final db = await database;
    if (db == null) {
      var result = languageCode == null
          ? List<VocabularyItem>.from(_inMemoryVocab)
          : _inMemoryVocab
                .where((e) => e.languageCode == languageCode.toUpperCase())
                .toList();
      if (limit != null) {
        result = result.skip(offset).take(limit).toList();
      }
      return result;
    }

    final rows = await db.query(
      'vocabulary',
      where: languageCode != null ? 'language_code = ?' : null,
      whereArgs: languageCode != null ? [languageCode.toUpperCase()] : null,
      orderBy: 'id DESC',
      limit: limit,
      offset: limit != null ? offset : null,
    );
    return rows.map((e) => VocabularyItem.fromMap(e)).toList();
  }

  // -------------------------------------------------------------
  // SRS PROGRESS
  // -------------------------------------------------------------

  Future<SrsProgress?> getSrsProgress(int vocabId) async {
    final db = await database;
    if (db == null) {
      return _inMemorySrs[vocabId];
    }

    final rows = await db.query(
      'srs_progress',
      where: 'vocab_id = ?',
      whereArgs: [vocabId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SrsProgress.fromMap(rows.first);
  }

  Future<void> updateSrsProgress(SrsProgress progress) async {
    final db = await database;
    if (db == null) {
      _inMemorySrs[progress.vocabId] = progress;
      return;
    }

    await db.insert(
      'srs_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDueReviews({
    String? languageCode,
  }) async {
    final db = await database;
    if (db == null) {
      final now = DateTime.now();
      final dueVocabs = _inMemoryVocab.where((v) {
        if (languageCode != null &&
            v.languageCode != languageCode.toUpperCase()) {
          return false;
        }
        final srs = _inMemorySrs[v.id];
        return srs == null || !srs.nextReviewDate.isAfter(now);
      }).toList();

      return dueVocabs.map((v) {
        final map = v.toMap();
        final srs = _inMemorySrs[v.id];
        map['repetition_count'] = srs?.repetitionCount ?? 0;
        map['interval_days'] = srs?.intervalDays ?? 1;
        map['ease_factor'] = srs?.easeFactor ?? 2.5;
        map['next_review_date'] =
            srs?.nextReviewDate.toIso8601String() ?? now.toIso8601String();
        return map;
      }).toList();
    }

    final nowIso = DateTime.now().toIso8601String();
    String sql = '''
      SELECT v.*, s.repetition_count, s.interval_days, s.ease_factor, s.next_review_date, s.last_reviewed_at
      FROM vocabulary v
      INNER JOIN srs_progress s ON v.id = s.vocab_id
      WHERE s.next_review_date <= ?
    ''';
    List<dynamic> args = [nowIso];
    if (languageCode != null) {
      sql += ' AND v.language_code = ?';
      args.add(languageCode.toUpperCase());
    }
    sql += ' ORDER BY s.next_review_date ASC';
    return await db.rawQuery(sql, args);
  }

  Future<int> getDueCount({String? languageCode}) async {
    final db = await database;
    if (db == null) {
      final list = await getDueReviews(languageCode: languageCode);
      return list.length;
    }

    final nowIso = DateTime.now().toIso8601String();
    String sql = '''
      SELECT COUNT(*) as count
      FROM vocabulary v
      INNER JOIN srs_progress s ON v.id = s.vocab_id
      WHERE s.next_review_date <= ?
    ''';
    List<dynamic> args = [nowIso];
    if (languageCode != null) {
      sql += ' AND v.language_code = ?';
      args.add(languageCode.toUpperCase());
    }
    final res = await db.rawQuery(sql, args);
    return (res.first['count'] as int?) ?? 0;
  }

  // -------------------------------------------------------------
  // TAGS
  // -------------------------------------------------------------

  Future<List<TagModel>> getAllTags() async {
    final db = await database;
    if (db == null) return List.from(_inMemoryTags);
    final rows = await db.query('tags', orderBy: 'id ASC');
    return rows.map((e) => TagModel.fromMap(e)).toList();
  }

  Future<int> addTag(String name) async {
    final db = await database;
    if (db == null) {
      // Fix: dùng max ID thay vì length để tránh conflict khi có tag bị xóa
      final maxId = _inMemoryTags.isEmpty
          ? 0
          : _inMemoryTags.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b);
      final nextId = maxId + 1;
      _inMemoryTags.add(TagModel(id: nextId, name: name.trim()));
      return nextId;
    }
    return await db.insert('tags', {
      'name': name.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // -------------------------------------------------------------
  // SETTINGS & STREAK
  // -------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final db = await database;
    if (db == null) return _inMemorySettings[key];
    final res = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['value']?.toString();
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    if (db == null) {
      _inMemorySettings[key] = value;
      return;
    }
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> checkAndUpdateStreak() async {
    final lastActiveStr = await getSetting('last_active_date');
    final streakStr = await getSetting('streak_count');
    int currentStreak = int.tryParse(streakStr ?? '1') ?? 1;

    final now = DateTime.now();
    if (lastActiveStr != null) {
      final lastActive = DateTime.tryParse(lastActiveStr);
      if (lastActive != null) {
        final daysDiff = DateTime(now.year, now.month, now.day)
            .difference(
              DateTime(lastActive.year, lastActive.month, lastActive.day),
            )
            .inDays;
        if (daysDiff == 1) {
          currentStreak += 1;
        } else if (daysDiff > 1) {
          currentStreak = 1;
        }
      }
    }
    await setSetting('streak_count', currentStreak.toString());
    await setSetting('last_active_date', now.toIso8601String());
    return currentStreak;
  }

  // -------------------------------------------------------------
  // PROGRESS & DAILY ACTIVITIES (real data cho ProgressProvider)
  // -------------------------------------------------------------

  /// Đếm số từ vựng đã được "mastered" — repetition_count >= 5
  Future<int> getMasteredWordsCount({String? languageCode}) async {
    final db = await database;
    if (db == null) {
      return _inMemorySrs.values.where((s) {
        if (s.repetitionCount < 5) return false;
        if (languageCode == null) return true;
        return _inMemoryVocab.any(
          (word) =>
              word.id == s.vocabId &&
              word.languageCode == languageCode.toUpperCase(),
        );
      }).length;
    }
    String sql = '''
      SELECT COUNT(*) as count
      FROM srs_progress s
      INNER JOIN vocabulary v ON s.vocab_id = v.id
      WHERE s.repetition_count >= 5
    ''';
    final args = <dynamic>[];
    if (languageCode != null) {
      sql += ' AND v.language_code = ?';
      args.add(languageCode.toUpperCase());
    }
    final res = await db.rawQuery(sql, args);
    return (res.first['count'] as int?) ?? 0;
  }

  /// Đếm tổng số từ trong notebook
  Future<int> getTotalWordsCount({String? languageCode}) async {
    final db = await database;
    if (db == null) {
      if (languageCode == null) return _inMemoryVocab.length;
      return _inMemoryVocab
          .where((e) => e.languageCode == languageCode.toUpperCase())
          .length;
    }
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM vocabulary${languageCode != null ? ' WHERE language_code = ?' : ''}',
      languageCode != null ? [languageCode.toUpperCase()] : null,
    );
    return (res.first['count'] as int?) ?? 0;
  }

  /// Ghi nhận hoạt động học trong ngày (upsert theo date)
  Future<void> recordDailyActivity({
    int cardsReviewed = 0,
    int speakingPracticed = 0,
    int wordsAdded = 0,
    int xpGained = 0,
  }) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(
      0,
      10,
    ); // YYYY-MM-DD
    if (db == null) return; // in-memory: skip persistence

    // Upsert: nếu đã có record hôm nay thì cộng dồn
    await db.execute(
      '''
      INSERT INTO daily_activities (date, cards_reviewed, speaking_practiced, words_added, xp_gained)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(date) DO UPDATE SET
        cards_reviewed    = cards_reviewed + excluded.cards_reviewed,
        speaking_practiced = speaking_practiced + excluded.speaking_practiced,
        words_added       = words_added + excluded.words_added,
        xp_gained         = xp_gained + excluded.xp_gained
    ''',
      [today, cardsReviewed, speakingPracticed, wordsAdded, xpGained],
    );
  }

  /// Lấy lịch sử hoạt động [days] ngày gần nhất
  Future<List<Map<String, dynamic>>> getRecentActivities({
    int days = 28,
  }) async {
    final db = await database;
    if (db == null) return []; // in-memory: trả về rỗng

    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
    return await db.query(
      'daily_activities',
      where: 'date >= ?',
      whereArgs: [cutoff],
      orderBy: 'date ASC',
    );
  }

  // -------------------------------------------------------------
  // CURRICULUM UNITS & PROGRESS
  // -------------------------------------------------------------

  /// Lưu một Unit mới (do AI tạo hoặc người dùng thêm) kèm danh sách từ vựng
  Future<void> saveLearningUnit(
    CurriculumUnit unit,
    List<VocabularyItem> items,
  ) async {
    final db = await database;
    if (db == null) {
      int nextId = _inMemoryVocab.isEmpty
          ? 1
          : (_inMemoryVocab
                    .map((e) => e.id ?? 0)
                    .reduce((a, b) => a > b ? a : b) +
                1);
      final savedWords = <VocabularyItem>[];
      for (final word in items) {
        final withId = word.copyWith(id: nextId);
        _inMemoryVocab.add(withId);
        _inMemorySrs[nextId] = SrsProgress(
          vocabId: nextId,
          repetitionCount: 0,
          intervalDays: 1,
          easeFactor: 2.5,
          nextReviewDate: DateTime.now(),
        );
        savedWords.add(withId);
        nextId++;
      }
      final newUnit = unit.copyWith(words: savedWords);
      _inMemoryUnits.removeWhere((u) => u.id == unit.id);
      _inMemoryUnits.add(newUnit);
      return;
    }

    await db.transaction((txn) async {
      await txn.insert(
        'learning_units',
        unit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final item in items) {
        int vocabId;
        if (item.id != null) {
          vocabId = item.id!;
        } else {
          vocabId = await txn.insert('vocabulary', item.toMap());
          await txn.insert('srs_progress', {
            'vocab_id': vocabId,
            'repetition_count': 0,
            'interval_days': 1,
            'ease_factor': 2.5,
            'next_review_date': DateTime.now().toIso8601String(),
            'last_reviewed_at': null,
          });
        }
        await txn.insert('unit_vocabulary', {
          'unit_id': unit.id,
          'vocab_id': vocabId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// Lấy toàn bộ Units theo ngôn ngữ ('EN' hoặc 'ZH'), kèm danh sách từ và trạng thái hoàn thành
  Future<List<CurriculumUnit>> getLearningUnits(String languageCode) async {
    final db = await database;
    if (db == null) {
      return _inMemoryUnits
          .where(
            (u) => u.languageCode.toUpperCase() == languageCode.toUpperCase(),
          )
          .map((u) {
            final isDone = _inMemoryUnitProgress[u.id] ?? u.isCompleted;
            final score = _inMemoryUnitScores[u.id] ?? u.lastScore;
            return u.copyWith(isCompleted: isDone, lastScore: score);
          })
          .toList();
    }

    // Đảm bảo default curriculum đã có trong db
    await _seedDefaultCurriculum(db);

    final unitRows = await db.query(
      'learning_units',
      where: 'language_code = ?',
      whereArgs: [languageCode.toUpperCase()],
      orderBy: 'order_index ASC, created_at ASC',
    );

    final List<CurriculumUnit> results = [];
    for (final row in unitRows) {
      final unitId = row['id'] as String;

      // Get progress
      final progressRows = await db.query(
        'unit_progress',
        where: 'unit_id = ?',
        whereArgs: [unitId],
        limit: 1,
      );
      bool isCompleted = false;
      int? lastScore;
      DateTime? completedAt;
      if (progressRows.isNotEmpty) {
        isCompleted = (progressRows.first['is_completed'] as int? ?? 0) == 1;
        lastScore = progressRows.first['last_score'] as int?;
        final dtStr = progressRows.first['completed_at'] as String?;
        if (dtStr != null) completedAt = DateTime.tryParse(dtStr);
      }

      // Get vocabulary items
      final vocabRows = await db.rawQuery(
        '''
        SELECT v.* FROM vocabulary v
        INNER JOIN unit_vocabulary uv ON v.id = uv.vocab_id
        WHERE uv.unit_id = ?
        ORDER BY v.id ASC
      ''',
        [unitId],
      );

      final words = vocabRows.map((r) => VocabularyItem.fromMap(r)).toList();

      results.add(
        CurriculumUnit.fromMap(
          row,
          words: words,
          isCompleted: isCompleted,
          lastScore: lastScore,
          completedAt: completedAt,
        ),
      );
    }
    return results;
  }

  /// Cập nhật tiến độ hoàn thành và điểm số của Unit
  Future<void> updateUnitProgress(
    String unitId, {
    required bool isCompleted,
    int? score,
  }) async {
    final db = await database;
    if (db == null) {
      _inMemoryUnitProgress[unitId] = isCompleted;
      if (score != null) _inMemoryUnitScores[unitId] = score;
      return;
    }

    await db.execute(
      '''
      INSERT INTO unit_progress (unit_id, is_completed, completed_at, last_score)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(unit_id) DO UPDATE SET
        is_completed = excluded.is_completed,
        completed_at = excluded.completed_at,
        last_score = excluded.last_score
    ''',
      [
        unitId,
        isCompleted ? 1 : 0,
        isCompleted ? DateTime.now().toIso8601String() : null,
        score ?? 0,
      ],
    );
  }

  /// Xóa một Unit do AI tạo
  Future<void> deleteLearningUnit(String unitId) async {
    final db = await database;
    if (db == null) {
      _inMemoryUnits.removeWhere((u) => u.id == unitId);
      _inMemoryUnitProgress.remove(unitId);
      _inMemoryUnitScores.remove(unitId);
      return;
    }

    await db.transaction((txn) async {
      await txn.delete(
        'unit_vocabulary',
        where: 'unit_id = ?',
        whereArgs: [unitId],
      );
      await txn.delete(
        'unit_progress',
        where: 'unit_id = ?',
        whereArgs: [unitId],
      );
      await txn.delete('learning_units', where: 'id = ?', whereArgs: [unitId]);
    });
  }

  // -------------------------------------------------------------
  // VOCIVO V2 — PROFILE, SESSIONS, ATTEMPTS & SKILL MASTERY
  // -------------------------------------------------------------

  Future<LearningProfile> getLearningProfile(String courseCode) async {
    final code = courseCode.toUpperCase();
    final db = await database;
    if (db == null) {
      return _inMemoryProfiles.putIfAbsent(
        code,
        () => LearningProfile.defaults(code),
      );
    }
    final rows = await db.query(
      'learning_profiles',
      where: 'course_code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isNotEmpty) return LearningProfile.fromMap(rows.first);
    final profile = LearningProfile.defaults(code);
    await db.insert('learning_profiles', profile.toMap());
    return profile;
  }

  Future<void> saveLearningProfile(LearningProfile profile) async {
    final db = await database;
    if (db == null) {
      _inMemoryProfiles[profile.courseCode] = profile;
      return;
    }
    await db.insert(
      'learning_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LearningSession?> getActiveLearningSession(String courseCode) async {
    final code = courseCode.toUpperCase();
    final db = await database;
    if (db == null) {
      final sessions =
          _inMemorySessions.values
              .where(
                (s) =>
                    s.courseCode == code &&
                    s.status == LearningSessionStatus.inProgress,
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions.firstOrNull;
    }
    final rows = await db.query(
      'learning_sessions',
      where: 'course_code = ? AND status = ?',
      whereArgs: [code, LearningSessionStatus.inProgress.name],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LearningSession.fromMap(rows.first);
  }

  Future<void> saveLessonDefinition(LessonDefinition lesson) async {
    final db = await database;
    if (db == null) {
      _inMemoryLessons[lesson.id] = lesson;
      return;
    }
    await db.insert(
      'lesson_definitions',
      lesson.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LessonDefinition?> getLessonDefinition(String lessonId) async {
    final db = await database;
    if (db == null) return _inMemoryLessons[lessonId];
    final rows = await db.query(
      'lesson_definitions',
      where: 'id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    return rows.isEmpty ? null : LessonDefinition.fromMap(rows.first);
  }

  Future<void> saveLearningSession(LearningSession session) async {
    final db = await database;
    if (db == null) {
      _inMemorySessions[session.id] = session;
      return;
    }
    await db.insert(
      'learning_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Hoàn tất phiên, tiến độ unit và daily activity trong cùng một transaction.
  /// Điều kiện `status = inProgress` biến thao tác này thành idempotent, nên
  /// double-click hoặc retry sau lỗi mạng/IO không thể cộng XP hai lần.
  Future<bool> completeLearningSession(
    LearningSession completed, {
    required int averageScore,
    required int speakingPracticed,
  }) async {
    final db = await database;
    if (db == null) {
      final current = _inMemorySessions[completed.id];
      if (current?.status != LearningSessionStatus.inProgress) return false;
      _inMemorySessions[completed.id] = completed;
      if (completed.unitId != null) {
        _inMemoryUnitProgress[completed.unitId!] = true;
        _inMemoryUnitScores[completed.unitId!] = averageScore;
      }
      return true;
    }
    return _completeLearningSessionInDatabase(
      db,
      completed,
      averageScore: averageScore,
      speakingPracticed: speakingPracticed,
    );
  }

  @visibleForTesting
  Future<bool> completeLearningSessionForTest(
    Database db,
    LearningSession completed, {
    required int averageScore,
    required int speakingPracticed,
  }) => _completeLearningSessionInDatabase(
    db,
    completed,
    averageScore: averageScore,
    speakingPracticed: speakingPracticed,
  );

  Future<bool> _completeLearningSessionInDatabase(
    Database db,
    LearningSession completed, {
    required int averageScore,
    required int speakingPracticed,
  }) {
    return db.transaction((txn) async {
      final updated = await txn.update(
        'learning_sessions',
        completed.toMap(),
        where: 'id = ? AND status = ?',
        whereArgs: [completed.id, LearningSessionStatus.inProgress.name],
      );
      if (updated == 0) return false;

      if (completed.unitId != null) {
        await txn.execute(
          '''
          INSERT INTO unit_progress
            (unit_id, is_completed, completed_at, last_score, current_lesson, checkpoint_score)
          VALUES (?, 1, ?, ?, 1, ?)
          ON CONFLICT(unit_id) DO UPDATE SET
            is_completed = 1,
            completed_at = excluded.completed_at,
            last_score = excluded.last_score,
            current_lesson = MAX(current_lesson, excluded.current_lesson),
            checkpoint_score = MAX(checkpoint_score, excluded.checkpoint_score)
        ''',
          [
            completed.unitId,
            completed.completedAt?.toIso8601String(),
            averageScore,
            averageScore,
          ],
        );
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      await txn.execute(
        '''
        INSERT INTO daily_activities
          (date, cards_reviewed, speaking_practiced, words_added, xp_gained)
        VALUES (?, ?, ?, 0, ?)
        ON CONFLICT(date) DO UPDATE SET
          cards_reviewed = cards_reviewed + excluded.cards_reviewed,
          speaking_practiced = speaking_practiced + excluded.speaking_practiced,
          xp_gained = xp_gained + excluded.xp_gained
      ''',
        [today, completed.totalSteps, speakingPracticed, completed.xpEarned],
      );
      return true;
    });
  }

  /// Lưu attempt theo UNIQUE(session_id, exercise_id) và chỉ cập nhật mastery
  /// khi attempt thực sự được thêm. Nhờ vậy retry UI không cộng tiến độ hai lần.
  Future<bool> recordExerciseAttempt(
    ExerciseAttempt attempt, {
    required String courseCode,
    LearningSession? advancedSession,
  }) async {
    final code = courseCode.toUpperCase();
    final masteryId =
        '${code}_${attempt.skill.name}_${attempt.vocabularyId ?? 0}';
    final outcome = (attempt.score / 100).clamp(0.0, 1.0);
    final db = await database;
    if (db == null) {
      if (_inMemoryAttempts.any(
        (e) =>
            e.sessionId == attempt.sessionId &&
            e.exerciseId == attempt.exerciseId,
      )) {
        return false;
      }
      _inMemoryAttempts.add(attempt);
      final previous = _inMemoryMastery[masteryId];
      final nextAttempts = (previous?.attempts ?? 0) + 1;
      final nextMastery = previous == null
          ? outcome
          : (previous.mastery * 0.75 + outcome * 0.25).clamp(0.0, 1.0);
      _inMemoryMastery[masteryId] = SkillMastery(
        courseCode: code,
        skill: attempt.skill,
        vocabularyId: attempt.vocabularyId,
        mastery: nextMastery,
        attempts: nextAttempts,
        updatedAt: DateTime.now(),
      );
      if (advancedSession != null) {
        _inMemorySessions[advancedSession.id] = advancedSession;
      }
      return true;
    }

    return db.transaction((txn) async {
      final inserted = await txn.insert(
        'exercise_attempts',
        attempt.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (inserted == 0) return false;

      final rows = await txn.query(
        'skill_mastery',
        where: 'id = ?',
        whereArgs: [masteryId],
        limit: 1,
      );
      final previous = rows.isEmpty ? null : SkillMastery.fromMap(rows.first);
      final nextAttempts = (previous?.attempts ?? 0) + 1;
      final nextMastery = previous == null
          ? outcome
          : (previous.mastery * 0.75 + outcome * 0.25).clamp(0.0, 1.0);
      await txn.insert('skill_mastery', {
        'id': masteryId,
        'course_code': code,
        'skill': attempt.skill.name,
        'vocab_id': attempt.vocabularyId,
        'mastery': nextMastery,
        'attempts': nextAttempts,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (advancedSession != null) {
        final sessionUpdated = await txn.update(
          'learning_sessions',
          advancedSession.toMap(),
          where: 'id = ? AND status = ?',
          whereArgs: [
            advancedSession.id,
            LearningSessionStatus.inProgress.name,
          ],
        );
        if (sessionUpdated != 1) {
          throw StateError(
            'Không thể cập nhật phiên ${advancedSession.id} sau attempt.',
          );
        }
      }
      return true;
    });
  }

  Future<List<SkillMastery>> getSkillMastery(String courseCode) async {
    final code = courseCode.toUpperCase();
    final db = await database;
    if (db == null) {
      return _inMemoryMastery.values
          .where((m) => m.courseCode == code)
          .toList();
    }
    final rows = await db.query(
      'skill_mastery',
      where: 'course_code = ?',
      whereArgs: [code],
      orderBy: 'mastery ASC, updated_at DESC',
    );
    return rows.map(SkillMastery.fromMap).toList();
  }

  Future<int> getRecentMistakeCount(String courseCode, {int days = 30}) async {
    final code = courseCode.toUpperCase();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final db = await database;
    if (db == null) {
      return _inMemoryAttempts.where((attempt) {
        final session = _inMemorySessions[attempt.sessionId];
        return !attempt.isCorrect &&
            attempt.createdAt.isAfter(cutoff) &&
            session?.courseCode == code;
      }).length;
    }
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM exercise_attempts a
      INNER JOIN learning_sessions s ON s.id = a.session_id
      WHERE s.course_code = ? AND a.is_correct = 0 AND a.created_at >= ?
    ''',
      [code, cutoff.toIso8601String()],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> updateUnitLessonProgress(
    String unitId, {
    required int currentLesson,
    int? checkpointScore,
  }) async {
    final db = await database;
    if (db == null) return;
    await db.execute(
      '''
      INSERT INTO unit_progress
        (unit_id, is_completed, completed_at, last_score, current_lesson, checkpoint_score)
      VALUES (?, 0, NULL, 0, ?, ?)
      ON CONFLICT(unit_id) DO UPDATE SET
        current_lesson = MAX(current_lesson, excluded.current_lesson),
        checkpoint_score = MAX(checkpoint_score, excluded.checkpoint_score)
    ''',
      [unitId, currentLesson, checkpointScore ?? 0],
    );
  }
}
