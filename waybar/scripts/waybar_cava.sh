#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_cava.sh
# Purpose: 为 Waybar 提供 cava 频谱字符流（长驻自恢复）。
# Used by: modules/cava.jsonc -> custom/cava（format: "{}"，非 JSON）
# Calls:
#   - cava: 输出原始数值/分号分隔频谱
#   - python: scripts/py/waybar_cava_proc.py
#     Output: 每次输入一行 cava 数据，输出一行「方块字符频谱」到 stdout。
# Script output: 持续向 stdout 输出频谱行（Waybar 会实时显示）。
# Script exit: 正常不退出（while true）；Waybar 关闭管道/进程结束即停止。
# --------------------------------------------------------------------

set -u

config_file="$HOME/.config/cava/config_waybar"
proc_py="$HOME/.config/waybar/scripts/py/waybar_cava_proc.py"

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

# Waybar 启动时环境变量有时不完整；如果能找到 Pulse socket，就显式指向它。
if [ -z "${PULSE_SERVER:-}" ]; then
    uid="$(id -u)"
    pulse_sock="/run/user/${uid}/pulse/native"
    if [ -S "$pulse_sock" ]; then
        export PULSE_SERVER="unix:${pulse_sock}"
    fi
fi

# 配置文件缺失时不要直接退出，避免模块“死掉”；持续输出空行等待用户修复。
if [ ! -f "$config_file" ]; then
    while true; do
        echo ""
        sleep 5
    done
fi

# cava 偶发连不上音频服务会直接退出；这里做自恢复，避免 Waybar 模块永久停止。
while true; do
    if command -v cava >/dev/null 2>&1; then
        if [ -n "${WAYBAR_CAVA_DEBUG:-}" ] && [ "${WAYBAR_CAVA_DEBUG}" != "0" ]; then
            cava -p "$config_file" | python3 -u "$proc_py" || true
        else
            cava -p "$config_file" 2>/dev/null | python3 -u "$proc_py" 2>/dev/null || true
        fi
    else
        echo ""
        sleep 5
    fi
    sleep 1
done
