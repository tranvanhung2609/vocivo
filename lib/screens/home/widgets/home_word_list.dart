import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../widgets/word_card.dart';

/// Danh sách hiển thị từ vựng kèm skeleton loading và empty states đẹp
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
    // ── Loading state: shimmer skeleton ──────────────────────────
    if (vocabState.isLoading) {
      return const WordListSkeleton(count: 5);
    }

    // ── Empty state ───────────────────────────────────────────────
    if (vocabState.searchResults.isEmpty) {
      return _buildEmptyState(context);
    }

    // ── Word list ─────────────────────────────────────────────────
    return ListView.builder(
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
    final bool isSearchEmpty = searchQuery.isEmpty;
    final textColor =
        isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final mutedColor =
        isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Illustration container ────────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primaryEnglishLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryEnglish.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  isSearchEmpty
                      ? Icons.library_books_outlined
                      : Icons.search_off_rounded,
                  size: 44,
                  color: AppColors.primaryEnglish,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────
            Text(
              isSearchEmpty
                  ? 'Chưa có từ nào trong danh mục này'
                  : 'Không tìm thấy "$searchQuery"',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),

            const SizedBox(height: 8),

            // ── Subtitle ──────────────────────────────────────────
            Text(
              isSearchEmpty
                  ? 'Thêm từ mới hoặc chuyển sang danh mục khác để bắt đầu học.'
                  : 'Hãy để AI phân tích âm Hán-Việt, ngữ cảnh và ví dụ cho bạn!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: mutedColor,
              ),
            ),

            const SizedBox(height: 24),

            // ── CTA buttons ───────────────────────────────────────
            if (!isSearchEmpty) ...[
              FilledButton.icon(
                onPressed: () => onTriggerAiLookup(searchQuery, currentLang),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text('AI phân tích "$searchQuery"'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryEnglish,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ] else ...[
              // Hint chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildHintChip(
                      icon: Icons.add_rounded,
                      label: 'Thêm từ mới',
                      isDark: isDark),
                  _buildHintChip(
                      icon: Icons.import_export_rounded,
                      label: 'Import danh sách',
                      isDark: isDark),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHintChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark3 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
