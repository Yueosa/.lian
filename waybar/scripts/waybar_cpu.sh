#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_cpu.sh
# 用途：Waybar 自定义 CPU 模块入口（CPU 使用率/温度/功耗等）。
# 使用位置：modules/cpu.jsonc -> custom/cpu (return-type=json)
# 调用：
#   - python: scripts/py/waybar_cpu.py
#     Output: 单行 JSON（text/tooltip/class 等，tooltip 内含 Pango markup）。
# 输出：原样输出 Python 打印的 JSON 到 stdout。
# 退出码：0（出错也应尽量返回 JSON；此处 set -e 仅保证脚本自身健壮）。
# --------------------------------------------------------------------
set -euo pipefail

python3 "$HOME/.config/waybar/scripts/py/waybar_cpu.py"
