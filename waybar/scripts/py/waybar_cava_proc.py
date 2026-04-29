#!/usr/bin/env python3
"""cava 输出处理器：数值频谱 -> 方块字符频谱。

用途：从 stdin 读取 cava 的每一行频谱数据，将其映射为字符条形图并输出到 stdout。

输入：
- stdin：cava 输出（常见为 `0;1;2;...;` 或其它分隔格式）

输出：
- stdout：每行一串字符（用于 Waybar 的 custom/cava 模块）

行为：
- 如果长时间静音，会输出空字符串以“隐藏”该模块（可通过 TIMEOUT 控制）。
- 设置 WAYBAR_CAVA_DEBUG=1 会输出调试信息。

依赖：Python 标准库。
"""

import sys
import time
import os
import re

# 字符映射 (8个等级)
BAR = " ▂▃▄▅▆▇█"

# 记录最后一次有声音的时间
# 初始化为 0，确保启动时如果无声则直接隐藏
last_active = 0.0
TIMEOUT = 8.0  # 8秒延迟消失

DEBUG = os.environ.get("WAYBAR_CAVA_DEBUG", "").strip() not in ("", "0", "false", "False")
MAX_FPS = float(os.environ.get("WAYBAR_CAVA_FPS", "20") or "20")
MIN_INTERVAL = 1.0 / max(MAX_FPS, 1.0)


_INT_RE = re.compile(r"\d+")


def parse_levels(line: str):
    """Return a list of ints if the line looks numeric; otherwise None."""
    if ";" in line:
        parts = [p for p in line.split(";") if p]
        if not parts:
            return None
        try:
            return [int(p) for p in parts]
        except Exception:
            return None

    # Try to extract numbers from any delimiter format.
    nums = _INT_RE.findall(line)
    if not nums:
        return None
    try:
        return [int(n) for n in nums]
    except Exception:
        return None


def main() -> int:
    global last_active

    last_emit = 0.0
    last_text = None

    for line in sys.stdin:
        now = time.time()
        raw = line
        line = line.strip().strip(";")
        if not line:
            continue

        levels = parse_levels(line)

        # If cava is already outputting bar characters, just pass it through.
        if levels is None:
            out = line
            if out and now - last_emit >= MIN_INTERVAL:
                last_active = now
                last_emit = now
                last_text = out
                print(out, flush=True)
            elif DEBUG:
                print("(no data)", flush=True)
            continue

        is_silent = True
        output_chars = []

        try:
            for val in levels:
                if val > 0:
                    is_silent = False

                if val < len(BAR):
                    output_chars.append(BAR[val])
                else:
                    output_chars.append(BAR[-1])
        except Exception:
            if DEBUG:
                print(f"(parse error) {raw!r}", file=sys.stderr, flush=True)
            continue

        if not is_silent:
            out = "".join(output_chars)
            last_active = now
            if now - last_emit >= MIN_INTERVAL:
                last_emit = now
                last_text = out
                print(out, flush=True)
        else:
            if now - last_active < TIMEOUT:
                out = "".join(output_chars)
                if now - last_emit >= MIN_INTERVAL:
                    last_emit = now
                    last_text = out
                    print(out, flush=True)
            else:
                if DEBUG:
                    print("(silent)", flush=True)
                else:
                    if last_text != "" or now - last_emit >= MIN_INTERVAL:
                        last_emit = now
                        last_text = ""
                        print("", flush=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
