import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/database/app_database.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vocabulary_item.dart';
import '../../models/tag_model.dart';
import '../../providers/vocabulary_provider.dart';

class ImportPreviewDialog extends ConsumerStatefulWidget {
  final List<VocabularyItem> initialItems;
  final String sourceTitle;

  const ImportPreviewDialog({
    super.key,
    required this.initialItems,
    this.sourceTitle = 'Xem trước dữ liệu nhập',
  });

  static Future<void> show(
    BuildContext context, {
    required List<VocabularyItem> items,
    String sourceTitle = 'Xem trước từ vựng',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImportPreviewDialog(
        initialItems: items,
        sourceTitle: sourceTitle,
      ),
    );
  }

  @override
  ConsumerState<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends ConsumerState<ImportPreviewDialog> {
  late List<VocabularyItem> _items;
  final Set<int> _selectedIndices = {};
  final Map<int, bool> _duplicateMap = {};
  bool _isLoadingChecks = true;
  bool _isSaving = false;
  int? _selectedTagId;
  List<TagModel> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
    _checkDuplicatesAndInitSelection();
  }

  Future<void> _checkDuplicatesAndInitSelection() async {
    final tags = await AppDatabase.instance.getAllTags();
    final Map<int, bool> duplicates = {};

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final isSaved = await AppDatabase.instance.isWordSaved(item.word, item.languageCode);
      duplicates[i] = isSaved;
      if (!isSaved) {
        _selectedIndices.add(i);
      }
    }

    if (mounted) {
      setState(() {
        _availableTags = tags;
        _duplicateMap.addAll(duplicates);
        _isLoadingChecks = false;
      });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _items.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.clear();
        for (int i = 0; i < _items.length; i++) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  void _selectOnlyNew() {
    setState(() {
      _selectedIndices.clear();
      for (int i = 0; i < _items.length; i++) {
        if (_duplicateMap[i] != true) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  Future<void> _handleSave() async {
    if (_selectedIndices.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final selectedItems = _selectedIndices.map((idx) => _items[idx]).toList();
      final tagIds = _selectedTagId != null ? [_selectedTagId!] : null;

      final savedCount = await SyncService.instance.saveVocabularyBatch(
        selectedItems,
        tagIds: tagIds,
      );

      await ref.read(vocabularyProvider.notifier).loadInitialData();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Đã thêm $savedCount từ vựng mới vào Sổ tay thành công!'),
                ),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu từ vựng: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _editItem(int index) {
    final item = _items[index];
    final wordController = TextEditingController(text: item.word);
    final meaningController = TextEditingController(text: item.meaningVi);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa thông tin từ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wordController,
              decoration: const InputDecoration(labelText: 'Từ / Chữ Hán'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: meaningController,
              decoration: const InputDecoration(labelText: 'Nghĩa tiếng Việt'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items[index] = item.copyWith(
                  word: wordController.text.trim(),
                  meaningVi: meaningController.text.trim(),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _items.length;
    final newCount = _duplicateMap.values.where((isDup) => !isDup).length;
    final duplicateCount = totalCount - newCount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.bgDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEnglish.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.checklist_rtl_rounded,
                      color: AppColors.primaryEnglish,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sourceTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                          ),
                        ),
                        Text(
                          _isLoadingChecks
                              ? 'Đang kiểm tra từ trùng lặp...'
                              : 'Tìm thấy $totalCount từ ($newCount từ mới, $duplicateCount đã có trong sổ)',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Controls & Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _toggleSelectAll,
                        icon: Icon(
                          _selectedIndices.length == _items.length
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _selectedIndices.length == _items.length ? 'Bỏ chọn hết' : 'Chọn tất cả',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (duplicateCount > 0)
                        TextButton.icon(
                          onPressed: _selectOnlyNew,
                          icon: const Icon(Icons.filter_alt_outlined, size: 16),
                          label: const Text('Chỉ chọn từ mới', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),

                  // Tag dropdown
                  if (_availableTags.isNotEmpty)
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedTagId,
                        hint: const Text('Gán nhãn (Tùy chọn)', style: TextStyle(fontSize: 12)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Không gán nhãn', style: TextStyle(fontSize: 12)),
                          ),
                          ..._availableTags.map(
                            (tag) => DropdownMenuItem<int?>(
                              value: tag.id,
                              child: Text(tag.name, style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => _selectedTagId = val),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Item List
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Không có từ vựng nào được nhận diện.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final item = _items[idx];
                        final isSelected = _selectedIndices.contains(idx);
                        final isDuplicate = _duplicateMap[idx] == true;
                        final isZh = item.languageCode.toUpperCase() == 'ZH';

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? (isZh ? AppColors.primaryChinese : AppColors.primaryEnglish)
                                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndices.remove(idx);
                                } else {
                                  _selectedIndices.add(idx);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedIndices.add(idx);
                                        } else {
                                          _selectedIndices.remove(idx);
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),

                                  // Word Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.word,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? AppColors.textDarkPrimary
                                                    : AppColors.textLightPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (item.phonetic != null && item.phonetic!.isNotEmpty)
                                              Text(
                                                item.phonetic!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isZh
                                                      ? AppColors.primaryChinese
                                                      : AppColors.primaryEnglish,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            if (item.hanViet != null && item.hanViet!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '(${item.hanViet})',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.hanVietText,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                            const Spacer(),

                                            // Level badge
                                            if (item.level != null && item.level!.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF334155)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.level!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        // Meaning
                                        Text(
                                          item.meaningVi.isEmpty ? '(Chưa có nghĩa)' : item.meaningVi,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? AppColors.textDarkSecondary
                                                : AppColors.textLightSecondary,
                                          ),
                                        ),

                                        // Duplicate warning
                                        if (isDuplicate) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.amber.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.info_outline_rounded,
                                                    size: 13, color: Colors.amber),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Từ này đã có trong Sổ tay',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.amber,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        // Notes or Examples summary if present
                                        if (item.examples.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Ví dụ: "${item.examples.first.text}"',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: isDark
                                                  ? AppColors.textDarkMuted
                                                  : AppColors.textLightMuted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Edit Button
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Chỉnh sửa',
                                    onPressed: () => _editItem(idx),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),

            // Footer action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Đã chọn ${_selectedIndices.length} / ${_items.length} từ',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _selectedIndices.isEmpty || _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_done_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Đang lưu...' : 'Lưu ${_selectedIndices.length} từ vào Sổ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
