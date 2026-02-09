#!/usr/bin/env python3
"""Waybar 时钟模块（输出 JSON）。

用途：被 waybar_clock.sh 调用，生成当前时间字符串。

输入：
- 读取状态文件：${XDG_CACHE_HOME:-~/.cache}/waybar_clock_mode
    - 0: %Y-%m-%d %H:%M
    - 1: %H:%M:%S
    - 2: %Y-%m-%d %H:%M:%S

输出：
- stdout 单行 JSON，例如：{"text": "2026-02-09 20:14"}

依赖：Python 标准库。
"""

import json
import os
from datetime import datetime
from pathlib import Path


def main() -> int:
    state_file = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "waybar_clock_mode"

    mode = 0
    try:
        mode = int(state_file.read_text(encoding="utf-8").strip())
    except Exception:
        mode = 0

    if mode == 1:
        fmt = "%H:%M:%S"
    elif mode == 2:
        fmt = "%Y-%m-%d %H:%M:%S"
    else:
        fmt = "%Y-%m-%d %H:%M"

    text = datetime.now().strftime(fmt)
    print(json.dumps({"text": text}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
