import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';

class AddWordDialog extends ConsumerStatefulWidget {
  final String initialLanguage;

  const AddWordDialog({super.key, required this.initialLanguage});

  static Future<void> show(BuildContext context, {required String initialLanguage}) {
    return showDialog(
      context: context,
      builder: (ctx) => AddWordDialog(initialLanguage: initialLanguage),
    );
  }

  @override
  ConsumerState<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends ConsumerState<AddWordDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _languageCode;
  final _wordCtrl = TextEditingController();
  final _phoneticCtrl = TextEditingController();
  final _hanVietCtrl = TextEditingController();
  final _meaningCtrl = TextEditingController();
  final _wordTypeCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _exampleTextCtrl = TextEditingController();
  final _exampleViCtrl = TextEditingController();
  int? _selectedTagId;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.initialLanguage;
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    _phoneticCtrl.dispose();
    _hanVietCtrl.dispose();
    _meaningCtrl.dispose();
    _wordTypeCtrl.dispose();
    _levelCtrl.dispose();
    _notesCtrl.dispose();
    _exampleTextCtrl.dispose();
    _exampleViCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabState = ref.watch(vocabularyProvider);
    final isZh = _languageCode == 'ZH';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isZh ? AppColors.primaryChineseLight : AppColors.primaryEnglishLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.note_add_rounded,
                      color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thêm từ mới vào sổ cá nhân',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Language selector chips
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('🇨🇳 Tiếng Trung'),
                    selected: isZh,
                    onSelected: (val) {
                      if (val) setState(() => _languageCode = 'ZH');
                    },
                    selectedColor: AppColors.primaryChineseLight,
                    labelStyle: TextStyle(
                      color: isZh ? AppColors.primaryChinese : null,
                      fontWeight: isZh ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('🇬🇧 Tiếng Anh'),
                    selected: !isZh,
                    onSelected: (val) {
                      if (val) setState(() => _languageCode = 'EN');
                    },
                    selectedColor: AppColors.primaryEnglishLight,
                    labelStyle: TextStyle(
                      color: !isZh ? AppColors.primaryEnglish : null,
                      fontWeight: !isZh ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Scrollable input fields
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Word input
                      TextFormField(
                        controller: _wordCtrl,
                        decoration: InputDecoration(
                          labelText: isZh ? 'Chữ Hán *' : 'Từ vựng tiếng Anh *',
                          hintText: isZh ? 'VD: 坚持' : 'VD: persistent',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập từ' : null,
                      ),
                      const SizedBox(height: 12),

                      // Phonetic / Pinyin
                      TextFormField(
                        controller: _phoneticCtrl,
                        decoration: InputDecoration(
                          labelText: isZh ? 'Pinyin (phiên âm)' : 'Phiên âm IPA',
                          hintText: isZh ? 'VD: jiānchí' : 'VD: /pəˈsɪs.tənt/',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Han-Viet (only for Chinese)
                      if (isZh) ...[
                        TextFormField(
                          controller: _hanVietCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Âm Hán-Việt (rất quan trọng)',
                            hintText: 'VD: Kiên trì',
                            prefixIcon: Icon(Icons.translate_rounded, color: AppColors.crimsonAccent),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Meaning VI
                      TextFormField(
                        controller: _meaningCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nghĩa tiếng Việt *',
                          hintText: 'VD: Kiên trì, không từ bỏ',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập nghĩa tiếng Việt' : null,
                      ),
                      const SizedBox(height: 12),

                      // Word type & Level in one row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _wordTypeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Từ loại',
                                hintText: 'verb, noun, adj...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _levelCtrl,
                              decoration: InputDecoration(
                                labelText: isZh ? 'Cấp độ HSK' : 'Cấp độ CEFR',
                                hintText: isZh ? 'HSK 1-6' : 'A1 - C2',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Notes / Breakdown
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: InputDecoration(
                          labelText: isZh ? 'Mẹo nhớ / Cấu tạo chữ' : 'Mẹo ghi nhớ cá nhân',
                          hintText: isZh ? 'VD: 坚 (Kiên) + 持 (Trì)' : 'VD: Gốc từ persist + đuôi ent',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Example Sentence
                      TextFormField(
                        controller: _exampleTextCtrl,
                        decoration: InputDecoration(
                          labelText: isZh ? 'Câu ví dụ (Tiếng Trung)' : 'Câu ví dụ (Tiếng Anh)',
                          hintText: 'VD: Practice makes perfect.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _exampleViCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dịch câu ví dụ (Tiếng Việt)',
                          hintText: 'VD: Có công mài sắt có ngày nên kim.',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tag selector dropdown
                      if (vocabState.tags.isNotEmpty)
                        DropdownButtonFormField<int?>(
                          initialValue: _selectedTagId,
                          decoration: const InputDecoration(
                            labelText: 'Gắn thẻ danh mục',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Không gắn thẻ')),
                            ...vocabState.tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedTagId = val),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;

                      List<ExampleSentence> examples = [];
                      if (_exampleTextCtrl.text.trim().isNotEmpty) {
                        examples.add(ExampleSentence(
                          text: _exampleTextCtrl.text.trim(),
                          vi: _exampleViCtrl.text.trim(),
                        ));
                      }

                      final newItem = VocabularyItem(
                        languageCode: _languageCode,
                        word: _wordCtrl.text.trim(),
                        phonetic: _phoneticCtrl.text.trim().isEmpty ? null : _phoneticCtrl.text.trim(),
                        hanViet: _hanVietCtrl.text.trim().isEmpty ? null : _hanVietCtrl.text.trim(),
                        meaningVi: _meaningCtrl.text.trim(),
                        wordType: _wordTypeCtrl.text.trim().isEmpty ? null : _wordTypeCtrl.text.trim(),
                        level: _levelCtrl.text.trim().isEmpty ? null : _levelCtrl.text.trim(),
                        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                        breakdown: isZh && _notesCtrl.text.trim().contains('+') ? _notesCtrl.text.trim() : null,
                        examples: examples,
                      );

                      final success = await ref.read(vocabularyProvider.notifier).saveWord(
                        newItem,
                        tagIds: _selectedTagId != null ? [_selectedTagId!] : null,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Đã thêm từ "${newItem.word}" vào sổ & kích hoạt lịch ôn SRS!'
                                  : 'Từ "${newItem.word}" đã tồn tại trong sổ từ vựng.',
                            ),
                            backgroundColor: success ? AppColors.successGreen : AppColors.warningYellow,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Lưu vào Sổ từ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                      foregroundColor: Colors.white,
                    ),
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
