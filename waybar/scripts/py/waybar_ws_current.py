#!/usr/bin/env python3
"""Waybar 当前工作区指示器（输出 JSON）。

用途：显示当前位于哪个 Hyprland 工作区，用单字符/圈号表示。

数据来源（按优先级）：
- ${XDG_CACHE_HOME:-~/.cache}/waybar/active_workspace.json
  （由 hypr-event-daemon.service 写入；事件驱动，秒级以下延迟）
- 回退到 `hyprctl activeworkspace -j`（首启或守护未运行时）

输出：
- stdout 单行 JSON：
    - text: 工作区符号（❶..⓿ 或数字）
    - class: ws-current ws-<id>
    - tooltip: workspace 信息

依赖：hyprctl。
"""


import json
import os
import subprocess
from pathlib import Path
from typing import Any


CACHE_FILE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "waybar" / "active_workspace.json"


SYMBOL = {
    1: "❶",
    2: "❷",
    3: "❸",
    4: "❹",
    5: "❺",
    6: "❻",
    7: "❼",
    8: "❽",
    9: "❾",
    10: "⓿",
}


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def _safe_int(value: Any) -> int | None:
    try:
        return int(value)
    except Exception:
        return None


def _load_active() -> dict | None:
    try:
        raw = CACHE_FILE.read_text(encoding="utf-8").strip()
        if raw:
            return json.loads(raw)
    except Exception:
        pass
    proc = _run(["hyprctl", "activeworkspace", "-j"])
    if proc.returncode == 0 and proc.stdout.strip():
        try:
            return json.loads(proc.stdout)
        except Exception:
            return None
    return None


def main() -> None:
    # Always print valid JSON so Waybar never marks the module failed.
    data = _load_active()
    ws_id = _safe_int(data.get("id")) if isinstance(data, dict) else None
    ws_name = (
        str(data.get("name")) if isinstance(data, dict) and data.get("name") is not None else None
    )

    if ws_id is None:
        out = {
            "text": "?",
            "class": "ws-current",
            "tooltip": "workspace: unknown",
        }
        print(json.dumps(out, ensure_ascii=False))
        return

    symbol = SYMBOL.get(ws_id, str(ws_id))
    tooltip = f"workspace {ws_id}"
    if ws_name and ws_name != str(ws_id):
        tooltip = f"workspace {ws_id} ({ws_name})"

    out = {
        "text": symbol,
        "class": f"ws-current ws-{ws_id}",
        "tooltip": tooltip,
    }
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
