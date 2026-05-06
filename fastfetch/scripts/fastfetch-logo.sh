#!/usr/bin/env bash
# ----------------------------------------------------------------------
# 脚本：fastfetch-logo.sh
# 用途：从 ~/.config/fastfetch/logo/ 中随机抽一张图片当 fastfetch 的 logo。
# 使用位置：fastfetch/config.jsonc -> logo.source
# 输出：stdout 一个图片路径（jpg/jpeg/png/webp）
# 注意：仓库里的 fastfetch/logo 是 .gitignore 的，请放自己的图。
# ----------------------------------------------------------------------

find -L "$HOME/.config/fastfetch/logo" -type f \
  \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) \
  | shuf -n 1

