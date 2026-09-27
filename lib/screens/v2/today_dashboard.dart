import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/learning_v2.dart';
import '../../providers/daily_learning_provider.dart';
import '../../providers/language_mode_provider.dart';
import '../../providers/progress_provider.dart';

class TodayDashboard extends ConsumerWidget {
  const TodayDashboard({
    required this.onStartSession,
    required this.onOpenPath,
    required this.onOpenPractice,
    super.key,
  });

  final Future<void> Function() onStartSession;
  final VoidCallback onOpenPath;
  final VoidCallback onOpenPractice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(dailyLearningProvider);
    final progress = ref.watch(progressProvider);
    final language = ref.watch(languageModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => ref.read(dailyLearningProvider.notifier).refresh(),
      child: CustomScrollView(
        key: const PageStorageKey('today-dashboard'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
            sliver: SliverList.list(
              children: [
                _DashboardHeader(
                  language: language,
                  streak: progress.currentStreak,
                ),
                const SizedBox(height: 24),
                if (learning.isLoading)
                  const _DashboardSkeleton()
                else if (learning.errorMessage != null)
                  _ErrorState(
                    message: learning.errorMessage!,
                    onRetry: () =>
                        ref.read(dailyLearningProvider.notifier).refresh(),
                  )
                else ...[
                  _FocusHero(
                    learning: learning,
                    onStart: onStartSession,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: 'Kế hoạch hôm nay',
                    actionLabel: 'Tùy chỉnh',
                    onAction: () =>
                        _showPlanSettings(context, ref, learning.profile),
                  ),
                  const SizedBox(height: 12),
                  _DailyPlanList(plan: learning.plan),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontal = constraints.maxWidth >= 760;
                      final cards = [
                        _QuickCard(
                          icon: Icons.alt_route_rounded,
                          color: AppColors.accent,
                          title: 'Tiếp tục lộ trình',
                          subtitle:
                              learning.nextUnit?.title ??
                              'Khám phá khóa học của bạn',
                          onTap: onOpenPath,
                        ),
                        _QuickCard(
                          icon: Icons.fitness_center_rounded,
                          color: AppColors.primaryEnglish,
                          title: 'Luyện kỹ năng',
                          subtitle: learning.dueCount > 0
                              ? '${learning.dueCount} từ đang đến hạn'
                              : 'Nghe, nói và sửa lỗi theo nhu cầu',
                          onTap: onOpenPractice,
                        ),
                      ];
                      if (horizontal) {
                        return Row(
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 16),
                            Expanded(child: cards[1]),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 12),
                          cards[1],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlanSettings(
    BuildContext context,
    WidgetRef ref,
    LearningProfile? profile,
  ) {
    if (profile == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thời lượng học mỗi ngày'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vocivo sẽ tự cân đối ôn tập, bài mới và luyện nói trong thời gian bạn chọn.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [5, 10, 15, 25]
                  .map(
                    (minutes) => ChoiceChip(
                      label: Text('$minutes phút'),
                      selected: profile.dailyMinutes == minutes,
                      onSelected: (_) async {
                        Navigator.pop(dialogContext);
                        await ref
                            .read(dailyLearningProvider.notifier)
                            .setDailyMinutes(minutes);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.language, required this.streak});
  final String language;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Chào buổi sáng'
        : hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, sẵn sàng tiến thêm một bước?',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                language == 'ZH'
                    ? 'Khóa Tiếng Trung • Học ít nhưng dùng được ngay.'
                    : 'Khóa Tiếng Anh • Học ít nhưng dùng được ngay.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (streak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.streakOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.streakOrange,
                  size: 21,
                ),
                const SizedBox(width: 6),
                Text(
                  '$streak ngày',
                  style: const TextStyle(
                    color: AppColors.streakOrangeDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FocusHero extends StatelessWidget {
  const _FocusHero({
    required this.learning,
    required this.onStart,
    required this.isDark,
  });
  final DailyLearningState learning;
  final Future<void> Function() onStart;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasActive = learning.activeSession != null;
    final plan = learning.plan;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF102A32)]
              : [const Color(0xFFE8FFF5), const Color(0xFFF0F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F6C58) : const Color(0xFFB7E9D5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryEnglish.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  hasActive ? 'PHIÊN HỌC ĐANG DỞ' : 'TRỌNG TÂM HÔM NAY',
                  style: const TextStyle(
                    color: AppColors.primaryEnglishDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hasActive ? 'Tiếp tục nơi bạn đã dừng' : 'Nhớ từ để nói được',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasActive
                    ? learning.activeLesson?.title ?? 'Phiên học cá nhân'
                    : '${plan?.estimatedMinutes ?? 15} phút • ${plan?.tasks.length ?? 0} hoạt động cân bằng',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onStart,
                icon: Icon(
                  hasActive ? Icons.play_arrow_rounded : Icons.bolt_rounded,
                ),
                label: Text(
                  hasActive
                      ? 'Tiếp tục phiên học'
                      : 'Bắt đầu phiên học hôm nay',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(240, 54),
                  backgroundColor: AppColors.primaryEnglishDeep,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
          final visual = SizedBox(
            width: 190,
            height: 160,
            child: CustomPaint(painter: _SpeechPulsePainter(isDark: isDark)),
          );
          if (compact) return content;
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 24),
              visual,
            ],
          );
        },
      ),
    );
  }
}

class _DailyPlanList extends StatelessWidget {
  const _DailyPlanList({required this.plan});
  final DailyPlan? plan;

  @override
  Widget build(BuildContext context) {
    final tasks = plan?.tasks ?? const <DailyPlanTask>[];
    if (tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Kế hoạch sẽ xuất hiện khi khóa học có nội dung.'),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var index = 0; index < tasks.length; index++) ...[
              _PlanTaskTile(index: index, task: tasks[index]),
              if (index < tasks.length - 1)
                const Divider(indent: 72, endIndent: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanTaskTile extends StatelessWidget {
  const _PlanTaskTile({required this.index, required this.task});
  final int index;
  final DailyPlanTask task;

  @override
  Widget build(BuildContext context) {
    final icon = switch (task.type) {
      DailyTaskType.review => Icons.refresh_rounded,
      DailyTaskType.lesson => Icons.menu_book_rounded,
      DailyTaskType.listening => Icons.headphones_rounded,
      DailyTaskType.speaking => Icons.mic_rounded,
      DailyTaskType.mistakes => Icons.build_circle_outlined,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryEnglish.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primaryEnglishDeep, size: 21),
      ),
      title: Text(
        task.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        task.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${task.estimatedMinutes} phút',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      TextButton(onPressed: onAction, child: Text(actionLabel)),
    ],
  );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      const SizedBox(height: 28),
      for (var i = 0; i < 3; i++)
        Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tải lại'),
          ),
        ],
      ),
    ),
  );
}

class _SpeechPulsePainter extends CustomPainter {
  const _SpeechPulsePainter({required this.isDark});
  final bool isDark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF6FFBBE) : AppColors.primaryEnglish
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    const heights = [34.0, 68.0, 104.0, 76.0, 46.0, 88.0, 58.0];
    final gap = size.width / (heights.length + 1);
    for (var i = 0; i < heights.length; i++) {
      final x = gap * (i + 1);
      canvas.drawLine(
        Offset(x, centerY - heights[i] / 2),
        Offset(x, centerY + heights[i] / 2),
        paint,
      );
    }
    final glow = Paint()
      ..color = paint.color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, centerY), 78, glow);
  }

  @override
  bool shouldRepaint(covariant _SpeechPulsePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
