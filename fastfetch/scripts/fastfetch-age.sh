#!/usr/bin/env bash
# ----------------------------------------------------------------------
# 脚本：fastfetch-age.sh
# 用途：计算从系统初装日起到今天的天数，给 fastfetch 当“系统年龄”字段。
# 使用位置：fastfetch/config.jsonc -> modules.command
# 说明：起始日期硬编码为 2025-05-12（我自己的初装日），自行修改即可。
# 输出：stdout 单行，例如 "180 days"
# ----------------------------------------------------------------------

start_date="2025-05-12"
start_ts=$(date -d "$start_date" +%s)
now_ts=$(date +%s)
diff=$(( (now_ts - start_ts) / 86400 ))
echo "${diff} days since 2025-05-12"
