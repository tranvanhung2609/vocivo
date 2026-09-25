import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../models/vocabulary_item.dart';
import '../models/srs_progress.dart';

@immutable
class SrsState {
  final List<VocabularyItem> dueItems;
  final int currentIndex;
  final bool isCardFlipped;
  final bool isSessionCompleted;
  final int streak;
  final bool isLoading;

  const SrsState({
    this.dueItems = const [],
    this.currentIndex = 0,
    this.isCardFlipped = false,
    this.isSessionCompleted = false,
    this.streak = 1,
    this.isLoading = false,
  });

  VocabularyItem? get currentItem =>
      dueItems.isNotEmpty && currentIndex < dueItems.length
          ? dueItems[currentIndex]
          : null;

  int get totalDue => dueItems.length;
  int get remaining => dueItems.length - currentIndex;

  SrsState copyWith({
    List<VocabularyItem>? dueItems,
    int? currentIndex,
    bool? isCardFlipped,
    bool? isSessionCompleted,
    int? streak,
    bool? isLoading,
  }) {
    return SrsState(
      dueItems: dueItems ?? this.dueItems,
      currentIndex: currentIndex ?? this.currentIndex,
      isCardFlipped: isCardFlipped ?? this.isCardFlipped,
      isSessionCompleted: isSessionCompleted ?? this.isSessionCompleted,
      streak: streak ?? this.streak,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SrsNotifier extends Notifier<SrsState> {
  @override
  SrsState build() {
    Future.microtask(() => initSrs());
    return const SrsState(isLoading: true);
  }

  Future<void> initSrs() async {
    state = state.copyWith(isLoading: true);
    final streak = await AppDatabase.instance.checkAndUpdateStreak();
    await loadDueCards();
    state = state.copyWith(streak: streak, isLoading: false);
  }

  Future<void> loadDueCards({String? languageCode}) async {
    final rows = await AppDatabase.instance.getDueReviews(languageCode: languageCode);
    final items = rows.map((r) => VocabularyItem.fromMap(r)).toList();
    state = state.copyWith(
      dueItems: items,
      currentIndex: 0,
      isCardFlipped: false,
      isSessionCompleted: items.isEmpty,
    );
  }

  void flipCard() {
    state = state.copyWith(isCardFlipped: !state.isCardFlipped);
  }

  Future<void> submitReview(SrsRating rating) async {
    final current = state.currentItem;
    if (current == null || current.id == null) return;

    // Fetch current progress
    final existing = await AppDatabase.instance.getSrsProgress(current.id!);
    final progress = existing ?? SrsProgress(
      vocabId: current.id!,
      nextReviewDate: DateTime.now(),
    );

    // Apply SM-2 update
    final updated = progress.applyReview(rating);
    await AppDatabase.instance.updateSrsProgress(updated);

    // If rated "Again", re-insert into end of current session queue to repeat
    List<VocabularyItem> nextItems = List.from(state.dueItems);
    if (rating == SrsRating.again) {
      nextItems.add(current);
    }

    final nextIndex = state.currentIndex + 1;
    final isFinished = nextIndex >= nextItems.length;

    state = state.copyWith(
      dueItems: nextItems,
      currentIndex: nextIndex,
      isCardFlipped: false,
      isSessionCompleted: isFinished,
    );
  }

  void restartSession() {
    state = state.copyWith(
      currentIndex: 0,
      isCardFlipped: false,
      isSessionCompleted: false,
    );
  }
}

final srsProvider = NotifierProvider<SrsNotifier, SrsState>(() {
  return SrsNotifier();
});
