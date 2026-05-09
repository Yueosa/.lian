#!/usr/bin/env python3
import argparse
import base64
import hashlib
import html as html_module
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import unquote


def run_cmd(cmd, input_text=None):
    return subprocess.run(
        cmd,
        input=input_text,
        text=False if isinstance(input_text, (bytes, bytearray)) else True,
        capture_output=True,
        check=False,
    )


# 已知图片魔数（覆盖常见格式 + Qt Image 支持的格式）
def detect_image_kind(data):
    if not data:
        return None
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if data.startswith(b"\xff\xd8\xff"):
        return "jpeg"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "gif"
    if data.startswith(b"RIFF") and len(data) > 12 and data[8:12] == b"WEBP":
        return "webp"
    if data.startswith(b"BM"):
        return "bmp"
    if data.startswith((b"II*\x00", b"MM\x00*")):
        return "tiff"
    if data.startswith(b"\x00\x00\x01\x00"):
        return "ico"
    # AVIF / HEIC: ftyp box at offset 4
    if len(data) >= 12 and data[4:8] == b"ftyp":
        brand = data[8:12]
        if brand in (b"avif", b"avis"):
            return "avif"
        if brand in (b"heic", b"heix", b"hevc", b"hevx", b"mif1"):
            return "heic"
    return None


# cliphist list 行尾标注：`[[ binary data N KiB <type> WxH ]]`
_BINARY_HINT_RE = re.compile(r"\[\[\s*binary data\s+[^\]]*?\b(png|jpe?g|gif|webp|bmp|tiff?|ico|avif|heic|heif)\b[^\]]*\]\]", re.IGNORECASE)

def hint_image_kind(preview_text):
    if not preview_text:
        return None
    m = _BINARY_HINT_RE.search(preview_text)
    if not m:
        return None
    kind = m.group(1).lower()
    if kind == "jpg":
        kind = "jpeg"
    if kind == "tif":
        kind = "tiff"
    if kind == "heif":
        kind = "heic"
    return kind


# 从 HTML 富文本（如 QQ 右键复制图片）中提取本地图片路径
_HTML_IMG_SRC_RE = re.compile(r"""<img\b[^>]*?\bsrc\s*=\s*(?P<q>["'])(?P<src>.*?)(?P=q)""", re.IGNORECASE | re.DOTALL)

def extract_html_image_path(decoded_text):
    if not decoded_text:
        return None
    head = decoded_text.lstrip()[:32].lower()
    if not (head.startswith("<html") or head.startswith("<body") or head.startswith("<img") or head.startswith("<!doctype")):
        return None
    m = _HTML_IMG_SRC_RE.search(decoded_text)
    if not m:
        return None
    src = html_module.unescape(m.group("src")).strip()
    if src.startswith("file://"):
        path = unquote(src[7:])
    elif src.startswith("/"):
        path = unquote(src)
    else:
        return None
    p = Path(path)
    if not p.exists() or not p.is_file():
        return None
    return p


# 把 HTML 剥成纯文本（兜底用，提取不到图片时显示为 text 条目）
_TAG_RE = re.compile(r"<[^>]+>")

def html_to_plain(decoded_text):
    text = _TAG_RE.sub(" ", decoded_text)
    text = html_module.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


# 判断字节是否"看起来像二进制不可显示内容"：
# 用 utf-8 解码失败比例 + NUL 字节占比来判定
def looks_binary(data):
    if not data:
        return False
    if b"\x00" in data[:4096]:
        return True
    sample = data[:4096]
    try:
        sample.decode("utf-8")
        return False
    except UnicodeDecodeError:
        # 非 utf-8 不一定是二进制（可能是 GBK 等），但保守视为可疑
        return True


def decode_entry(decode_input, entry_id):
    if isinstance(decode_input, bytes):
        decode_input = decode_input.decode("utf-8", errors="replace")

    # Some cliphist builds accept the full list line, others prefer just ID.
    for candidate in [decode_input, str(entry_id)]:
        proc = run_cmd(["cliphist", "decode"], input_text=(candidate + "\n").encode("utf-8", errors="replace"))
        if proc.returncode == 0:
            return proc.stdout

    return None



def parse_list_line(line):
    text = line.strip()
    if not text:
        return None

    if text.startswith("│"):
        text = text.lstrip("│").strip()

    m = re.match(r"^(\d+)\s+(.*)$", text)
    if not m:
        return None

    entry_id = m.group(1)
    preview = m.group(2).strip()
    # Keep the normalized line for decode input so QML can replay the same value.
    decode_input = f"{entry_id}\t{preview}" if preview else entry_id
    return entry_id, preview, decode_input


def main():
    parser = argparse.ArgumentParser(description="Dump cliphist entries with text/image metadata")
    parser.add_argument("--limit", type=int, default=30)
    parser.add_argument("--workers", type=int, default=32)
    args = parser.parse_args()

    t0 = time.time()
    list_proc = run_cmd(["cliphist", "list"])
    t1 = time.time()
    if list_proc.returncode != 0:
        print("[]")
        return

    parsed_lines = []
    for line in list_proc.stdout.splitlines():
        parsed = parse_list_line(line)
        if parsed is not None:
            parsed_lines.append(parsed)
    parsed_lines = parsed_lines[: max(1, args.limit)]
    t2 = time.time()

    cache_dir = Path(os.path.expanduser("~/.cache/quickshell/clipboard_thumbs"))
    cache_dir.mkdir(parents=True, exist_ok=True)
    meta_cache_path = cache_dir / "_meta_cache.json"
    try:
        meta_cache = json.loads(meta_cache_path.read_text("utf-8"))
        if not isinstance(meta_cache, dict):
            meta_cache = {}
    except Exception:
        meta_cache = {}

    def build_entry(args_tuple):
        entry_id, preview_text, decode_input = args_tuple
        cached = meta_cache.get(entry_id)
        if cached is not None:
            # 校验 image 缓存路径还在
            if cached.get("kind") == "image":
                thumb_uri = cached.get("thumb", "")
                thumb_fs = thumb_uri[7:] if thumb_uri.startswith("file://") else thumb_uri
                if thumb_fs and Path(thumb_fs).exists():
                    return cached
            else:
                return cached

        decoded = decode_entry(decode_input, entry_id)
        if decoded is None:
            return None

        raw_b64 = base64.b64encode(decode_input.encode("utf-8", errors="replace")).decode("ascii")
        binary_hint = hint_image_kind(preview_text)
        magic_kind = detect_image_kind(decoded)

        # 1) 真二进制图片：cliphist 已标注 binary，或魔数嗅得到
        if binary_hint or magic_kind:
            kind = magic_kind or binary_hint
            digest = hashlib.sha1(decoded).hexdigest()[:20]
            ext = "jpg" if kind == "jpeg" else kind
            thumb_path = cache_dir / f"{digest}.{ext}"
            if not thumb_path.exists():
                try:
                    thumb_path.write_bytes(decoded)
                except Exception:
                    return None
            return {
                "kind": "image",
                "raw_b64": raw_b64,
                "thumb": "file://" + str(thumb_path),
                "label": preview_text[:120],
                "mime": f"image/{kind}",
                # 剪贴板原始 mime 与展示一致：真二进制图片
                "paste_mime": f"image/{kind}",
            }

        # 2) HTML 富文本（典型：QQ 右键"复制图片" → <html><body><img src="file://...">）
        #    cliphist 不会标注 binary，魔数也嗅不到；要从 HTML 里抠出图片路径
        decoded_text = decoded.decode("utf-8", errors="replace")
        html_img = extract_html_image_path(decoded_text)
        if html_img is not None:
            # 直接软链/复制源文件到缓存（避免源被删）
            try:
                src_bytes = html_img.read_bytes()
            except Exception:
                src_bytes = None
            if src_bytes:
                src_kind = detect_image_kind(src_bytes) or html_img.suffix.lstrip(".").lower() or "png"
                if src_kind == "jpg":
                    src_kind = "jpeg"
                ext = "jpg" if src_kind == "jpeg" else src_kind
                digest = hashlib.sha1(src_bytes).hexdigest()[:20]
                thumb_path = cache_dir / f"{digest}.{ext}"
                if not thumb_path.exists():
                    try:
                        thumb_path.write_bytes(src_bytes)
                    except Exception:
                        thumb_path = html_img  # 兜底直接用源路径
                label = f"[图片] {html_img.name}"
                img_uri = "file://" + str(html_img)
                # 用单行 img 片段作为回填 HTML，避免 <html>\r\n<body> 包装在部分应用里触发前导空行
                paste_html = f'<img src="{img_uri}">'
                return {
                    "kind": "image",
                    "raw_b64": raw_b64,
                    "thumb": "file://" + str(thumb_path),
                    "label": label[:120],
                    "mime": f"image/{src_kind}",
                    # 剪贴板原始 mime 是 text/html（QQ 等富文本路径）：
                    # 必须以 text/html 回填，否则 wl-copy 会把 HTML 字节当 PNG 推过去
                    "paste_mime": "text/html",
                    "paste_html": paste_html,
                }
            # 文件存在但读不出 → 仍当未知，避免渲染整坨 HTML
            return {
                "kind": "unknown",
                "raw_b64": raw_b64,
                "preview": f"[无法读取图片] {html_img.name}",
            }

        # 3) 仍嗅不到但内容明显是二进制（NUL 字节 / utf-8 解码失败）→ 标记 unknown，不要乱渲染
        if looks_binary(decoded):
            return {
                "kind": "unknown",
                "raw_b64": raw_b64,
                "preview": preview_text[:120] or f"[二进制 {len(decoded)} 字节]",
            }

        # 4) 真文本
        text = decoded_text.replace("\x00", " ").strip()
        # 如果是 HTML 但没有图（比如纯 HTML 片段），剥成纯文本展示
        head = text.lstrip()[:32].lower()
        if head.startswith("<html") or head.startswith("<body") or head.startswith("<!doctype"):
            text = html_to_plain(text)
        if not text:
            text = preview_text.strip()

        single_line = " ".join(text.splitlines())
        return {
            "kind": "text",
            "raw_b64": raw_b64,
            "text": single_line,
            "full_text": text,
            "preview": single_line[:220],
            "paste_mime": "text/plain",
        }

    workers = max(1, min(args.workers, len(parsed_lines) or 1))
    t3 = time.time()
    new_meta = {}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        entries = list(pool.map(build_entry, parsed_lines))
    t4 = time.time()

    # NDJSON 流式输出：每条一行（逐行输出，QML 可边读边解析）
    t5 = time.time()
    for (entry_id, _, _), entry in zip(parsed_lines, entries):
        if entry is not None:
            print(json.dumps(entry, ensure_ascii=False), file=sys.stdout, flush=True)
            new_meta[entry_id] = entry

    try:
        meta_cache_path.write_text(json.dumps(new_meta, ensure_ascii=False), "utf-8")
    except Exception:
        pass


if __name__ == "__main__":
    main()
