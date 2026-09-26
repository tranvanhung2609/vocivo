import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/curriculum_model.dart';
import '../../providers/curriculum_provider.dart';
import '../../providers/srs_provider.dart';
import '../widgets/ai_lookup_dialog.dart';
import '../review/srs_review_screen.dart';
import '../speaking/speaking_screen.dart';
import '../notebook/notebook_screen.dart';
import 'unit_detail_screen.dart';
import 'widgets/ai_generate_deck_dialog.dart';

class RoadmapView extends ConsumerWidget {
  const RoadmapView({super.key});

  IconData _getIconForName(String iconName) {
    switch (iconName) {
      case 'waving_hand':
        return Icons.waving_hand;
      case 'handshake':
        return Icons.handshake;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'flight_takeoff':
        return Icons.flight_takeoff;
      case 'hotel':
        return Icons.hotel;
      case 'work':
        return Icons.work;
      case 'badge':
        return Icons.badge;
      case 'psychology':
        return Icons.psychology;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'translate':
        return Icons.translate;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'payments':
        return Icons.payments;
      case 'explore':
        return Icons.explore;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.school;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(curriculumProvider);
    final srsState = ref.watch(srsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh = state.languageCode == 'ZH';
    final accentColor = isZh ? const Color(0xFFEF4444) : AppColors.primaryEnglish;

    return RefreshIndicator(
      color: accentColor,
      onRefresh: () async {
        await ref.read(curriculumProvider.notifier).loadCurriculum(state.languageCode);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Language Toggle (EN / ZH) ─────────────────────────
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildLangTab(
                      context: context,
                      ref: ref,
                      label: '🇬🇧 Lộ Trình Tiếng Anh',
                      isSelected: !isZh,
                      targetLang: 'EN',
                      isDark: isDark,
                      activeColor: AppColors.primaryEnglish,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildLangTab(
                      context: context,
                      ref: ref,
                      label: '🇨🇳 Lộ Trình Tiếng Trung',
                      isSelected: isZh,
                      targetLang: 'ZH',
                      isDark: isDark,
                      activeColor: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Progress & Motivation Hero Card ───────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          accentColor.withValues(alpha: 0.25),
                          const Color(0xFF1E293B),
                        ]
                      : [
                          accentColor.withOpacity(0.12),
                          Colors.white,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.streakOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: AppColors.streakOrange, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'Chuỗi ${srsState.streak} ngày',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.streakOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${state.totalCompletedUnits}/${state.totalUnits} Bài học',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isZh ? 'Lộ Trình Tiếng Trung HSK' : 'Lộ Trình Tiếng Anh Toàn Diện',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isZh
                        ? 'Học từng chặng: Bính âm ➔ HSK 1 ➔ HSK 2 ➔ HSK 3 thực chiến'
                        : 'Lộ trình chuẩn CEFR: A1 Khởi động ➔ A2 Giao tiếp ➔ B1 Công sở',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Overall progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: state.overallProgress,
                      minHeight: 8,
                      backgroundColor:
                          isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Button "AI Tạo Bộ Thẻ Mới"
                  ElevatedButton(
                    onPressed: () {
                      AiGenerateDeckDialog.show(
                        context,
                        languageCode: state.languageCode,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'AI Tạo Bộ Thẻ Theo Chủ Đề Mới',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 3. Quick Utility Row ─────────────────────────────────
            Row(
              children: [
                _buildQuickAction(
                  context: context,
                  icon: Icons.repeat,
                  label: 'Ôn tập SRS',
                  badge: srsState.totalDue > 0 ? '${srsState.totalDue}' : null,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SrsReviewScreen()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  context: context,
                  icon: Icons.mic_rounded,
                  label: 'Luyện nói',
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SpeakingScreen()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  context: context,
                  icon: Icons.menu_book_rounded,
                  label: 'Sổ từ vựng',
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotebookScreen()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  context: context,
                  icon: Icons.search_rounded,
                  label: 'Tra từ AI',
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  onTap: () {
                    AiLookupDialog.show(
                      context,
                      query: '',
                      languageCode: state.languageCode,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 4. Custom AI Generated Decks Section ─────────────────
            if (state.aiUnits.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Bộ Thẻ AI Của Bạn',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      AiGenerateDeckDialog.show(
                        context,
                        languageCode: state.languageCode,
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm chủ đề'),
                    style: TextButton.styleFrom(
                      foregroundColor: accentColor,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...state.aiUnits.map((unit) => _buildUnitCard(context, unit, isDark, accentColor)),
              const SizedBox(height: 20),
            ],

            // ── 5. Standard Roadmap Stages & Units ────────────────────
            Text(
              'Lộ Trình Bài Học Theo Chặng',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...state.stages.map((stage) {
                return _buildStageSection(context, stage, isDark, accentColor);
              }),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildLangTab({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required bool isSelected,
    required String targetLang,
    required bool isDark,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(curriculumProvider.notifier).switchLanguage(targetLang);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? badge,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageSection(
    BuildContext context,
    LearningStage stage,
    bool isDark,
    Color accentColor,
  ) {
    final stageColor = Color(stage.badgeColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stage Header Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: stageColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIconForName(stage.iconName), color: stageColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: stageColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stage.level,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: stageColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${stage.completedUnitsCount}/${stage.totalUnitsCount} bài',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stage.title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        stage.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Unit items in this Stage
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: stage.units.map((unit) {
                return _buildUnitCard(context, unit, isDark, accentColor);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard(
    BuildContext context,
    CurriculumUnit unit,
    bool isDark,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UnitDetailScreen(unitId: unit.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: unit.isCompleted
                    ? const Color(0xFF10B981).withOpacity(0.5)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                // Unit icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: unit.isCompleted
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    unit.isCompleted
                        ? Icons.check
                        : _getIconForName(unit.iconName),
                    color: unit.isCompleted ? const Color(0xFF10B981) : accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              unit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (unit.isAiGenerated) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'AI',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        unit.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${unit.words.length} từ vựng',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                          if (unit.lastScore != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${unit.lastScore}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
