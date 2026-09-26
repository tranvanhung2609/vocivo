import 'package:flutter_test/flutter_test.dart';
import 'package:vocivo/core/constants/curriculum_seed_data.dart';
import 'package:vocivo/core/database/app_database.dart';
import 'package:vocivo/models/curriculum_model.dart';
import 'package:vocivo/models/vocabulary_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Curriculum & Roadmap Tests', () {
    test('English roadmap contains expected stages and units', () {
      final stages = CurriculumSeedData.englishStages;
      expect(stages.isNotEmpty, isTrue);
      expect(stages.length, greaterThanOrEqualTo(4));

      for (final stage in stages) {
        expect(stage.languageCode, 'EN');
        expect(stage.units.isNotEmpty, isTrue);
        for (final unit in stage.units) {
          expect(unit.languageCode, 'EN');
          expect(unit.words.isNotEmpty, isTrue);
          for (final word in unit.words) {
            expect(word.word.isNotEmpty, isTrue);
            expect(word.meaningVi.isNotEmpty, isTrue);
          }
        }
      }
    });

    test('Chinese roadmap contains expected stages and units with pinyin', () {
      final stages = CurriculumSeedData.chineseStages;
      expect(stages.isNotEmpty, isTrue);
      expect(stages.length, greaterThanOrEqualTo(4));

      for (final stage in stages) {
        expect(stage.languageCode, 'ZH');
        expect(stage.units.isNotEmpty, isTrue);
        for (final unit in stage.units) {
          expect(unit.languageCode, 'ZH');
          expect(unit.words.isNotEmpty, isTrue);
          for (final word in unit.words) {
            expect(word.word.isNotEmpty, isTrue);
            expect(word.phonetic, isNotNull);
            expect(word.meaningVi.isNotEmpty, isTrue);
          }
        }
      }
    });

    test('AppDatabase can load learning units and update progress', () async {
      final enUnits = await AppDatabase.instance.getLearningUnits('EN');
      expect(enUnits.isNotEmpty, isTrue);

      final firstUnit = enUnits.first;
      expect(firstUnit.words.isNotEmpty, isTrue);

      // Update unit progress
      await AppDatabase.instance.updateUnitProgress(
        firstUnit.id,
        isCompleted: true,
        score: 95,
      );

      final updatedUnits = await AppDatabase.instance.getLearningUnits('EN');
      final updatedFirstUnit = updatedUnits.firstWhere((u) => u.id == firstUnit.id);
      expect(updatedFirstUnit.isCompleted, isTrue);
      expect(updatedFirstUnit.lastScore, 95);
    });

    test('Custom AI Deck can be created and saved', () async {
      const customUnit = CurriculumUnit(
        id: 'test_ai_deck_1',
        stageId: 'custom_ai',
        stageTitle: '✨ Chủ Đề AI Tự Tạo',
        languageCode: 'ZH',
        title: 'Chủ đề thử nghiệm Taobao',
        description: 'Các từ mua sắm online',
        level: 'HSK 2',
        isAiGenerated: true,
      );

      final words = [
        VocabularyItem(
          languageCode: 'ZH',
          word: '淘宝',
          phonetic: 'táobǎo',
          meaningVi: 'Taobao (sàn thương mại điện tử)',
        ),
        VocabularyItem(
          languageCode: 'ZH',
          word: '包邮',
          phonetic: 'bāo yóu',
          meaningVi: 'Miễn phí vận chuyển (Freeship)',
        ),
      ];

      await AppDatabase.instance.saveLearningUnit(customUnit, words);

      final zhUnits = await AppDatabase.instance.getLearningUnits('ZH');
      final found = zhUnits.firstWhere((u) => u.id == 'test_ai_deck_1');
      expect(found.title, 'Chủ đề thử nghiệm Taobao');
      expect(found.isAiGenerated, isTrue);
      expect(found.words.length, 2);

      // Delete custom unit
      await AppDatabase.instance.deleteLearningUnit('test_ai_deck_1');
      final afterDelete = await AppDatabase.instance.getLearningUnits('ZH');
      expect(afterDelete.any((u) => u.id == 'test_ai_deck_1'), isFalse);
    });
  });
}
