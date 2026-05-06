#!/usr/bin/env python3
"""Waybar 更新数量模块（仅读缓存）。

数据由 systemd user timer `lian-updates.timer` 调用 `updates_fetch.sh` 产出：
    ${XDG_CACHE_HOME:-~/.cache}/waybar/updates.json

本脚本只做：读 JSON → 算"X 分钟前" → 输出 Waybar JSON。
0 网络调用，毫秒级返回。
"""

import json
import os
import time
from pathlib import Path

PINK = "#F5A9B8"
BLUE = "#209CE6"

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "waybar" / "updates.json"


def span(color: str, text: str) -> str:
    return f"<span color='{color}'>{text}</span>"


def field(label: str, value: str) -> str:
    return f"{span(PINK, label)} {span(BLUE, value)}"


def humanize_ago(ts: int, now: int) -> str:
    if ts <= 0:
        return "从未"
    d = max(0, now - ts)
    if d < 60:
        return f"{d} 秒前"
    if d < 3600:
        return f"{d // 60} 分钟前"
    if d < 86400:
        return f"{d // 3600} 小时前"
    return f"{d // 86400} 天前"


def main() -> int:
    try:
        data = json.loads(CACHE.read_text(encoding="utf-8"))
    except FileNotFoundError:
        # timer 还没跑过：显示等待状态而不是 0
        print(json.dumps({"text": "…", "tooltip": "等待首次采集…\n手动: systemctl --user start lian-updates.service"}, ensure_ascii=False))
        return 0
    except Exception as e:
        print(json.dumps({"text": "?", "tooltip": f"缓存损坏: {e}"}, ensure_ascii=False))
        return 0

    official = int(data.get("official", 0))
    aur = int(data.get("aur", 0))
    total = int(data.get("total", official + aur))
    updated_at = int(data.get("updated_at", 0))
    last_error_at = int(data.get("last_error_at", 0))
    ok = bool(data.get("ok", True))

    now = int(time.time())

    if total <= 0:
        # 没有更新：保持空 text（与原行为一致），但 tooltip 仍可显示状态便于排查
        text = ""
    else:
        text = str(total)

    tip_lines = [
        field("Official:", str(official)),
        field("AUR:", str(aur)),
        field("更新于:", humanize_ago(updated_at, now)),
    ]
    if not ok and last_error_at > 0:
        tip_lines.append(field("上次失败:", humanize_ago(last_error_at, now)))

    print(json.dumps({"text": text, "tooltip": "\n".join(tip_lines)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
