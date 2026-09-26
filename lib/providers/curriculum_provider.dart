import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/curriculum_seed_data.dart';
import '../core/database/app_database.dart';
import '../core/services/ai_service.dart';
import '../models/curriculum_model.dart';
import 'language_mode_provider.dart';

@immutable
class CurriculumState {
  final String languageCode; // 'EN' or 'ZH'
  final List<LearningStage> stages;
  final List<CurriculumUnit> aiUnits;
  final bool isLoading;
  final bool isGeneratingAiDeck;
  final String? errorMessage;

  const CurriculumState({
    this.languageCode = 'EN',
    this.stages = const [],
    this.aiUnits = const [],
    this.isLoading = false,
    this.isGeneratingAiDeck = false,
    this.errorMessage,
  });

  int get totalCompletedUnits {
    int count = 0;
    for (final s in stages) {
      count += s.completedUnitsCount;
    }
    count += aiUnits.where((u) => u.isCompleted).length;
    return count;
  }

  int get totalUnits {
    int count = 0;
    for (final s in stages) {
      count += s.units.length;
    }
    count += aiUnits.length;
    return count;
  }

  double get overallProgress =>
      totalUnits > 0 ? (totalCompletedUnits / totalUnits).clamp(0.0, 1.0) : 0.0;

  CurriculumState copyWith({
    String? languageCode,
    List<LearningStage>? stages,
    List<CurriculumUnit>? aiUnits,
    bool? isLoading,
    bool? isGeneratingAiDeck,
    String? errorMessage,
  }) {
    return CurriculumState(
      languageCode: languageCode ?? this.languageCode,
      stages: stages ?? this.stages,
      aiUnits: aiUnits ?? this.aiUnits,
      isLoading: isLoading ?? this.isLoading,
      isGeneratingAiDeck: isGeneratingAiDeck ?? this.isGeneratingAiDeck,
      errorMessage: errorMessage,
    );
  }
}

class CurriculumNotifier extends Notifier<CurriculumState> {
  @override
  CurriculumState build() {
    final currentLang = ref.watch(languageModeProvider);
    final lang = (currentLang == 'ZH') ? 'ZH' : 'EN';
    Future.microtask(() => loadCurriculum(lang));
    return CurriculumState(languageCode: lang, isLoading: true);
  }

  /// Tải dữ liệu lộ trình học từ SQLite
  Future<void> loadCurriculum(String languageCode) async {
    state = state.copyWith(isLoading: true, languageCode: languageCode, errorMessage: null);
    try {
      final dbUnits = await AppDatabase.instance.getLearningUnits(languageCode);
      final isZh = languageCode.toUpperCase() == 'ZH';
      final baseStages = isZh ? CurriculumSeedData.chineseStages : CurriculumSeedData.englishStages;

      // Group dbUnits by stageId
      final Map<String, List<CurriculumUnit>> stageUnitMap = {};
      final List<CurriculumUnit> aiDecks = [];

      for (final unit in dbUnits) {
        if (unit.isAiGenerated || unit.stageId == 'custom_ai') {
          aiDecks.add(unit);
        } else {
          stageUnitMap.putIfAbsent(unit.stageId, () => []).add(unit);
        }
      }

      // Rebuild stages with actual unit progress & words from DB
      final mergedStages = baseStages.map((stage) {
        final stageUnits = stageUnitMap[stage.id];
        if (stageUnits != null && stageUnits.isNotEmpty) {
          return stage.copyWith(units: stageUnits);
        }
        return stage;
      }).toList();

      state = state.copyWith(
        languageCode: languageCode,
        stages: mergedStages,
        aiUnits: aiDecks,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading curriculum: $e');
      // Fallback directly to in-memory template
      final isZh = languageCode.toUpperCase() == 'ZH';
      final fallbackStages = isZh ? CurriculumSeedData.chineseStages : CurriculumSeedData.englishStages;
      state = state.copyWith(
        stages: fallbackStages,
        aiUnits: [],
        isLoading: false,
        errorMessage: 'Lỗi tải lộ trình: $e',
      );
    }
  }

  /// Đổi ngôn ngữ lộ trình ('EN' hoặc 'ZH')
  void switchLanguage(String languageCode) {
    if (state.languageCode == languageCode) return;
    ref.read(languageModeProvider.notifier).setLanguage(languageCode);
    loadCurriculum(languageCode);
  }

  /// Tạo bộ thẻ / bài học mới bằng AI
  Future<CurriculumUnit?> generateAiTopicDeck({
    required String topic,
    String? level,
    int wordCount = 8,
  }) async {
    state = state.copyWith(isGeneratingAiDeck: true, errorMessage: null);
    try {
      final unit = await AiService.instance.generateTopicDeck(
        topic: topic,
        languageCode: state.languageCode,
        level: level,
        wordCount: wordCount,
      );

      // Lưu vào SQLite
      await AppDatabase.instance.saveLearningUnit(unit, unit.words);

      // Ghi nhận hoạt động thêm từ vào Progress
      await AppDatabase.instance.recordDailyActivity(wordsAdded: unit.words.length);

      // Tải lại state
      await loadCurriculum(state.languageCode);

      state = state.copyWith(isGeneratingAiDeck: false);
      return unit;
    } catch (e) {
      debugPrint('Error generating AI deck: $e');
      state = state.copyWith(
        isGeneratingAiDeck: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  /// Đánh dấu một bài học đã hoàn thành
  Future<void> markUnitCompleted(String unitId, {int? score}) async {
    try {
      await AppDatabase.instance.updateUnitProgress(
        unitId,
        isCompleted: true,
        score: score,
      );
      await AppDatabase.instance.recordDailyActivity(
        xpGained: (score ?? 100),
      );
      await loadCurriculum(state.languageCode);
    } catch (e) {
      debugPrint('Error marking unit completed: $e');
    }
  }

  /// Xóa bộ thẻ AI tự tạo
  Future<void> deleteAiUnit(String unitId) async {
    try {
      await AppDatabase.instance.deleteLearningUnit(unitId);
      await loadCurriculum(state.languageCode);
    } catch (e) {
      debugPrint('Error deleting AI unit: $e');
    }
  }
}

final curriculumProvider =
    NotifierProvider<CurriculumNotifier, CurriculumState>(CurriculumNotifier.new);
