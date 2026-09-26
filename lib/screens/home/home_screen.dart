import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/language_mode_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/srs_provider.dart';
import '../../providers/ai_search_provider.dart';
import '../widgets/ai_lookup_dialog.dart';
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
enum _NavDest { search, review, notebook, speaking, progress, settings }

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
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        snap: true,
        snapSizes: const [0.5, 0.88, 0.95],
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
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

  // ── Navigation helper with smooth fade transition ──────────────
  void _navigateTo(_NavDest dest) {
    Widget? screen;
    switch (dest) {
      case _NavDest.review:
        screen = const SrsReviewScreen();
        break;
      case _NavDest.speaking:
        screen = const SpeakingScreen();
        break;
      case _NavDest.notebook:
        screen = const NotebookScreen();
        break;
      case _NavDest.progress:
        screen = const ProgressScreen();
        break;
      case _NavDest.settings:
        screen = const SettingsScreen();
        break;
      case _NavDest.search:
        return;
    }
    Navigator.push(
      context,
      _buildPageRoute(screen),
    );
  }

  /// Smooth fade+slide transition for all page navigation
  PageRouteBuilder<void> _buildPageRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );
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
              ? HomeTabletLayout(
                  isZh: isZh,
                  isDark: isDark,
                  vocabState: vocabState,
                  srsState: srsState,
                  currentLang: currentLang,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  tabletNavIndex: _desktopNavIndex,
                  onSelectNavIndex: (i) => setState(() => _desktopNavIndex = i),
                  onNavigateTo: _navigateToIndex,
                  onTriggerAiLookup: _triggerAiLookup,
                  onSelectWord: (item) {
                    ref.read(vocabularyProvider.notifier).selectWord(item);
                  },
                )
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
}
