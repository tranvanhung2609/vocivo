import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../widgets/language_switcher.dart';
import '../../widgets/daily_goal_card.dart';

/// Thanh tìm kiếm và bộ lọc (cấp độ HSK/CEFR, chủ đề tags)
class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.isZh,
    required this.isDark,
    required this.vocabState,
    required this.currentLang,
    required this.onTriggerAiLookup,
    this.showDailyGoal = true,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isZh;
  final bool isDark;
  final VocabularyState vocabState;
  final String currentLang;
  final void Function(String query, String lang) onTriggerAiLookup;
  final bool showDailyGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Language mode row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isZh ? '🇨🇳 Chế độ Tiếng Trung' : '🇺🇸 Chế độ Tiếng Anh',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primaryEnglish,
                ),
              ),
              const LanguageSwitcher(),
            ],
          ),

          if (showDailyGoal) ...[
            const SizedBox(height: 10),
            const DailyGoalCard(),
          ],

          const SizedBox(height: 10),

          // Search bar + AI button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: (val) {
                    ref.read(vocabularyProvider.notifier).search(val);
                  },
                  onSubmitted: (val) => onTriggerAiLookup(val, currentLang),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: isZh
                        ? 'Tra chữ Hán, Pinyin, Hán-Việt...'
                        : 'Tra từ tiếng Anh, nghĩa...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (ctx, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            searchController.clear();
                            ref.read(vocabularyProvider.notifier).search('');
                          },
                        );
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildAiButton(context),
            ],
          ),

          const SizedBox(height: 10),
          _buildLevelFilters(ref),

          if (vocabState.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildTagFilters(ref),
          ],
        ],
      ),
    );
  }

  Widget _buildAiButton(BuildContext context) {
    return IconButton.filled(
      onPressed: () {
        if (searchController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Vui lòng nhập từ bạn muốn AI phân tích.')),
          );
          return;
        }
        onTriggerAiLookup(searchController.text, currentLang);
      },
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primaryEnglish,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltip: 'Phân tích sâu cùng AI (BYOK)',
      icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
    );
  }

  Widget _buildLevelFilters(WidgetRef ref) {
    final levels = isZh
        ? ['HSK 1', 'HSK 2', 'HSK 3', 'HSK 4', 'HSK 5', 'HSK 6']
        : ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: vocabState.selectedLevel == null,
              onSelected: (_) =>
                  ref.read(vocabularyProvider.notifier).filterByLevel(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...levels.map((lvl) {
            final isSelected = vocabState.selectedLevel == lvl;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(lvl),
                selected: isSelected,
                selectedColor: isZh ? AppColors.hskBg : AppColors.cefrBg,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isZh ? AppColors.hskText : AppColors.cefrText)
                      : null,
                ),
                visualDensity: VisualDensity.compact,
                onSelected: (_) =>
                    ref.read(vocabularyProvider.notifier).filterByLevel(lvl),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTagFilters(WidgetRef ref) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Tất cả chủ đề'),
              selected: vocabState.selectedTagId == null,
              onSelected: (_) =>
                  ref.read(vocabularyProvider.notifier).filterByTag(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...vocabState.tags.map((tag) {
            final isSelected = vocabState.selectedTagId == tag.id;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(tag.name),
                selected: isSelected,
                selectedColor: AppColors.primaryEnglishLight,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryEnglish : null,
                ),
                visualDensity: VisualDensity.compact,
                onSelected: (_) =>
                    ref.read(vocabularyProvider.notifier).filterByTag(tag.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}
