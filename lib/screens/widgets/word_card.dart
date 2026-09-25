import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';
import 'pinyin_text.dart';

class WordCard extends ConsumerWidget {
  final VocabularyItem item;
  final bool isSavedInNotebook;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  final bool isSelected;

  const WordCard({
    super.key,
    required this.item,
    this.isSavedInNotebook = true,
    this.isSelected = false,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isZh = item.languageCode.toUpperCase() == 'ZH';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? (isDark
              ? (isZh ? const Color(0xFF134E4A) : const Color(0xFF312E81))
              : (isZh ? AppColors.primaryChineseLight : AppColors.primaryEnglishLight))
          : (isDark ? AppColors.cardDark : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected
              ? (isZh ? AppColors.primaryChinese : AppColors.primaryEnglish)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isSelected ? 2.2 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Word, Level badge, TTS button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // Word / Hanzi
                        Text(
                          item.word,
                          style: GoogleFonts.outfit(
                            fontSize: isZh ? 26 : 22,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Level tag (HSK or CEFR)
                        if (item.level != null && item.level!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isZh
                                  ? AppColors.primaryChineseLight
                                  : AppColors.primaryEnglishLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isZh
                                    ? AppColors.primaryChinese.withValues(alpha: 0.3)
                                    : AppColors.primaryEnglish.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              item.level!,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Word type tag (EN)
                        if (!isZh && item.wordType != null && item.wordType!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.wordType!,
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // TTS speaker button
                  IconButton(
                    icon: Icon(
                      Icons.volume_up_rounded,
                      color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                      size: 24,
                    ),
                    tooltip: 'Phát âm',
                    onPressed: () {
                      TtsService.instance.speak(
                        text: item.word,
                        languageCode: item.languageCode,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Pronunciation row: Pinyin or IPA
              if (isZh && item.phonetic != null && item.phonetic!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PinyinText(
                    pinyin: item.phonetic!,
                    fontSize: 16,
                  ),
                )
              else if (!isZh && item.phonetic != null && item.phonetic!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    item.phonetic!,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Courier',
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),

              // Hán-Việt Badge (Chinese only) - PROMINENT AS REQUESTED
              if (isZh && item.hanViet != null && item.hanViet!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_stories_rounded, size: 14, color: AppColors.crimsonAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Hán-Việt: ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.crimsonAccent,
                        ),
                      ),
                      Text(
                        item.hanViet!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),

              // Meaning (VI)
              Text(
                item.meaningVi,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                ),
              ),

              // Breakdown (Chinese) or Collocations (English)
              if (isZh && item.breakdown != null && item.breakdown!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_customize_outlined, size: 16, color: AppColors.primaryChinese),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.breakdown!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!isZh && item.collocations.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.collocations.map((col) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Text(
                        col,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Examples Section
              if (item.examples.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                ...item.examples.take(2).map((ex) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                ex.text,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isZh && ex.pinyin != null && ex.pinyin!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 2),
                            child: Text(
                              ex.pinyin!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                              ),
                            ),
                          ),
                        if (ex.vi.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 2),
                            child: Text(
                              ex.vi,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],

              // Footer actions (Save to notebook or Delete)
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isSavedInNotebook)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ref.read(vocabularyProvider.notifier).saveWord(item);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Đã lưu "${item.word}" vào Sổ từ vựng!'
                                    : 'Từ "${item.word}" đã có trong sổ từ vựng.',
                              ),
                              backgroundColor: success ? AppColors.successGreen : AppColors.warningYellow,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                      label: const Text('Lưu vào Sổ từ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    )
                  else if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed, size: 20),
                      tooltip: 'Xóa khỏi sổ',
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
