#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_bluetooth.sh
# Purpose: Waybar 自定义蓝牙模块入口（只负责调用 Python 并透传输出）。
# Used by: modules/bluetooth.jsonc -> custom/bluetooth (return-type=json)
# Calls:
#   - python: scripts/py/waybar_bluetooth.py
#     Output: 单行 JSON（至少包含 text/class/tooltip；text 内可含 Pango span）。
# Script output: 原样输出 Python 打印的那一行 JSON 到 stdout。
# Script exit: 正常情况下退出码跟随 python；Waybar 侧只关心 stdout。
# --------------------------------------------------------------------

set -u

python3 "$HOME/.config/waybar/scripts/py/waybar_bluetooth.py"
