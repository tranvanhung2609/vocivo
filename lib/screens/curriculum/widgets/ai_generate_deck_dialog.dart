import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/curriculum_provider.dart';
import '../../../providers/settings_provider.dart';
import '../unit_detail_screen.dart';

class AiGenerateDeckDialog extends ConsumerStatefulWidget {
  final String languageCode;

  const AiGenerateDeckDialog({super.key, required this.languageCode});

  static Future<void> show(BuildContext context, {required String languageCode}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiGenerateDeckDialog(languageCode: languageCode),
    );
  }

  @override
  ConsumerState<AiGenerateDeckDialog> createState() => _AiGenerateDeckDialogState();
}

class _AiGenerateDeckDialogState extends ConsumerState<AiGenerateDeckDialog> {
  final TextEditingController _topicController = TextEditingController();
  late String _selectedLevel;
  int _wordCount = 8;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.languageCode == 'ZH' ? 'HSK 2' : 'A2';
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  List<String> get _suggestions => widget.languageCode == 'ZH'
      ? [
          'Gọi món lẩu & đồ nướng',
          'Đặt hàng Taobao & 1688',
          'Đi tàu cao tốc & Sân bay',
          'Khám bệnh & Mua thuốc',
          'Thuê nhà & Sinh hoạt phí',
          'Đàm phán giá cả nhà xưởng',
        ]
      : [
          'Phỏng vấn IT Senior',
          'Tiếng Anh sân bay & Hải quan',
          'Thuyết trình & Họp dự án',
          'Gọi món tại quán rượu Pub',
          'Hỏi đường & Thuê xe tự lái',
          'Giao dịch ngân hàng & Đầu tư',
        ];

  List<String> get _levels => widget.languageCode == 'ZH'
      ? ['HSK 1', 'HSK 2', 'HSK 3', 'HSK 4', 'HSK 5', 'HSK 6']
      : ['A1', 'A2', 'B1', 'B2', 'C1'];

  Future<void> _handleGenerate() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = 'Vui lòng nhập chủ đề bạn muốn học.');
      return;
    }

    final settings = ref.read(settingsProvider);
    if (!settings.hasGeminiKey && !settings.hasOpenAiKey) {
      setState(() => _error =
          'Vui lòng cài đặt API Key Google Gemini (miễn phí) trong Cài đặt để AI tạo bài học.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    HapticFeedback.mediumImpact();

    final newUnit = await ref.read(curriculumProvider.notifier).generateAiTopicDeck(
          topic: topic,
          level: _selectedLevel,
          wordCount: _wordCount,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (newUnit != null) {
      Navigator.of(context).pop(); // đóng dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Đã tạo thành công bộ thẻ "${newUnit.title}"!'),
          backgroundColor: AppColors.primaryEnglish,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UnitDetailScreen(unitId: newUnit.id),
        ),
      );
    } else {
      final stateErr = ref.read(curriculumProvider).errorMessage;
      setState(() => _error = stateErr ?? 'Không thể tạo bộ thẻ lúc này. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh = widget.languageCode == 'ZH';
    final accentColor = isZh ? const Color(0xFFEF4444) : AppColors.primaryEnglish;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: accentColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isZh ? 'AI Tạo Bộ Thẻ Tiếng Trung' : 'AI Tạo Bộ Thẻ Tiếng Anh',
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Tự động soạn từ vựng, phiên âm & ví dụ chuẩn',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isLoading)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error message banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.redAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Topic Input
                Text(
                  'Chủ đề bạn muốn học:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _topicController,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleGenerate(),
                  decoration: InputDecoration(
                    hintText: isZh
                        ? 'Ví dụ: Đặt hàng Taobao, Đi du lịch Thượng Hải...'
                        : 'Ví dụ: Phỏng vấn xin việc IT, Tiếng Anh tại sân bay...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    prefixIcon: Icon(Icons.topic_outlined, color: accentColor, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Suggestions Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestions.map((sug) {
                    return InkWell(
                      onTap: _isLoading
                          ? null
                          : () {
                              _topicController.text = sug;
                              setState(() => _error = null);
                            },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+ $sug',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Level & Word Count Selector Row
                Row(
                  children: [
                    // Level
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cấp độ:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedLevel,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: _levels.map((lvl) {
                                  return DropdownMenuItem(
                                    value: lvl,
                                    child: Text(
                                      lvl,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (val) {
                                        if (val != null) setState(() => _selectedLevel = val);
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Word count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số lượng từ:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _wordCount,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: [5, 8, 10, 15].map((cnt) {
                                  return DropdownMenuItem(
                                    value: cnt,
                                    child: Text(
                                      '$cnt từ vựng',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (val) {
                                        if (val != null) setState(() => _wordCount = val);
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button / Loading state
                if (_isLoading) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'AI đang biên soạn bộ thẻ từ vựng...',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đang trích xuất nghĩa ngữ cảnh, phiên âm và câu ví dụ song ngữ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _handleGenerate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tạo Bộ Thẻ Học Ngay',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
