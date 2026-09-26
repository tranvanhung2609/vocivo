import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/language_mode_provider.dart';
import '../../providers/settings_provider.dart';
import '../home/home_screen.dart';
import '../../widgets/vocivo_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Selected options in onboarding
  String _selectedLanguageMode = 'BOTH'; // 'EN', 'ZH', 'BOTH'
  int _dailyTarget = 10; // 5, 10, 20
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    // Save language mode
    if (_selectedLanguageMode != 'BOTH') {
      ref.read(languageModeProvider.notifier).setLanguage(_selectedLanguageMode);
    }
    // Save API key if provided
    if (_apiKeyController.text.trim().isNotEmpty) {
      await ref
          .read(settingsProvider.notifier)
          .setGeminiApiKey(_apiKeyController.text.trim());
    }
    // Mark completed
    await ref.read(settingsProvider.notifier).completeOnboarding();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isTabletPlus = width >= AppBreakpoints.tablet;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.surfaceLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTabletPlus ? 580 : double.infinity,
            ),
            child: Column(
              children: [
                // Top skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        'Bỏ qua',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                        ),
                      ),
                    ),
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildWelcomeSlide(isDark),
                      _buildGoalsSlide(isDark),
                      _buildAiSetupSlide(isDark),
                    ],
                  ),
                ),

                // Bottom Navigation controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    children: [
                      // Smooth Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final isCurrent = index == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isCurrent ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primaryEnglish
                                  : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Next / Start Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryEnglish,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentPage == 2 ? 'Bắt Đầu Trải Nghiệm' : 'Tiếp Tục',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 1: WELCOME & BRAND
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildWelcomeSlide(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing logo
          const VocivoLogo(
            size: 84,
            showText: false,
          ),
          const SizedBox(height: 28),

          Text(
            'Chào mừng đến với\nVocivo',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Ghi nhớ từ vựng và luyện nói mỗi ngày — để những từ đã học trở thành lời bạn tự tin nói ra bằng tiếng Anh và tiếng Trung.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.55,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
          const SizedBox(height: 32),

          // Feature highlights
          _buildFeatureRow(
            icon: Icons.mic_rounded,
            title: 'Luyện Phát Âm Trực Tiếp',
            desc: 'Đánh giá độ chuẩn xác, hoàn thiện và lưu loát theo thời gian thực.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            icon: Icons.style_rounded,
            title: 'Flashcard 3D & SRS SM-2',
            desc: 'Tối ưu hóa thời điểm ôn tập để ghi nhớ vĩnh viễn không quên.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildFeatureRow(
            icon: Icons.translate_rounded,
            title: 'Chiết Tự & Âm Hán-Việt',
            desc: 'Phân tích chiết tự chữ Hán giúp người Việt học từ vựng Trung siêu nhanh.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryEnglishLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryEnglish, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 2: LANGUAGE GOALS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildGoalsSlide(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mục Tiêu Học Tập',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn ngôn ngữ bạn muốn ưu tiên học và khối lượng từ mỗi ngày:',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Language selection
          Text(
            'Ngôn ngữ trọng tâm:',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildLanguageOption(
            key: 'EN',
            title: 'Tiếng Anh',
            subtitle: 'Giao tiếp, IPA, Oxford 3000, CEFR A1–C2',
            icon: Icons.language_rounded,
            color: AppColors.primaryEnglish,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildLanguageOption(
            key: 'ZH',
            title: 'Tiếng Trung (HSK)',
            subtitle: 'Chữ Hán, Pinyin thanh điệu, Âm Hán-Việt',
            icon: Icons.translate_rounded,
            color: AppColors.accent,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildLanguageOption(
            key: 'BOTH',
            title: 'Song Ngữ Cả Hai (Khuyên dùng)',
            subtitle: 'Học đối chiếu Anh — Trung cho người Việt',
            icon: Icons.compare_arrows_rounded,
            color: AppColors.streakOrange,
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // Daily Target selection
          Text(
            'Mục tiêu số từ mỗi ngày:',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTargetPill(5, 'Thư thái', isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildTargetPill(10, 'Tiêu chuẩn', isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildTargetPill(20, 'Tăng tốc', isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedLanguageMode == key;
    return InkWell(
      onTap: () => setState(() => _selectedLanguageMode = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetPill(int target, String desc, bool isDark) {
    final isSelected = _dailyTarget == target;
    return InkWell(
      onTap: () => setState(() => _dailyTarget = target),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryEnglish
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryEnglish
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$target từ',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : AppColors.textLightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 3: AI BYOK SETUP (OPTIONAL)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildAiSetupSlide(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.streakAmber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.streakAmber,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Trí Tuệ Nhân Tạo (BYOK)',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vocivo hoạt động hoàn toàn offline với SQLite. Bạn có thể thêm khóa Gemini API cá nhân (hoàn toàn miễn phí) để kích hoạt tính năng phân tích nghĩa sâu và ví dụ tự động.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              hintText: 'Dán Gemini API Key tại đây (tùy chọn)...',
              prefixIcon: const Icon(Icons.key_rounded, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Dán từ clipboard',
                    icon: const Icon(Icons.content_paste_rounded, size: 20),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null && data!.text!.trim().isNotEmpty) {
                        _apiKeyController.text = data.text!.trim();
                      }
                    },
                  ),
                  IconButton(
                    tooltip: _obscureApiKey ? 'Hiện khóa' : 'Ẩn khóa',
                    icon: Icon(_obscureApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
                    onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              filled: true,
              fillColor: isDark ? AppColors.cardDark : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '💡 Bạn có thể để trống và thêm khóa này bất kỳ lúc nào trong phần Cài đặt.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Ready summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryEnglishLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryEnglish.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: AppColors.primaryEnglish, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mọi thứ đã sẵn sàng! Chạm vào nút bên dưới để bắt đầu chinh phục từ vựng.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryEnglishDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
