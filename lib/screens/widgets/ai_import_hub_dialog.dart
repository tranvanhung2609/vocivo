import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/ai_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vocabulary_item.dart';
import '../../providers/language_mode_provider.dart';
import '../settings/settings_screen.dart';
import 'import_preview_dialog.dart';

class AiImportHubDialog extends ConsumerStatefulWidget {
  const AiImportHubDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AiImportHubDialog(),
    );
  }

  @override
  ConsumerState<AiImportHubDialog> createState() => _AiImportHubDialogState();
}

class _AiImportHubDialogState extends ConsumerState<AiImportHubDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Common options
  late String _targetLanguage;
  String? _selectedLevel;
  int _maxWords = 10;
  bool _isLoading = false;
  String _loadingMessage = '';

  // Tab 1: Image
  XFile? _selectedImage;
  Uint8List? _imageBytes;

  // Tab 2: Text
  final TextEditingController _textController = TextEditingController();

  // Tab 3: File
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  int? _fileSize;
  String? _fileContentPreview;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _targetLanguage = ref.read(languageModeProvider);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // ACTIONS: IMAGE PICKING & EXTRACTION
  // --------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi khi chọn ảnh: $e');
    }
  }

  Future<void> _processImageExtraction() async {
    if (_imageBytes == null) {
      _showErrorSnackBar('Vui lòng chọn hoặc chụp một bức ảnh trước.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'AI đang đọc hình ảnh & trích xuất từ vựng...';
    });

    try {
      final mimeType = _selectedImage?.mimeType ?? 'image/jpeg';
      final results = await AiService.instance.extractVocabularyFromImage(
        imageBytes: _imageBytes!,
        mimeType: mimeType,
        languageCode: _targetLanguage,
        targetLevel: _selectedLevel,
        maxWords: _maxWords,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (results.isEmpty) {
        _showErrorSnackBar('AI không tìm thấy từ vựng phù hợp trong ảnh này.');
        return;
      }

      Navigator.pop(context); // Close hub
      ImportPreviewDialog.show(
        context,
        items: results,
        sourceTitle: 'Từ vựng trích xuất từ ảnh ($_targetLanguage)',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _handleAiError(e);
      }
    }
  }

  // --------------------------------------------------------------------------
  // ACTIONS: TEXT EXTRACTION
  // --------------------------------------------------------------------------

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
    }
  }

  void _insertSampleText() {
    if (_targetLanguage.toUpperCase() == 'ZH') {
      _textController.text =
          '随着人工智能技术的迅速发展，越来越多的学习者开始利用数字化工具来提升语言能力。持之以恒是掌握一门外语的关键因素。';
    } else {
      _textController.text =
          'Sustainable development requires resilient economic policies and unprecedented global collaboration. Innovations in renewable energy have significantly reduced carbon emissions.';
    }
  }

  Future<void> _processTextExtraction() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập hoặc dán văn bản.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'AI đang phân tích văn bản & lọc từ vựng...';
    });

    try {
      final results = await AiService.instance.extractVocabularyFromText(
        text: text,
        languageCode: _targetLanguage,
        targetLevel: _selectedLevel,
        maxWords: _maxWords,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (results.isEmpty) {
        _showErrorSnackBar('Không tìm thấy từ vựng nào trong đoạn văn.');
        return;
      }

      Navigator.pop(context);
      ImportPreviewDialog.show(
        context,
        items: results,
        sourceTitle: 'Từ vựng trích xuất từ văn bản ($_targetLanguage)',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _handleAiError(e);
      }
    }
  }

  // --------------------------------------------------------------------------
  // ACTIONS: FILE PICKING & EXTRACTION
  // --------------------------------------------------------------------------

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'txt'],
      );

      if (res.isNotEmpty) {
        final file = res.first;
        final bytes = await file.xFile.readAsBytes();
        final size = await file.length() ?? bytes.length;
        final raw = utf8.decode(bytes, allowMalformed: true);
        final preview = raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;

        setState(() {
          _selectedFile = file;
          _fileBytes = bytes;
          _fileSize = size;
          _fileContentPreview = preview;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi khi mở file: $e');
    }
  }

  Future<void> _processFileImport() async {
    if (_selectedFile == null || _fileBytes == null) {
      _showErrorSnackBar('Vui lòng chọn một tệp JSON, CSV hoặc TXT.');
      return;
    }

    final ext = (_selectedFile!.extension ?? '').toLowerCase();
    final rawText = utf8.decode(_fileBytes!, allowMalformed: true);

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang phân tích định dạng tệp $ext...';
    });

    try {
      List<VocabularyItem> results = [];

      if (ext == 'json') {
        results = SyncService.instance.parseJsonToVocabulary(rawText);
      } else if (ext == 'csv') {
        results = SyncService.instance.parseCsvToVocabulary(
          rawText,
          defaultLanguageCode: _targetLanguage,
        );
      } else {
        // TXT file: try simple line-based parse first; if too few, use AI
        final simpleList = SyncService.instance.parseRawTextToVocabulary(
          rawText,
          defaultLanguageCode: _targetLanguage,
        );
        if (simpleList.length >= 3 && simpleList.any((e) => e.meaningVi.isNotEmpty)) {
          results = simpleList;
        } else {
          // Unstructured text -> call AI
          setState(() => _loadingMessage = 'AI đang đọc tệp văn bản và trích xuất từ vựng...');
          results = await AiService.instance.extractVocabularyFromText(
            text: rawText,
            languageCode: _targetLanguage,
            targetLevel: _selectedLevel,
            maxWords: _maxWords,
          );
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (results.isEmpty) {
        _showErrorSnackBar('Không tìm thấy dữ liệu từ vựng hợp lệ trong tệp này.');
        return;
      }

      Navigator.pop(context);
      ImportPreviewDialog.show(
        context,
        items: results,
        sourceTitle: 'Từ tệp: ${_selectedFile!.name}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _handleAiError(e);
      }
    }
  }

  // --------------------------------------------------------------------------
  // HELPERS
  // --------------------------------------------------------------------------

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleAiError(Object error) {
    final errorStr = error.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.errorRed),
            SizedBox(width: 8),
            Text('Lỗi kết nối AI'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorStr.replaceAll('Exception: ', '')),
            const SizedBox(height: 12),
            const Text(
              'Gợi ý: Kiểm tra lại API Key cá nhân trong phần Cài đặt và đảm bảo kết nối mạng ổn định.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('Cài đặt API Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh = _targetLanguage.toUpperCase() == 'ZH';
    final primaryColor = isZh ? AppColors.primaryChinese : AppColors.primaryEnglish;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.bgDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Stack(
          children: [
            Column(
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
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nhập từ vựng thông minh (AI Hub)',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                              ),
                            ),
                            const Text(
                              'Sử dụng API Key cá nhân để trích xuất từ ảnh, tài liệu và văn bản',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Common Configuration Bar (Language, Level, Max Words)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Language Selector
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Ngôn ngữ: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          DropdownButton<String>(
                            value: _targetLanguage,
                            isDense: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'EN', child: Text('🇬🇧 Tiếng Anh', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'ZH', child: Text('🇨🇳 Tiếng Trung', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _targetLanguage = val;
                                  _selectedLevel = null;
                                });
                              }
                            },
                          ),
                        ],
                      ),

                      // Level Filter
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Trình độ: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          DropdownButton<String?>(
                            value: _selectedLevel,
                            isDense: true,
                            underline: const SizedBox(),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Tất cả cấp độ', style: TextStyle(fontSize: 12))),
                              if (isZh) ...[
                                const DropdownMenuItem(value: 'HSK 1-2', child: Text('HSK 1-2 (Cơ bản)', style: TextStyle(fontSize: 12))),
                                const DropdownMenuItem(value: 'HSK 3-4', child: Text('HSK 3-4 (Trung cấp)', style: TextStyle(fontSize: 12))),
                                const DropdownMenuItem(value: 'HSK 5-6', child: Text('HSK 5-6 (Cao cấp)', style: TextStyle(fontSize: 12))),
                              ] else ...[
                                const DropdownMenuItem(value: 'A1-A2', child: Text('A1-A2 (Cơ bản)', style: TextStyle(fontSize: 12))),
                                const DropdownMenuItem(value: 'B1-B2', child: Text('B1-B2 (Trung cấp)', style: TextStyle(fontSize: 12))),
                                const DropdownMenuItem(value: 'C1-C2', child: Text('C1-C2 (IELTS / Advanced)', style: TextStyle(fontSize: 12))),
                              ],
                            ],
                            onChanged: (val) => setState(() => _selectedLevel = val),
                          ),
                        ],
                      ),

                      // Max Words
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Số lượng từ: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          DropdownButton<int>(
                            value: _maxWords,
                            isDense: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5 từ', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 10, child: Text('10 từ', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 15, child: Text('15 từ', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 20, child: Text('20 từ', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _maxWords = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs Header
                TabBar(
                  controller: _tabController,
                  indicatorColor: primaryColor,
                  labelColor: primaryColor,
                  unselectedLabelColor: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                  tabs: const [
                    Tab(icon: Icon(Icons.photo_camera_rounded, size: 20), text: 'Chụp / Ảnh'),
                    Tab(icon: Icon(Icons.article_rounded, size: 20), text: 'Dán Văn bản'),
                    Tab(icon: Icon(Icons.folder_open_rounded, size: 20), text: 'Tệp CSV/JSON'),
                  ],
                ),
                const Divider(height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImageTab(isDark, primaryColor),
                      _buildTextTab(isDark, primaryColor),
                      _buildFileTab(isDark, primaryColor),
                    ],
                  ),
                ),
              ],
            ),

            // Loading Overlay
            if (_isLoading)
              Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        _loadingMessage,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Đang khai thác tối đa API Key cá nhân của bạn...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: IMAGE MULTIMODAL
  // --------------------------------------------------------------------------

  Widget _buildImageTab(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Chụp trang sách'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Chọn từ Thư viện'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Image Preview or Placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: _imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Chụp hoặc chọn ảnh trang sách, đề thi, biển báo...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'AI Vision sẽ đọc ảnh và tự động lọc từ vựng chất lượng cao',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _imageBytes != null && !_isLoading ? _processImageExtraction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.document_scanner_rounded),
            label: Text(
              'AI Quét ảnh & Trích xuất từ vựng',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: FREE-FORM TEXT
  // --------------------------------------------------------------------------

  Widget _buildTextTab(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Dán bài báo, bài luận, đoạn văn hoặc danh sách từ:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _pasteClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Dán', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: _insertSampleText,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                label: const Text('Ví dụ mẫu', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: _targetLanguage.toUpperCase() == 'ZH'
                    ? 'Dán đoạn văn tiếng Trung hoặc danh sách từ thô vào đây...'
                    : 'Paste English article, essay, or raw word list here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: !_isLoading ? _processTextExtraction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              'AI Trích xuất từ vựng từ văn bản',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: FILE IMPORT (JSON / CSV / TXT)
  // --------------------------------------------------------------------------

  Widget _buildFileTab(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Chọn tệp từ máy tính (.json, .csv, .txt)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: _selectedFile != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.description_rounded, color: AppColors.primaryEnglish),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedFile!.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            Text(
                              '${((_fileSize ?? 0) / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const Text(
                          'Xem trước nội dung đầu file:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _fileContentPreview ?? '',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_zip_outlined,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Hỗ trợ tệp Vocivo JSON, bảng tính CSV, hoặc TXT',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tự động phân giải cột và nhận diện chuẩn cấu trúc từ điển',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _selectedFile != null && !_isLoading ? _processFileImport : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.input_rounded),
            label: Text(
              'Đọc và phân tích tệp',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
