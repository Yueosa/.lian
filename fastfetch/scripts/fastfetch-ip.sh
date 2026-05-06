#!/usr/bin/env bash
# ----------------------------------------------------------------------
# 脚本：fastfetch-ip.sh
# 用途：拿到本机出网用的本地 IP，给 fastfetch 当 IP 字段。
# 使用位置：fastfetch/config.jsonc -> modules.command
# 实现：用 `ip route get 1.1.1.1` 让内核选源 IP；若离线输出 "Offline"。
# 输出：stdout 单行，例如 "192.168.1.7" 或 "Offline"
# ----------------------------------------------------------------------

ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
echo "${ip:-Offline}"
