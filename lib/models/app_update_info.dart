/// Model đại diện cho thông tin bản cập nhật lấy từ GitHub Releases API.
class AppUpdateInfo {
  /// Version mới nhất trên server, ví dụ: "1.2.0"
  final String latestVersion;

  /// Version đang chạy trên máy user, ví dụ: "1.0.0"
  final String currentVersion;

  /// Release notes (body của GitHub Release — thường là Markdown)
  final String releaseNotes;

  /// URL download trực tiếp file APK hoặc ZIP tương ứng platform
  final String downloadUrl;

  /// Tên file download, ví dụ: "vocivo-android-release.apk"
  final String fileName;

  /// Kích thước file tính bằng bytes
  final int fileSizeBytes;

  /// Nếu true, user bắt buộc phải update (không thể bỏ qua)
  final bool isForceUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSizeBytes,
    this.isForceUpdate = false,
  });

  /// Kích thước file dạng human-readable, ví dụ: "45.2 MB"
  String get fileSizeFormatted {
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Kiểm tra có update hay không bằng cách so sánh semver
  bool get hasUpdate => _compareSemver(latestVersion, currentVersion) > 0;

  /// So sánh 2 chuỗi semver (major.minor.patch).
  /// Trả về:  1 nếu a > b, -1 nếu a < b, 0 nếu bằng nhau.
  static int _compareSemver(String a, String b) {
    final partsA = _parseSemver(a);
    final partsB = _parseSemver(b);
    for (int i = 0; i < 3; i++) {
      if (partsA[i] > partsB[i]) return 1;
      if (partsA[i] < partsB[i]) return -1;
    }
    return 0;
  }

  static List<int> _parseSemver(String version) {
    // Loại bỏ prefix 'v' hoặc 'V' nếu có, ví dụ: "v1.2.0" → "1.2.0"
    var clean = version.trim();
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1);
    }
    // Loại bỏ build number (+...) và pre-release tag (-...)
    clean = clean.split('+')[0].split('-')[0];
    final parts = clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    // Đảm bảo luôn có đủ 3 phần
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  /// Factory từ GitHub Releases API response JSON
  factory AppUpdateInfo.fromGitHubRelease({
    required Map<String, dynamic> json,
    required String currentVersion,
    required String platformAssetKeyword, // 'android' hoặc 'windows'
  }) {
    final tagName = (json['tag_name'] as String? ?? 'v0.0.0');
    final releaseBody = json['body'] as String? ?? '';
    final isForce = releaseBody.contains('[FORCE_UPDATE]');
    final assets = (json['assets'] as List<dynamic>? ?? []);

    // Tìm asset phù hợp với platform
    Map<String, dynamic>? targetAsset;
    if (platformAssetKeyword == 'windows') {
      // Ưu tiên 1: Installer EXE (.exe)
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.contains('windows') && name.endsWith('.exe')) {
          targetAsset = asset as Map<String, dynamic>;
          break;
        }
      }
      // Ưu tiên 2: Fallback sang ZIP
      if (targetAsset == null) {
        for (final asset in assets) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.contains('windows') && name.endsWith('.zip')) {
            targetAsset = asset as Map<String, dynamic>;
            break;
          }
        }
      }
    } else {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.contains(platformAssetKeyword) && name.endsWith('.apk')) {
          targetAsset = asset as Map<String, dynamic>;
          break;
        }
      }
    }

    return AppUpdateInfo(
      latestVersion: tagName,
      currentVersion: currentVersion,
      releaseNotes: releaseBody.replaceAll('[FORCE_UPDATE]', '').trim(),
      downloadUrl: targetAsset?['browser_download_url'] as String? ?? '',
      fileName: targetAsset?['name'] as String? ?? '',
      fileSizeBytes: targetAsset?['size'] as int? ?? 0,
      isForceUpdate: isForce,
    );
  }
}
