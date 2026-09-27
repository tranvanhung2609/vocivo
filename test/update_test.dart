import 'package:flutter_test/flutter_test.dart';
import 'package:vocivo/models/app_update_info.dart';

void main() {
  group('AppUpdateInfo Semver & Asset Parsing Tests', () {
    test('Correctly identifies newer versions', () {
      final info1 = AppUpdateInfo(
        latestVersion: 'v1.1.1',
        currentVersion: '1.1.0+3',
        releaseNotes: 'Bug fixes',
        downloadUrl: 'https://example.com/vocivo.exe',
        fileName: 'vocivo.exe',
        fileSizeBytes: 1000,
      );
      expect(info1.hasUpdate, isTrue);

      final info2 = AppUpdateInfo(
        latestVersion: '1.1.0',
        currentVersion: '1.1.0+3',
        releaseNotes: '',
        downloadUrl: '',
        fileName: '',
        fileSizeBytes: 0,
      );
      expect(info2.hasUpdate, isFalse);

      final info3 = AppUpdateInfo(
        latestVersion: 'v1.0.9',
        currentVersion: '1.1.0',
        releaseNotes: '',
        downloadUrl: '',
        fileName: '',
        fileSizeBytes: 0,
      );
      expect(info3.hasUpdate, isFalse);

      final info4 = AppUpdateInfo(
        latestVersion: 'v2.0.0',
        currentVersion: '1.9.9+99',
        releaseNotes: '',
        downloadUrl: '',
        fileName: '',
        fileSizeBytes: 0,
      );
      expect(info4.hasUpdate, isTrue);
    });

    test('Parses GitHub Release response correctly for Windows', () {
      final sampleJson = {
        'tag_name': 'v1.1.1',
        'body': '### Sửa lỗi cập nhật và khởi chạy Windows',
        'assets': [
          {
            'name': 'vocivo-android-release.apk',
            'browser_download_url': 'https://github.com/downloads/vocivo-android-release.apk',
            'size': 65000000,
          },
          {
            'name': 'vocivo-windows-setup.exe',
            'browser_download_url': 'https://github.com/downloads/vocivo-windows-setup.exe',
            'size': 14000000,
          },
          {
            'name': 'vocivo-windows-x64.zip',
            'browser_download_url': 'https://github.com/downloads/vocivo-windows-x64.zip',
            'size': 16000000,
          },
        ],
      };

      final windowsInfo = AppUpdateInfo.fromGitHubRelease(
        json: sampleJson,
        currentVersion: '1.1.0',
        platformAssetKeyword: 'windows',
      );

      expect(windowsInfo.hasUpdate, isTrue);
      expect(windowsInfo.fileName, equals('vocivo-windows-setup.exe'));
      expect(windowsInfo.downloadUrl, equals('https://github.com/downloads/vocivo-windows-setup.exe'));
      expect(windowsInfo.fileSizeBytes, equals(14000000));
      expect(windowsInfo.isForceUpdate, isFalse);
    });

    test('Only accepts APK assets for Android updates', () {
      final info = AppUpdateInfo.fromGitHubRelease(
        json: {
          'tag_name': 'v2.0.0',
          'assets': [
            {
              'name': 'vocivo-android-notes.txt',
              'browser_download_url': 'https://github.com/notes.txt',
              'size': 10,
            },
            {
              'name': 'vocivo-android-release.apk',
              'browser_download_url': 'https://github.com/vocivo.apk',
              'size': 20,
            },
          ],
        },
        currentVersion: '1.0.0',
        platformAssetKeyword: 'android',
      );

      expect(info.fileName, 'vocivo-android-release.apk');
    });
  });
}
