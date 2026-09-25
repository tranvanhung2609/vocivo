import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/language_mode_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/srs_provider.dart';
import '../../providers/ai_search_provider.dart';
import '../widgets/ai_lookup_dialog.dart';
import '../widgets/add_word_dialog.dart';
import '../widgets/word_detail_panel.dart';
import '../review/srs_review_screen.dart';
import '../notebook/notebook_screen.dart';
import '../settings/settings_screen.dart';
import '../speaking/speaking_screen.dart';
import '../progress/progress_screen.dart';
import 'widgets/home_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Navigation destination definitions (shared across all layout modes)
// ─────────────────────────────────────────────────────────────────────────────
enum _NavDest { search, review, speaking, notebook, progress, settings }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Desktop/tablet sidebar nav index (0 = search, stays in-page)
  int _desktopNavIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── AI Lookup ─────────────────────────────────────────────────
  void _triggerAiLookup(String query, String lang) {
    if (query.trim().isEmpty) return;
    ref.read(aiSearchProvider.notifier).lookupWord(
          query: query.trim(),
          languageCode: lang,
        );
    AiLookupDialog.show(context, query: query.trim(), languageCode: lang);
  }

  // ── Word Detail (mobile / tablet = bottom sheet) ──────────────
  void _showWordDetailModal(VocabularyItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true, // respects notch / home indicator
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        snap: true,
        snapSizes: const [0.5, 0.88, 0.95],
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.cardDark
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: WordDetailPanel(
                  item: item,
                  scrollController: controller,
                  onClose: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation helper ─────────────────────────────────────────
  void _navigateTo(_NavDest dest) {
    switch (dest) {
      case _NavDest.review:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SrsReviewScreen()),
        );
        break;
      case _NavDest.speaking:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SpeakingScreen()),
        );
        break;
      case _NavDest.notebook:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotebookScreen()),
        );
        break;
      case _NavDest.progress:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProgressScreen()),
        );
        break;
      case _NavDest.settings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
      case _NavDest.search:
        break;
    }
  }

  void _navigateToIndex(int index) {
    if (index >= 0 && index < _NavDest.values.length) {
      _navigateTo(_NavDest.values[index]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(languageModeProvider);
    final vocabState = ref.watch(vocabularyProvider);
    final srsState = ref.watch(srsProvider);
    final isZh = currentLang == 'ZH';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    // Desktop keyboard shortcut: Ctrl+F → focus search
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: isDesktop
          ? HomeDesktopLayout(
              isZh: isZh,
              isDark: isDark,
              vocabState: vocabState,
              srsState: srsState,
              currentLang: currentLang,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              desktopNavIndex: _desktopNavIndex,
              onSelectNavIndex: (i) => setState(() => _desktopNavIndex = i),
              onNavigateTo: _navigateToIndex,
              onTriggerAiLookup: _triggerAiLookup,
              onSelectWord: (item) {
                ref.read(vocabularyProvider.notifier).selectWord(item);
              },
            )
          : isTablet
              ? _buildTabletLayout(
                  context, isZh, isDark, vocabState, srsState, currentLang)
              : HomeMobileLayout(
                  isZh: isZh,
                  isDark: isDark,
                  vocabState: vocabState,
                  srsState: srsState,
                  currentLang: currentLang,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onNavigateTo: _navigateToIndex,
                  onTriggerAiLookup: _triggerAiLookup,
                  onSelectWord: (item) {
                    ref.read(vocabularyProvider.notifier).selectWord(item);
                    _showWordDetailModal(item);
                  },
                ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABLET LAYOUT  (600–1024px)
  // [NavigationRail] | [Master List] | [Detail Panel — if word selected]
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout(
    BuildContext context,
    bool isZh,
    bool isDark,
    VocabularyState vocabState,
    SrsState srsState,
    String currentLang,
  ) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ── NavigationRail (compact icons) ────────────────────
            NavigationRail(
              selectedIndex: _desktopNavIndex,
              onDestinationSelected: (i) {
                if (i == 0) {
                  setState(() => _desktopNavIndex = 0);
                } else {
                  _navigateTo(_NavDest.values[i]);
                }
              },
              minWidth: AppBreakpoints.navRailWidth,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.search_rounded),
                  label: Text('Tra từ'),
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
                  icon: Icon(Icons.mic_none_rounded),
                  selectedIcon: Icon(Icons.mic_rounded),
                  label: Text('Luyện nói'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.bookmark_outline_rounded),
                  selectedIcon: Icon(Icons.bookmark_rounded),
                  label: Text('Sổ từ'),
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
              child: vocabState.selectedWord != null
                  ? Row(
                      children: [
                        // Word list (constrained)
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              HomeSearchBar(
                                searchController: _searchController,
                                searchFocusNode: _searchFocusNode,
                                isZh: isZh,
                                isDark: isDark,
                                vocabState: vocabState,
                                currentLang: currentLang,
                                onTriggerAiLookup: _triggerAiLookup,
                                showDailyGoal: false,
                              ),
                              Expanded(
                                child: HomeWordList(
                                  vocabState: vocabState,
                                  isZh: isZh,
                                  isDark: isDark,
                                  currentLang: currentLang,
                                  isDesktop: true,
                                  searchQuery: _searchController.text,
                                  onSelectWord: (item) {
                                    ref
                                        .read(vocabularyProvider.notifier)
                                        .selectWord(item);
                                  },
                                  onTriggerAiLookup: _triggerAiLookup,
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
                          searchController: _searchController,
                          searchFocusNode: _searchFocusNode,
                          isZh: isZh,
                          isDark: isDark,
                          vocabState: vocabState,
                          currentLang: currentLang,
                          onTriggerAiLookup: _triggerAiLookup,
                          showDailyGoal: false,
                        ),
                        Expanded(
                          child: HomeWordList(
                            vocabState: vocabState,
                            isZh: isZh,
                            isDark: isDark,
                            currentLang: currentLang,
                            isDesktop: true,
                            searchQuery: _searchController.text,
                            onSelectWord: (item) {
                              ref
                                  .read(vocabularyProvider.notifier)
                                  .selectWord(item);
                            },
                            onTriggerAiLookup: _triggerAiLookup,
                          ),
                        ),
                      ],
                    ),
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
