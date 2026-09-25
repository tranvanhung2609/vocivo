# Vocivo Python Companion Tool (AI Vocabulary Extractor)

Công cụ trích xuất và làm giàu từ vựng tự động từ tài liệu (PDF, DOCX, TXT, CSV) sử dụng mô hình **BYOK (Google Gemini / OpenAI)**, kế thừa kiến trúc từ dự án `AIOpenLab`.

## Cài đặt thư viện:
```bash
pip install -r tools/requirements.txt
```

## Cấu hình API Key:
Tạo file `.env` hoặc thiết lập biến môi trường:
```bash
GOOGLE_API_KEY=your_gemini_api_key_here
# hoặc
OPENAI_API_KEY=your_openai_api_key_here
```

## Cách sử dụng:

### 1. Trích xuất từ vựng tiếng Anh từ tệp PDF/Ebook:
```bash
python tools/vocab_extractor.py sample.pdf --lang EN --level B2 --max 20 --output my_vocab.json
```

### 2. Trích xuất từ vựng tiếng Trung (HSK) từ đề thi DOCX:
```bash
python tools/vocab_extractor.py exam.docx --lang ZH --level "HSK 4" --max 15 --output hsk4_words.json
```

### 3. Nạp vào ứng dụng Vocivo:
1. Mở ứng dụng **Vocivo** trên điện thoại hoặc máy tính.
2. Vào màn hình **Sổ từ vựng**.
3. Bấm biểu tượng **AI Import Hub (Ngôi sao ✨)** hoặc menu **Sao lưu & Nhập/Xuất** -> Chọn **AI Import Hub**.
4. Chuyển sang tab **Tệp CSV/JSON** -> Chọn file `.json` vừa tạo.
5. Xem trước danh sách từ, bỏ chọn từ trùng lặp và bấm **"Lưu vào Sổ"**!
