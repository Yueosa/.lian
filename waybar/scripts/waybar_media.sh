#!/usr/bin/env bash

# ----------------------------------------------------------------------
# Script: waybar_media.sh
# Purpose: Waybar 自定义媒体/歌词模块入口。
# Used by:
#   - modules/media.jsonc -> custom/media (return-type=json)
# Calls:
#   - python scripts/py/waybar_media.py
#     - Output: 单行 JSON（text/class/alt/tooltip；text 为歌词或曲目信息）
# Output:
#   - stdout: 直接输出 Python 的 JSON
# Exit:
#   - 0：即使缺依赖也返回 JSON（避免 Waybar 判定模块失败）
# ----------------------------------------------------------------------
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

PINK="#F5A9B8"
BLUE="#209CE6"

if ! has playerctl || ! has python3; then
  printf '{"text":"YeaArch-Sakurine","class":"stopped","alt":"stopped","tooltip":"playerctl/python3 not found"}\n'
  exit 0
fi

python3 "$HOME/.config/waybar/scripts/py/waybar_media.py"
