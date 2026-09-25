import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../providers/srs_provider.dart';
import '../../../widgets/vocivo_logo.dart';
import '../../widgets/language_switcher.dart';
import '../../widgets/add_word_dialog.dart';
import '../../widgets/word_detail_panel.dart';
import 'home_search_bar.dart';
import 'home_word_list.dart';

/// Layout dành cho màn hình lớn (Desktop >= 1024px)
/// Gồm 3 cột: [Sidebar 260px] | [Master List 460px] | [Detail Panel mở rộng]
class HomeDesktopLayout extends StatelessWidget {
  const HomeDesktopLayout({
    super.key,
    required this.isZh,
    required this.isDark,
    required this.vocabState,
    required this.srsState,
    required this.currentLang,
    required this.searchController,
    required this.searchFocusNode,
    required this.desktopNavIndex,
    required this.onSelectNavIndex,
    required this.onNavigateTo,
    required this.onTriggerAiLookup,
    required this.onSelectWord,
  });

  final bool isZh;
  final bool isDark;
  final VocabularyState vocabState;
  final SrsState srsState;
  final String currentLang;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final int desktopNavIndex;
  final ValueChanged<int> onSelectNavIndex;
  final void Function(int navIndex) onNavigateTo;
  final void Function(String query, String lang) onTriggerAiLookup;
  final void Function(VocabularyItem item) onSelectWord;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primaryEnglish;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ── Cột 1: Sidebar ────────────────────────────────────
            SizedBox(
              width: AppBreakpoints.sidebarWidth,
              child: _buildSidebar(context, activeColor),
            ),

            // ── Cột 2: Master List ────────────────────────────────
            SizedBox(
              width: AppBreakpoints.masterListWidth,
              child: Column(
                children: [
                  HomeSearchBar(
                    searchController: searchController,
                    searchFocusNode: searchFocusNode,
                    isZh: isZh,
                    isDark: isDark,
                    vocabState: vocabState,
                    currentLang: currentLang,
                    onTriggerAiLookup: onTriggerAiLookup,
                    showDailyGoal: true,
                  ),
                  Expanded(
                    child: HomeWordList(
                      vocabState: vocabState,
                      isZh: isZh,
                      isDark: isDark,
                      currentLang: currentLang,
                      isDesktop: true,
                      searchQuery: searchController.text,
                      onSelectWord: onSelectWord,
                      onTriggerAiLookup: onTriggerAiLookup,
                    ),
                  ),
                ],
              ),
            ),

            VerticalDivider(
              width: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),

            // ── Cột 3: Detail Panel ───────────────────────────────
            Expanded(
              child: _buildDetailPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (vocabState.selectedWord != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: WordDetailPanel(item: vocabState.selectedWord!),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primaryEnglishLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              size: 36,
              color: AppColors.primaryEnglish,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn một từ để xem chi tiết',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Phonetics • Nghĩa • Câu ví dụ • Chiết tự',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, Color activeColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo thương hiệu
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: VocivoLogo(
              size: 38,
              fontSize: 19,
              showSlogan: true,
            ),
          ),

          // Streak + Bộ chuyển ngôn ngữ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStreakBadge(),
                const LanguageSwitcher(),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Menu navigation
          _buildSidebarNavItem(
            icon: Icons.search_rounded,
            label: 'Tra cứu từ vựng',
            isSelected: desktopNavIndex == 0,
            badge: null,
            onTap: () => onSelectNavIndex(0),
            activeColor: activeColor,
          ),
          _buildSidebarNavItem(
            icon: Icons.style_outlined,
            label: 'Ôn tập SRS (SM-2)',
            isSelected: false,
            badge: srsState.totalDue > 0 ? '${srsState.totalDue}' : null,
            onTap: () => onNavigateTo(1),
            activeColor: activeColor,
          ),
          _buildSidebarNavItem(
            icon: Icons.mic_outlined,
            label: 'Luyện phát âm',
            isSelected: false,
            badge: null,
            onTap: () => onNavigateTo(2),
            activeColor: activeColor,
          ),
          _buildSidebarNavItem(
            icon: Icons.bookmark_outline_rounded,
            label: 'Sổ từ vựng cá nhân',
            isSelected: false,
            badge: '${vocabState.notebookItems.length}',
            onTap: () => onNavigateTo(3),
            activeColor: activeColor,
          ),
          _buildSidebarNavItem(
            icon: Icons.emoji_events_outlined,
            label: 'Tiến độ & Thành tích',
            isSelected: false,
            badge: null,
            onTap: () => onNavigateTo(4),
            activeColor: activeColor,
          ),
          _buildSidebarNavItem(
            icon: Icons.settings_outlined,
            label: 'Cài đặt & API Key',
            isSelected: false,
            badge: null,
            onTap: () => onNavigateTo(5),
            activeColor: activeColor,
          ),

          const Spacer(),

          // Nút thêm từ
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () =>
                  AddWordDialog.show(context, initialLanguage: currentLang),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm từ mới'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEnglish,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge() {
    return InkWell(
      onTap: () => onNavigateTo(4),
      borderRadius: BorderRadius.circular(16),
      child: Tooltip(
        message: 'Xem tiến độ & chuỗi học',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.streakOrangeLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.streakOrange, size: 18),
              const SizedBox(width: 4),
              Text(
                '${srsState.streak} ngày',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: const Color(0xFFC2410C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required String? badge,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? activeColor.withValues(alpha: 0.15)
                    : activeColor.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(
                    color: activeColor.withValues(alpha: 0.3), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? activeColor
                    : (isDark
                        ? AppColors.textDarkMuted
                        : AppColors.textLightMuted),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.textLightPrimary)
                        : (isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textLightSecondary),
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: activeColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
