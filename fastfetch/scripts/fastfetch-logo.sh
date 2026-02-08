#!/usr/bin/env bash
IMG_DIR="$HOME/.config/fastfetch/logo"
find -L ~/.config/fastfetch/logo -type f \
  \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) \
  | shuf -n 1

