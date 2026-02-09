#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_window.sh
# 用途：
#   1. Waybar 自定义窗口标题模块（无参数时）
#   2. 快捷键触发的窗口信息弹窗（带参数时）
# 
# 用法：
#   waybar_window.sh              # Waybar 模块模式（输出 JSON）
#   waybar_window.sh show         # 弹出通知显示窗口信息
#   waybar_window.sh copy-class   # 直接复制 Class 到剪贴板
#
# 使用位置：
#   - modules/window.jsonc -> custom/window (return-type=json)
#   - Hyprland bind: SUPER+X
# --------------------------------------------------------------------

set -u

MODE=${1:-waybar}

if ! command -v hyprctl >/dev/null 2>&1; then
    if [[ "$MODE" == "waybar" ]]; then
        printf '{"text":"","tooltip":"","class":"window"}\n'
    fi
    exit 0
fi

ACTIVE_JSON=$(hyprctl activewindow -j 2>/dev/null || true)
export ACTIVE_JSON MODE

if [[ "$MODE" == "waybar" ]]; then
    # Waybar 模块模式
    python3 "$HOME/.config/waybar/scripts/py/waybar_window.py"
else
    # 弹窗模式（show / copy-class）
    python3 "$HOME/.config/waybar/scripts/py/waybar_window_popup.py"
fi
