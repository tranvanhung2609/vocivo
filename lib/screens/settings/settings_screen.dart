import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/ai_service.dart';
import '../../providers/settings_provider.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _openAiController = TextEditingController();
  bool _obscureGemini = true;
  bool _obscureOpenAi = true;
  bool _isTestingKey = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _geminiController.text = settings.geminiApiKey;
    _openAiController.text = settings.openAiApiKey;
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _openAiController.dispose();
    super.dispose();
  }

  Future<void> _testApiKey() async {
    setState(() => _isTestingKey = true);
    try {
      // Save current input first
      await ref.read(settingsProvider.notifier).setGeminiApiKey(_geminiController.text);
      final testRes = await AiService.instance.lookupWord(
        query: 'hello',
        languageCode: 'EN',
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.successGreen),
                SizedBox(width: 8),
                Text('Kết nối thành công!'),
              ],
            ),
            content: Text(
              'API Key hoạt động chính xác!\n\nAI đã phân tích từ "${testRes.word}": ${testRes.meaningVi}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tuyệt vời')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.errorRed),
                SizedBox(width: 8),
                Text('Kiểm tra thất bại'),
              ],
            ),
            content: Text('Chi tiết lỗi:\n$e'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingKey = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cài đặt & Cấu hình AI',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: AI BYOK
          _buildSectionHeader(
            icon: Icons.vpn_key_rounded,
            title: 'Cấu hình AI (Bring-Your-Own-Key)',
            subtitle: 'Dùng API Key cá nhân của bạn để tra cứu không giới hạn (\$0 Server Cost)',
          ),
          const SizedBox(height: 14),

          // Provider selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'gemini',
                label: Text('Google Gemini (Miễn phí)'),
                icon: Icon(Icons.auto_awesome_rounded),
              ),
              ButtonSegment(
                value: 'openai',
                label: Text('OpenAI'),
                icon: Icon(Icons.psychology_rounded),
              ),
            ],
            selected: {settings.activeProvider},
            onSelectionChanged: (set) {
              ref.read(settingsProvider.notifier).setActiveProvider(set.first);
            },
          ),
          const SizedBox(height: 16),

          if (settings.activeProvider == 'gemini') ...[
            // Gemini API Key
            TextField(
              controller: _geminiController,
              obscureText: _obscureGemini,
              decoration: InputDecoration(
                labelText: 'Google Gemini API Key',
                hintText: 'AIzaSy...',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureGemini ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscureGemini = !_obscureGemini),
                ),
              ),
              onChanged: (val) {
                ref.read(settingsProvider.notifier).setGeminiApiKey(val);
              },
            ),
            const SizedBox(height: 8),

            // Instructions to get free Gemini key
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primaryEnglish, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bạn có thể lấy Gemini API Key hoàn toàn miễn phí tại Google AI Studio (aistudio.google.com).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Gemini Model dropdown
            DropdownButtonFormField<String>(
              initialValue: settings.geminiModel,
              decoration: const InputDecoration(
                labelText: 'Mô hình Gemini',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'gemini-1.5-flash', child: Text('Gemini 1.5 Flash (Khuyên dùng - Nhanh)')),
                DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('Gemini 2.0 Flash (Thế hệ mới)')),
                DropdownMenuItem(value: 'gemini-2.5-flash', child: Text('Gemini 2.5 Flash')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).setGeminiModel(val);
                }
              },
            ),
          ] else ...[
            // OpenAI API Key
            TextField(
              controller: _openAiController,
              obscureText: _obscureOpenAi,
              decoration: InputDecoration(
                labelText: 'OpenAI API Key',
                hintText: 'sk-...',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureOpenAi ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscureOpenAi = !_obscureOpenAi),
                ),
              ),
              onChanged: (val) {
                ref.read(settingsProvider.notifier).setOpenAiApiKey(val);
              },
            ),
          ],

          const SizedBox(height: 16),

          // Test API Key button
          OutlinedButton.icon(
            onPressed: _isTestingKey ? null : _testApiKey,
            icon: _isTestingKey
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_check_rounded),
            label: Text(_isTestingKey ? 'Đang kiểm tra kết nối...' : 'Kiểm tra hoạt động API Key'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          // Section 2: Giao diện (Theme Mode)
          _buildSectionHeader(
            icon: Icons.palette_outlined,
            title: 'Giao diện & Trải nghiệm',
            subtitle: 'Chuyển đổi chế độ màu sắc hiển thị',
          ),
          const SizedBox(height: 14),

          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Hệ thống'),
                icon: Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Sáng'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Tối'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (set) {
              ref.read(settingsProvider.notifier).setThemeMode(set.first);
            },
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          // Section 3: Về Vocivo
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Thông tin ứng dụng',
            subtitle: 'Vocivo — Học từ vựng & Luyện nói mỗi ngày',
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.successGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Kiến trúc Local-first (\$0 Server Cost)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Hỗ trợ đa nền tảng: Windows Desktop (.exe) và Android (.apk).\n'
                  '• Database cục bộ SQLite bảo mật tuyệt đối, hoạt động 100% offline.\n'
                  '• Tra cứu song ngữ Anh - Trung qua lăng kính âm Hán-Việt & Pinyin 4 thanh điệu.\n'
                  '• Thuật toán lặp lại ngắt quãng SM-2 tiêu chuẩn khoa học (Spaced Repetition System).',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    );
                  },
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('Xem lại hướng dẫn bắt đầu (Onboarding)'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryEnglish),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
