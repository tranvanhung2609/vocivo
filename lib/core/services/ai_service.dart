import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/vocabulary_item.dart';
import '../../models/curriculum_model.dart';
import 'secure_storage_service.dart';

/// Thời gian timeout mặc định cho mọi API call
const _kApiTimeout = Duration(seconds: 30);

class AiService {
  static final AiService instance = AiService._internal();
  AiService._internal();

  static const String _chineseSystemPrompt = '''
Bạn là chuyên gia từ điển và ngôn ngữ học Trung - Việt. Hãy phân tích từ hoặc cụm từ được yêu cầu và trả về kết quả ĐÚNG ĐỊNH DẠNG JSON sau, không kèm bất kỳ giải thích nào khác ngoài JSON:
{
  "word": "学习",
  "pinyin": "xuéxí",
  "han_viet": "Học tập",
  "meaning_vi": "Học tập, học hỏi",
  "hsk_level": "HSK 1",
  "breakdown": "学 (Học: bắt chước) + 习 (Tập: thực hành lặp lại)",
  "examples": [
    {
      "zh": "我们每天都要学习汉语。",
      "pinyin": "Wǒmen měitiān dōu yào xuéxí hànyǔ.",
      "vi": "Chúng tôi ngày nào cũng phải học tiếng Trung."
    }
  ]
}
''';

  static const String _englishSystemPrompt = '''
Bạn là chuyên gia từ điển và ngôn ngữ học Anh - Việt. Hãy phân tích từ hoặc cụm từ được yêu cầu và trả về kết quả ĐÚNG ĐỊNH DẠNG JSON sau, không kèm bất kỳ giải thích nào khác ngoài JSON:
{
  "word": "resilient",
  "ipa": "/rɪˈzɪl.jənt/",
  "word_type": "adjective",
  "meaning_vi": "Kiên cường, có khả năng phục hồi nhanh",
  "level": "B2",
  "collocations": ["resilient economy", "highly resilient"],
  "examples": [
    {
      "en": "Children are often remarkably resilient.",
      "vi": "Trẻ em thường có khả năng thích ứng và hồi phục đáng kinh ngạc."
    }
  ]
}
''';

  // ==========================================================================
  // PUBLIC API
  // ==========================================================================

  /// Lookup single word với AI (BYOK)
  Future<VocabularyItem> lookupWord({
    required String query,
    required String languageCode,
  }) async {
    final provider = await SecureStorageService.instance.getActiveProvider();
    final isChinese = languageCode.toUpperCase() == 'ZH';
    final systemInstruction = isChinese ? _chineseSystemPrompt : _englishSystemPrompt;
    final prompt = '$systemInstruction\n\nTừ cần phân tích: "$query"';

    final String rawText;
    if (provider == 'openai') {
      rawText = await _callOpenAi(
        messages: [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': 'Từ cần phân tích: "$query"'},
        ],
        responseFormat: {'type': 'json_object'},
      );
    } else {
      rawText = await _callGemini(
        contents: [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      );
    }
    return _parseSingleItemJson(rawText, query, languageCode);
  }

  /// Trích xuất từ vựng từ đoạn văn bản thô
  Future<List<VocabularyItem>> extractVocabularyFromText({
    required String text,
    required String languageCode,
    String? targetLevel,
    int maxWords = 10,
  }) async {
    final isChinese = languageCode.toUpperCase() == 'ZH';
    final prompt = _buildBatchExtractionPrompt(
      isChinese: isChinese,
      targetLevel: targetLevel,
      maxWords: maxWords,
      inputDescription: 'Đoạn văn bản / ghi chú sau:\n"""\n$text\n"""',
    );
    return _extractList(prompt: prompt, languageCode: languageCode);
  }

  /// Trích xuất từ vựng từ ảnh (camera snap / document scan)
  Future<List<VocabularyItem>> extractVocabularyFromImage({
    required List<int> imageBytes,
    required String mimeType,
    required String languageCode,
    String? targetLevel,
    int maxWords = 12,
  }) async {
    final provider = await SecureStorageService.instance.getActiveProvider();
    final isChinese = languageCode.toUpperCase() == 'ZH';
    final prompt = _buildBatchExtractionPrompt(
      isChinese: isChinese,
      targetLevel: targetLevel,
      maxWords: maxWords,
      inputDescription:
          'Hình ảnh đính kèm (có thể là trang sách, tài liệu học tập, bảng tin hoặc biển hiệu). Hãy đọc chữ trong ảnh và chọn lọc các từ/cụm từ giá trị nhất.',
    );

    final base64Image = base64Encode(imageBytes);
    final String rawText;

    if (provider == 'openai') {
      rawText = await _callOpenAi(
        messages: [
          {
            'role': 'system',
            'content':
                'Bạn là chuyên gia ngôn ngữ học. Hãy quan sát hình ảnh và trả về kết quả duy nhất ở định dạng JSON với thuộc tính "items" chứa danh sách các từ vựng.',
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
              }
            ],
          }
        ],
        responseFormat: {'type': 'json_object'},
      );
    } else {
      rawText = await _callGemini(
        contents: [
          {
            'parts': [
              {
                'inline_data': {'mime_type': mimeType, 'data': base64Image}
              },
              {'text': prompt}
            ]
          }
        ],
      );
    }
    return _parseListResponseJson(rawText, languageCode);
  }

  /// Enrich danh sách từ đơn giản thành VocabularyItems đầy đủ
  Future<List<VocabularyItem>> enrichVocabularyBatch({
    required List<String> words,
    required String languageCode,
  }) async {
    if (words.isEmpty) return [];
    final isChinese = languageCode.toUpperCase() == 'ZH';
    final wordListFormatted = words.map((w) => '- $w').join('\n');
    final prompt = _buildBatchExtractionPrompt(
      isChinese: isChinese,
      maxWords: words.length,
      inputDescription: 'Danh sách các từ sau cần phân tích chi tiết:\n$wordListFormatted',
    );
    return _extractList(prompt: prompt, languageCode: languageCode);
  }

  /// Tạo bộ thẻ / bài học hoàn chỉnh theo chủ đề bất kỳ bằng AI
  Future<CurriculumUnit> generateTopicDeck({
    required String topic,
    required String languageCode,
    String? level,
    int wordCount = 8,
  }) async {
    final isChinese = languageCode.toUpperCase() == 'ZH';
    final provider = await SecureStorageService.instance.getActiveProvider();

    final systemInstruction = isChinese
        ? '''Bạn là chuyên gia ngôn ngữ học và biên soạn giáo trình tiếng Trung thực chiến hàng đầu.
Hãy tạo một bộ bài học từ vựng hoàn chỉnh về chủ đề: "$topic" với cấp độ: "${level ?? 'HSK 1 - HSK 3'}", gồm đúng $wordCount từ/cụm từ quan trọng nhất.

Trả về kết quả ĐÚNG ĐỊNH DẠNG JSON sau (không kèm bất kỳ văn bản nào khác ngoài JSON):
{
  "unit_title": "Tên bài học tiếng Việt (ví dụ: Gọi món & Ẩm thực Tứ Xuyên)",
  "unit_description": "Mô tả 1 câu về mục tiêu bài học",
  "icon_name": "restaurant",
  "level": "${level ?? 'HSK 2'}",
  "items": [
    {
      "word": "麻婆豆腐",
      "pinyin": "mápó dòufu",
      "han_viet": "Ma bà đậu phụ",
      "meaning_vi": "Đậu phụ Tứ Xuyên (cay tê)",
      "word_type": "noun",
      "hsk_level": "HSK 2",
      "notes": "Món ăn đặc sản kinh điển của tỉnh Tứ Xuyên",
      "examples": [
        {
          "zh": "老板，请给我来一份麻婆豆腐。",
          "pinyin": "Lǎobǎn, qǐng gěi wǒ lái yí fèn mápó dòufu.",
          "vi": "Ông chủ ơi, cho tôi một phần đậu phụ Tứ Xuyên."
        }
      ]
    }
  ]
}'''
        : '''Bạn là chuyên gia ngôn ngữ học và biên soạn giáo trình tiếng Anh thực chiến hàng đầu.
Hãy tạo một bộ bài học từ vựng hoàn chỉnh về chủ đề: "$topic" với cấp độ: "${level ?? 'A2 - B1'}", gồm đúng $wordCount từ/cụm từ thiết thực nhất.

Trả về kết quả ĐÚNG ĐỊNH DẠNG JSON sau (không kèm bất kỳ văn bản nào khác ngoài JSON):
{
  "unit_title": "Tên bài học tiếng Việt (ví dụ: Phỏng vấn xin việc IT)",
  "unit_description": "Mô tả 1 câu về mục tiêu bài học",
  "icon_name": "work",
  "level": "${level ?? 'B1'}",
  "items": [
    {
      "word": "architecture",
      "ipa": "/ˈɑː.kɪ.tek.tʃər/",
      "word_type": "noun",
      "meaning_vi": "Kiến trúc hệ thống phần mềm",
      "level": "B1",
      "notes": "Dùng rất nhiều trong phỏng vấn kỹ thuật",
      "collocations": ["microservices architecture", "clean architecture"],
      "examples": [
        {
          "en": "I have experience designing scalable software architecture.",
          "vi": "Tôi có kinh nghiệm thiết kế kiến trúc phần mềm có khả năng mở rộng."
        }
      ]
    }
  ]
}''';

    final String rawText;
    if (provider == 'openai') {
      rawText = await _callOpenAi(
        messages: [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': 'Tạo bộ thẻ bài học chủ đề: "$topic"'},
        ],
        responseFormat: {'type': 'json_object'},
      );
    } else {
      rawText = await _callGemini(
        contents: [
          {
            'parts': [
              {'text': systemInstruction}
            ]
          }
        ],
      );
    }

    final cleanJson = _cleanJsonString(rawText);
    final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;

    final unitTitle = decoded['unit_title']?.toString().trim() ?? topic;
    final unitDesc = decoded['unit_description']?.toString().trim() ?? 'Bộ từ vựng chủ đề $topic';
    final iconName = decoded['icon_name']?.toString().trim() ?? (isChinese ? 'translate' : 'school');
    final actualLevel = decoded['level']?.toString().trim() ?? (level ?? (isChinese ? 'HSK 2' : 'A2'));

    final rawItems = decoded['items'] as List? ?? [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((e) => _parseItemMap(e, languageCode))
        .toList();

    return CurriculumUnit(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      stageId: 'custom_ai',
      stageTitle: '✨ Chủ Đề AI Tự Tạo',
      languageCode: languageCode.toUpperCase(),
      title: unitTitle,
      description: unitDesc,
      iconName: iconName,
      level: actualLevel,
      isAiGenerated: true,
      words: items,
      orderIndex: 999,
    );
  }

  // ==========================================================================
  // PRIVATE HTTP HELPERS — Tập trung logic gọi API, tránh duplication
  // ==========================================================================

  /// Kiểm tra trực tiếp kết nối với API Key cụ thể và kiểm tra định dạng
  Future<String> testConnection({
    required String provider, // 'gemini' hoặc 'openai'
    required String apiKey,
    String? geminiModel,
  }) async {
    final cleanKey = apiKey.trim();
    if (provider == 'gemini') {
      if (cleanKey.startsWith('sk-')) {
        throw Exception(
          'Khóa bạn nhập bắt đầu bằng "sk-" — đây là API Key của OpenAI (ChatGPT)!\n'
          'Vui lòng chọn tab "OpenAI" phía trên để sử dụng khóa này, hoặc lấy Gemini API Key miễn phí tại aistudio.google.com.',
        );
      }
      return await _callGemini(
        contents: [
          {
            'parts': [
              {'text': 'Trả về JSON: {"status": "ok", "message": "hello"}'}
            ]
          }
        ],
        apiKeyOverride: cleanKey,
        modelOverride: geminiModel,
      );
    } else {
      if (cleanKey.startsWith('AIzaSy')) {
        throw Exception(
          'Khóa bạn nhập bắt đầu bằng "AIzaSy" — đây là API Key của Google Gemini!\n'
          'Vui lòng chọn tab "Google Gemini (Miễn phí)" phía trên để sử dụng khóa này.',
        );
      }
      return await _callOpenAi(
        messages: [
          {'role': 'user', 'content': 'Hello, reply with JSON: {"status": "ok"}'},
        ],
        responseFormat: {'type': 'json_object'},
        apiKeyOverride: cleanKey,
      );
    }
  }

  /// Gọi Gemini API và trả về text thô từ response
  Future<String> _callGemini({
    required List<Map<String, dynamic>> contents,
    double temperature = 0.2,
    String? apiKeyOverride,
    String? modelOverride,
  }) async {
    final apiKey = apiKeyOverride ?? await SecureStorageService.instance.getGeminiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('Vui lòng nhập API Key Google Gemini trong phần Cài đặt (miễn phí tại Google AI Studio).');
    }

    var model = modelOverride ?? await SecureStorageService.instance.getGeminiModel();
    if (model == 'gemini-flash-latest' ||
        model.contains('3.8') ||
        model.contains('2.5-flash-lite')) {
      model = 'gemini-1.5-flash';
    }

    var url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'responseMimeType': 'application/json',
      }
    });

    var response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(
          _kApiTimeout,
          onTimeout: () => throw Exception('Kết nối Gemini bị timeout sau 30 giây. Hãy thử lại.'),
        );

    // Fallback nếu model cũ bị 404
    if (response.statusCode == 404 && model != 'gemini-1.5-flash') {
      url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
      );
      response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_kApiTimeout);
    }

    if (response.statusCode != 200) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>?;
      final errorMsg = errorJson?['error']?['message']?.toString()
          ?? 'Lỗi gọi Gemini API (${response.statusCode})';
      throw Exception(errorMsg);
    }

    final jsonRes = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = jsonRes['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Không nhận được kết quả phân tích từ Gemini.');
    }
    return candidates[0]['content']?['parts']?[0]?['text']?.toString() ?? '';
  }

  /// Gọi OpenAI Chat Completions API và trả về text thô từ response
  Future<String> _callOpenAi({
    required List<Map<String, dynamic>> messages,
    Map<String, dynamic>? responseFormat,
    String model = 'gpt-4o-mini',
    double temperature = 0.2,
    String? apiKeyOverride,
  }) async {
    final apiKey = apiKeyOverride ?? await SecureStorageService.instance.getOpenAiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('Vui lòng nhập API Key OpenAI trong phần Cài đặt.');
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final bodyMap = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
    };
    if (responseFormat != null) bodyMap['response_format'] = responseFormat;

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(bodyMap),
        )
        .timeout(
          _kApiTimeout,
          onTimeout: () => throw Exception('Kết nối OpenAI bị timeout sau 30 giây. Hãy thử lại.'),
        );

    if (response.statusCode != 200) {
      final errorJson = jsonDecode(response.body) as Map<String, dynamic>?;
      final errorMsg = errorJson?['error']?['message']?.toString()
          ?? 'Lỗi gọi OpenAI API (${response.statusCode})';
      throw Exception(errorMsg);
    }

    final jsonRes = jsonDecode(response.body) as Map<String, dynamic>;
    return jsonRes['choices']?[0]?['message']?['content']?.toString() ?? '';
  }

  // ==========================================================================
  // PRIVATE BATCH HELPERS
  // ==========================================================================

  Future<List<VocabularyItem>> _extractList({
    required String prompt,
    required String languageCode,
  }) async {
    final provider = await SecureStorageService.instance.getActiveProvider();
    final String rawText;

    if (provider == 'openai') {
      rawText = await _callOpenAi(
        messages: [
          {
            'role': 'system',
            'content': 'Bạn là chuyên gia ngôn ngữ học. Hãy trả về kết quả duy nhất ở định dạng JSON với thuộc tính "items" chứa danh sách các từ vựng.',
          },
          {'role': 'user', 'content': prompt},
        ],
        responseFormat: {'type': 'json_object'},
      );
    } else {
      rawText = await _callGemini(
        contents: [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      );
    }
    return _parseListResponseJson(rawText, languageCode);
  }

  // ==========================================================================
  // PROMPT BUILDER
  // ==========================================================================

  String _buildBatchExtractionPrompt({
    required bool isChinese,
    String? targetLevel,
    required int maxWords,
    required String inputDescription,
  }) {
    if (isChinese) {
      return '''
Bạn là chuyên gia từ điển Trung - Việt. Hãy phân tích nội dung sau và trích xuất tối đa $maxWords từ/cụm từ tiếng Trung tiêu biểu nhất${targetLevel != null ? ' (ưu tiên cấp độ $targetLevel)' : ''}.

$inputDescription

Yêu cầu: Trả về kết quả JSON với thuộc tính "items" chứa mảng các đối tượng, mỗi đối tượng có cấu trúc chính xác sau:
{
  "items": [
    {
      "word": "学习",
      "pinyin": "xuéxí",
      "han_viet": "Học tập",
      "meaning_vi": "Học tập, học hỏi",
      "hsk_level": "HSK 1",
      "breakdown": "学 (Học) + 习 (Tập)",
      "examples": [
        {
          "zh": "我们每天都要学习汉语。",
          "pinyin": "Wǒmen měitiān dōu yào xuéxí hànyǔ.",
          "vi": "Chúng tôi ngày nào cũng phải học tiếng Trung."
        }
      ]
    }
  ]
}
Chỉ trả về JSON thuần túy, không có văn bản dẫn nhập.
''';
    } else {
      return '''
Bạn là chuyên gia từ điển Anh - Việt. Hãy phân tích nội dung sau và trích xuất tối đa $maxWords từ/cụm từ tiếng Anh tiêu biểu nhất${targetLevel != null ? ' (ưu tiên cấp độ $targetLevel)' : ''}.

$inputDescription

Yêu cầu: Trả về kết quả JSON với thuộc tính "items" chứa mảng các đối tượng, mỗi đối tượng có cấu trúc chính xác sau:
{
  "items": [
    {
      "word": "resilient",
      "ipa": "/rɪˈzɪl.jənt/",
      "word_type": "adjective",
      "meaning_vi": "Kiên cường, mau phục hồi",
      "level": "B2",
      "notes": "Gốc từ Latin: re + salire (bật nảy trở lại)",
      "collocations": ["resilient economy", "highly resilient"],
      "examples": [
        {
          "en": "Children are often remarkably resilient.",
          "vi": "Trẻ em thường có khả năng thích ứng và hồi phục đáng kinh ngạc."
        }
      ]
    }
  ]
}
Chỉ trả về JSON thuần túy, không có văn bản dẫn nhập.
''';
    }
  }

  // ==========================================================================
  // JSON PARSER HELPERS
  // ==========================================================================

  VocabularyItem _parseSingleItemJson(String rawText, String query, String languageCode) {
    final cleanJson = _cleanJsonString(rawText);
    final Map<String, dynamic> data = jsonDecode(cleanJson) as Map<String, dynamic>;
    return _parseItemMap(data, languageCode, fallbackWord: query);
  }

  List<VocabularyItem> _parseListResponseJson(String rawText, String languageCode) {
    final cleanJson = _cleanJsonString(rawText);
    final decoded = jsonDecode(cleanJson);

    List rawList = [];
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawList = decoded['items'] ?? decoded['vocabulary'] ?? decoded['words'] ?? decoded['data'] ?? [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => _parseItemMap(e, languageCode))
        .toList();
  }

  VocabularyItem _parseItemMap(Map<String, dynamic> data, String languageCode, {String? fallbackWord}) {
    final isChinese = languageCode.toUpperCase() == 'ZH';
    final word = data['word']?.toString().trim() ?? fallbackWord ?? '';
    final phonetic = isChinese
        ? data['pinyin']?.toString()
        : (data['ipa']?.toString() ?? data['phonetic']?.toString());
    final hanViet = data['han_viet']?.toString();
    final meaningVi = data['meaning_vi']?.toString() ?? data['meaning']?.toString() ?? '';
    final wordType = data['word_type']?.toString();
    final level = isChinese
        ? (data['hsk_level']?.toString() ?? data['level']?.toString())
        : data['level']?.toString();
    // notes = breakdown ở đây là annotation từ AI (ví dụ phân tích hán tự)
    final notes = data['breakdown']?.toString() ?? data['notes']?.toString();

    // Collocations
    List<String> collocations = [];
    if (data['collocations'] is List) {
      collocations = (data['collocations'] as List).map((e) => e.toString()).toList();
    }

    // Examples
    List<ExampleSentence> examples = [];
    if (data['examples'] is List) {
      examples = (data['examples'] as List).map((e) {
        if (e is Map<String, dynamic>) return ExampleSentence.fromMap(e);
        return ExampleSentence(text: e.toString(), vi: '');
      }).toList();
    }

    return VocabularyItem(
      languageCode: languageCode.toUpperCase(),
      word: word,
      phonetic: phonetic,
      hanViet: hanViet,
      meaningVi: meaningVi,
      wordType: wordType,
      level: level,
      notes: notes,
      breakdown: data['breakdown']?.toString(),
      collocations: collocations,
      examples: examples,
      isSaved: false,
    );
  }

  /// Xóa markdown code fence nếu model trả về JSON bọc trong ```json ... ```
  String _cleanJsonString(String raw) {
    String clean = raw.trim();
    // Xử lý các prefix: ```json, ```dart, ```
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
