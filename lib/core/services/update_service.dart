import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_update_info.dart';

/// Service quản lý toàn bộ vòng đời cập nhật app:
/// check → download → install (Android APK / Windows ZIP).
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // ────────────────────────────────────────────────────────────────
  // Config
  // ────────────────────────────────────────────────────────────────
  static const String _repoOwner = 'tranvanhung2609';
  static const String _repoName = 'vocivo';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// SharedPreferences key lưu thời điểm check update gần nhất (Unix ms)
  static const String _kLastCheckKey = 'update_last_check_ms';

  /// Khoảng thời gian tối thiểu giữa 2 lần auto-check (24 giờ)
  static const Duration _checkInterval = Duration(hours: 24);

  final Dio _apiDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  ));

  final Dio _downloadDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 15),
    followRedirects: true,
    maxRedirects: 10,
  ));

  CancelToken? _cancelToken;

  // ────────────────────────────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────────────────────────────

  /// Kiểm tra xem có bản cập nhật mới không.
  ///
  /// [forceCheck] = true bỏ qua cooldown 24h (dùng khi user nhấn "Kiểm tra ngay").
  ///
  /// Trả về [AppUpdateInfo] nếu có update, null nếu đang dùng bản mới nhất
  /// hoặc có lỗi.
  Future<AppUpdateInfo?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // Bỏ qua nếu chưa đến thời gian check (trừ khi forceCheck)
      if (!forceCheck && !await _shouldCheck()) {
        debugPrint('[UpdateService] Skipping check — within cooldown window.');
        return null;
      }

      // Lấy version hiện tại
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      // Gọi GitHub API
      final response = await _apiDio.get<Map<String, dynamic>>(_apiUrl);
      if (response.statusCode != 200 || response.data == null) return null;

      // Lưu thời điểm check
      await _saveLastCheckTime();

      // Xác định platform keyword để chọn đúng asset
      final platformKeyword = _getPlatformAssetKeyword();
      if (platformKeyword == null) return null; // platform không hỗ trợ

      final updateInfo = AppUpdateInfo.fromGitHubRelease(
        json: response.data!,
        currentVersion: currentVersion,
        platformAssetKeyword: platformKeyword,
      );

      if (!updateInfo.hasUpdate) {
        debugPrint(
          '[UpdateService] Already on latest version: $currentVersion',
        );
        return null;
      }

      if (updateInfo.downloadUrl.isEmpty) {
        debugPrint('[UpdateService] No asset found for platform: $platformKeyword');
        return null;
      }

      debugPrint(
        '[UpdateService] Update available: $currentVersion → ${updateInfo.latestVersion}',
      );
      return updateInfo;
    } catch (e) {
      debugPrint('[UpdateService] checkForUpdate error: $e');
      return null;
    }
  }

  /// Download file cập nhật về thư mục tạm.
  ///
  /// [onProgress] callback trả về tiến trình từ 0.0 đến 1.0.
  /// [onSpeed] callback trả về tốc độ download (bytes/s), optional.
  ///
  /// Trả về đường dẫn tuyệt đối của file đã download.
  /// Throws [Exception] nếu có lỗi hoặc bị cancel.
  Future<String> downloadUpdate(
    AppUpdateInfo updateInfo, {
    required void Function(double progress) onProgress,
    void Function(double bytesPerSec)? onSpeed,
  }) async {
    _validateUpdateSource(updateInfo);
    _cancelToken = CancelToken();
    final savePath = await _getDownloadPath(updateInfo.fileName);

    // Xóa file cũ nếu tồn tại
    final file = File(savePath);
    if (await file.exists()) await file.delete();

    // ignore: unused_local_variable
    int lastBytes = 0;
    // ignore: unused_local_variable
    DateTime lastTime = DateTime.now();

    await _downloadDio.download(
      updateInfo.downloadUrl,
      savePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;

        // Tiến trình
        final progress = received / total;
        onProgress(progress.clamp(0.0, 1.0));

        // Tốc độ download
        if (onSpeed != null) {
          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;
          if (elapsed > 500) {
            final speed = (received - lastBytes) / (elapsed / 1000);
            onSpeed(speed);
            lastBytes = received;
            lastTime = now;
          }
        }
      },
    );

    final downloadedSize = await file.length();
    if (downloadedSize == 0 ||
        (updateInfo.fileSizeBytes > 0 && downloadedSize != updateInfo.fileSizeBytes)) {
      await file.delete();
      throw const FormatException(
        'File cập nhật tải về không đúng kích thước công bố.',
      );
    }

    return savePath;
  }

  /// Hủy download đang chạy.
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    _cancelToken = null;
  }

  /// Cài đặt file update đã download.
  ///
  /// - Android: Mở APK bằng PackageInstaller
  /// - Windows: Giải nén ZIP và chạy updater script
  Future<void> installUpdate(String filePath) async {
    if (Platform.isAndroid) {
      await _installAndroid(filePath);
    } else if (Platform.isWindows) {
      await _installWindows(filePath);
    } else {
      throw UnsupportedError(
        'Auto-install không được hỗ trợ trên platform này.',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Android Install
  // ────────────────────────────────────────────────────────────────

  Future<void> _installAndroid(String apkPath) async {
    final result = await OpenFile.open(apkPath);
    if (result.type != ResultType.done) {
      throw Exception(
        'Không thể mở file APK: ${result.message}',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Windows Install
  // ────────────────────────────────────────────────────────────────

  Future<void> _installWindows(String filePath) async {
    final lower = filePath.toLowerCase();

    // Trường hợp 1: File cài đặt Installer (.exe) - Inno Setup
    if (lower.endsWith('.exe')) {
      // Chạy Installer trong background.
      // /SILENT: cài đặt ngầm theo đúng vị trí hiện tại
      // /CLOSEAPPLICATIONS: đóng ứng dụng cũ
      // /RESTARTAPPLICATIONS: tự khởi chạy lại sau khi cài xong
      await Process.start(
        filePath,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      exit(0);
    }

    // Trường hợp 2: Fallback cho file ZIP portable
    final zipPath = filePath;
    final tempDir = await getTemporaryDirectory();
    final extractDir = '${tempDir.path}\\vocivo_update_extracted';
    final batPath = '${tempDir.path}\\vocivo_updater.bat';

    // Lấy thư mục cài đặt hiện tại (nơi vocivo.exe đang chạy)
    final exePath = Platform.resolvedExecutable; // e.g. C:\Program Files\Vocivo\vocivo.exe
    final installDir = File(exePath).parent.path;

    // Tạo thư mục giải nén
    final extractDirectory = Directory(extractDir);
    if (await extractDirectory.exists()) {
      await extractDirectory.delete(recursive: true);
    }

    // Giải nén ZIP bằng PowerShell
    await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive -Force -Path "$zipPath" -DestinationPath "$extractDir"',
    ]);

    // Tạo updater.bat:
    // 1. Chờ process vocivo.exe thoát
    // 2. Copy files mới vào thư mục cài đặt
    // 3. Khởi động lại app
    final batContent = '''
@echo off
echo [Vocivo Updater] Waiting for app to close...
timeout /t 3 /nobreak >nul

echo [Vocivo Updater] Copying new files...
xcopy /e /i /y "$extractDir\\*" "$installDir\\"

echo [Vocivo Updater] Launching Vocivo...
start "" "$installDir\\vocivo.exe"

echo [Vocivo Updater] Done. Cleaning up...
del /f /q "$zipPath"
rmdir /s /q "$extractDir"
del /f /q "%~f0"
''';

    await File(batPath).writeAsString(batContent);

    // Chạy updater script trong background và thoát app
    await Process.start(
      'cmd.exe',
      ['/c', batPath],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );

    // Thoát app để updater có thể copy files
    exit(0);
  }

  // ────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────

  /// Trả về keyword để filter asset theo platform.
  /// null nếu platform không hỗ trợ auto-download.
  String? _getPlatformAssetKeyword() {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return null;
  }

  /// Lấy đường dẫn lưu file download.
  Future<String> _getDownloadPath(String fileName) async {
    Directory dir;
    if (Platform.isAndroid) {
      // Android: lưu vào external storage (accessible bởi PackageInstaller)
      dir = (await getExternalStorageDirectory()) ?? await getTemporaryDirectory();
    } else {
      dir = await getTemporaryDirectory();
    }
    return p.join(dir.path, p.basename(fileName));
  }

  void _validateUpdateSource(AppUpdateInfo updateInfo) {
    final uri = Uri.tryParse(updateInfo.downloadUrl);
    if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') {
      throw const FormatException(
        'Nguồn cập nhật không hợp lệ; chỉ chấp nhận GitHub Releases qua HTTPS.',
      );
    }

    final safeName = p.basename(updateInfo.fileName);
    if (safeName.isEmpty || safeName != updateInfo.fileName) {
      throw const FormatException('Tên file cập nhật không hợp lệ.');
    }
    final lower = safeName.toLowerCase();
    final validExtension = Platform.isAndroid
        ? lower.endsWith('.apk')
        : Platform.isWindows &&
            (lower.endsWith('.exe') || lower.endsWith('.zip'));
    if (!validExtension) {
      throw const FormatException(
        'Định dạng file cập nhật không phù hợp với hệ điều hành.',
      );
    }
  }

  /// Kiểm tra xem có nên check update không (based on 24h cooldown).
  Future<bool> _shouldCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckMs = prefs.getInt(_kLastCheckKey) ?? 0;
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
    return DateTime.now().difference(lastCheck) >= _checkInterval;
  }

  /// Lưu thời điểm check update hiện tại.
  Future<void> _saveLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }
}
