import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/curriculum_model.dart';
import '../../providers/curriculum_provider.dart';
import '../../providers/daily_learning_provider.dart';
import '../../providers/language_mode_provider.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/vocivo_logo.dart';
import '../progress/progress_screen.dart';
import '../review/srs_review_screen.dart';
import '../settings/settings_screen.dart';
import '../speaking/speaking_screen.dart';
import 'learning_path_view.dart';
import 'lesson_player_screen.dart';
import 'practice_hub.dart';
import 'today_dashboard.dart';
import 'vocabulary_library_view.dart';

enum V2Destination { today, path, practice, library, progress }

class VocivoAppShell extends ConsumerStatefulWidget {
  const VocivoAppShell({super.key});

  @override
  ConsumerState<VocivoAppShell> createState() => _VocivoAppShellState();
}

class _VocivoAppShellState extends ConsumerState<VocivoAppShell> {
  V2Destination _destination = V2Destination.today;
  bool _sidebarExpanded = true;

  static const _destinations =
      <({String label, IconData icon, IconData selectedIcon})>[
        (
          label: 'Hôm nay',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        (
          label: 'Lộ trình',
          icon: Icons.alt_route_outlined,
          selectedIcon: Icons.alt_route_rounded,
        ),
        (
          label: 'Luyện tập',
          icon: Icons.fitness_center_outlined,
          selectedIcon: Icons.fitness_center_rounded,
        ),
        (
          label: 'Sổ từ',
          icon: Icons.bookmark_outline_rounded,
          selectedIcon: Icons.bookmark_rounded,
        ),
        (
          label: 'Tiến bộ',
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights_rounded,
        ),
      ];

  void _select(V2Destination destination) =>
      setState(() => _destination = destination);

  Future<void> _openDailySession() async {
    final session = await ref
        .read(dailyLearningProvider.notifier)
        .startOrResumeDailySession();
    if (!mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khóa học chưa có nội dung để bắt đầu.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const LessonPlayerScreen()),
    );
    if (!mounted) return;
    await ref.read(dailyLearningProvider.notifier).refresh();
    final lang = ref.read(languageModeProvider);
    await ref.read(curriculumProvider.notifier).loadCurriculum(lang);
  }

  Future<void> _openUnit(CurriculumUnit unit) async {
    await ref.read(dailyLearningProvider.notifier).startUnitSession(unit);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const LessonPlayerScreen()),
    );
    if (mounted) {
      await ref.read(dailyLearningProvider.notifier).refresh();
      await ref
          .read(curriculumProvider.notifier)
          .loadCurriculum(unit.languageCode);
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final width = MediaQuery.sizeOf(context).width;
    final showContextPanel = width >= 1380;
    final selectedIndex = _destination.index;

    final pages = <Widget>[
      TodayDashboard(
        onStartSession: _openDailySession,
        onOpenPath: () => _select(V2Destination.path),
        onOpenPractice: () => _select(V2Destination.practice),
      ),
      LearningPathView(onStartUnit: _openUnit),
      PracticeHub(
        onOpenReview: () => _push(const SrsReviewScreen()),
        onOpenSpeaking: () => _push(const SpeakingScreen()),
        onStartQuickSession: _openDailySession,
      ),
      const VocabularyLibraryView(),
      const ProgressScreen(),
    ];

    final content = IndexedStack(index: selectedIndex, children: pages);

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
          _select(V2Destination.today),
      const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
          _select(V2Destination.path),
      const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () =>
          _select(V2Destination.practice),
      const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
          _select(V2Destination.library),
      const SingleActivator(LogicalKeyboardKey.digit5, alt: true): () =>
          _select(V2Destination.progress),
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: isDesktop
            ? Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      _DesktopSidebar(
                        selectedIndex: selectedIndex,
                        expanded: _sidebarExpanded,
                        onToggle: () => setState(
                          () => _sidebarExpanded = !_sidebarExpanded,
                        ),
                        onSelected: (index) =>
                            _select(V2Destination.values[index]),
                        onSettings: () => _push(const SettingsScreen()),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                      if (showContextPanel) ...[
                        const VerticalDivider(width: 1),
                        const SizedBox(width: 300, child: _ContextPanel()),
                      ],
                    ],
                  ),
                ),
              )
            : Scaffold(
                appBar: AppBar(
                  title: Text(_destinations[selectedIndex].label),
                  leadingWidth: 52,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: VocivoLogo(size: 32, showText: false),
                  ),
                  actions: [
                    const _CompactCourseSwitcher(),
                    IconButton(
                      tooltip: 'Cài đặt',
                      onPressed: () => _push(const SettingsScreen()),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                body: isTablet
                    ? Row(
                        children: [
                          NavigationRail(
                            selectedIndex: selectedIndex,
                            onDestinationSelected: (index) =>
                                _select(V2Destination.values[index]),
                            labelType: NavigationRailLabelType.all,
                            destinations: _destinations
                                .map(
                                  (item) => NavigationRailDestination(
                                    icon: Icon(item.icon),
                                    selectedIcon: Icon(item.selectedIcon),
                                    label: Text(item.label),
                                  ),
                                )
                                .toList(),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: content),
                        ],
                      )
                    : content,
                bottomNavigationBar: isTablet
                    ? null
                    : NavigationBar(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (index) =>
                            _select(V2Destination.values[index]),
                        destinations: _destinations
                            .map(
                              (item) => NavigationDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(item.selectedIcon),
                                label: item.label,
                              ),
                            )
                            .toList(),
                      ),
              ),
      ),
    );
  }
}

class _DesktopSidebar extends ConsumerWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.expanded,
    required this.onToggle,
    required this.onSelected,
    required this.onSettings,
  });
  final int selectedIndex;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = expanded
        ? AppBreakpoints.sidebarWidth
        : AppBreakpoints.navRailWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: isDark ? AppColors.surfaceDark1 : Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 76,
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: expanded ? 18 : 16),
                  child: VocivoLogo(size: 36, showText: expanded, fontSize: 20),
                ),
                if (expanded) const Spacer(),
                IconButton(
                  tooltip: expanded ? 'Thu gọn sidebar' : 'Mở rộng sidebar',
                  onPressed: onToggle,
                  icon: Icon(
                    expanded
                        ? Icons.first_page_rounded
                        : Icons.last_page_rounded,
                  ),
                ),
                if (expanded) const SizedBox(width: 8),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8),
            child: _CourseSwitcher(expanded: expanded, language: language),
          ),
          const SizedBox(height: 16),
          for (
            var index = 0;
            index < _VocivoAppShellState._destinations.length;
            index++
          )
            _SidebarItem(
              item: _VocivoAppShellState._destinations[index],
              selected: index == selectedIndex,
              expanded: expanded,
              shortcut: 'Alt+${index + 1}',
              onTap: () => onSelected(index),
            ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8),
            child: _SidebarItem(
              item: const (
                label: 'Cài đặt',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
              ),
              selected: false,
              expanded: expanded,
              shortcut: '',
              onTap: onSettings,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CourseSwitcher extends ConsumerWidget {
  const _CourseSwitcher({required this.expanded, required this.language});
  final bool expanded;
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> setLanguage(String code) async {
      await ref.read(languageModeProvider.notifier).setLanguage(code);
      await ref.read(curriculumProvider.notifier).loadCurriculum(code);
    }

    if (!expanded) {
      return Tooltip(
        message: language == 'ZH' ? 'Tiếng Trung' : 'Tiếng Anh',
        child: InkWell(
          onTap: () => setLanguage(language == 'ZH' ? 'EN' : 'ZH'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              language == 'ZH' ? '中' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: language,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Khóa học',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(value: 'EN', child: Text('🇬🇧  Tiếng Anh')),
        DropdownMenuItem(value: 'ZH', child: Text('🇨🇳  Tiếng Trung')),
      ],
      onChanged: (value) {
        if (value != null) setLanguage(value);
      },
    );
  }
}

class _CompactCourseSwitcher extends ConsumerWidget {
  const _CompactCourseSwitcher();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageModeProvider);
    return TextButton(
      onPressed: () => ref
          .read(languageModeProvider.notifier)
          .setLanguage(language == 'ZH' ? 'EN' : 'ZH'),
      child: Text(language == 'ZH' ? '🇨🇳 ZH' : '🇬🇧 EN'),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.shortcut,
    required this.onTap,
  });
  final ({String label, IconData icon, IconData selectedIcon}) item;
  final bool selected;
  final bool expanded;
  final String shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8, vertical: 3),
    child: Tooltip(
      message: expanded ? '' : item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryEnglish.withValues(alpha: 0.11)
                : null,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(
                    color: AppColors.primaryEnglish.withValues(alpha: 0.25),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected
                    ? AppColors.primaryEnglish
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primaryEnglishDeep : null,
                    ),
                  ),
                ),
                if (shortcut.isNotEmpty)
                  Text(shortcut, style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ContextPanel extends ConsumerWidget {
  const _ContextPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(dailyLearningProvider);
    final progress = ref.watch(progressProvider);
    final profile = learning.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? AppColors.surfaceDark1 : Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Tổng quan',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _ContextStat(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.streakOrange,
            value: '${progress.currentStreak}',
            label: 'ngày liên tiếp',
          ),
          const SizedBox(height: 10),
          _ContextStat(
            icon: Icons.bolt_rounded,
            color: AppColors.streakAmber,
            value: '${progress.totalXp}',
            label: 'XP tích lũy',
          ),
          const SizedBox(height: 10),
          _ContextStat(
            icon: Icons.refresh_rounded,
            color: AppColors.primaryEnglish,
            value: '${learning.dueCount}',
            label: 'từ đến hạn',
          ),
          const SizedBox(height: 26),
          Text('Mục tiêu học', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryEnglish.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.goal ?? 'Giao tiếp thực tế',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  '${profile?.dailyMinutes ?? 15} phút mỗi ngày',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('Gợi ý hôm nay', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            learning.dueCount > 0
                ? 'Bắt đầu bằng phần ôn tập để củng cố trí nhớ trước khi học nội dung mới.'
                : 'Bạn đã xử lý phần ôn tập. Đây là lúc phù hợp để học bài tiếp theo và luyện nói.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ContextStat extends StatelessWidget {
  const _ContextStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}
