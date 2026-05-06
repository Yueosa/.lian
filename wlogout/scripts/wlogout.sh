#!/usr/bin/env bash
# ----------------------------------------------------------------------
# 脚本：wlogout.sh
# 用途：wlogout 各按钮被点击后真正执行的动作分发器。
# 使用位置：wlogout/layout 中各按钮的 "action" 调用。
# 用法：wlogout.sh {lock|logout|shutdown|reboot}
#   lock     -> hyprlock
#   logout   -> hyprctl dispatch exit
#   shutdown -> systemctl poweroff
#   reboot   -> systemctl reboot
# ----------------------------------------------------------------------

ACTION="$1"


command_exists() {
    command -v "$1" >/dev/null 2>&1
}


case "$ACTION" in
    lock)
        if command_exists hyprlock; then
            hyprlock
        else
            echo "hyprlock 未安装 😿"
            exit 1
        fi
        ;;
    logout)
        if command_exists hyprshutdown; then
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
