import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../providers/srs_provider.dart';
import '../../../widgets/vocivo_logo.dart';
import '../../curriculum/roadmap_view.dart';
import '../../curriculum/widgets/ai_generate_deck_dialog.dart';
import '../../widgets/ai_lookup_dialog.dart';

/// Layout dành cho Mobile (< 600px)
/// Tối ưu cho thao tác một tay, lấy Lộ Trình Học Tập (Roadmap) làm trung tâm
class HomeMobileLayout extends StatefulWidget {
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
  State<HomeMobileLayout> createState() => _HomeMobileLayoutState();
}

class _HomeMobileLayoutState extends State<HomeMobileLayout> {
  // FAB hide-on-scroll state
  bool _showFab = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrollingDown = _scrollController.position.userScrollDirection ==
        ScrollDirection.reverse;
    final isScrollingUp = _scrollController.position.userScrollDirection ==
        ScrollDirection.forward;
    if (isScrollingDown && _showFab) {
      setState(() => _showFab = false);
    } else if (isScrollingUp && !_showFab) {
      setState(() => _showFab = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _buildMobileAppBar(context),
      body: const RoadmapView(),
      floatingActionButton: AnimatedSlide(
        offset: _showFab ? Offset.zero : const Offset(0, 2.5),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _showFab ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.extended(
            onPressed: () => AiGenerateDeckDialog.show(
              context,
              languageCode: widget.currentLang,
            ),
            backgroundColor: widget.isZh ? const Color(0xFFEF4444) : AppColors.primaryEnglish,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: Text(
              'Tạo Bộ Thẻ AI',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
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
        // Tra từ AI
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Tra cứu AI',
          onPressed: () =>
              AiLookupDialog.show(context, query: '', languageCode: widget.currentLang),
        ),
        // Progress & Achievements button
        IconButton(
          icon: const Icon(Icons.emoji_events_outlined),
          tooltip: 'Tiến độ & Thành tích',
          onPressed: () => widget.onNavigateTo(4), // Progress = index 4
        ),
        // Settings
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Cài đặt',
          onPressed: () => widget.onNavigateTo(5), // Settings = index 5
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: (widget.isDark ? AppColors.cardDark : Colors.white)
              .withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
              color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          // ─── Nav index mapping (đồng nhất với _NavDest enum) ───────────
          // _NavDest: 0=roadmap 1=review 2=notebook 3=speaking 4=progress 5=settings
          // BottomNav: 0=roadmap 1=review 2=notebook 3=speaking 4=settings
          onDestinationSelected: (idx) {
            switch (idx) {
              case 0:
                break; // Stay on home / roadmap
              case 1:
                widget.onNavigateTo(1); // Review
                break;
              case 2:
                widget.onNavigateTo(2); // Notebook
                break;
              case 3:
                widget.onNavigateTo(3); // Speaking
                break;
              case 4:
                widget.onNavigateTo(5); // Settings
                break;
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.alt_route_rounded),
              selectedIcon: Icon(Icons.alt_route_rounded),
              label: 'Lộ trình',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${widget.srsState.totalDue}'),
                isLabelVisible: widget.srsState.totalDue > 0,
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
      onTap: () => widget.onNavigateTo(4),
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
                '${widget.srsState.streak}',
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
