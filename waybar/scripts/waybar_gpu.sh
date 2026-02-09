#!/usr/bin/env bash

# --------------------------------------------------------------------
# Script: waybar_gpu.sh
# Purpose: Waybar 自定义 GPU 信息模块入口（基于 nvidia-smi）。
# Used by: modules/gpu.jsonc -> custom/gpuinfo (return-type=json)
# Calls:
#   - python: scripts/py/waybar_gpu.py
#     Output: 单行 JSON：{"text": "..", "tooltip": "..(Pango markup).."}
# Script output: 原样输出 Python 打印的 JSON 到 stdout。
# Script exit: 0。
# --------------------------------------------------------------------
set -euo pipefail

python3 "$HOME/.config/waybar/scripts/py/waybar_gpu.py"
