#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_media_fast.sh
# 用途：高频刷新包装器：循环运行既有的 media 脚本并连续输出 JSON 行。
# 使用位置：可选（用于想要更顺滑的 media 刷新时）；本仓库当前 custom/media 仍走 waybar_media.sh。
# 调用：
#   - TARGET: 默认 ~/.local/bin/sh/waybar/waybar_media.sh（需可执行）
#     Output: 单行 JSON
# Python 输出：取决于 TARGET（此脚本本身不直接调用 Python）。
# 输出：持续输出 JSON 行到 stdout（Waybar 读取到哪行就显示哪行）。
# 退出码：正常不退出；Waybar 关闭管道（PIPE）时自动 exit 0。
# --------------------------------------------------------------------
set -u

# Waybar custom/media 的“高频刷新包装器”。
# 它会不断重复运行既有的一次性脚本，并持续输出 JSON 行。
# 输出格式完全一致，只是刷新频率更高。

TARGET="$HOME/.local/bin/sh/waybar/waybar_media.sh"
SLEEP_S="${WAYBAR_MEDIA_FAST_SLEEP:-0.2}"

# Waybar 关闭管道（PIPE）时静默退出。
trap 'exit 0' PIPE

last_good=""

fallback_json() {
  printf '%s\n' '{"text":"YeaArch-Sakurine","class":"stopped","alt":"stopped","tooltip":"media script missing"}' 2>/dev/null || exit 0
}

while true; do
  if [[ -x "$TARGET" ]]; then
    # Ensure each iteration prints exactly one JSON line.
    out="$("$TARGET" 2>/dev/null || true)"
    out="${out%%$'\n'*}"

    # If script prints nothing (or explicit empty text), keep showing last value.
    if [[ -z "${out//[[:space:]]/}" ]] || printf '%s' "$out" | /usr/bin/grep -qE '"text"[[:space:]]*:[[:space:]]*""'; then
      if [[ -n "$last_good" ]]; then
        printf '%s\n' "$last_good" 2>/dev/null || exit 0
      else
        fallback_json
      fi
    else
      printf '%s\n' "$out" 2>/dev/null || exit 0
      last_good="$out"
    fi
  else
    if [[ -n "$last_good" ]]; then
      printf '%s\n' "$last_good" 2>/dev/null || exit 0
    else
      fallback_json
    fi
  fi
  # Use sleep; if it fails (e.g. interrupted), just exit.
  sleep "$SLEEP_S" || exit 0
done
