import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/ai_search_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../settings/settings_screen.dart';
import 'word_card.dart';

class AiLookupDialog extends ConsumerWidget {
  final String query;
  final String languageCode;

  const AiLookupDialog({
    super.key,
    required this.query,
    required this.languageCode,
  });

  static Future<void> show(BuildContext context, {required String query, required String languageCode}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiLookupDialog(query: query, languageCode: languageCode),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(aiSearchProvider);
    final isZh = languageCode.toUpperCase() == 'ZH';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isZh ? AppColors.primaryChineseLight : AppColors.primaryEnglishLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phân tích cùng AI ($languageCode)',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                        ),
                      ),
                      Text(
                        'Tra cứu từ: "$query"',
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildBody(context, ref, aiState, isZh, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AiSearchState aiState,
    bool isZh,
    bool isDark,
  ) {
    if (aiState.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            CircularProgressIndicator(
              color: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
            ),
            const SizedBox(height: 20),
            Text(
              'Đang kết nối AI để phân tích ngữ cảnh, từ nguyên & ví dụ...',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Áp dụng chuẩn HSK / CEFR & âm Hán-Việt',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (aiState.hasError) {
      final isKeyError = aiState.errorMessage!.contains('API Key');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorRedLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Không thể hoàn thành tra cứu AI',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.errorRed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aiState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (isKeyError)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Cài đặt API Key ngay (Miễn phí)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEnglish,
                  foregroundColor: Colors.white,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(aiSearchProvider.notifier).lookupWord(
                        query: query,
                        languageCode: languageCode,
                      );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
              ),
          ],
        ),
      );
    }

    if (aiState.hasResult) {
      final item = aiState.result!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WordCard(
            item: item,
            isSavedInNotebook: false,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final success = await ref.read(vocabularyProvider.notifier).saveWord(item);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Đã lưu "${item.word}" vào Sổ từ vựng & lên lịch SRS!'
                          : 'Từ "${item.word}" đã có trong sổ từ vựng.',
                    ),
                    backgroundColor: success ? AppColors.successGreen : AppColors.warningYellow,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.bookmark_added_rounded, size: 20),
            label: const Text('Lưu vào Sổ từ & Bắt đầu Ôn tập SRS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isZh ? AppColors.primaryChinese : AppColors.primaryEnglish,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
