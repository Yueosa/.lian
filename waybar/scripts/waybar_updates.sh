#!/usr/bin/env bash
# 仅作为 Waybar 入口；实际逻辑在 py/waybar_updates.py（只读缓存）。
# 缓存由 systemd user timer `lian-updates.timer` 周期更新。
exec python3 "$HOME/.config/waybar/scripts/py/waybar_updates.py"
