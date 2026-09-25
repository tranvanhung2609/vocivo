import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/ai_service.dart';
import '../models/vocabulary_item.dart';

@immutable
class AiSearchState {
  final bool isLoading;
  final VocabularyItem? result;
  final String? errorMessage;

  const AiSearchState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  bool get hasResult => result != null;
  bool get hasError => errorMessage != null;
}

class AiSearchNotifier extends Notifier<AiSearchState> {
  @override
  AiSearchState build() => const AiSearchState();

  Future<void> lookupWord({
    required String query,
    required String languageCode,
  }) async {
    if (query.trim().isEmpty) return;

    state = const AiSearchState(isLoading: true);
    try {
      final item = await AiService.instance.lookupWord(
        query: query.trim(),
        languageCode: languageCode,
      );
      state = AiSearchState(isLoading: false, result: item);
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring(11);
      }
      state = AiSearchState(isLoading: false, errorMessage: msg);
    }
  }

  void reset() {
    state = const AiSearchState();
  }
}

final aiSearchProvider = NotifierProvider<AiSearchNotifier, AiSearchState>(() {
  return AiSearchNotifier();
});
