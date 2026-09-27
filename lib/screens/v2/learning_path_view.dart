import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/curriculum_model.dart';
import '../../providers/curriculum_provider.dart';

class LearningPathView extends ConsumerWidget {
  const LearningPathView({required this.onStartUnit, super.key});
  final Future<void> Function(CurriculumUnit unit) onStartUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(curriculumProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = state.languageCode == 'ZH'
        ? const Color(0xFFDC5A5A)
        : AppColors.primaryEnglish;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.stages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 56),
            const SizedBox(height: 14),
            const Text('Chưa có lộ trình cho khóa học này.'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(curriculumProvider.notifier)
                  .loadCurriculum(state.languageCode),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    final allUnits = state.stages.expand((stage) => stage.units).toList();
    final firstIncomplete = allUnits.indexWhere((unit) => !unit.isCompleted);

    return RefreshIndicator(
      onRefresh: () => ref
          .read(curriculumProvider.notifier)
          .loadCurriculum(state.languageCode),
      child: CustomScrollView(
        key: PageStorageKey('learning-path-${state.languageCode}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lộ trình ${state.languageCode == 'ZH' ? 'Tiếng Trung' : 'Tiếng Anh'}',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.languageCode == 'ZH'
                                ? 'Từ Pinyin và HSK đến giao tiếp trong tình huống thực tế.'
                                : 'Từ nền tảng CEFR đến giao tiếp tự tin trong công việc và đời sống.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    _ProgressRing(
                      value: state.overallProgress,
                      label: '${state.totalCompletedUnits}/${state.totalUnits}',
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                for (final stage in state.stages) ...[
                  _StageHeader(stage: stage, accent: accent),
                  const SizedBox(height: 12),
                  for (final unit in stage.units)
                    _TimelineUnit(
                      unit: unit,
                      status: _statusFor(unit, allUnits, firstIncomplete),
                      accent: accent,
                      isDark: isDark,
                      onTap: () => onStartUnit(unit),
                    ),
                  const SizedBox(height: 24),
                ],
                if (state.aiUnits.isNotEmpty) ...[
                  _StageHeader(
                    stage: LearningStage(
                      id: 'ai',
                      languageCode: state.languageCode,
                      title: 'Bộ học cá nhân',
                      subtitle: 'Nội dung do bạn tạo bằng AI',
                      level: 'Cá nhân hóa',
                      units: state.aiUnits,
                    ),
                    accent: accent,
                  ),
                  const SizedBox(height: 12),
                  for (final unit in state.aiUnits)
                    _TimelineUnit(
                      unit: unit,
                      status: unit.isCompleted
                          ? _UnitStatus.completed
                          : _UnitStatus.current,
                      accent: accent,
                      isDark: isDark,
                      onTap: () => onStartUnit(unit),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _UnitStatus _statusFor(
    CurriculumUnit unit,
    List<CurriculumUnit> allUnits,
    int firstIncomplete,
  ) {
    if (unit.isCompleted) return _UnitStatus.completed;
    final index = allUnits.indexWhere((candidate) => candidate.id == unit.id);
    if (firstIncomplete < 0 || index == firstIncomplete) {
      return _UnitStatus.current;
    }
    return _UnitStatus.locked;
  }
}

enum _UnitStatus { completed, current, locked }

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage, required this.accent});
  final LearningStage stage;
  final Color accent;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          stage.level,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stage.title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              stage.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class _TimelineUnit extends StatelessWidget {
  const _TimelineUnit({
    required this.unit,
    required this.status,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });
  final CurriculumUnit unit;
  final _UnitStatus status;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = status != _UnitStatus.locked;
    final statusText = switch (status) {
      _UnitStatus.completed =>
        unit.lastScore == null
            ? 'Đã hoàn thành'
            : 'Đã hoàn thành • ${unit.lastScore}%',
      _UnitStatus.current => 'Bài tiếp theo',
      _UnitStatus.locked => 'Hoàn thành bài trước để mở khóa',
    };
    final icon = switch (status) {
      _UnitStatus.completed => Icons.check_rounded,
      _UnitStatus.current => Icons.play_arrow_rounded,
      _UnitStatus.locked => Icons.lock_outline_rounded,
    };
    final nodeColor = status == _UnitStatus.locked
        ? (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted)
        : accent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: nodeColor.withValues(alpha: 0.22),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: status == _UnitStatus.current
                        ? nodeColor
                        : nodeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 2),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: status == _UnitStatus.current
                        ? Colors.white
                        : nodeColor,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: nodeColor.withValues(alpha: 0.22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 7),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: nodeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(_iconFor(unit.iconName), color: nodeColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: enabled
                                    ? null
                                    : Theme.of(context).disabledColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$statusText • ${unit.words.length} từ',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (enabled)
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) => switch (name) {
    'restaurant' => Icons.restaurant_rounded,
    'flight_takeoff' => Icons.flight_takeoff_rounded,
    'work' => Icons.work_outline_rounded,
    'shopping_bag' => Icons.shopping_bag_outlined,
    'family_restroom' => Icons.family_restroom_rounded,
    'handshake' => Icons.handshake_outlined,
    'waving_hand' => Icons.waving_hand_outlined,
    _ => Icons.chat_bubble_outline_rounded,
  };
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.label,
    required this.color,
  });
  final double value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 66,
    height: 66,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    ),
  );
}
