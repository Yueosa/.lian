#!/bin/bash

# --------------------------------------------------------------------
# Script: waybar_updates.sh
# Purpose: 统计 Arch 官方仓库与 AUR 的可更新数量，并快速返回给 Waybar。
# Used by: modules/updates.jsonc -> custom/updates (return-type=json)
# Calls:
#   - checkupdates（官方仓库）
#   - paru -Qua（AUR）
# Notes:
#   - 使用 timeout + 缓存避免断网/卡住导致 Waybar 杀死模块。
# Output:
#   - stdout: 单行 JSON：{"text":"<total>", "tooltip":"...(Pango markup)..."}
# Script exit: 0。
# --------------------------------------------------------------------

# 目标：脚本必须“快速返回”，否则 Waybar 可能会在断网/卡住时终止它。
# 这里用 timeout + 缓存，保证离线时也能立刻输出，联网后再自然更新。

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
CACHE_FILE="$CACHE_DIR/updates_counts"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

read_cache() {
    if [ -f "$CACHE_FILE" ]; then
        # shellcheck disable=SC2162
        read C_OFFICIAL C_AUR C_TS < "$CACHE_FILE" || true
    fi
    C_OFFICIAL=${C_OFFICIAL:-0}
    C_AUR=${C_AUR:-0}
}

write_cache() {
    printf '%s %s %s\n' "$1" "$2" "$(date +%s)" > "$CACHE_FILE" 2>/dev/null || true
}

read_cache

# Official
if command -v checkupdates >/dev/null 2>&1; then
    # checkupdates 通常不需要网络，但也可能因环境问题卡住；加 timeout 保证快速返回
    OFFICIAL=$(timeout 8s checkupdates 2>/dev/null | wc -l)
else
    OFFICIAL=0
fi

# AUR
if command -v paru >/dev/null 2>&1; then
    # 断网时 paru -Qua 可能长时间阻塞；用 timeout 防止 Waybar 认为脚本“挂死”
    AUR_RAW=$(timeout 8s paru -Qua 2>/dev/null)
    AUR_RC=$?
    if [ "$AUR_RC" -eq 0 ]; then
        AUR=$(printf '%s\n' "$AUR_RAW" | wc -l)
        AUR_STALE=0
    else
        # timeout(124) / 其它错误：用缓存值，避免离线时整块模块消失或不刷新
        AUR=$C_AUR
        AUR_STALE=1
    fi
else
    AUR=0
    AUR_STALE=0
fi

TOTAL=$((OFFICIAL + AUR))

# 只要有成功拿到的值，就刷新缓存（AUR 超时则不覆盖缓存）
if [ "${AUR_STALE:-0}" -eq 0 ]; then
    write_cache "$OFFICIAL" "$AUR"
else
    write_cache "$OFFICIAL" "$C_AUR"
fi

# 注意：JSON 字符串里不能出现“真实换行”，必须输出 \n
if [ "$TOTAL" -gt 0 ]; then
    if [ "${AUR_STALE:-0}" -eq 1 ]; then
        AUR_LABEL="AUR (stale)"
    else
        AUR_LABEL="AUR"
    fi
    printf '{"text":"%s","tooltip":"<span color='\''#F5A9B8'\''>Official</span> <span color='\''#209CE6'\''>%s</span>\\n<span color='\''#F5A9B8'\''>%s</span> <span color='\''#209CE6'\''>%s</span>"}\n' "$TOTAL" "$OFFICIAL" "$AUR_LABEL" "$AUR"
else
    printf '{"text":"","tooltip":""}\n'
fi

