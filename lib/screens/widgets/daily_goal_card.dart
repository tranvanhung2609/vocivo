import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/srs_provider.dart';
import '../../providers/language_mode_provider.dart';
import '../review/srs_review_screen.dart';
import '../progress/progress_screen.dart';

class DailyGoalCard extends ConsumerWidget {
  const DailyGoalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srsState = ref.watch(srsProvider);
    final currentLang = ref.watch(languageModeProvider);
    final isZh = currentLang == 'ZH';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const dailyTarget = 10;
    final remainingDue = srsState.totalDue;
    final completedToday = (dailyTarget - remainingDue).clamp(0, dailyTarget);
    final progress = (completedToday / dailyTarget).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Streak & XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Streak badge
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProgressScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.streakOrangeLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: AppColors.streakOrange, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${srsState.streak} ngày liên tiếp',
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

              // XP Badge
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProgressScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFEFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA5F3FC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: AppColors.xpCyan, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '+${completedToday * 5} XP',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: const Color(0xFF0E7490),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Daily Progress Row
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mục tiêu học hôm nay',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remainingDue > 0
                          ? 'Còn $remainingDue thẻ cần ôn tập để duy trì chuỗi!'
                          : 'Đã hoàn thành xuất sắc mục tiêu hôm nay! 🎉',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Action button
              if (remainingDue > 0)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const SrsReviewScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ôn ngay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
