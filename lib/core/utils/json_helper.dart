/// Helper dùng chung để làm sạch JSON string có thể bị bọc trong markdown code fence.
/// Tái sử dụng bởi AiService và SyncService.
class JsonHelper {
  JsonHelper._();

  /// Xóa markdown code fence nếu model trả về JSON bọc trong ```json ... ``` hoặc ```...```
  static String cleanJsonString(String raw) {
    String clean = raw.trim();
    if (clean.startsWith('```')) {
      final newlineIdx = clean.indexOf('\n');
      if (newlineIdx != -1) {
        clean = clean.substring(newlineIdx + 1);
      }
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean.trim();
  }
}
