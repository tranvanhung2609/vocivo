import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/ai_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../widgets/update/update_dialog.dart';
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
  bool _isCheckingUpdate = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _geminiController.text = settings.geminiApiKey;
    _openAiController.text = settings.openAiApiKey;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _geminiController.dispose();
    _openAiController.dispose();
    super.dispose();
  }

  void _onKeyChanged(String val, bool isGemini) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (isGemini) {
        ref.read(settingsProvider.notifier).setGeminiApiKey(val.trim());
      } else {
        ref.read(settingsProvider.notifier).setOpenAiApiKey(val.trim());
      }
    });
  }

  Future<void> _saveKeyExplicitly(bool isGemini) async {
    _debounceTimer?.cancel();
    final text = isGemini ? _geminiController.text.trim() : _openAiController.text.trim();
    if (isGemini) {
      await ref.read(settingsProvider.notifier).setGeminiApiKey(text);
    } else {
      await ref.read(settingsProvider.notifier).setOpenAiApiKey(text);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Đã lưu ${isGemini ? "Google Gemini" : "OpenAI"} API Key thành công!'),
              ),
            ],
          ),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testApiKey() async {
    final settings = ref.read(settingsProvider);
    final isGemini = settings.activeProvider == 'gemini';
    final keyToTest = isGemini ? _geminiController.text.trim() : _openAiController.text.trim();
    final providerName = isGemini ? 'Google Gemini' : 'OpenAI';

    if (keyToTest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Vui lòng nhập API Key cho $providerName trước khi kiểm tra.')),
            ],
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Phát hiện trường hợp nhập nhầm khóa giữa 2 nhà cung cấp
    if (!isGemini && keyToTest.startsWith('AIzaSy')) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primaryEnglish),
              SizedBox(width: 8),
              Expanded(child: Text('Phát hiện API Key Google Gemini')),
            ],
          ),
          content: const Text(
            'Khóa bạn vừa nhập bắt đầu bằng "AIzaSy" — đây là API Key của Google Gemini (miễn phí), không phải của OpenAI!\n\n'
            'Bạn có muốn tự động chuyển sang tab Google Gemini để lưu và kiểm tra không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _switchToProvider('gemini', keyToTest);
              },
              child: const Text('Chuyển sang Gemini'),
            ),
          ],
        ),
      );
      return;
    }

    if (isGemini && keyToTest.startsWith('sk-')) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primaryEnglish),
              SizedBox(width: 8),
              Expanded(child: Text('Phát hiện API Key OpenAI')),
            ],
          ),
          content: const Text(
            'Khóa bạn vừa nhập bắt đầu bằng "sk-" — đây là API Key của OpenAI (ChatGPT), không phải của Google Gemini!\n\n'
            'Bạn có muốn tự động chuyển sang tab OpenAI để lưu và kiểm tra không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _switchToProvider('openai', keyToTest);
              },
              child: const Text('Chuyển sang OpenAI'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isTestingKey = true);
    try {
      // Lưu API Key đang nhập vào bộ nhớ trước khi test
      if (isGemini) {
        await ref.read(settingsProvider.notifier).setGeminiApiKey(keyToTest);
      } else {
        await ref.read(settingsProvider.notifier).setOpenAiApiKey(keyToTest);
      }

      await AiService.instance.testConnection(
        provider: isGemini ? 'gemini' : 'openai',
        apiKey: keyToTest,
        geminiModel: settings.geminiModel,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.successGreen),
                const SizedBox(width: 8),
                Expanded(child: Text('Kết nối $providerName thành công!')),
              ],
            ),
            content: Text(
              'API Key hoạt động chính xác!\n\n• Nhà cung cấp: $providerName\n• Mô hình: ${isGemini ? settings.geminiModel : "gpt-4o-mini"}\n• Trạng thái: Sẵn sàng sử dụng cho toàn bộ tính năng AI trong app.',
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
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.errorRed),
                const SizedBox(width: 8),
                Expanded(child: Text('Kiểm tra $providerName thất bại')),
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

  Future<void> _switchToProvider(String targetProvider, String key) async {
    await ref.read(settingsProvider.notifier).setActiveProvider(targetProvider);
    if (targetProvider == 'gemini') {
      _geminiController.text = key;
      await ref.read(settingsProvider.notifier).setGeminiApiKey(key);
      _openAiController.clear();
      await ref.read(settingsProvider.notifier).setOpenAiApiKey('');
    } else {
      _openAiController.text = key;
      await ref.read(settingsProvider.notifier).setOpenAiApiKey(key);
      _geminiController.clear();
      await ref.read(settingsProvider.notifier).setGeminiApiKey('');
    }
    if (mounted) {
      setState(() {});
      _testApiKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if ((previous == null || !previous.isLoaded) && next.isLoaded) {
        if (_geminiController.text.isEmpty && next.geminiApiKey.isNotEmpty) {
          _geminiController.text = next.geminiApiKey;
        }
        if (_openAiController.text.isEmpty && next.openAiApiKey.isNotEmpty) {
          _openAiController.text = next.openAiApiKey;
        }
      }
    });

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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Dán từ clipboard',
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null && data!.text!.trim().isNotEmpty) {
                          _geminiController.text = data.text!.trim();
                          _saveKeyExplicitly(true);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: _obscureGemini ? 'Hiện khóa' : 'Ẩn khóa',
                      icon: Icon(_obscureGemini ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
                      onPressed: () => setState(() => _obscureGemini = !_obscureGemini),
                    ),
                  ],
                ),
              ),
              onChanged: (val) => _onKeyChanged(val, true),
              onSubmitted: (val) => _saveKeyExplicitly(true),
            ),
            if (_geminiController.text.trim().startsWith('sk-'))
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Khóa này có dạng của OpenAI (bắt đầu bằng sk-).',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _switchToProvider('openai', _geminiController.text.trim()),
                      child: const Text('Chuyển sang OpenAI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
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
              initialValue: ['gemini-flash-latest', 'gemini-2.5-flash-lite', 'gemini-3.8-flash'].contains(settings.geminiModel)
                  ? settings.geminiModel
                  : 'gemini-flash-latest',
              decoration: const InputDecoration(
                labelText: 'Mô hình Gemini',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'gemini-flash-latest', child: Text('Gemini Flash (Mặc định - Khuyên dùng)')),
                DropdownMenuItem(value: 'gemini-2.5-flash-lite', child: Text('Gemini 2.5 Flash Lite (Tiết kiệm)')),
                DropdownMenuItem(value: 'gemini-3.8-flash', child: Text('Gemini 3.8 Flash (Thế hệ mới)')),
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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Dán từ clipboard',
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null && data!.text!.trim().isNotEmpty) {
                          _openAiController.text = data.text!.trim();
                          _saveKeyExplicitly(false);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: _obscureOpenAi ? 'Hiện khóa' : 'Ẩn khóa',
                      icon: Icon(_obscureOpenAi ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
                      onPressed: () => setState(() => _obscureOpenAi = !_obscureOpenAi),
                    ),
                  ],
                ),
              ),
              onChanged: (val) => _onKeyChanged(val, false),
              onSubmitted: (val) => _saveKeyExplicitly(false),
            ),
            if (_openAiController.text.trim().startsWith('AIzaSy'))
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Khóa này có dạng của Google Gemini (bắt đầu bằng AIzaSy).',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _switchToProvider('gemini', _openAiController.text.trim()),
                      child: const Text('Chuyển sang Gemini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 16),

          // Action buttons: Save & Test
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _saveKeyExplicitly(settings.activeProvider == 'gemini'),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Lưu API Key'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTestingKey ? null : _testApiKey,
                  icon: _isTestingKey
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(
                    _isTestingKey
                        ? 'Đang kiểm tra...'
                        : 'Kiểm tra ${settings.activeProvider == "gemini" ? "Gemini" : "OpenAI"}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
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

          // ── Visual Theme Picker (3-card) ────────────────────────
          Row(
            children: [
              _buildThemeCard(
                context: context,
                isDark: isDark,
                mode: ThemeMode.system,
                currentMode: settings.themeMode,
                icon: Icons.brightness_auto_rounded,
                label: 'Hệ thống',
                previewBg: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FAFC), Color(0xFF1E293B)],
                ),
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.system),
              ),
              const SizedBox(width: 10),
              _buildThemeCard(
                context: context,
                isDark: isDark,
                mode: ThemeMode.light,
                currentMode: settings.themeMode,
                icon: Icons.light_mode_rounded,
                label: 'Sáng',
                previewBg: const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFF8FAFC)],
                ),
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 10),
              _buildThemeCard(
                context: context,
                isDark: isDark,
                mode: ThemeMode.dark,
                currentMode: settings.themeMode,
                icon: Icons.dark_mode_rounded,
                label: 'Tối',
                previewBg: const LinearGradient(
                  colors: [Color(0xFF0B1120), Color(0xFF0B1120)],
                ),
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark),
              ),
            ],
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

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          // Section 4: Cập nhật ứng dụng
          _buildSectionHeader(
            icon: Icons.system_update_rounded,
            title: 'Cập nhật ứng dụng',
            subtitle: 'Kiểm tra phiên bản mới nhất từ GitHub Releases',
          ),
          const SizedBox(height: 12),
          _buildUpdateSection(isDark),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildUpdateSection(bool isDark) {
    final updateState = ref.watch(updateProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryEnglish.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primaryEnglish,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiểm tra cập nhật',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textDarkPrimary
                            : AppColors.textLightPrimary,
                      ),
                    ),
                    Text(
                      _getUpdateStatusText(updateState),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _getUpdateStatusColor(updateState, isDark),
                      ),
                    ),
                  ],
                ),
              ),
              _buildUpdateStatusIcon(updateState),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isCheckingUpdate ? null : () => _checkUpdateManually(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryEnglish,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isCheckingUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _isCheckingUpdate ? 'Đang kiểm tra...' : 'Kiểm tra ngay',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUpdateStatusText(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.available:
        return '✨ Có phiên bản mới: ${state.updateInfo?.latestVersion ?? ''}';
      case UpdateStatus.noUpdate:
        return '✅ Đang dùng phiên bản mới nhất';
      case UpdateStatus.error:
        return '⚠️ Không thể kiểm tra - Thử lại sau';
      default:
        return 'Nhấn để kiểm tra phiên bản mới';
    }
  }

  Color _getUpdateStatusColor(UpdateState state, bool isDark) {
    switch (state.status) {
      case UpdateStatus.available:
        return AppColors.primaryEnglish;
      case UpdateStatus.noUpdate:
        return AppColors.successGreen;
      case UpdateStatus.error:
        return AppColors.warningYellow;
      default:
        return isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    }
  }

  Widget _buildUpdateStatusIcon(UpdateState state) {
    if (state.status == UpdateStatus.available) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryEnglish.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryEnglish.withAlpha(60)),
        ),
        child: Text(
          'Mới',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryEnglish,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _checkUpdateManually() async {
    setState(() => _isCheckingUpdate = true);
    try {
      await ref.read(updateProvider.notifier).manualCheck();
      final state = ref.read(updateProvider);
      if (mounted && state.status == UpdateStatus.available) {
        await UpdateDialog.show(context);
      } else if (mounted && state.status == UpdateStatus.noUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Đang dùng phiên bản mới nhất rồi!')),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  /// Rich theme card with gradient preview, icon, and selected indicator
  Widget _buildThemeCard({
    required BuildContext context,
    required bool isDark,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required String label,
    required Gradient previewBg,
    required VoidCallback onTap,
  }) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryEnglish
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 2.0 : 1.5,
            ),
            color: isDark ? AppColors.surfaceDark2 : Colors.white,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryEnglish.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              // Preview thumbnail
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: previewBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 22,
                    color: mode == ThemeMode.dark
                        ? Colors.white70
                        : AppColors.primaryEnglish,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Label
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryEnglish
                      : (isDark
                          ? AppColors.textDarkSecondary
                          : AppColors.textLightSecondary),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primaryEnglish,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
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
