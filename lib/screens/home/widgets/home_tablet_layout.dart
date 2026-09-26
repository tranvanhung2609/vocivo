import 'package:flutter/material.dart';
import '../../../core/constants/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../providers/srs_provider.dart';
import '../../curriculum/roadmap_view.dart';
import '../../widgets/add_word_dialog.dart';
import '../../widgets/word_detail_panel.dart';
import 'home_search_bar.dart';
import 'home_word_list.dart';

/// Layout dành cho Tablet (600–1023px)
/// [NavigationRail compact] | [Master List] | [Detail Panel — nếu chọn từ]
class HomeTabletLayout extends StatelessWidget {
  const HomeTabletLayout({
    super.key,
    required this.isZh,
    required this.isDark,
    required this.vocabState,
    required this.srsState,
    required this.currentLang,
    required this.searchController,
    required this.searchFocusNode,
    required this.tabletNavIndex,
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
  final int tabletNavIndex;
  final ValueChanged<int> onSelectNavIndex;
  final void Function(int navIndex) onNavigateTo;
  final void Function(String query, String lang) onTriggerAiLookup;
  final void Function(VocabularyItem item) onSelectWord;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ── NavigationRail (compact icons only) ───────────────
            NavigationRail(
              selectedIndex: tabletNavIndex,
              onDestinationSelected: (i) {
                if (i == 0) {
                  onSelectNavIndex(0);
                } else {
                  onNavigateTo(i);
                }
              },
              minWidth: AppBreakpoints.navRailWidth,
              useIndicator: true,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.alt_route_rounded),
                  selectedIcon: Icon(Icons.alt_route_rounded),
                  label: Text('Lộ trình'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    label: Text('${srsState.totalDue}'),
                    isLabelVisible: srsState.totalDue > 0,
                    child: const Icon(Icons.style_outlined),
                  ),
                  selectedIcon: const Icon(Icons.style_rounded),
                  label: const Text('Ôn tập'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.bookmark_outline_rounded),
                  selectedIcon: Icon(Icons.bookmark_rounded),
                  label: Text('Sổ từ'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.mic_none_rounded),
                  selectedIcon: Icon(Icons.mic_rounded),
                  label: Text('Luyện nói'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.emoji_events_outlined),
                  selectedIcon: Icon(Icons.emoji_events_rounded),
                  label: Text('Tiến độ'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Cài đặt'),
                ),
              ],
            ),

            VerticalDivider(
              width: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),

            // ── Dual-pane: list + optional detail ────────────────
            Expanded(
              child: tabletNavIndex == 0
                  ? const RoadmapView()
                  : (vocabState.selectedWord != null
                      ? Row(
                          children: [
                            // Word list (constrained)
                            SizedBox(
                              width: 360,
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
                                    showDailyGoal: false,
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
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                            // Detail panel
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child:
                                    WordDetailPanel(item: vocabState.selectedWord!),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            HomeSearchBar(
                              searchController: searchController,
                              searchFocusNode: searchFocusNode,
                              isZh: isZh,
                              isDark: isDark,
                              vocabState: vocabState,
                              currentLang: currentLang,
                              onTriggerAiLookup: onTriggerAiLookup,
                              showDailyGoal: false,
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
                        )),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            AddWordDialog.show(context, initialLanguage: currentLang),
        backgroundColor: AppColors.primaryEnglish,
        foregroundColor: Colors.white,
        tooltip: 'Thêm từ mới',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
