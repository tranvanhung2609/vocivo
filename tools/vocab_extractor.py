"""
Vocivo - AI Vocabulary Extractor (Python Companion Tool)
Inspired by AIOpenLab architecture.

This script extracts and enriches vocabulary from PDF, DOCX, TXT, CSV, or markdown files
using Google Gemini or OpenAI API (Bring-Your-Own-Key).
The output file is 100% compatible with Vocivo's Import Hub format.

Usage:
    python tools/vocab_extractor.py <file_path> [--lang EN|ZH] [--level A1-C2|HSK1-6] [--max 20] [--output vocab.json]
"""

import os
import sys
import json
import argparse
import re
from datetime import datetime
from typing import List, Dict, Any, Optional

# Configure standard output encoding for Windows terminals
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

# Optional document loaders
try:
    from pypdf import PdfReader
    HAS_PYPDF = True
except ImportError:
    HAS_PYPDF = False

try:
    import docx2txt
    HAS_DOCX = True
except ImportError:
    HAS_DOCX = False

# Optional dotenv loader
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    # Basic fallback to read .env file manually if dotenv is not installed
    if os.path.exists('.env'):
        with open('.env', 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def remove_non_utf8_characters(text: str) -> str:
    """Remove non-UTF-8 characters to ensure text integrity (from AIOpenLab)."""
    return text.encode('utf-8', 'ignore').decode('utf-8')


def clean_text_advanced(text: str) -> str:
    """Advanced text cleaning, removing unnecessary patterns and fixing formatting (from AIOpenLab)."""
    text = remove_non_utf8_characters(text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def load_file_content(file_path: str) -> str:
    """Load text content from PDF, DOCX, TXT, CSV, or other text file."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")

    ext = os.path.splitext(file_path)[1].lower()

    if ext == '.pdf':
        if not HAS_PYPDF:
            raise ImportError("Vui long cai dat pypdf: pip install pypdf")
        reader = PdfReader(file_path)
        pages_text = [page.extract_text() or '' for page in reader.pages]
        combined = " ".join(pages_text)
        return clean_text_advanced(combined)

    elif ext in ['.docx', '.doc']:
        if not HAS_DOCX:
            raise ImportError("Vui long cai dat docx2txt: pip install docx2txt")
        text = docx2txt.process(file_path)
        return clean_text_advanced(text)

    else:
        # Fallback text reader
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            return clean_text_advanced(f.read())


def _clean_json_markdown(raw_text: str) -> str:
    """Strip markdown code fence blocks if returned by LLM."""
    clean = raw_text.strip()
    if clean.startswith('```json'):
        clean = clean[7:]
    elif clean.startswith('```'):
        clean = clean[3:]
    if clean.endswith('```'):
        clean = clean[:-3]
    return clean.strip()


def extract_with_gemini(text: str, api_key: str, language: str = 'EN', target_level: Optional[str] = None, max_words: int = 15) -> List[Dict[str, Any]]:
    """Extract vocabulary using Google Gemini API with automatic model fallback."""
    import urllib.request
    import urllib.error

    is_chinese = language.upper() == 'ZH'
    configured_model = os.getenv("GEMINI_MODEL", "gemini-3.1-flash-lite")
    candidate_models = [
        configured_model,
        "gemini-3.1-flash-lite",
        "gemini-3.5-flash",
        "gemini-3.8-flash",
        "gemini-flash-latest",
    ]
    # Remove duplicates while preserving order
    models_to_try = list(dict.fromkeys(candidate_models))

    if is_chinese:
        prompt = f"""
Bạn là chuyên gia ngôn ngữ học Trung - Việt. Hãy đọc văn bản sau và trích xuất tối đa {max_words} từ/cụm từ tiếng Trung trọng tâm nhất{f' (ưu tiên cấp độ {target_level})' if target_level else ''}.

Văn bản:
\"\"\"
{text[:8000]}
\"\"\"

Trả về kết quả duy nhất ở định dạng JSON với key "items":
{{
  "items": [
    {{
      "word": "学习",
      "language_code": "ZH",
      "phonetic": "xuéxí",
      "han_viet": "Học tập",
      "meaning_vi": "Học tập, học hỏi",
      "level": "HSK 1",
      "breakdown": "学 (Học) + 习 (Tập)",
      "notes": "学 (Học) + 习 (Tập)",
      "examples": [
        {{
          "zh": "我们每天都要学习汉语。",
          "pinyin": "Wǒmen měitiān dōu yào xuéxí hànyǔ.",
          "vi": "Chúng tôi ngày nào cũng phải học tiếng Trung."
        }}
      ]
    }}
  ]
}}
"""
    else:
        prompt = f"""
Bạn là chuyên gia ngôn ngữ học Anh - Việt. Hãy đọc văn bản sau và trích xuất tối đa {max_words} từ/cụm từ tiếng Anh trọng tâm nhất{f' (ưu tiên cấp độ {target_level})' if target_level else ''}.

Văn bản:
\"\"\"
{text[:8000]}
\"\"\"

Trả về kết quả duy nhất ở định dạng JSON với key "items":
{{
  "items": [
    {{
      "word": "resilient",
      "language_code": "EN",
      "phonetic": "/rɪˈzɪl.jənt/",
      "meaning_vi": "Kiên cường, mau phục hồi",
      "word_type": "adjective",
      "level": "B2",
      "notes": "Gốc từ Latin: re (lại) + salire (bật nảy)",
      "collocations": ["resilient economy", "highly resilient"],
      "examples": [
        {{
          "en": "Children are often remarkably resilient.",
          "vi": "Trẻ em thường có khả năng thích ứng và hồi phục đáng kinh ngạc."
        }}
      ]
    }}
  ]
}}
"""

    last_error = None
    for model in models_to_try:
        print(f"    -> Đang thử mô hình: {model}...")
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json"
            }
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )

        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                res_data = json.loads(resp.read().decode('utf-8'))
                candidates = res_data.get('candidates', [])
                if not candidates:
                    continue
                raw_text = candidates[0]['content']['parts'][0]['text']
                clean_text = _clean_json_markdown(raw_text)
                parsed = json.loads(clean_text)
                return parsed.get("items", parsed if isinstance(parsed, list) else [])
        except urllib.error.HTTPError as e:
            last_error = e.read().decode('utf-8', errors='ignore')
            if e.code in [400, 404, 429, 503]:
                # Try next model in fallback chain
                continue
            raise RuntimeError(f"Lỗi gọi Gemini API (HTTP {e.code}): {last_error}")
        except Exception as e:
            last_error = str(e)
            continue

    raise RuntimeError(f"Không thể kết nối đến các model Gemini. Chi tiết: {last_error}")


def extract_with_openai(text: str, api_key: str, language: str = 'EN', target_level: Optional[str] = None, max_words: int = 15) -> List[Dict[str, Any]]:
    """Extract vocabulary using OpenAI API."""
    import urllib.request
    import urllib.error

    is_chinese = language.upper() == 'ZH'
    prompt = f"Trích xuất {max_words} từ vựng tiếng {'Trung' if is_chinese else 'Anh'} kèm phiên âm, nghĩa tiếng Việt, cấp độ và ví dụ:\n\n{text[:8000]}"

    url = "https://api.openai.com/v1/chat/completions"
    payload = {
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": "Bạn là chuyên gia từ điển. Trả về JSON với key 'items' chứa danh sách từ vựng chuẩn cấu trúc Vocivo."},
            {"role": "user", "content": prompt}
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.2
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode('utf-8'),
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_key}'
        }
    )

    try:
        with urllib.request.urlopen(req) as resp:
            res_data = json.loads(resp.read().decode('utf-8'))
            raw_text = res_data['choices'][0]['message']['content']
            clean_text = _clean_json_markdown(raw_text)
            parsed = json.loads(clean_text)
            return parsed.get("items", parsed if isinstance(parsed, list) else [])
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode('utf-8', errors='ignore')
        raise RuntimeError(f"Lỗi gọi OpenAI API (HTTP {e.code}): {err_msg}")


def main():
    parser = argparse.ArgumentParser(description="Vocivo AI Vocabulary Extractor (BYOK)")
    parser.add_argument("file", help="Path to input document (PDF, DOCX, TXT, CSV, etc.)")
    parser.add_argument("--lang", default="EN", choices=["EN", "ZH"], help="Target language (EN or ZH)")
    parser.add_argument("--level", default=None, help="Target level (e.g. B2, C1, HSK 4)")
    parser.add_argument("--max", type=int, default=15, help="Maximum number of words to extract")
    parser.add_argument("--output", default=None, help="Output JSON file path")
    parser.add_argument("--provider", default="gemini", choices=["gemini", "openai"], help="AI Provider")

    args = parser.parse_args()

    print(f"[1/3] Đang đọc nội dung từ file: {args.file}...")
    try:
        content = load_file_content(args.file)
    except Exception as e:
        print(f"[!] Lỗi khi đọc file: {e}")
        sys.exit(1)

    print(f"[2/3] Đã đọc thành công {len(content)} ký tự.")

    gemini_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    openai_key = os.getenv("OPENAI_API_KEY")

    try:
        if args.provider == "gemini":
            if not gemini_key:
                print("[!] Lỗi: Chưa có GOOGLE_API_KEY trong file .env hoặc biến môi trường.")
                print("    Bạn có thể lấy key miễn phí tại https://aistudio.google.com")
                sys.exit(1)
            print(f"[3/3] Đang gọi Google Gemini ({args.lang}) để phân tích từ vựng...")
            items = extract_with_gemini(content, gemini_key, args.lang, args.level, args.max)
        else:
            if not openai_key:
                print("[!] Lỗi: Chưa có OPENAI_API_KEY trong file .env hoặc biến môi trường.")
                sys.exit(1)
            print(f"[3/3] Đang gọi OpenAI ({args.lang}) để phân tích từ vựng...")
            items = extract_with_openai(content, openai_key, args.lang, args.level, args.max)
    except Exception as e:
        print(f"[!] Lỗi khi gọi AI: {e}")
        sys.exit(1)

    output_path = args.output
    if not output_path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"vocivo_export_{args.lang}_{timestamp}.json"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Đã trích xuất thành công {len(items)} từ vựng và lưu tại: {output_path}")
    print("👉 Mở ứng dụng Vocivo -> Sổ từ vựng -> AI Import Hub -> Chọn file này để duyệt và nạp vào sổ!")


if __name__ == "__main__":
    main()
