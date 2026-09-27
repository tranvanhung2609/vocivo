import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/learning_v2.dart';
import '../../providers/daily_learning_provider.dart';

class PracticeHub extends ConsumerWidget {
  const PracticeHub({
    required this.onOpenReview,
    required this.onOpenSpeaking,
    required this.onStartQuickSession,
    super.key,
  });

  final VoidCallback onOpenReview;
  final VoidCallback onOpenSpeaking;
  final Future<void> Function() onStartQuickSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(dailyLearningProvider);
    final mastery = _averages(learning.mastery);

    return RefreshIndicator(
      onRefresh: () => ref.read(dailyLearningProvider.notifier).refresh(),
      child: CustomScrollView(
        key: const PageStorageKey('practice-hub'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
            sliver: SliverList.list(
              children: [
                Text(
                  'Luyện tập',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chọn đúng kỹ năng bạn muốn củng cố hôm nay.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 26),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 820
                        ? 3
                        : constraints.maxWidth >= 520
                        ? 2
                        : 1;
                    const gap = 14.0;
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    final cards = [
                      _PracticeCard(
                        icon: Icons.event_available_rounded,
                        color: AppColors.primaryEnglish,
                        title: 'Đến hạn hôm nay',
                        subtitle: learning.dueCount > 0
                            ? '${learning.dueCount} từ cần được nhắc lại'
                            : 'Bạn đã hoàn thành phần ôn tập',
                        badge: '${learning.dueCount}',
                        onTap: onOpenReview,
                      ),
                      _PracticeCard(
                        icon: Icons.build_circle_outlined,
                        color: AppColors.streakOrange,
                        title: 'Lỗi của tôi',
                        subtitle: learning.mistakeCount > 0
                            ? 'Luyện lại ${learning.mistakeCount} lỗi gần đây'
                            : 'Lỗi sai sẽ được lưu tự động',
                        badge: '${learning.mistakeCount}',
                        onTap: onOpenReview,
                      ),
                      _PracticeCard(
                        icon: Icons.trending_up_rounded,
                        color: AppColors.accent,
                        title: 'Từ yếu',
                        subtitle: 'Ưu tiên các từ có mức ghi nhớ thấp',
                        onTap: onOpenReview,
                      ),
                      _PracticeCard(
                        icon: Icons.headphones_rounded,
                        color: const Color(0xFF7C3AED),
                        title: 'Nghe',
                        subtitle: 'Nhận diện từ và cụm từ ở tốc độ thật',
                        onTap: onStartQuickSession,
                      ),
                      _PracticeCard(
                        icon: Icons.mic_rounded,
                        color: const Color(0xFFDB2777),
                        title: 'Phát âm',
                        subtitle: 'Shadowing và nhận phản hồi tức thì',
                        onTap: onOpenSpeaking,
                      ),
                      _PracticeCard(
                        icon: Icons.timer_outlined,
                        color: const Color(0xFF0891B2),
                        title: 'Phiên 5 phút',
                        subtitle: 'Một vòng học nhanh khi bạn bận rộn',
                        onTap: onStartQuickSession,
                      ),
                    ];
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: cards
                          .map((card) => SizedBox(width: width, child: card))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 30),
                Text(
                  'Sức mạnh kỹ năng',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        for (final skill in LearningSkill.values)
                          _SkillProgress(
                            skill: skill,
                            value: mastery[skill] ?? 0,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<LearningSkill, double> _averages(List<SkillMastery> items) {
    final values = <LearningSkill, List<double>>{};
    for (final item in items) {
      values.putIfAbsent(item.skill, () => []).add(item.mastery);
    }
    return {
      for (final entry in values.entries)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
    };
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color),
                ),
                const Spacer(),
                if (badge != null && badge != '0')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Bắt đầu',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward_rounded, size: 17, color: color),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SkillProgress extends StatelessWidget {
  const _SkillProgress({required this.skill, required this.value});
  final LearningSkill skill;
  final double value;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (skill) {
      LearningSkill.vocabulary => ('Từ vựng', Icons.menu_book_rounded),
      LearningSkill.listening => ('Nghe', Icons.headphones_rounded),
      LearningSkill.recall => ('Ghi nhớ', Icons.psychology_rounded),
      LearningSkill.speaking => ('Nói', Icons.mic_rounded),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryEnglish),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.primaryEnglish.withValues(
                  alpha: 0.1,
                ),
                color: AppColors.primaryEnglish,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 38,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
