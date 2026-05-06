#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_cava.sh
# 用途：为 Waybar 提供 cava 频谱字符流（长驻自恢复）。
# 使用位置：modules/cava.jsonc -> custom/cava（format: "{}"，非 JSON）
# 调用：
#   - cava: 输出原始数值/分号分隔频谱
#   - python: scripts/py/waybar_cava_proc.py
#     Output: 每次输入一行 cava 数据，输出一行「方块字符频谱」到 stdout。
# 输出：持续向 stdout 输出频谱行（Waybar 会实时显示）。
# 退出码：正常不退出（while true）；Waybar 关闭管道/进程结束即停止。
# --------------------------------------------------------------------

set -u

config_file="$HOME/.config/cava/config_waybar"
proc_py="$HOME/.config/waybar/scripts/py/waybar_cava_proc.py"
gate_py="$HOME/.config/waybar/scripts/py/cava_gate.py"
cava_pid=""
proc_pid=""
gate_pid=""

cleanup() {
    [ -n "${gate_pid:-}" ] && kill "$gate_pid" 2>/dev/null || true
    # 守护可能已把 cava STOP 住，必须先 CONT 否则 kill 不被立即处理
    [ -n "${cava_pid:-}" ] && kill -CONT "$cava_pid" 2>/dev/null || true
    [ -n "${cava_pid:-}" ] && kill "$cava_pid" 2>/dev/null || true
    [ -n "${proc_pid:-}" ] && kill "$proc_pid" 2>/dev/null || true
    wait "$cava_pid" "$proc_pid" "$gate_pid" 2>/dev/null || true
}

trap 'cleanup; exit 0' INT TERM HUP PIPE EXIT

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
        tmp_fifo="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava.$$"
        rm -f "$tmp_fifo" 2>/dev/null || true
        mkfifo "$tmp_fifo" 2>/dev/null || {
            echo ""
            sleep 5
            continue
        }

        if [ -n "${WAYBAR_CAVA_DEBUG:-}" ] && [ "${WAYBAR_CAVA_DEBUG}" != "0" ]; then
            python3 -u "$proc_py" < "$tmp_fifo" &
            proc_pid=$!
            cava -p "$config_file" > "$tmp_fifo" &
            cava_pid=$!
        else
            python3 -u "$proc_py" < "$tmp_fifo" 2>/dev/null &
            proc_pid=$!
            cava -p "$config_file" > "$tmp_fifo" 2>/dev/null &
            cava_pid=$!
        fi

        # 启动门控守护：根据是否有 sink-input 在播放，对 cava 进程 STOP/CONT
        if [ -f "$gate_py" ] && command -v pactl >/dev/null 2>&1; then
            python3 -u "$gate_py" --pid "$cava_pid" 2>/dev/null &
            gate_pid=$!
        fi

        wait "$cava_pid" "$proc_pid" 2>/dev/null || true
        cleanup
        cava_pid=""
        proc_pid=""
        gate_pid=""
        rm -f "$tmp_fifo" 2>/dev/null || true
    else
        echo ""
        sleep 5
    fi
    sleep 1
done
