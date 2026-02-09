#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_memory.sh
# 用途：Waybar 自定义内存模块入口（内存/Swap 百分比、进程占用等）。
# 使用位置：modules/memory.jsonc -> custom/memory (return-type=json)
# 调用：
#   - python: scripts/py/waybar_memory.py
#     Output: 单行 JSON（text/tooltip 等，tooltip 内含 Pango markup）。
# 输出：原样输出 Python 打印的 JSON 到 stdout。
# 退出码：0。
# --------------------------------------------------------------------
set -euo pipefail

python3 "$HOME/.config/waybar/scripts/py/waybar_memory.py"
