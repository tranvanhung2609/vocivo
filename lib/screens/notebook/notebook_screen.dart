import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/sync_service.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/vocabulary_provider.dart';
import '../widgets/word_card.dart';
import '../widgets/add_word_dialog.dart';
import '../widgets/word_detail_panel.dart';
import '../widgets/ai_import_hub_dialog.dart';

class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _filterController = TextEditingController();
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _handleExportJson() async {
    try {
      final jsonStr = await SyncService.instance.exportToJson();
      final path = await SyncService.instance.saveExportFile(
        content: jsonStr,
        extension: 'json',
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.successGreen),
                SizedBox(width: 8),
                Text('Sao lưu thành công'),
              ],
            ),
            content: SelectableText(
              'File sao lưu JSON (\$0 Server Cost) đã được lưu tại:\n\n$path\n\nBạn có thể chuyển file này sang điện thoại Android hoặc máy tính khác để đồng bộ dữ liệu hoàn toàn bảo mật.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất file: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _handleExportFlashcardsCsv() async {
    try {
      final csvStr = await SyncService.instance.exportToFlashcardsCsv();
      final path = await SyncService.instance.saveExportFile(
        content: csvStr,
        extension: 'csv',
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.style_rounded, color: AppColors.primaryEnglish),
                SizedBox(width: 8),
                Text('Xuất bộ thẻ Flashcard (CSV)'),
              ],
            ),
            content: SelectableText(
              'File CSV bộ thẻ Flashcard đã tạo thành công tại:\n\n$path\n\nBạn có thể lưu trữ hoặc nhập vào bất kỳ ứng dụng và nền tảng flashcard nào.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất CSV: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _handleImportJson() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập từ vựng (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dán nội dung JSON đã xuất từ thiết bị khác vào đây:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '[{"word": "example", "language_code": "EN", ...}]',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final count = await SyncService.instance.importFromJson(controller.text);
                await ref.read(vocabularyProvider.notifier).loadInitialData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã nhập thành công $count từ vựng mới!'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi nhập dữ liệu: $e'),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Nhập ngay'),
          ),
        ],
      ),
    );
  }

  void _showWordDetailModal(VocabularyItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardDark
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: WordDetailPanel(
          item: item,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocabState = ref.watch(vocabularyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sổ từ vựng cá nhân',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Nhập từ thông minh (AI Import Hub)',
            color: AppColors.primaryEnglish,
            onPressed: () => AiImportHubDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Thêm từ thủ công',
            onPressed: () {
              final lang = _tabController.index == 2 ? 'ZH' : 'EN';
              AddWordDialog.show(context, initialLanguage: lang);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Sao lưu & Nhập/Xuất',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'ai_import') AiImportHubDialog.show(context);
              if (val == 'json') _handleExportJson();
              if (val == 'flashcard_csv') _handleExportFlashcardsCsv();
              if (val == 'import') _handleImportJson();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'ai_import',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.primaryEnglish, size: 20),
                    SizedBox(width: 10),
                    Text('AI Import Hub (Ảnh/File/Text)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'json',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, color: AppColors.primaryEnglish, size: 20),
                    SizedBox(width: 10),
                    Text('Xuất file sao lưu (JSON)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'flashcard_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: AppColors.primaryChinese, size: 20),
                    SizedBox(width: 10),
                    Text('Xuất thẻ Flashcard (CSV)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: AppColors.streakOrange, size: 20),
                    SizedBox(width: 10),
                    Text('Nhập nhanh từ JSON (Raw)'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryEnglish,
          unselectedLabelColor: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
          indicatorColor: AppColors.primaryEnglish,
          tabs: [
            Tab(text: 'Tất cả (${vocabState.notebookItems.length})'),
            Tab(
              text: 'Tiếng Anh (${vocabState.notebookItems.where((e) => e.languageCode == 'EN').length})',
            ),
            Tab(
              text: 'Tiếng Trung (${vocabState.notebookItems.where((e) => e.languageCode == 'ZH').length})',
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Filter search bar in notebook
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _filterController,
                  onChanged: (v) => setState(() => _filterText = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Lọc trong sổ từ cá nhân (chữ Hán, tiếng Anh, Hán-Việt hoặc nghĩa)...',
                    prefixIcon: const Icon(Icons.filter_list_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    suffixIcon: _filterText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filterText = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Tabs content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(vocabState.notebookItems, null),
                    _buildList(vocabState.notebookItems, 'EN'),
                    _buildList(vocabState.notebookItems, 'ZH'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final lang = _tabController.index == 2 ? 'ZH' : 'EN';
          AddWordDialog.show(context, initialLanguage: lang);
        },
        backgroundColor: _tabController.index == 2 ? AppColors.primaryChinese : AppColors.primaryEnglish,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm từ mới'),
      ),
    );
  }

  Widget _buildList(List<VocabularyItem> items, String? langCode) {
    List<VocabularyItem> filtered = items;
    if (langCode != null) {
      filtered = filtered.where((e) => e.languageCode == langCode).toList();
    }
    if (_filterText.isNotEmpty) {
      filtered = filtered.where((e) {
        return e.word.toLowerCase().contains(_filterText) ||
            e.meaningVi.toLowerCase().contains(_filterText) ||
            (e.hanViet != null && e.hanViet!.toLowerCase().contains(_filterText));
      }).toList();
    }

    if (filtered.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_motion_rounded,
                size: 54,
                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
              ),
              const SizedBox(height: 14),
              Text(
                _filterText.isNotEmpty
                    ? 'Không tìm thấy từ vựng nào khớp với "$_filterText".'
                    : 'Chưa có từ vựng nào trong danh sách này.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filterText.isNotEmpty
                    ? 'Hãy thử tìm từ khóa khác hoặc xóa bộ lọc.'
                    : 'Hãy sử dụng AI để chụp ảnh sách giáo khoa, dán văn bản hoặc nhập từ file để làm giàu vốn từ vựng ngay lập tức.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                ),
              ),
              const SizedBox(height: 18),
              if (_filterText.isEmpty)
                ElevatedButton.icon(
                  onPressed: () => AiImportHubDialog.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEnglish,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Nhập từ cùng AI (Ảnh / File / Văn bản)'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final item = filtered[i];
        return WordCard(
          item: item,
          isSavedInNotebook: true,
          onTap: () => _showWordDetailModal(item),
          onDelete: () {
            showDialog(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: const Text('Xác nhận xóa'),
                content: Text('Bạn có chắc muốn xóa từ "${item.word}" khỏi sổ từ vựng không?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dCtx);
                      if (item.id != null) {
                        ref.read(vocabularyProvider.notifier).deleteWord(item.id!);
                      }
                    },
                    child: const Text('Xóa', style: TextStyle(color: AppColors.errorRed)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
