#!/usr/bin/env python3
"""Waybar GPU 模块（NVIDIA）。

用途：读取 nvidia-smi 的 GPU 温度/功耗/显存占用，并输出给 Waybar。

输出：
- stdout 单行 JSON：{"text": "xx%", "tooltip": "..."}
    - text 优先显示显存占用百分比；拿不到则显示温度。
    - tooltip 为多行 Pango 文本。

依赖：
- nvidia-smi（通常来自 nvidia-utils）。
- Python 标准库。
"""

import json
import re
import shutil
import subprocess

PINK = "#F5A9B8"
BLUE = "#209CE6"


def span(color: str, text: str) -> str:
    return f"<span color='{color}'>{text}</span>"


def field(label: str, value: str) -> str:
    return f"{span(PINK, label)} {span(BLUE, value)}"


def fnum(s: str):
    s = (s or "").strip()
    if not s or s.upper() == "N/A":
        return None
    s = re.sub(r"[^0-9.+-]", "", s)
    try:
        return float(s)
    except Exception:
        return None


def main() -> int:
    if not shutil.which("nvidia-smi"):
        print(json.dumps({"text": "N/A", "tooltip": "nvidia-smi not found"}, ensure_ascii=False))
        return 0

    try:
        line = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=name,power.draw,temperature.gpu,memory.used,memory.total",
                "--format=csv,noheader,nounits",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        ).splitlines()[0].strip()
    except Exception:
        line = ""

    if not line:
        print(json.dumps({"text": "ERR", "tooltip": "nvidia-smi returned empty output"}, ensure_ascii=False))
        return 0

    parts = [p.strip() for p in line.split(",")]
    name = parts[0] if len(parts) >= 1 else "Unknown"
    power = fnum(parts[1]) if len(parts) >= 2 else None
    temp = fnum(parts[2]) if len(parts) >= 3 else None
    mem_used = fnum(parts[3]) if len(parts) >= 4 else None
    mem_total = fnum(parts[4]) if len(parts) >= 5 else None

    text = "GPU"
    if mem_used is not None and mem_total and mem_total > 0:
        text = f"{(mem_used / mem_total * 100):.0f}%"
    elif temp is not None:
        text = f"{temp:.0f}°C"

    lines = [field("显卡:", name)]
    if temp is not None:
        lines.append(field("温度:", f"{temp:.0f}°C"))
    if power is not None:
        lines.append(field("功耗:", f"{power:.1f} W"))

    tooltip = "\n".join(lines)
    print(json.dumps({"text": text, "tooltip": tooltip}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
