#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_clock_toggle.sh
# 用途：切换时钟显示模式，并通知 Waybar 立即刷新时钟模块。
# 使用位置：modules/clock.jsonc -> custom/clock 的 on-click-right
# 调用：
#   - 写入状态文件: ${XDG_CACHE_HOME:-~/.cache}/waybar_clock_mode
#   - 发送 Waybar 信号: pkill -RTMIN+11 waybar
# Python 输出：无（不调用 Python）。
# 输出：无 stdout 输出。
# 退出码：0（即使 pkill 失败也忽略）。
# --------------------------------------------------------------------

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar_clock_mode"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

mode=0
if [ -f "$STATE_FILE" ]; then
  mode=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
fi

case "$mode" in
  0) next=1 ;;
  1) next=2 ;;
  *) next=0 ;;
esac

echo "$next" > "$STATE_FILE"

# 通知 Waybar：刷新监听 signal 11 的自定义模块
pkill -RTMIN+11 waybar 2>/dev/null || true
