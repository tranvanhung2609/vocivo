import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/update_provider.dart';
import 'download_progress_sheet.dart';

/// Dialog hiển thị thông báo có bản cập nhật mới.
/// Hỗ trợ:
///   - Hiển thị release notes (có scroll)
///   - Nút "Cập nhật ngay" → bắt đầu download
///   - Nút "Để sau" (ẩn nếu isForceUpdate = true)
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);
    final info = updateState.updateInfo;
    if (info == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      // Không cho back nếu force update
      canPop: !info.isForceUpdate,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              _buildHeader(context, info, isDark),

              // ── Release notes ───────────────────────────────────
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildReleaseNotes(context, info, isDark),
                ),
              ),

              // ── File info ────────────────────────────────────────
              _buildFileInfo(context, info, isDark),

              // ── Buttons ──────────────────────────────────────────
              _buildButtons(context, ref, info),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, info, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryEnglish.withAlpha(isDark ? 40 : 25),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Icon với vòng glow
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryEnglish.withAlpha(20),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEnglish.withAlpha(60),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: AppColors.primaryEnglish,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Có bản cập nhật mới! 🎉',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _versionChip(info.currentVersion, isDark, isCurrent: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
                ),
              ),
              _versionChip(info.latestVersion, isDark, isCurrent: false),
            ],
          ),
          if (info.isForceUpdate) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.errorRed.withAlpha(60)),
              ),
              child: Text(
                'Bắt buộc cập nhật để tiếp tục sử dụng',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.errorRed,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _versionChip(String version, bool isDark, {required bool isCurrent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
            : AppColors.primaryEnglish.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? Colors.transparent
              : AppColors.primaryEnglish.withAlpha(60),
        ),
      ),
      child: Text(
        version.startsWith('v') ? version : 'v$version',
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isCurrent
              ? (isDark ? AppColors.textDarkMuted : AppColors.textLightMuted)
              : AppColors.primaryEnglish,
        ),
      ),
    );
  }

  Widget _buildReleaseNotes(BuildContext context, info, bool isDark) {
    if (info.releaseNotes.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Text(
            info.releaseNotes,
            style: GoogleFonts.outfit(
              fontSize: 13,
              height: 1.6,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfo(BuildContext context, info, bool isDark) {
    final isAndroid = info.fileName.contains('android');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Icon(
            isAndroid ? Icons.android_rounded : Icons.desktop_windows_rounded,
            size: 16,
            color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
          ),
          const SizedBox(width: 6),
          Text(
            isAndroid ? 'Android APK' : 'Windows',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.download_rounded,
            size: 16,
            color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
          ),
          const SizedBox(width: 4),
          Text(
            info.fileSizeFormatted,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, WidgetRef ref, info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          // Nút "Cập nhật ngay"
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => _onUpdatePressed(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryEnglish,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.system_update_rounded, size: 20),
              label: Text(
                'Cập nhật ngay',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Nút "Để sau" — ẩn khi force update
          if (!info.isForceUpdate) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () {
                  ref.read(updateProvider.notifier).dismiss();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Để sau',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textDarkMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onUpdatePressed(BuildContext context, WidgetRef ref) async {
    // Đóng dialog và mở progress sheet
    Navigator.of(context).pop();
    await ref.read(updateProvider.notifier).startDownload();

    if (context.mounted) {
      DownloadProgressSheet.show(context);
    }
  }
}
