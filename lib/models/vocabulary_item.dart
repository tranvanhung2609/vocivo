import 'dart:convert';

class ExampleSentence {
  final String text; // en or zh
  final String? pinyin; // for Chinese
  final String vi; // Vietnamese translation

  const ExampleSentence({
    required this.text,
    this.pinyin,
    required this.vi,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'pinyin': pinyin,
      'vi': vi,
    };
  }

  factory ExampleSentence.fromMap(Map<String, dynamic> map) {
    return ExampleSentence(
      text: map['text']?.toString() ?? map['zh']?.toString() ?? map['en']?.toString() ?? '',
      pinyin: map['pinyin']?.toString(),
      vi: map['vi']?.toString() ?? '',
    );
  }
}

class VocabularyItem {
  final int? id;
  final String languageCode; // 'EN' or 'ZH'
  final String word; // English word or Hanzi
  final String? phonetic; // IPA (for EN) or Pinyin (for ZH)
  final String? hanViet; // Sino-Vietnamese reading (ZH only)
  final String meaningVi; // Vietnamese definition
  final String? wordType; // noun, verb, adj, idiom...
  final String? level; // A1-C2, HSK 1-6
  final String? examplesJson; // Raw JSON array string
  final String? notes; // Personal memory tips or radical breakdown
  final String? createdAt;

  // Transient / helper fields
  final List<ExampleSentence> examples;
  final List<String> collocations;
  final String? breakdown; // e.g. "学 (Học) + 习 (Tập)"
  final bool isSaved; // whether it's saved in local SQLite notebook

  VocabularyItem({
    this.id,
    required this.languageCode,
    required this.word,
    this.phonetic,
    this.hanViet,
    required this.meaningVi,
    this.wordType,
    this.level,
    this.examplesJson,
    this.notes,
    this.createdAt,
    List<ExampleSentence>? examples,
    List<String>? collocations,
    this.breakdown,
    this.isSaved = true,
  })  : examples = examples ?? _parseExamples(examplesJson),
        collocations = collocations ?? const [];

  static List<ExampleSentence> _parseExamples(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => ExampleSentence.fromMap(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'language_code': languageCode.toUpperCase(),
      'word': word,
      'phonetic': phonetic,
      'han_viet': hanViet,
      'meaning_vi': meaningVi,
      'word_type': wordType,
      'level': level,
      'examples_json': examplesJson ?? jsonEncode(examples.map((e) => e.toMap()).toList()),
      'notes': notes ?? breakdown,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory VocabularyItem.fromMap(Map<String, dynamic> map) {
    final rawNotes = map['notes']?.toString();
    final rawExamplesJson = map['examples_json']?.toString();
    return VocabularyItem(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      languageCode: map['language_code']?.toString().toUpperCase() ?? 'EN',
      word: map['word']?.toString() ?? '',
      phonetic: map['phonetic']?.toString(),
      hanViet: map['han_viet']?.toString(),
      meaningVi: map['meaning_vi']?.toString() ?? '',
      wordType: map['word_type']?.toString(),
      level: map['level']?.toString(),
      examplesJson: rawExamplesJson,
      notes: rawNotes,
      createdAt: map['created_at']?.toString(),
      breakdown: rawNotes != null && rawNotes.contains('+') ? rawNotes : null,
      isSaved: true,
    );
  }

  VocabularyItem copyWith({
    int? id,
    String? languageCode,
    String? word,
    String? phonetic,
    String? hanViet,
    String? meaningVi,
    String? wordType,
    String? level,
    String? examplesJson,
    String? notes,
    String? createdAt,
    List<ExampleSentence>? examples,
    List<String>? collocations,
    String? breakdown,
    bool? isSaved,
  }) {
    return VocabularyItem(
      id: id ?? this.id,
      languageCode: languageCode ?? this.languageCode,
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      hanViet: hanViet ?? this.hanViet,
      meaningVi: meaningVi ?? this.meaningVi,
      wordType: wordType ?? this.wordType,
      level: level ?? this.level,
      examplesJson: examplesJson ?? this.examplesJson,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      examples: examples ?? this.examples,
      collocations: collocations ?? this.collocations,
      breakdown: breakdown ?? this.breakdown,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
