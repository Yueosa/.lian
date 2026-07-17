#!/usr/bin/env python3
# lianwall_space.py — space --json + 缩略图路径
# 优先：~/.cache/Lian/LianWall/thumbnails/{md5}_*.jpg
# 图片无缓存：thumb=原路径 + thumb_orig=true（UI 强制小 sourceSize）
# 视频无缓存：thumb=""（占位，不解码视频）

import hashlib
import json
import os
import subprocess
import sys

VIDEO_EXT = {
    ".mp4", ".mkv", ".webm", ".avi", ".mov", ".flv",
    ".wmv", ".m4v", ".3gp", ".ogv", ".ts", ".m2ts",
}


def is_video(path: str) -> bool:
    return os.path.splitext(path)[1].lower() in VIDEO_EXT


def find_thumb(thumb_dir: str, path: str) -> str:
    if not path or not os.path.isdir(thumb_dir):
        return ""
    digest = hashlib.md5(path.encode("utf-8")).hexdigest()
    # 精确常见尺寸，再扫同 hash 前缀
    for suf in ("_720x720.jpg", "_320x320.jpg", "_720p.jpg", "_180p.jpg"):
        cand = os.path.join(thumb_dir, digest + suf)
        if os.path.isfile(cand):
            return cand
    try:
        for name in os.listdir(thumb_dir):
            if name.startswith(digest) and name.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                return os.path.join(thumb_dir, name)
    except OSError:
        pass
    return ""


def main() -> int:
    home = os.environ.get("HOME", "")
    thumb_dir = os.path.join(home, ".cache", "Lian", "LianWall", "thumbnails")
    try:
        raw = subprocess.check_output(["lianwall", "space", "--json"], text=True)
        data = json.loads(raw)
    except Exception as e:
        print(json.dumps({"error": str(e), "items": []}), flush=True)
        return 1

    items = data.get("items") if isinstance(data, dict) else data
    if not isinstance(items, list):
        items = []

    out_items = []
    for it in items:
        if not isinstance(it, dict):
            continue
        path = str(it.get("path") or "")
        thumb = find_thumb(thumb_dir, path)
        thumb_orig = False
        if not thumb and path and not is_video(path) and os.path.isfile(path):
            # 仅静态图允许回退原图（由 UI sourceSize 限制解码）
            thumb = path
            thumb_orig = True
        row = dict(it)
        row["thumb"] = thumb
        row["thumb_orig"] = thumb_orig
        row["is_video"] = is_video(path)
        out_items.append(row)

    out_items.sort(key=lambda r: (0 if r.get("is_current") else 1, int(r.get("index") or 0)))

    payload = {
        "mode": data.get("mode", "") if isinstance(data, dict) else "",
        "items": out_items,
        "count": len(out_items),
    }
    print(json.dumps(payload, ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
