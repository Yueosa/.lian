#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_open_nmtui.sh
# 用途：在可用的终端里打开 nmtui（通常用于 network 模块右键）。
# 使用位置：modules/network.jsonc 的 on-click-right
# 调用：
#   - 选择一个终端（优先 $TERMINAL），然后 exec <terminal> -e nmtui
# Python 输出：无。
# 输出：无 stdout（exec 后由终端接管）。
# 退出码：找不到终端则 exit 0；否则被 exec 替换为终端进程。
# --------------------------------------------------------------------
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

term=""

# 尊重用户指定的默认终端（如果存在）。
if [[ -n "${TERMINAL:-}" ]] && has "$TERMINAL"; then
  term="$TERMINAL"
fi

# 兜底候选（优先 Wayland 友好的终端）
if [[ -z "$term" ]]; then
  for t in foot kitty alacritty wezterm konsole gnome-terminal xterm; do
    if has "$t"; then
      term="$t"
      break
    fi
  done
fi

[[ -z "$term" ]] && exit 0

case "$term" in
  foot)
    exec foot -e nmtui
    ;;
  wezterm)
    exec wezterm start -- nmtui
    ;;
  gnome-terminal)
    exec gnome-terminal -- nmtui
    ;;
  konsole)
    exec konsole -e nmtui
    ;;
  *)
    exec "$term" -e nmtui
    ;;
esac
