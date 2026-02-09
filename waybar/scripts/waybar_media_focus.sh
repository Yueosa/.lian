#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_media_focus.sh
# Purpose: 将 Hyprland 焦点切换到当前活跃播放器窗口（用于右键 media）。
# Used by: modules/media.jsonc 的 on-click-right
# Calls:
#   - python: scripts/py/waybar_media_focus.py
#     Behavior: 选择 Playing/Paused 的 player，并用 hyprctl focuswindow 聚焦其窗口。
# Python output: 无（不向 Waybar 输出 JSON）。
# Script output: 无 stdout。
# Script exit: 0（缺依赖时直接返回）。
# --------------------------------------------------------------------
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

if ! has playerctl || ! has hyprctl || ! has python3; then
  exit 0
fi

python3 "$HOME/.config/waybar/scripts/py/waybar_media_focus.py"
