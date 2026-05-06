#!/usr/bin/env bash
# --------------------------------------------------------------------
# 脚本：updates_fetch.sh
# 用途：后台采集 Arch 官方仓库 + AUR 可更新数量，写入缓存供 Waybar 读取。
# 调用方：systemd user timer (lian-updates.timer) 或手动
#         systemctl --user start lian-updates.service
# 输出：
#   ${XDG_CACHE_HOME:-$HOME/.cache}/waybar/updates.json
#   {"official":N,"aur":M,"total":N+M,"updated_at":<unix>,"ok":true}
#   失败时保留旧 official/aur，更新 last_error_at + ok=false
# 副作用：写完后向 waybar 发送 RTMIN+8 实时信号触发刷新。
# --------------------------------------------------------------------

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
CACHE_FILE="$CACHE_DIR/updates.json"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

count_lines() { sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]'; }

now=$(date +%s)

# Official
official=""
if command -v checkupdates >/dev/null 2>&1; then
    raw=$(timeout 30s checkupdates 2>/dev/null)
    rc=$?
    # checkupdates: 0=有更新, 2=无更新, 其他=错误
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then
        official=$(printf '%s\n' "$raw" | count_lines)
    fi
elif command -v pacman >/dev/null 2>&1; then
    raw=$(timeout 15s pacman -Qu 2>/dev/null)
    rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
        official=$(printf '%s\n' "$raw" | count_lines)
    fi
fi

# AUR
aur=""
if command -v paru >/dev/null 2>&1; then
    raw=$(timeout 30s paru -Qua 2>/dev/null)
    rc=$?
    # paru -Qua 没有更新时也可能非零，不能据此判断成功；只用 timeout(124) 排除
    if [ "$rc" -ne 124 ]; then
        aur=$(printf '%s\n' "$raw" | count_lines)
    fi
fi

# 读旧缓存（用于失败时保留数字）
prev_official=0
prev_aur=0
prev_updated_at=0
if [ -r "$CACHE_FILE" ] && command -v python3 >/dev/null 2>&1; then
    eval "$(python3 - "$CACHE_FILE" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(f"prev_official={int(d.get('official',0))}")
    print(f"prev_aur={int(d.get('aur',0))}")
    print(f"prev_updated_at={int(d.get('updated_at',0))}")
except Exception:
    pass
PY
)"
fi

ok="true"
if [ -z "$official" ]; then official=$prev_official; ok="false"; fi
if [ -z "$aur" ];      then aur=$prev_aur;          ok="false"; fi

total=$((official + aur))

if [ "$ok" = "true" ]; then
    updated_at=$now
    last_error_at=0
else
    updated_at=$prev_updated_at
    last_error_at=$now
fi

tmp="$CACHE_FILE.tmp.$$"
printf '{"official":%s,"aur":%s,"total":%s,"updated_at":%s,"last_error_at":%s,"ok":%s}\n' \
    "$official" "$aur" "$total" "$updated_at" "$last_error_at" "$ok" > "$tmp"
mv -f "$tmp" "$CACHE_FILE"

# 通知 waybar 立刻刷新（custom/updates 模块 signal=8）
pkill -RTMIN+8 waybar 2>/dev/null || true

exit 0
