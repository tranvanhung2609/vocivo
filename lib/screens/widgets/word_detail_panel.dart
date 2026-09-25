import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';
import 'pinyin_text.dart';
import 'hanzi_canvas_dialog.dart';

class WordDetailPanel extends ConsumerStatefulWidget {
  final VocabularyItem item;
  final VoidCallback? onClose;
  /// Optional scroll controller — pass the one from DraggableScrollableSheet
  /// so the sheet and the inner scroll view are properly linked.
  final ScrollController? scrollController;

  const WordDetailPanel({
    super.key,
    required this.item,
    this.onClose,
    this.scrollController,
  });

  @override
  ConsumerState<WordDetailPanel> createState() => _WordDetailPanelState();
}

class _WordDetailPanelState extends ConsumerState<WordDetailPanel> {
  late TextEditingController _notesCtrl;
  bool _isEditingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant WordDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _notesCtrl.text = widget.item.notes ?? '';
      _isEditingNotes = false;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isZh = item.languageCode.toUpperCase() == 'ZH';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isZh ? AppColors.primaryChineseLight : AppColors.primaryEnglishLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isZh ? 'Tiếng Trung (HSK)' : 'Tiếng Anh (Oxford)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main word / Hanzi row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.word,
                          style: GoogleFonts.outfit(
                            fontSize: isZh ? 44 : 32,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                          ),
                        ),
                      ),

                      // TTS audio button
                      IconButton.filledTonal(
                        icon: const Icon(Icons.volume_up_rounded, size: 26),
                        tooltip: 'Phát âm bản địa',
                        onPressed: () {
                          TtsService.instance.speak(text: item.word, languageCode: item.languageCode);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Pronunciation: Pinyin with tone styling or IPA
                  if (isZh && item.phonetic != null)
                    PinyinText(pinyin: item.phonetic!, fontSize: 20)
                  else if (!isZh && item.phonetic != null)
                    Text(
                      item.phonetic!,
                      style: const TextStyle(fontSize: 16, fontFamily: 'Courier', color: Color(0xFF64748B)),
                    ),

                  const SizedBox(height: 12),

                  // Action Buttons row: Hanzi Practice Canvas (Chinese only)
                  if (isZh) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        HanziCanvasDialog.show(
                          context,
                          hanzi: item.word,
                          pinyin: item.phonetic,
                          hanViet: item.hanViet,
                          meaningVi: item.meaningVi,
                        );
                      },
                      icon: const Icon(Icons.draw_rounded, size: 18),
                      label: const Text('Luyện viết chữ Hán (田字格)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryChinese,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Sino-Vietnamese Han-Viet Badge
                  if (isZh && item.hanViet != null && item.hanViet!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_stories_rounded, size: 18, color: AppColors.crimsonAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Âm Hán-Việt: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.crimsonAccent,
                            ),
                          ),
                          Text(
                            item.hanViet!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tags & Levels
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.level != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isZh ? AppColors.primaryChineseLight : AppColors.primaryEnglishLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isZh
                                  ? AppColors.primaryChinese.withValues(alpha: 0.3)
                                  : AppColors.primaryEnglish.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            item.level!,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                            ),
                          ),
                        ),
                      if (item.wordType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.wordType!,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Vietnamese Meaning
                  Text(
                    'Định nghĩa tiếng Việt:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.meaningVi,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                    ),
                  ),

                  // Component Breakdown or Collocations
                  if (isZh && item.breakdown != null && item.breakdown!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.dashboard_customize_outlined, size: 16, color: AppColors.primaryChinese),
                              const SizedBox(width: 6),
                              Text(
                                'Cấu tạo chữ & Từ nguyên:',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.breakdown!,
                            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!isZh && item.collocations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Cụm từ thường gặp (Collocations):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.collocations.map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      )).toList(),
                    ),
                  ],

                  // Examples
                  if (item.examples.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Câu ví dụ ngữ cảnh:',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...item.examples.map((ex) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ex.text,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                                    tooltip: 'Nghe ví dụ',
                                    onPressed: () {
                                      TtsService.instance.speak(text: ex.text, languageCode: item.languageCode);
                                    },
                                  ),
                                ],
                              ),
                              if (isZh && ex.pinyin != null)
                                Text(ex.pinyin!, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 4),
                              Text(ex.vi, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : const Color(0xFF475569))),
                            ],
                          ),
                        )),
                  ],

                  // Notes & Personal Mnemonics Editor
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: AppColors.streakOrange, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Ghi chú cá nhân (Mẹo nhớ):',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _isEditingNotes = !_isEditingNotes);
                        },
                        child: Text(_isEditingNotes ? 'Xong' : 'Chỉnh sửa'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_isEditingNotes) ...[
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Nhập mẹo liên tưởng cá nhân của bạn...',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (item.id != null) {
                            await ref.read(vocabularyProvider.notifier).updateNotes(item.id!, _notesCtrl.text.trim());
                            setState(() => _isEditingNotes = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã cập nhật ghi chú cá nhân!')),
                              );
                            }
                          }
                        },
                        child: const Text('Lưu ghi chú'),
                      ),
                    ),
                  ] else ...[
                    Text(
                      _notesCtrl.text.isNotEmpty ? _notesCtrl.text : 'Chưa có mẹo nhớ cá nhân. Bấm "Chỉnh sửa" để thêm.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: _notesCtrl.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                        color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
