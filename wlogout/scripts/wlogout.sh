#!/usr/bin/env bash
# ----------------------------------------------------------------------
# 脚本：wlogout.sh
# 用途：wlogout 各按钮被点击后真正执行的动作分发器。
# 使用位置：wlogout/layout 中各按钮的 "action" 调用。
# 用法：wlogout.sh {lock|logout|shutdown|reboot}
#   lock     -> qs ipc call lock lock
#   logout   -> hyprctl dispatch exit
#   shutdown -> systemctl poweroff
#   reboot   -> systemctl reboot
# ----------------------------------------------------------------------

ACTION="$1"

case "$ACTION" in
    lock)
        qs ipc call lock lock
        ;;
    logout)
        if command -v hyprshutdown >/dev/null 2>&1; then
            hyprshutdown
        else
            hyprctl dispatch exit
        fi
        ;;
    shutdown)
        systemctl poweroff
        ;;
    reboot)
        systemctl reboot
        ;;
    *)
        echo "Usage: $0 {lock|logout|shutdown|reboot}"
        exit 1
        ;;
esac
