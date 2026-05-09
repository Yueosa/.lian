#!/usr/bin/env python3
import json
import os
import time
from pathlib import Path

_cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
CACHE = _cache_home / "quickshell" / "updates.json"
LEGACY_CACHE = _cache_home / "waybar" / "updates.json"


def humanize_ago(ts: int, now: int) -> str:
    if ts <= 0:
        return "从未"
    delta = max(0, now - ts)
    if delta < 60:
        return f"{delta} 秒前"
    if delta < 3600:
        return f"{delta // 60} 分钟前"
    if delta < 86400:
        return f"{delta // 3600} 小时前"
    return f"{delta // 86400} 天前"


def main() -> int:
    cache_file = CACHE if CACHE.exists() else LEGACY_CACHE
    try:
        data = json.loads(cache_file.read_text(encoding="utf-8"))
    except Exception:
        data = {
            "official": 0,
            "aur": 0,
            "total": 0,
            "updated_at": 0,
            "last_error_at": 0,
            "ok": False,
        }

    official = int(data.get("official", 0))
    aur = int(data.get("aur", 0))
    total = int(data.get("total", official + aur))
    updated_at = int(data.get("updated_at", 0))
    last_error_at = int(data.get("last_error_at", 0))
    ok = bool(data.get("ok", True))
    official_pkgs = data.get("official_packages", [])
    aur_pkgs = data.get("aur_packages", [])

    now = int(time.time())
    payload = {
        "official": official,
        "aur": aur,
        "total": total,
        "updated_at": updated_at,
        "last_error_at": last_error_at,
        "ok": ok,
        "updated_ago": humanize_ago(updated_at, now),
        "error_ago": humanize_ago(last_error_at, now) if last_error_at > 0 else "",
        "official_packages": official_pkgs[:100],
        "aur_packages": aur_pkgs[:100],
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
