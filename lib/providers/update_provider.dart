import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/update_service.dart';
import '../models/app_update_info.dart';

// ────────────────────────────────────────────────────────────────
// State
// ────────────────────────────────────────────────────────────────

enum UpdateStatus {
  idle,
  checking,
  available,
  noUpdate,
  downloading,
  installing,
  error,
}

@immutable
class UpdateState {
  final UpdateStatus status;
  final AppUpdateInfo? updateInfo;

  /// Tiến trình download từ 0.0 đến 1.0
  final double downloadProgress;

  /// Tốc độ download tính bằng bytes/s
  final double downloadSpeed;

  /// Đường dẫn file đã download xong (chờ install)
  final String? downloadedFilePath;

  final String? errorMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.updateInfo,
    this.downloadProgress = 0.0,
    this.downloadSpeed = 0.0,
    this.downloadedFilePath,
    this.errorMessage,
  });

  bool get isLoading =>
      status == UpdateStatus.checking ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.installing;

  UpdateState copyWith({
    UpdateStatus? status,
    AppUpdateInfo? updateInfo,
    double? downloadProgress,
    double? downloadSpeed,
    String? downloadedFilePath,
    String? errorMessage,
  }) {
    return UpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  UpdateState clearError() => UpdateState(
        status: status,
        updateInfo: updateInfo,
        downloadProgress: downloadProgress,
        downloadSpeed: downloadSpeed,
        downloadedFilePath: downloadedFilePath,
      );
}

// ────────────────────────────────────────────────────────────────
// Notifier
// ────────────────────────────────────────────────────────────────

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    return const UpdateState();
  }

  /// Check update tự động (có cooldown 24h).
  /// Gọi sau khi app khởi động xong.
  Future<void> autoCheck() async {
    await _doCheck(forceCheck: false);
  }

  /// Check update thủ công (user nhấn nút, bỏ qua cooldown).
  Future<void> manualCheck() async {
    await _doCheck(forceCheck: true);
  }

  Future<void> _doCheck({required bool forceCheck}) async {
    if (state.isLoading) return;

    state = const UpdateState(status: UpdateStatus.checking);

    try {
      final updateInfo = await UpdateService.instance.checkForUpdate(
        forceCheck: forceCheck,
      );

      if (updateInfo != null) {
        state = UpdateState(
          status: UpdateStatus.available,
          updateInfo: updateInfo,
        );
      } else {
        state = const UpdateState(status: UpdateStatus.noUpdate);
      }
    } catch (e) {
      debugPrint('[UpdateProvider] check error: $e');
      state = UpdateState(
        status: UpdateStatus.error,
        errorMessage: 'Không thể kiểm tra cập nhật. Vui lòng thử lại sau.',
      );
    }
  }

  /// Bắt đầu download bản cập nhật.
  Future<void> startDownload() async {
    final info = state.updateInfo;
    if (info == null) return;
    if (state.status == UpdateStatus.downloading) return;

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0.0,
      downloadSpeed: 0.0,
    );

    try {
      final filePath = await UpdateService.instance.downloadUpdate(
        info,
        onProgress: (progress) {
          state = state.copyWith(downloadProgress: progress);
        },
        onSpeed: (speed) {
          state = state.copyWith(downloadSpeed: speed);
        },
      );

      // Download xong, chờ user xác nhận install
      state = state.copyWith(
        status: UpdateStatus.available,
        downloadedFilePath: filePath,
        downloadProgress: 1.0,
      );
    } on Exception catch (e) {
      final msg = e.toString();
      // Kiểm tra nếu bị cancel bởi user
      if (msg.contains('User cancelled')) {
        state = UpdateState(
          status: UpdateStatus.available,
          updateInfo: state.updateInfo,
        );
      } else {
        debugPrint('[UpdateProvider] download error: $e');
        state = UpdateState(
          status: UpdateStatus.error,
          updateInfo: state.updateInfo,
          errorMessage: 'Tải xuống thất bại. Vui lòng kiểm tra kết nối mạng.',
        );
      }
    }
  }

  /// Hủy download.
  void cancelDownload() {
    UpdateService.instance.cancelDownload();
  }

  /// Cài đặt file đã download.
  Future<void> installUpdate() async {
    final filePath = state.downloadedFilePath;
    if (filePath == null) return;

    state = state.copyWith(status: UpdateStatus.installing);

    try {
      await UpdateService.instance.installUpdate(filePath);
      // Android: app sẽ bị kill bởi hệ thống sau khi install
      // Windows: exit(0) được gọi trong service
    } catch (e) {
      debugPrint('[UpdateProvider] install error: $e');
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Cài đặt thất bại: $e',
      );
    }
  }

  /// Đặt lại trạng thái về idle (dùng khi user bấm "Để sau").
  void dismiss() {
    state = const UpdateState(status: UpdateStatus.idle);
  }

  /// Xóa lỗi và quay lại trạng thái trước.
  void clearError() {
    state = state.clearError();
  }
}

// ────────────────────────────────────────────────────────────────
// Provider
// ────────────────────────────────────────────────────────────────

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(() {
  return UpdateNotifier();
});
