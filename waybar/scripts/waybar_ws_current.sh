#!/usr/bin/env bash

# ----------------------------------------------------------------------
# Script: waybar_ws_current.sh
# Purpose: Waybar 当前工作区“单字符”指示器入口。
# Used by:
#   - modules/ws_current.jsonc -> custom/ws_current (return-type=json)
# Calls:
#   - python scripts/py/waybar_ws_current.py
# Output:
#   - stdout: 单行 JSON（text/class/tooltip）
# Exit:
#   - 0：始终输出 JSON，避免 Waybar 判定模块失败
# ----------------------------------------------------------------------

set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf '{"text":"?","class":"ws-current","tooltip":"python3 not found"}\n'
  exit 0
fi

python3 "$HOME/.config/waybar/scripts/py/waybar_ws_current.py" || \
  printf '{"text":"?","class":"ws-current","tooltip":"ws_current failed"}\n'
