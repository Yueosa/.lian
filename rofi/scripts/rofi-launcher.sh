#!/usr/bin/env bash
# ----------------------------------------------------------------------
# 脚本：rofi-launcher.sh
# 用途：rofi 启动器统一入口，支持子模式（drun / window / run …）。
# 使用位置：~/.local/bin/rofi/rofi-launcher 软链 → 此脚本
#         Hyprland 快捷键 SUPER+A (drun) / ALT+TAB (window)
# 用法：rofi-launcher [drun|window|run|...]
# 主题：~/.config/rofi/sakurine.rasi（变性骄傲配色）
# 依赖：rofi-wayland
# ----------------------------------------------------------------------

## Sakurine's Rofi Launcher - Unified Launcher
## Theme: Sakurine (Transgender Pride)

MODE=${1:-drun}

case "$MODE" in
    drun|app|application)
        rofi -show drun -theme ~/.config/rofi/sakurine.rasi
        ;;
    window|win)
        rofi -show window -theme ~/.config/rofi/sakurine.rasi
        ;;
    *)
        echo "Usage: $0 {drun|window}"
        echo "  drun   - Application launcher"
        echo "  window - Window switcher"
        exit 1
        ;;
esac
