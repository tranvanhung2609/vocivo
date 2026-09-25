import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../models/achievement_model.dart';
import '../../models/learning_stats_model.dart';
import '../../providers/progress_provider.dart';
import '../../providers/vocabulary_provider.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final progressState = ref.watch(progressProvider);
    final vocabState = ref.watch(vocabularyProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isTablet = width >= AppBreakpoints.tablet && width < AppBreakpoints.desktop;

    final userLevel = progressState.userLevel;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiến Độ & Thành Tích',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
              ),
            ),
            Text(
              '${progressState.unlockedAchievementsCount}/${progressState.achievements.length} Huy hiệu  •  ${progressState.totalXp} XP',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1040 : (isTablet ? 760 : double.infinity),
            ),
            child: isDesktop
                ? _buildDesktopLayout(progressState, vocabState, userLevel, isDark)
                : _buildMobileLayout(progressState, vocabState, userLevel, isDark),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MOBILE / TABLET LAYOUT
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    ProgressState progress,
    VocabularyState vocabState,
    UserLevel userLevel,
    bool isDark,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level Card
          _buildLevelCard(userLevel, isDark),
          const SizedBox(height: 16),

          // Streak & Quick Stats
          _buildStreakCard(progress, isDark),
          const SizedBox(height: 16),

          // Weekly Activity & Heatmap
          _buildActivityCard(progress.recentActivities, isDark),
          const SizedBox(height: 16),

          // Mastery Funnel
          _buildMasteryFunnelCard(vocabState, isDark),
          const SizedBox(height: 24),

          // Achievements Section
          _buildAchievementsSection(progress.achievements, isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DESKTOP DUAL-COLUMN LAYOUT
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(
    ProgressState progress,
    VocabularyState vocabState,
    UserLevel userLevel,
    bool isDark,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Level, Streak, Activity
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _buildLevelCard(userLevel, isDark),
                const SizedBox(height: 18),
                _buildStreakCard(progress, isDark),
                const SizedBox(height: 18),
                _buildActivityCard(progress.recentActivities, isDark),
                const SizedBox(height: 18),
                _buildMasteryFunnelCard(vocabState, isDark),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Right Column: Achievements & Badges
          Expanded(
            flex: 6,
            child: _buildAchievementsSection(progress.achievements, isDark),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LEVEL & XP CARD
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLevelCard(UserLevel userLevel, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF065F46), const Color(0xFF047857)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.shadowLevel2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Level Badge Circle
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CẤP',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '${userLevel.level}',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Title & XP
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userLevel.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${userLevel.currentXp} / ${userLevel.nextLevelXp} XP để lên cấp tiếp theo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Bolt Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.streakAmber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.streakAmber,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: userLevel.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: AppColors.streakAmber,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STREAK & STATS CARD
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildStreakCard(ProgressState progress, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: AppColors.shadowLevel1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.streakOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.streakOrange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chuỗi học liên tiếp: ${progress.currentStreak} ngày',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kỷ lục cao nhất: ${progress.longestStreak} ngày liên tục 🔥',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Streak Milestone Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMilestonePill(label: '3 Ngày', target: 3, current: progress.currentStreak, isDark: isDark),
              _buildMilestonePill(label: '7 Ngày', target: 7, current: progress.currentStreak, isDark: isDark),
              _buildMilestonePill(label: '14 Ngày', target: 14, current: progress.currentStreak, isDark: isDark),
              _buildMilestonePill(label: '30 Ngày', target: 30, current: progress.currentStreak, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonePill({
    required String label,
    required int target,
    required int current,
    required bool isDark,
  }) {
    final passed = current >= target;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: passed
            ? AppColors.streakOrange.withValues(alpha: 0.12)
            : (isDark ? AppColors.bgDark : AppColors.bgLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: passed
              ? AppColors.streakOrange.withValues(alpha: 0.4)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: passed
                ? AppColors.streakOrange
                : (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: passed
                  ? AppColors.streakOrange
                  : (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ACTIVITY HEATMAP & WEEKLY STATS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildActivityCard(List<DailyActivity> activities, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: AppColors.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hoạt Động 4 Tuần Gần Nhất',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                ),
              ),
              Row(
                children: [
                  _buildHeatmapLegend(0, 'Ít', isDark),
                  const SizedBox(width: 4),
                  _buildHeatmapLegend(1, '', isDark),
                  const SizedBox(width: 4),
                  _buildHeatmapLegend(2, '', isDark),
                  const SizedBox(width: 4),
                  _buildHeatmapLegend(3, 'Nhiều', isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Heatmap grid (7 rows x 4 columns)
          Center(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: activities.map((act) {
                Color cellColor;
                switch (act.intensity) {
                  case 3:
                    cellColor = AppColors.primaryEnglish;
                    break;
                  case 2:
                    cellColor = AppColors.primaryEnglish.withValues(alpha: 0.6);
                    break;
                  case 1:
                    cellColor = AppColors.primaryEnglish.withValues(alpha: 0.25);
                    break;
                  default:
                    cellColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
                }

                final dateStr = DateFormat('dd/MM').format(act.date);

                return Tooltip(
                  message: '$dateStr: ${act.cardsReviewed} thẻ SRS, ${act.speakingPracticed} bài nói (+${act.xpGained} XP)',
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapLegend(int intensity, String label, bool isDark) {
    Color color;
    switch (intensity) {
      case 3:
        color = AppColors.primaryEnglish;
        break;
      case 2:
        color = AppColors.primaryEnglish.withValues(alpha: 0.6);
        break;
      case 1:
        color = AppColors.primaryEnglish.withValues(alpha: 0.25);
        break;
      default:
        color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLightMuted)),
        ],
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MASTERY FUNNEL
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMasteryFunnelCard(VocabularyState vocabState, bool isDark) {
    final total = max(1, vocabState.notebookItems.length);
    final mastered = (total * 0.25).round();
    final reviewing = (total * 0.40).round();
    final learning = (total * 0.25).round();
    final newWords = total - mastered - reviewing - learning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: AppColors.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phân Bố Làm Chủ Từ Vựng',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Multi-segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: mastered, child: Container(color: AppColors.primaryEnglish)),
                  Expanded(flex: reviewing, child: Container(color: AppColors.accent)),
                  Expanded(flex: learning, child: Container(color: AppColors.streakAmber)),
                  Expanded(flex: max(1, newWords), child: Container(color: const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Legend labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFunnelLabel('Đã làm chủ', mastered, AppColors.primaryEnglish),
              _buildFunnelLabel('Đang ôn tập', reviewing, AppColors.accent),
              _buildFunnelLabel('Đang học', learning, AppColors.streakAmber),
              _buildFunnelLabel('Mới thêm', newWords, const Color(0xFF94A3B8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelLabel(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ACHIEVEMENTS GRID
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildAchievementsSection(List<Achievement> achievements, bool isDark) {
    final filtered = achievements.where((a) {
      if (_selectedCategory == 'unlocked') return a.isUnlocked;
      if (_selectedCategory == 'locked') return !a.isUnlocked;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Filter chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Danh Hiệu & Huy Hiệu',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
              ),
            ),
            // Filter Pills
            Row(
              children: [
                _buildFilterChip('all', 'Tất cả', isDark),
                const SizedBox(width: 4),
                _buildFilterChip('unlocked', 'Đã mở', isDark),
                const SizedBox(width: 4),
                _buildFilterChip('locked', 'Chưa', isDark),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Achievements List / Grid
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final ach = filtered[i];
            return _buildAchievementCard(ach, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedCategory == key;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryEnglish
              : (isDark ? AppColors.cardDark : AppColors.bgLight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement ach, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ach.isUnlocked
              ? ach.color.withValues(alpha: 0.35)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: ach.isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: ach.isUnlocked ? AppColors.shadowLevel1 : null,
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ach.isUnlocked
                  ? ach.color.withValues(alpha: 0.15)
                  : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
              border: Border.all(
                color: ach.isUnlocked ? ach.color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(
              ach.icon,
              color: ach.isUnlocked ? ach.color : const Color(0xFF94A3B8),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ach.title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ach.isUnlocked
                            ? (isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary)
                            : (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.streakAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${ach.rewardXp} XP',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.streakAmberDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ach.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                  ),
                ),
                const SizedBox(height: 6),

                // Progress Bar
                if (!ach.isUnlocked)
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: ach.progressFraction,
                            minHeight: 4,
                            backgroundColor:
                                isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                            color: ach.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${ach.currentProgress}/${ach.targetProgress}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textLightMuted),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Status Check / Lock
          if (ach.isUnlocked)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.successGreenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.successGreen,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}
