#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_cpu.sh
# Purpose: Waybar 自定义 CPU 模块入口（CPU 使用率/温度/功耗等）。
# Used by: modules/cpu.jsonc -> custom/cpu (return-type=json)
# Calls:
#   - python: scripts/py/waybar_cpu.py
#     Output: 单行 JSON（text/tooltip/class 等，tooltip 内含 Pango markup）。
# Script output: 原样输出 Python 打印的 JSON 到 stdout。
# Script exit: 0（出错也应尽量返回 JSON；此处 set -e 仅保证脚本自身健壮）。
# --------------------------------------------------------------------
set -euo pipefail

python3 "$HOME/.config/waybar/scripts/py/waybar_cpu.py"
