import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../providers/srs_provider.dart';
import '../../../widgets/vocivo_logo.dart';
import '../../widgets/add_word_dialog.dart';
import 'home_search_bar.dart';
import 'home_word_list.dart';

/// Layout dành cho Mobile (< 600px)
/// Tối ưu cho thao tác một tay, có bottom navigation bar và floating action button
class HomeMobileLayout extends StatelessWidget {
  const HomeMobileLayout({
    super.key,
    required this.isZh,
    required this.isDark,
    required this.vocabState,
    required this.srsState,
    required this.currentLang,
    required this.searchController,
    required this.searchFocusNode,
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
  final void Function(int navIndex) onNavigateTo;
  final void Function(String query, String lang) onTriggerAiLookup;
  final void Function(VocabularyItem item) onSelectWord;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _buildMobileAppBar(context),
      body: Column(
        children: [
          // Thanh tìm kiếm và bộ lọc trên cùng
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

          // Danh sách từ vựng
          Expanded(
            child: HomeWordList(
              vocabState: vocabState,
              isZh: isZh,
              isDark: isDark,
              currentLang: currentLang,
              isDesktop: false,
              searchQuery: searchController.text,
              onSelectWord: onSelectWord,
              onTriggerAiLookup: onTriggerAiLookup,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            AddWordDialog.show(context, initialLanguage: currentLang),
        backgroundColor: AppColors.primaryEnglish,
        foregroundColor: Colors.white,
        tooltip: 'Thêm từ mới',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildMobileBottomNav(),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      title: const VocivoLogo(
        size: 32,
        fontSize: 20,
      ),
      actions: [
        // Streak counter
        _buildStreakBadge(),
        const SizedBox(width: 4),
        // Progress & Achievements button
        IconButton(
          icon: const Icon(Icons.emoji_events_outlined),
          tooltip: 'Tiến độ & Thành tích',
          onPressed: () => onNavigateTo(4), // Progress
        ),
        // Add word button
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          tooltip: 'Thêm từ mới',
          onPressed: () =>
              AddWordDialog.show(context, initialLanguage: currentLang),
        ),
        // Settings
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Cài đặt',
          onPressed: () => onNavigateTo(5), // Settings
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: (isDark ? AppColors.cardDark : Colors.white)
              .withValues(alpha: 0.92),
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          onDestinationSelected: (idx) {
            switch (idx) {
              case 1:
                onNavigateTo(1); // Review
                break;
              case 2:
                onNavigateTo(2); // Speaking
                break;
              case 3:
                onNavigateTo(3); // Notebook
                break;
              case 4:
                onNavigateTo(5); // Settings
                break;
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.search_rounded),
              label: 'Tra từ',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${srsState.totalDue}'),
                isLabelVisible: srsState.totalDue > 0,
                child: const Icon(Icons.style_outlined),
              ),
              selectedIcon: const Icon(Icons.style_rounded),
              label: 'Ôn tập',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Sổ từ',
            ),
            const NavigationDestination(
              icon: Icon(Icons.mic_none_rounded),
              selectedIcon: Icon(Icons.mic_rounded),
              label: 'Luyện nói',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Cài đặt',
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.streakOrangeLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.streakOrange, size: 16),
              const SizedBox(width: 4),
              Text(
                '${srsState.streak}',
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
}
