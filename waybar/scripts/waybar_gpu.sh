#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_gpu.sh
# 用途：Waybar 自定义 GPU 信息模块入口（基于 nvidia-smi）。
# 使用位置：modules/gpu.jsonc -> custom/gpuinfo (return-type=json)
# 调用：
#   - python: scripts/py/waybar_gpu.py
#     Output: 单行 JSON：{"text": "..", "tooltip": "..(Pango markup).."}
# 输出：原样输出 Python 打印的 JSON 到 stdout。
# 退出码：0。
# --------------------------------------------------------------------
set -euo pipefail

python3 "$HOME/.config/waybar/scripts/py/waybar_gpu.py"
