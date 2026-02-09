#!/usr/bin/env bash

# --------------------------------------------------------------------
# 脚本：waybar_bluetooth.sh
# 用途：Waybar 自定义蓝牙模块入口（只负责调用 Python 并透传输出）。
# 使用位置：modules/bluetooth.jsonc -> custom/bluetooth (return-type=json)
# 调用：
#   - python: scripts/py/waybar_bluetooth.py
#     Output: 单行 JSON（至少包含 text/class/tooltip；text 内可含 Pango span）。
# 输出：原样输出 Python 打印的那一行 JSON 到 stdout。
# 退出码：正常情况下退出码跟随 python；Waybar 侧只关心 stdout。
# --------------------------------------------------------------------

set -u

python3 "$HOME/.config/waybar/scripts/py/waybar_bluetooth.py"
