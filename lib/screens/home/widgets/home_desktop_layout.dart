import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../providers/srs_provider.dart';
import '../../../widgets/vocivo_logo.dart';
import '../../curriculum/roadmap_view.dart';
import '../../widgets/language_switcher.dart';
import '../../widgets/add_word_dialog.dart';
import '../../widgets/word_detail_panel.dart';
import 'home_search_bar.dart';
import 'home_word_list.dart';

/// Layout dành cho màn hình lớn (Desktop >= 1024px)
/// Gồm 3 cột: [Sidebar collapsible] | [Master List 460px] | [Detail Panel mở rộng]
class HomeDesktopLayout extends StatefulWidget {
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
  State<HomeDesktopLayout> createState() => _HomeDesktopLayoutState();
}

class _HomeDesktopLayoutState extends State<HomeDesktopLayout> {
  // Sidebar collapse state — auto-collapse on narrower desktop windows
  bool _sidebarExpanded = true;

  bool get _isDark => widget.isDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-collapse sidebar when window width < 1280px
    final width = MediaQuery.sizeOf(context).width;
    final shouldExpand = width >= 1280;
    if (shouldExpand != _sidebarExpanded) {
      _sidebarExpanded = shouldExpand;
    }
  }

  double get _sidebarWidth =>
      _sidebarExpanded ? AppBreakpoints.sidebarWidth : AppBreakpoints.navRailWidth;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primaryEnglish;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ── Cột 1: Sidebar (Collapsible) ──────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _sidebarWidth,
              child: _buildSidebar(context, activeColor),
            ),

            if (widget.desktopNavIndex == 0)
              const Expanded(child: RoadmapView())
            else ...[
              // ── Cột 2: Master List ────────────────────────────────
              SizedBox(
                width: AppBreakpoints.masterListWidth,
                child: Column(
                  children: [
                    HomeSearchBar(
                      searchController: widget.searchController,
                      searchFocusNode: widget.searchFocusNode,
                      isZh: widget.isZh,
                      isDark: widget.isDark,
                      vocabState: widget.vocabState,
                      currentLang: widget.currentLang,
                      onTriggerAiLookup: widget.onTriggerAiLookup,
                      showDailyGoal: true,
                    ),
                    Expanded(
                      child: HomeWordList(
                        vocabState: widget.vocabState,
                        isZh: widget.isZh,
                        isDark: widget.isDark,
                        currentLang: widget.currentLang,
                        isDesktop: true,
                        searchQuery: widget.searchController.text,
                        onSelectWord: widget.onSelectWord,
                        onTriggerAiLookup: widget.onTriggerAiLookup,
                      ),
                    ),
                  ],
                ),
              ),

              VerticalDivider(
                width: 1,
                color: _isDark ? AppColors.borderDark : AppColors.borderLight,
              ),

              // ── Cột 3: Detail Panel ───────────────────────────────
              Expanded(
                child: _buildDetailPanel(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (widget.vocabState.selectedWord != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: WordDetailPanel(item: widget.vocabState.selectedWord!),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryEnglishLight,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEnglish.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
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
              color: _isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Phonetics • Nghĩa • Câu ví dụ • Chiết tự',
            style: TextStyle(
              fontSize: 13,
              color: _isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, Color activeColor) {
    return Container(
      decoration: BoxDecoration(
        color: _isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          right: BorderSide(
            color: _isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Logo + Collapse toggle ──────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                _sidebarExpanded ? 20 : 12, 20, 12, 12),
            child: Row(
              children: [
                if (_sidebarExpanded)
                  const Expanded(
                    child: VocivoLogo(
                      size: 34,
                      fontSize: 18,
                      showSlogan: true,
                    ),
                  ),
                if (!_sidebarExpanded) const Spacer(),
                // Collapse/Expand toggle button
                Tooltip(
                  message: _sidebarExpanded ? 'Thu gọn sidebar' : 'Mở rộng sidebar',
                  child: InkWell(
                    onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedRotation(
                        turns: _sidebarExpanded ? 0 : 0.5,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.keyboard_double_arrow_left_rounded,
                          size: 20,
                          color: _isDark
                              ? AppColors.textDarkMuted
                              : AppColors.textLightMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Streak + Language switcher (only when expanded) ─────
          if (_sidebarExpanded) ...[
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
          ] else ...[
            // Collapsed: just show streak icon centered
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildCompactStreak(),
              ),
            ),
          ],

          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── Navigation items ─────────────────────────────────────
          _buildNavItem(
            icon: Icons.alt_route_rounded,
            label: 'Lộ trình học tập',
            isSelected: widget.desktopNavIndex == 0,
            badge: null,
            onTap: () => widget.onSelectNavIndex(0),
            activeColor: activeColor,
          ),
          _buildNavItem(
            icon: Icons.style_outlined,
            label: 'Ôn tập SRS (SM-2)',
            isSelected: false,
            badge: widget.srsState.totalDue > 0
                ? '${widget.srsState.totalDue}'
                : null,
            onTap: () => widget.onNavigateTo(1),
            activeColor: activeColor,
          ),
          _buildNavItem(
            icon: Icons.bookmark_outline_rounded,
            label: 'Sổ từ vựng cá nhân',
            isSelected: false,
            badge: '${widget.vocabState.notebookItems.length}',
            onTap: () => widget.onNavigateTo(2),
            activeColor: activeColor,
          ),
          _buildNavItem(
            icon: Icons.mic_outlined,
            label: 'Luyện phát âm',
            isSelected: false,
            badge: null,
            onTap: () => widget.onNavigateTo(3),
            activeColor: activeColor,
          ),
          _buildNavItem(
            icon: Icons.emoji_events_outlined,
            label: 'Tiến độ & Thành tích',
            isSelected: false,
            badge: null,
            onTap: () => widget.onNavigateTo(4),
            activeColor: activeColor,
          ),
          _buildNavItem(
            icon: Icons.settings_outlined,
            label: 'Cài đặt & API Key',
            isSelected: false,
            badge: null,
            onTap: () => widget.onNavigateTo(5),
            activeColor: activeColor,
          ),

          const Spacer(),

          // ── Add word button (full or icon-only) ─────────────────
          Padding(
            padding: EdgeInsets.all(_sidebarExpanded ? 16 : 10),
            child: _sidebarExpanded
                ? ElevatedButton.icon(
                    onPressed: () => AddWordDialog.show(context,
                        initialLanguage: widget.currentLang),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm từ mới'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEnglish,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  )
                : Tooltip(
                    message: 'Thêm từ mới',
                    child: FloatingActionButton.small(
                      onPressed: () => AddWordDialog.show(context,
                          initialLanguage: widget.currentLang),
                      backgroundColor: AppColors.primaryEnglish,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
          ),
        ],
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
                '${widget.srsState.streak} ngày',
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

  Widget _buildCompactStreak() {
    return Tooltip(
      message: '${widget.srsState.streak} ngày liên tiếp',
      child: InkWell(
        onTap: () => widget.onNavigateTo(4),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.streakOrangeLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.streakOrange, size: 16),
              Text(
                '${widget.srsState.streak}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: const Color(0xFFC2410C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required String? badge,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: _sidebarExpanded ? 12 : 8, vertical: 2),
      child: Tooltip(
        message: _sidebarExpanded ? '' : label,
        child: _HoverableNavItem(
          onTap: onTap,
          isSelected: isSelected,
          isDark: _isDark,
          activeColor: activeColor,
          child: _sidebarExpanded
              ? Row(
                  children: [
                    Icon(
                      icon,
                      color: isSelected
                          ? activeColor
                          : (_isDark
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
                              ? (_isDark
                                  ? Colors.white
                                  : AppColors.textLightPrimary)
                              : (_isDark
                                  ? AppColors.textDarkSecondary
                                  : AppColors.textLightSecondary),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
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
                )
              : Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: isSelected
                            ? activeColor
                            : (_isDark
                                ? AppColors.textDarkMuted
                                : AppColors.textLightMuted),
                        size: 22,
                      ),
                      if (badge != null && badge != '0')
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: activeColor,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 14, minHeight: 14),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Reusable hoverable nav item with animated highlight
class _HoverableNavItem extends StatefulWidget {
  const _HoverableNavItem({
    required this.child,
    required this.onTap,
    required this.isSelected,
    required this.isDark,
    required this.activeColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDark;
  final Color activeColor;

  @override
  State<_HoverableNavItem> createState() => _HoverableNavItemState();
}

class _HoverableNavItemState extends State<_HoverableNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.isDark
                    ? widget.activeColor.withValues(alpha: 0.18)
                    : widget.activeColor.withValues(alpha: 0.10))
                : _hovered
                    ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04))
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(
                    color: widget.activeColor.withValues(alpha: 0.35),
                    width: 1.5)
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
