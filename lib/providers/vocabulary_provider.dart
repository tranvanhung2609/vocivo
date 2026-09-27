import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../models/vocabulary_item.dart';
import '../models/tag_model.dart';
import 'language_mode_provider.dart';

@immutable
class VocabularyState {
  final List<VocabularyItem> searchResults;
  final List<VocabularyItem> notebookItems;
  final List<TagModel> tags;
  final int? selectedTagId;
  final String? selectedLevel;
  final VocabularyItem? selectedWord;
  final String searchQuery;
  final bool isLoading;

  const VocabularyState({
    this.searchResults = const [],
    this.notebookItems = const [],
    this.tags = const [],
    this.selectedTagId,
    this.selectedLevel,
    this.selectedWord,
    this.searchQuery = '',
    this.isLoading = false,
  });

  VocabularyState copyWith({
    List<VocabularyItem>? searchResults,
    List<VocabularyItem>? notebookItems,
    List<TagModel>? tags,
    int? selectedTagId,
    bool clearTag = false,
    String? selectedLevel,
    bool clearLevel = false,
    VocabularyItem? selectedWord,
    bool clearSelectedWord = false,
    String? searchQuery,
    bool? isLoading,
  }) {
    return VocabularyState(
      searchResults: searchResults ?? this.searchResults,
      notebookItems: notebookItems ?? this.notebookItems,
      tags: tags ?? this.tags,
      selectedTagId: clearTag ? null : (selectedTagId ?? this.selectedTagId),
      selectedLevel: clearLevel ? null : (selectedLevel ?? this.selectedLevel),
      selectedWord: clearSelectedWord
          ? null
          : (selectedWord ?? this.selectedWord),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class VocabularyNotifier extends Notifier<VocabularyState> {
  /// Generation counter để hủy bỏ các async load cũ khi có call mới hơn.
  /// Giải quyết race condition khi đổi ngôn ngữ nhanh.
  int _loadGeneration = 0;

  @override
  VocabularyState build() {
    ref.listen(languageModeProvider, (prev, next) {
      if (prev != next) {
        state = state.copyWith(clearLevel: true, clearSelectedWord: true);
        loadInitialData();
      }
    });
    Future.microtask(() => loadInitialData());
    return const VocabularyState(isLoading: true);
  }

  Future<void> loadInitialData() async {
    // Tăng generation: nếu có call mới hơn khi đang load, call cũ sẽ tự hủy
    final generation = ++_loadGeneration;

    state = state.copyWith(isLoading: true);
    final lang = ref.read(languageModeProvider);
    final tags = await AppDatabase.instance.getAllTags();
    final results = await AppDatabase.instance.searchVocabulary(
      query: state.searchQuery,
      languageCode: lang,
      tagId: state.selectedTagId,
      level: state.selectedLevel,
    );
    // Đã bỏ getAllVocabulary() thừa — NotebookScreen tự query theo nhu cầu

    // Kiểm tra nếu đã có generation mới hơn → bỏ qua kết quả này
    if (generation != _loadGeneration) return;

    VocabularyItem? activeSelection = state.selectedWord;
    if (activeSelection == null ||
        !results.any((e) => e.word == activeSelection?.word)) {
      activeSelection = results.isNotEmpty ? results.first : null;
    }

    state = state.copyWith(
      tags: tags,
      searchResults: results,
      notebookItems: results,
      selectedWord: activeSelection,
      isLoading: false,
    );
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, isLoading: true);
    final generation = ++_loadGeneration;
    final lang = ref.read(languageModeProvider);
    final results = await AppDatabase.instance.searchVocabulary(
      query: query,
      languageCode: lang,
      tagId: state.selectedTagId,
      level: state.selectedLevel,
    );
    if (generation != _loadGeneration) return;
    state = state.copyWith(
      searchResults: results,
      selectedWord: results.isNotEmpty ? results.first : null,
      isLoading: false,
    );
  }

  Future<void> filterByTag(int? tagId) async {
    final generation = ++_loadGeneration;
    final clearTag = tagId == null || tagId == state.selectedTagId;
    state = state.copyWith(
      selectedTagId: clearTag ? null : tagId,
      clearTag: clearTag,
      isLoading: true,
    );
    final lang = ref.read(languageModeProvider);
    final results = await AppDatabase.instance.searchVocabulary(
      query: state.searchQuery,
      languageCode: lang,
      tagId: state.selectedTagId,
      level: state.selectedLevel,
    );
    if (generation != _loadGeneration) return;
    state = state.copyWith(
      searchResults: results,
      selectedWord: results.isNotEmpty ? results.first : null,
      isLoading: false,
    );
  }

  Future<void> filterByLevel(String? level) async {
    final generation = ++_loadGeneration;
    final clearLevel = level == null || level == state.selectedLevel;
    state = state.copyWith(
      selectedLevel: clearLevel ? null : level,
      clearLevel: clearLevel,
      isLoading: true,
    );
    final lang = ref.read(languageModeProvider);
    final results = await AppDatabase.instance.searchVocabulary(
      query: state.searchQuery,
      languageCode: lang,
      tagId: state.selectedTagId,
      level: state.selectedLevel,
    );
    if (generation != _loadGeneration) return;
    state = state.copyWith(
      searchResults: results,
      selectedWord: results.isNotEmpty ? results.first : null,
      isLoading: false,
    );
  }

  void selectWord(VocabularyItem? item) {
    state = state.copyWith(selectedWord: item);
  }

  Future<bool> saveWord(VocabularyItem item, {List<int>? tagIds}) async {
    try {
      final exists = await AppDatabase.instance.isWordSaved(
        item.word,
        item.languageCode,
      );
      if (exists) return false;

      await AppDatabase.instance.insertVocabulary(item, tagIds: tagIds);
      await loadInitialData();
      return true;
    } catch (e, st) {
      debugPrint('VocabularyNotifier.saveWord error: $e\n$st');
      return false;
    }
  }

  Future<void> deleteWord(int id) async {
    await AppDatabase.instance.deleteVocabulary(id);
    await loadInitialData();
  }

  Future<void> updateNotes(int id, String newNotes) async {
    await AppDatabase.instance.updateVocabularyNotes(id, newNotes);
    await loadInitialData();
  }

  Future<void> addTag(String name) async {
    if (name.trim().isEmpty) return;
    await AppDatabase.instance.addTag(name);
    final tags = await AppDatabase.instance.getAllTags();
    state = state.copyWith(tags: tags);
  }
}

final vocabularyProvider =
    NotifierProvider<VocabularyNotifier, VocabularyState>(() {
      return VocabularyNotifier();
    });
