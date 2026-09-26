import 'vocabulary_item.dart';

class CurriculumUnit {
  final String id;
  final String stageId;
  final String stageTitle;
  final String languageCode; // 'EN' or 'ZH'
  final String title;
  final String description;
  final String iconName;
  final String level; // A1, A2, B1, B2 or HSK 1..6
  final bool isAiGenerated;
  final int orderIndex;
  final List<VocabularyItem> words;
  final bool isCompleted;
  final int? lastScore;
  final DateTime? completedAt;

  const CurriculumUnit({
    required this.id,
    required this.stageId,
    required this.stageTitle,
    required this.languageCode,
    required this.title,
    required this.description,
    this.iconName = 'school',
    this.level = 'A1',
    this.isAiGenerated = false,
    this.orderIndex = 0,
    this.words = const [],
    this.isCompleted = false,
    this.lastScore,
    this.completedAt,
  });

  CurriculumUnit copyWith({
    String? id,
    String? stageId,
    String? stageTitle,
    String? languageCode,
    String? title,
    String? description,
    String? iconName,
    String? level,
    bool? isAiGenerated,
    int? orderIndex,
    List<VocabularyItem>? words,
    bool? isCompleted,
    int? lastScore,
    DateTime? completedAt,
  }) {
    return CurriculumUnit(
      id: id ?? this.id,
      stageId: stageId ?? this.stageId,
      stageTitle: stageTitle ?? this.stageTitle,
      languageCode: languageCode ?? this.languageCode,
      title: title ?? this.title,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      level: level ?? this.level,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      orderIndex: orderIndex ?? this.orderIndex,
      words: words ?? this.words,
      isCompleted: isCompleted ?? this.isCompleted,
      lastScore: lastScore ?? this.lastScore,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stage_id': stageId,
      'stage_title': stageTitle,
      'language_code': languageCode.toUpperCase(),
      'title': title,
      'description': description,
      'icon_name': iconName,
      'level': level,
      'is_ai_generated': isAiGenerated ? 1 : 0,
      'order_index': orderIndex,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory CurriculumUnit.fromMap(
    Map<String, dynamic> map, {
    List<VocabularyItem> words = const [],
    bool isCompleted = false,
    int? lastScore,
    DateTime? completedAt,
  }) {
    return CurriculumUnit(
      id: map['id']?.toString() ?? '',
      stageId: map['stage_id']?.toString() ?? '',
      stageTitle: map['stage_title']?.toString() ?? '',
      languageCode: map['language_code']?.toString().toUpperCase() ?? 'EN',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      iconName: map['icon_name']?.toString() ?? 'school',
      level: map['level']?.toString() ?? 'A1',
      isAiGenerated: (map['is_ai_generated'] == 1 || map['is_ai_generated'] == true),
      orderIndex: map['order_index'] is int ? map['order_index'] : int.tryParse(map['order_index']?.toString() ?? '0') ?? 0,
      words: words,
      isCompleted: isCompleted,
      lastScore: lastScore,
      completedAt: completedAt,
    );
  }
}

class LearningStage {
  final String id;
  final String languageCode;
  final String title;
  final String subtitle;
  final String level;
  final int badgeColor;
  final String iconName;
  final int orderIndex;
  final List<CurriculumUnit> units;

  const LearningStage({
    required this.id,
    required this.languageCode,
    required this.title,
    required this.subtitle,
    required this.level,
    this.badgeColor = 0xFF10B981,
    this.iconName = 'flag',
    this.orderIndex = 0,
    this.units = const [],
  });

  int get completedUnitsCount => units.where((u) => u.isCompleted).length;
  int get totalUnitsCount => units.length;
  double get progress =>
      totalUnitsCount > 0 ? completedUnitsCount / totalUnitsCount : 0.0;

  LearningStage copyWith({
    String? id,
    String? languageCode,
    String? title,
    String? subtitle,
    String? level,
    int? badgeColor,
    String? iconName,
    int? orderIndex,
    List<CurriculumUnit>? units,
  }) {
    return LearningStage(
      id: id ?? this.id,
      languageCode: languageCode ?? this.languageCode,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      level: level ?? this.level,
      badgeColor: badgeColor ?? this.badgeColor,
      iconName: iconName ?? this.iconName,
      orderIndex: orderIndex ?? this.orderIndex,
      units: units ?? this.units,
    );
  }
}
