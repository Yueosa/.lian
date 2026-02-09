#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_workspaces_scroll.sh
# Purpose: 为 hyprland/workspaces 提供“滚轮切工作区”的动作脚本。
# Used by: modules/workspaces.jsonc 的 on-scroll-up / on-scroll-down
# Calls:
#   - hyprctl activeworkspace -j / workspaces -j：获取工作区列表
#   - python: scripts/py/waybar_workspaces_scroll.py
#     Behavior: 选择下一个/上一个“已有窗口或当前”的 workspace，并 dispatch 切换。
#               或者切换到数值最小的空工作区 (DIR=empty)。
# Python output: 无（只做 hyprctl dispatch）。
# Script output: 无 stdout。
# Script exit: 0。
# --------------------------------------------------------------------
# Scroll through existing Hyprland workspaces (windows>0 plus current active).
# Usage: waybar_workspaces_scroll.sh [up|down|empty]
#   up/down: 切换到上/下一个有窗口的工作区
#   empty:   切换到数值最小的空工作区

DIR=${1:-up}

command -v hyprctl >/dev/null 2>&1 || exit 0

ACTIVE_JSON=$(hyprctl activeworkspace -j 2>/dev/null || true)
WS_JSON=$(hyprctl workspaces -j 2>/dev/null || true)

[ -n "$ACTIVE_JSON" ] && [ -n "$WS_JSON" ] || exit 0

export DIR ACTIVE_JSON WS_JSON

python3 "$HOME/.config/waybar/scripts/py/waybar_workspaces_scroll.py"
