import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';
import '../utils/json_helper.dart';
import '../../models/vocabulary_item.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  /// Export all vocabulary to JSON string
  Future<String> exportToJson() async {
    final allVocab = await AppDatabase.instance.getAllVocabulary();
    final list = allVocab.map((v) => v.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Export to standard Flashcard CSV format
  Future<String> exportToFlashcardsCsv({String? languageCode}) async {
    final items = await AppDatabase.instance.getAllVocabulary(languageCode: languageCode);
    final List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Word / Hanzi',
      'Phonetic / Pinyin',
      'Han-Viet',
      'Meaning (VI)',
      'Type / Level',
      'Breakdown / Notes',
      'Examples'
    ]);

    for (final item in items) {
      final examplesFormatted = item.examples.map((e) {
        if (e.pinyin != null && e.pinyin!.isNotEmpty) {
          return '${e.text} (${e.pinyin}): ${e.vi}';
        }
        return '${e.text}: ${e.vi}';
      }).join(' | ');

      rows.add([
        item.word,
        item.phonetic ?? '',
        item.hanViet ?? '',
        item.meaningVi,
        '${item.wordType ?? ''} ${item.level != null ? '(${item.level})' : ''}'.trim(),
        item.notes ?? item.breakdown ?? '',
        examplesFormatted,
      ]);
    }

    return csv.encode(rows);
  }

  /// Alias for backward compatibility
  Future<String> exportToAnkiCsv({String? languageCode}) =>
      exportToFlashcardsCsv(languageCode: languageCode);

  /// Save exported file to Documents/Downloads folder and return absolute path
  Future<String> saveExportFile({
    required String content,
    required String extension,
  }) async {
    if (kIsWeb) {
      return 'Trình duyệt web không hỗ trợ ghi file cục bộ trực tiếp.';
    }

    final docDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(docDir.path, 'vocivo', 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final filePath = p.join(exportDir.path, 'vocivo_backup_$timestamp.$extension');
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);
    return filePath;
  }

  /// Import vocabulary from JSON string (legacy direct import)
  Future<int> importFromJson(String jsonContent) async {
    final items = parseJsonToVocabulary(jsonContent);
    return saveVocabularyBatch(items);
  }

  /// Parse JSON string into VocabularyItem list without saving immediately
  List<VocabularyItem> parseJsonToVocabulary(String jsonContent) {
    String cleanJson = JsonHelper.cleanJsonString(jsonContent);

    final decoded = jsonDecode(cleanJson);
    List rawList = [];
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawList = decoded['items'] ?? decoded['vocabulary'] ?? decoded['words'] ?? decoded['data'] ?? [];
    }

    final List<VocabularyItem> results = [];
    for (final itemMap in rawList) {
      if (itemMap is Map<String, dynamic>) {
        final item = VocabularyItem.fromMap(itemMap);
        results.add(item.copyWith(isSaved: false));
      }
    }
    return results;
  }

  /// Parse CSV string into VocabularyItem list with dynamic column matching
  List<VocabularyItem> parseCsvToVocabulary(String csvContent, {String defaultLanguageCode = 'EN'}) {
    final normalized = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = csv.decode(normalized);

    if (rows.isEmpty) return [];

    int wordIdx = 0;
    int phoneticIdx = -1;
    int hanVietIdx = -1;
    int meaningIdx = 1;
    int typeIdx = -1;
    int levelIdx = -1;
    int notesIdx = -1;
    int examplesIdx = -1;

    int dataStartIndex = 0;

    // Check if first row is header
    final firstRow = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    bool hasHeader = false;

    for (int i = 0; i < firstRow.length; i++) {
      final col = firstRow[i];
      if (col.contains('word') || col.contains('từ') || col.contains('hanzi') || col.contains('vocab')) {
        wordIdx = i;
        hasHeader = true;
      } else if (col.contains('meaning') || col.contains('nghĩa') || col.contains('definition') || col.contains('dịch')) {
        meaningIdx = i;
        hasHeader = true;
      } else if (col.contains('phonetic') || col.contains('pinyin') || col.contains('ipa') || col.contains('phiên âm')) {
        phoneticIdx = i;
        hasHeader = true;
      } else if (col.contains('han_viet') || col.contains('hán việt') || col.contains('hanviet')) {
        hanVietIdx = i;
        hasHeader = true;
      } else if (col.contains('type') || col.contains('loại từ')) {
        typeIdx = i;
        hasHeader = true;
      } else if (col.contains('level') || col.contains('cấp độ') || col.contains('hsk') || col.contains('cefr')) {
        levelIdx = i;
        hasHeader = true;
      } else if (col.contains('example') || col.contains('ví dụ')) {
        examplesIdx = i;
        hasHeader = true;
      } else if (col.contains('note') || col.contains('ghi chú') || col.contains('breakdown')) {
        notesIdx = i;
        hasHeader = true;
      }
    }

    if (hasHeader) {
      dataStartIndex = 1;
    } else {
      // Positional defaults: Col 0: Word, Col 1: Meaning (or if 3 cols: Col 0: Word, Col 1: Phonetic, Col 2: Meaning)
      if (rows.first.length >= 3) {
        wordIdx = 0;
        phoneticIdx = 1;
        meaningIdx = 2;
      } else {
        wordIdx = 0;
        meaningIdx = rows.first.length > 1 ? 1 : 0;
      }
    }

    final List<VocabularyItem> results = [];

    for (int r = dataStartIndex; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      final word = wordIdx < row.length ? row[wordIdx].toString().trim() : '';
      if (word.isEmpty) continue;

      final meaning = (meaningIdx != -1 && meaningIdx < row.length) ? row[meaningIdx].toString().trim() : '';
      final phonetic = (phoneticIdx != -1 && phoneticIdx < row.length) ? row[phoneticIdx].toString().trim() : null;
      final hanViet = (hanVietIdx != -1 && hanVietIdx < row.length) ? row[hanVietIdx].toString().trim() : null;
      final type = (typeIdx != -1 && typeIdx < row.length) ? row[typeIdx].toString().trim() : null;
      final level = (levelIdx != -1 && levelIdx < row.length) ? row[levelIdx].toString().trim() : null;
      final notes = (notesIdx != -1 && notesIdx < row.length) ? row[notesIdx].toString().trim() : null;

      List<ExampleSentence> examples = [];
      if (examplesIdx != -1 && examplesIdx < row.length) {
        final exStr = row[examplesIdx].toString().trim();
        if (exStr.isNotEmpty) {
          final parts = exStr.split('|');
          for (final part in parts) {
            final p = part.trim();
            if (p.isNotEmpty) {
              if (p.contains(':')) {
                final split = p.split(':');
                examples.add(ExampleSentence(text: split[0].trim(), vi: split.sublist(1).join(':').trim()));
              } else {
                examples.add(ExampleSentence(text: p, vi: ''));
              }
            }
          }
        }
      }

      results.add(
        VocabularyItem(
          languageCode: defaultLanguageCode.toUpperCase(),
          word: word,
          phonetic: phonetic?.isNotEmpty == true ? phonetic : null,
          hanViet: hanViet?.isNotEmpty == true ? hanViet : null,
          meaningVi: meaning,
          wordType: type?.isNotEmpty == true ? type : null,
          level: level?.isNotEmpty == true ? level : null,
          notes: notes?.isNotEmpty == true ? notes : null,
          examples: examples,
          isSaved: false,
        ),
      );
    }

    return results;
  }

  /// Parse simple raw text line-by-line (e.g. "word: meaning" or "word - meaning")
  List<VocabularyItem> parseRawTextToVocabulary(String rawText, {String defaultLanguageCode = 'EN'}) {
    final lines = rawText.split('\n');
    final List<VocabularyItem> results = [];

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Remove bullet points like "- word", "* word", "1. word"
      trimmed = trimmed.replaceFirst(RegExp(r'^\s*[-*•]\s*'), '');
      trimmed = trimmed.replaceFirst(RegExp(r'^\s*\d+[\.\)]\s*'), '');

      String word = trimmed;
      String meaning = '';

      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        word = parts[0].trim();
        meaning = parts.sublist(1).join(':').trim();
      } else if (trimmed.contains(' - ')) {
        final parts = trimmed.split(' - ');
        word = parts[0].trim();
        meaning = parts.sublist(1).join(' - ').trim();
      } else if (trimmed.contains(' = ')) {
        final parts = trimmed.split(' = ');
        word = parts[0].trim();
        meaning = parts.sublist(1).join(' = ').trim();
      }

      if (word.isNotEmpty) {
        results.add(
          VocabularyItem(
            languageCode: defaultLanguageCode.toUpperCase(),
            word: word,
            meaningVi: meaning,
            isSaved: false,
          ),
        );
      }
    }
    return results;
  }

  /// Save a batch of VocabularyItem to SQLite database, skipping existing words.
  /// Dùng INSERT OR IGNORE + transaction để tránh N+1 query problem.
  Future<int> saveVocabularyBatch(List<VocabularyItem> items, {List<int>? tagIds}) async {
    if (items.isEmpty) return 0;

    final db = await AppDatabase.instance.database;

    // In-memory fallback: dùng vòng lặp đơn giản
    if (db == null) {
      int count = 0;
      for (final item in items) {
        final exists = await AppDatabase.instance.isWordSaved(item.word, item.languageCode);
        if (!exists) {
          await AppDatabase.instance.insertVocabulary(item, tagIds: tagIds);
          count++;
        }
      }
      return count;
    }

    int count = 0;
    try {
      await db.transaction((txn) async {
        for (final item in items) {
          // INSERT OR IGNORE: bỏ qua nếu từ đã tồn tại (dựa vào UNIQUE constraint)
          // Không cần check isWordSaved riêng → giảm từ 2N queries xuống còn N
          final id = await txn.insert(
            'vocabulary',
            item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (id > 0) {
            // Chèn SRS progress cho từ mới
            await txn.insert(
              'srs_progress',
              {
                'vocab_id': id,
                'repetition_count': 0,
                'interval_days': 1,
                'ease_factor': 2.5,
                'next_review_date': DateTime.now().toIso8601String(),
                'last_reviewed_at': null,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            // Gán tags nếu có
            if (tagIds != null) {
              for (final tagId in tagIds) {
                await txn.insert(
                  'vocab_tags',
                  {'vocab_id': id, 'tag_id': tagId},
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }
            }
            count++;
          }
        }
      });
    } catch (e, st) {
      debugPrint('saveVocabularyBatch error: $e\n$st');
    }
    return count;
  }
}
