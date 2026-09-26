import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/update_provider.dart';

/// Bottom sheet hiển thị tiến trình download và cài đặt bản cập nhật.
class DownloadProgressSheet extends ConsumerStatefulWidget {
  const DownloadProgressSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DownloadProgressSheet(),
    );
  }

  @override
  ConsumerState<DownloadProgressSheet> createState() =>
      _DownloadProgressSheetState();
}

class _DownloadProgressSheetState extends ConsumerState<DownloadProgressSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tự động đóng sheet khi về idle (hủy hoặc reset)
    ref.listen<UpdateState>(updateProvider, (prev, next) {
      if (next.status == UpdateStatus.idle) {
        if (mounted) Navigator.of(context).pop();
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 12,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildContent(context, ref, state, isDark),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    UpdateState state,
    bool isDark,
  ) {
    if (state.status == UpdateStatus.installing) {
      return _buildInstallingState(isDark);
    }

    if (state.status == UpdateStatus.error) {
      return _buildErrorState(context, ref, state, isDark);
    }

    // Trạng thái downloading hoặc download xong (chờ install)
    final isDownloadComplete =
        state.status == UpdateStatus.available &&
        state.downloadedFilePath != null;

    final progress = state.downloadProgress;
    final speed = state.downloadSpeed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) => Transform.scale(
                scale: state.status == UpdateStatus.downloading
                    ? _pulseAnimation.value
                    : 1.0,
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDownloadComplete
                      ? AppColors.successGreen.withAlpha(25)
                      : AppColors.primaryEnglish.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDownloadComplete
                      ? Icons.check_circle_rounded
                      : Icons.downloading_rounded,
                  color: isDownloadComplete
                      ? AppColors.successGreen
                      : AppColors.primaryEnglish,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDownloadComplete ? 'Tải xuống hoàn tất!' : 'Đang tải xuống...',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textDarkPrimary
                          : AppColors.textLightPrimary,
                    ),
                  ),
                  if (state.updateInfo != null)
                    Text(
                      state.updateInfo!.latestVersion.startsWith('v')
                          ? state.updateInfo!.latestVersion
                          : 'v${state.updateInfo!.latestVersion}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textDarkMuted
                            : AppColors.textLightMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDownloadComplete
                    ? AppColors.successGreen
                    : AppColors.primaryEnglish,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Progress % và speed
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textLightSecondary,
              ),
            ),
            if (speed > 0 && state.status == UpdateStatus.downloading)
              Text(
                _formatSpeed(speed),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textDarkMuted
                      : AppColors.textLightMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Action buttons
        if (isDownloadComplete)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => ref.read(updateProvider.notifier).installUpdate(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryEnglish,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.install_mobile_rounded, size: 20),
              label: Text(
                'Cài đặt ngay',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                ref.read(updateProvider.notifier).cancelDownload();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                'Hủy',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textDarkMuted
                      : AppColors.textLightMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInstallingState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primaryEnglish,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Đang cài đặt...',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'App sẽ tự động khởi động lại sau khi cài xong.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: isDark ? AppColors.textDarkMuted : AppColors.textLightMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    UpdateState state,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.errorRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tải xuống thất bại',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.textDarkPrimary
                            : AppColors.textLightPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.errorMessage ??
                          'Không thể tải bản cập nhật. Vui lòng kiểm tra lại kết nối mạng.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textDarkMuted
                            : AppColors.textLightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(updateProvider.notifier).dismiss();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Đóng',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(updateProvider.notifier).startDownload();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryEnglish,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Thử lại',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }
}
