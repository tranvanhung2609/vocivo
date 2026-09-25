import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../../models/vocabulary_item.dart';
import '../../models/srs_progress.dart';
import '../../models/tag_model.dart';
import '../constants/seed_data.dart';

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
        version: 2,
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
        debugPrint('Vocivo: Successfully migrated database from $legacyPath to $dbPath');
      } catch (e) {
        debugPrint('Vocivo: Legacy db copy note: $e');
      }
    }

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

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
  }

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
      await db.insert('vocab_tags', {
        'vocab_id': vocabId,
        'tag_id': 1,
      });
    }

    await db.insert('settings', {'key': 'streak_count', 'value': '1'});
    await db.insert('settings', {'key': 'last_active_date', 'value': DateTime.now().toIso8601String()});
  }

  // -------------------------------------------------------------
  // VOCABULARY CRUD
  // -------------------------------------------------------------

  Future<int> insertVocabulary(VocabularyItem item, {List<int>? tagIds}) async {
    final db = await database;
    if (db == null) {
      final nextId = _inMemoryVocab.isEmpty ? 1 : (_inMemoryVocab.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
      final newItem = item.copyWith(id: nextId);
      _inMemoryVocab.insert(0, newItem);
      _inMemorySrs[nextId] = SrsProgress(
        vocabId: nextId,
        nextReviewDate: DateTime.now(),
      );
      return nextId;
    }

    final id = await db.insert('vocabulary', item.toMap());
    await db.insert('srs_progress', {
      'vocab_id': id,
      'repetition_count': 0,
      'interval_days': 1,
      'ease_factor': 2.5,
      'next_review_date': DateTime.now().toIso8601String(),
      'last_reviewed_at': null,
    });

    if (tagIds != null) {
      for (final tagId in tagIds) {
        await db.insert('vocab_tags', {'vocab_id': id, 'tag_id': tagId});
      }
    }
    return id;
  }

  Future<bool> isWordSaved(String word, String languageCode) async {
    final db = await database;
    if (db == null) {
      return _inMemoryVocab.any((e) =>
          e.word.trim().toLowerCase() == word.trim().toLowerCase() &&
          e.languageCode == languageCode.toUpperCase());
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
      return 1;
    }

    // Wrap trong transaction để đảm bảo atomicity.
    // ON DELETE CASCADE đã xử lý srs_progress và vocab_tags tự động,
    // nhưng ta vẫn wrap để bắt lỗi toàn bộ.
    return await db.transaction((txn) async {
      // Xóa bảng liên kết trước (safe nếu CASCADE chưa được enable)
      await txn.delete('srs_progress', where: 'vocab_id = ?', whereArgs: [id]);
      await txn.delete('vocab_tags', where: 'vocab_id = ?', whereArgs: [id]);
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
    await db.update('vocabulary', {'notes': notes}, where: 'id = ?', whereArgs: [id]);
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
            (v.phonetic != null && v.phonetic!.toLowerCase().contains(trimmed)) ||
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

  Future<List<Map<String, dynamic>>> getDueReviews({String? languageCode}) async {
    final db = await database;
    if (db == null) {
      final now = DateTime.now();
      final dueVocabs = _inMemoryVocab.where((v) {
        if (languageCode != null && v.languageCode != languageCode.toUpperCase()) return false;
        final srs = _inMemorySrs[v.id];
        return srs == null || srs.nextReviewDate.isBefore(now);
      }).toList();

      return dueVocabs.map((v) {
        final map = v.toMap();
        final srs = _inMemorySrs[v.id];
        map['repetition_count'] = srs?.repetitionCount ?? 0;
        map['interval_days'] = srs?.intervalDays ?? 1;
        map['ease_factor'] = srs?.easeFactor ?? 2.5;
        map['next_review_date'] = srs?.nextReviewDate.toIso8601String() ?? now.toIso8601String();
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
    return await db.insert('tags', {'name': name.trim()}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // -------------------------------------------------------------
  // SETTINGS & STREAK
  // -------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final db = await database;
    if (db == null) return _inMemorySettings[key];
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (res.isEmpty) return null;
    return res.first['value']?.toString();
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    if (db == null) {
      _inMemorySettings[key] = value;
      return;
    }
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
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
            .difference(DateTime(lastActive.year, lastActive.month, lastActive.day))
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
      return _inMemorySrs.values
          .where((s) => s.repetitionCount >= 5)
          .length;
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
      return _inMemoryVocab.where((e) => e.languageCode == languageCode.toUpperCase()).length;
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
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    if (db == null) return; // in-memory: skip persistence

    // Upsert: nếu đã có record hôm nay thì cộng dồn
    await db.execute('''
      INSERT INTO daily_activities (date, cards_reviewed, speaking_practiced, words_added, xp_gained)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(date) DO UPDATE SET
        cards_reviewed    = cards_reviewed + excluded.cards_reviewed,
        speaking_practiced = speaking_practiced + excluded.speaking_practiced,
        words_added       = words_added + excluded.words_added,
        xp_gained         = xp_gained + excluded.xp_gained
    ''', [today, cardsReviewed, speakingPracticed, wordsAdded, xpGained]);
  }

  /// Lấy lịch sử hoạt động [days] ngày gần nhất
  Future<List<Map<String, dynamic>>> getRecentActivities({int days = 28}) async {
    final db = await database;
    if (db == null) return []; // in-memory: trả về rỗng

    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10);
    return await db.query(
      'daily_activities',
      where: 'date >= ?',
      whereArgs: [cutoff],
      orderBy: 'date ASC',
    );
  }
}
