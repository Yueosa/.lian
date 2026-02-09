#!/usr/bin/env bash
# 用法: wlogout.sh {lock|logout|shutdown|reboot}


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
