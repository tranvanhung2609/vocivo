import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../widgets/word_card.dart';

/// Danh sách hiển thị từ vựng kèm trạng thái trống/loading
class HomeWordList extends StatelessWidget {
  const HomeWordList({
    super.key,
    required this.vocabState,
    required this.isZh,
    required this.isDark,
    required this.currentLang,
    required this.isDesktop,
    required this.searchQuery,
    required this.onSelectWord,
    required this.onTriggerAiLookup,
  });

  final VocabularyState vocabState;
  final bool isZh;
  final bool isDark;
  final String currentLang;
  final bool isDesktop;
  final String searchQuery;
  final void Function(VocabularyItem item) onSelectWord;
  final void Function(String query, String lang) onTriggerAiLookup;

  @override
  Widget build(BuildContext context) {
    if (vocabState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryEnglish),
      );
    }

    if (vocabState.searchResults.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      // Padding dưới để không bị che bởi FAB hoặc bottom navigation bar
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: isDesktop ? 16 : 100,
      ),
      itemCount: vocabState.searchResults.length,
      itemBuilder: (ctx, i) {
        final item = vocabState.searchResults[i];
        final isSelected =
            isDesktop && item.word == vocabState.selectedWord?.word;

        return WordCard(
          item: item,
          isSavedInNotebook: true,
          isSelected: isSelected,
          onTap: () => onSelectWord(item),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.primaryEnglishLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.primaryEnglish,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              searchQuery.isEmpty
                  ? 'Chưa có từ nào trong danh mục này'
                  : 'Không tìm thấy "$searchQuery" offline',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textDarkPrimary
                    : AppColors.textLightPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nhấn ✨ để AI phân tích âm Hán-Việt, ngữ cảnh và ví dụ!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textDarkMuted
                    : AppColors.textLightMuted,
              ),
            ),
            if (searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => onTriggerAiLookup(searchQuery, currentLang),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text('Phân tích "$searchQuery" bằng AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEnglish,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
