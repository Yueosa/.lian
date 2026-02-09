#!/usr/bin/env bash

# ----------------------------------------------------------------------
# Script: waybar_clock.sh
# Purpose: Waybar 自定义时钟模块入口（由 Python 生成时间文本）。
# Used by:
#   - modules/clock.jsonc -> custom/clock (return-type=json)
# Calls:
#   - python scripts/py/waybar_clock.py
#     - Output: 单行 JSON，例如 {"text": "2026-02-02 20:14"}
# Output:
#   - stdout: 原样输出 Python 打印的 JSON
# Exit:
#   - 0：一次性执行成功；Waybar 按 interval/signal 重新调用
# Notes:
#   - 模式文件：${XDG_CACHE_HOME:-~/.cache}/waybar_clock_mode
#   - waybar_clock_toggle.sh 会切换模式并触发 signal 刷新
# ----------------------------------------------------------------------

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar_clock_mode"

mode=0
if [ -f "$STATE_FILE" ]; then
  mode=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
fi

case "$mode" in
  1) fmt='+%H:%M:%S' ;;
  2) fmt='+%Y-%m-%d %H:%M:%S' ;;
  *) fmt='+%Y-%m-%d %H:%M' ;;
esac

python3 "$HOME/.config/waybar/scripts/py/waybar_clock.py"
