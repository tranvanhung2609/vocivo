import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/curriculum_model.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/curriculum_provider.dart';
import '../review/srs_review_screen.dart';
import '../speaking/speaking_screen.dart';
import '../widgets/pinyin_text.dart';
import 'widgets/quick_quiz_dialog.dart';

class UnitDetailScreen extends ConsumerStatefulWidget {
  final String unitId;

  const UnitDetailScreen({super.key, required this.unitId});

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  final TtsService _ttsService = TtsService.instance;
  String? _playingWord;

  Future<void> _playTts(VocabularyItem item) async {
    setState(() => _playingWord = item.word);
    await _ttsService.speak(
      text: item.word,
      languageCode: item.languageCode,
    );
    if (mounted) setState(() => _playingWord = null);
  }

  CurriculumUnit? _findUnit(CurriculumState state) {
    for (final s in state.stages) {
      for (final u in s.units) {
        if (u.id == widget.unitId) return u;
      }
    }
    for (final u in state.aiUnits) {
      if (u.id == widget.unitId) return u;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final curriculumState = ref.watch(curriculumProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unit = _findUnit(curriculumState);

    if (unit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết bài học')),
        body: const Center(child: Text('Không tìm thấy bài học này')),
      );
    }

    final isZh = unit.languageCode == 'ZH';
    final accentColor = isZh ? const Color(0xFFEF4444) : AppColors.primaryEnglish;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : const Color(0xFF0F172A), size: 19),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          unit.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (unit.isAiGenerated)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              tooltip: 'Xóa bộ thẻ này',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: const Text('Bạn có chắc muốn xóa bộ thẻ này không?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  final navigator = Navigator.of(context);
                  await ref.read(curriculumProvider.notifier).deleteAiUnit(unit.id);
                  if (context.mounted) navigator.pop();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Banner Card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          accentColor.withValues(alpha: 0.2),
                          const Color(0xFF1E293B),
                        ]
                      : [
                          accentColor.withValues(alpha: 0.12),
                          Colors.white,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          unit.level,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (unit.isAiGenerated)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.amber, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'AI Tạo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.amberAccent : Colors.orange[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (unit.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF10B981), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Đã hoàn thành',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    unit.title,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    unit.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.style_outlined,
                          size: 16,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '${unit.words.length} từ vựng then chốt',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      if (unit.lastScore != null) ...[
                        const SizedBox(width: 14),
                        Icon(Icons.stars_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'Điểm: ${unit.lastScore}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 3 Action Buttons ─────────────────────────────────────────
            Row(
              children: [
                // Button 1: Flashcard SRS
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SrsReviewScreen(
                            customItems: unit.words,
                            title: unit.title,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.style, color: Colors.white, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            'Flashcard SRS',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Button 2: Shadowing
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SpeakingScreen(
                            initialItems: unit.words,
                            title: unit.title,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic, color: accentColor, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            'Luyện Nói',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Button 3: Quick Quiz
                Expanded(
                  child: InkWell(
                    onTap: () {
                      QuickQuizDialog.show(
                        context,
                        unitId: unit.id,
                        unitTitle: unit.title,
                        words: unit.words,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.quiz, color: Color(0xFFF59E0B), size: 24),
                          const SizedBox(height: 6),
                          Text(
                            'Vượt Ải (Quiz)',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Word List Title ──────────────────────────────────────────
            Text(
              'Danh sách từ vựng bài học',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // ── Word Cards ───────────────────────────────────────────────
            ...unit.words.map((item) {
              final isPlaying = _playingWord == item.word;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.word,
                                    style: GoogleFonts.outfit(
                                      fontSize: isZh ? 24 : 19,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (item.hanViet != null && item.hanViet!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.hanViet!,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (item.phonetic != null)
                                isZh
                                    ? PinyinText(
                                        pinyin: item.phonetic!,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                      )
                                    : Text(
                                        item.phonetic!,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                            ],
                          ),
                        ),
                        // Audio speaker button
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
                            color: isPlaying ? accentColor : const Color(0xFF64748B),
                            size: 22,
                          ),
                          onPressed: () => _playTts(item),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.meaningVi,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '💡 ${item.notes!}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (item.examples.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.examples.first.text,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                            if (item.examples.first.pinyin != null)
                              Text(
                                item.examples.first.pinyin!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              item.examples.first.vi,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
