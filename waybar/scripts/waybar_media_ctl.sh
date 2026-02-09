#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_media_ctl.sh
# Purpose: 媒体控制动作（点击/滚轮）——保证“显示哪个 player 就控制哪个”。
# Used by: modules/media.jsonc 的 on-click / on-scroll-* 
# Calls:
#   - playerctl: 默认使用缓存的播放器名
# Cache:
#   - ${XDG_CACHE_HOME:-~/.cache}/waybar/media_player 由 waybar_media.py 写入
# Python output: 无（不调用 Python）。
# Script output: 正常无 stdout；仅在参数错误时输出用法到 stderr。
# Script exit: 0（动作执行失败也吞掉）；参数错误 exit 2。
# --------------------------------------------------------------------
set -euo pipefail

ACTION="${1:-play-pause}"

CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/media_player"
PLAYER=""
if [[ -f "$CACHE_FILE" ]]; then
  PLAYER="$(head -n1 "$CACHE_FILE" 2>/dev/null || true)"
fi

run_playerctl() {
  local cmd=(playerctl)
  if [[ -n "${PLAYER//[[:space:]]/}" ]]; then
    cmd+=( -p "$PLAYER" )
  fi
  cmd+=("$@")
  "${cmd[@]}"
}

case "$ACTION" in
  play-pause)
    run_playerctl play-pause || true
    ;;
  next)
    run_playerctl next || true
    ;;
  previous|prev)
    run_playerctl previous || true
    ;;
  stop)
    run_playerctl stop || true
    ;;
  *)
    echo "Usage: $0 {play-pause|next|previous|stop}" >&2
    exit 2
    ;;
esac
