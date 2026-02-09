#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_memory.sh
# Purpose: Waybar 自定义内存模块入口（内存/Swap 百分比、进程占用等）。
# Used by: modules/memory.jsonc -> custom/memory (return-type=json)
# Calls:
#   - python: scripts/py/waybar_memory.py
#     Output: 单行 JSON（text/tooltip 等，tooltip 内含 Pango markup）。
# Script output: 原样输出 Python 打印的 JSON 到 stdout。
# Script exit: 0。
# --------------------------------------------------------------------
set -euo pipefail

python3 "$HOME/.config/waybar/scripts/py/waybar_memory.py"
