#!/usr/bin/env bash
# qsl 截图 — 仅区域 / 全屏
# 不常驻、不进 qs；Hyprland 直接 exec 本脚本。
#
# 用法：
#   capture.sh shot region [geometry]
#   capture.sh shot full

set -euo pipefail

SHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SHOT_DIR"

ACTION="${1:-}"
SCOPE="${2:-}"
GEOMETRY="${3:-}"

notify_capture() {
    local title="$1"
    local body="${2:-}"
    local icon="${3:-camera-photo}"
    # 通知失败不拖垮截图本身（无 notification daemon / 沙箱里常见）
    notify-send -a "qsl-capture" -i "$icon" "$title" "$body" 2>/dev/null || true
}

shot_region() {
    local path coords
    coords="${1:-}"
    path="$SHOT_DIR/Area_$(date +%Y%m%d_%H%M%S).png"

    if [[ -z "$coords" ]]; then
        coords="$(slurp || true)"
        if [[ -z "$coords" ]]; then
            notify_capture "截图已取消" "未选择截图区域" "camera-photo"
            return 0
        fi
    fi

    grim -g "$coords" "$path"
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$path"
    fi
    notify_capture "区域截图已保存" "路径：$path" "$path"
}

shot_full() {
    local path
    path="$SHOT_DIR/Screenshot_$(date +%Y%m%d_%H%M%S).png"

    grim "$path"
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$path"
    fi
    notify_capture "全屏截图已保存" "路径：$path" "$path"
}

case "$ACTION" in
    shot)
        case "${SCOPE:-region}" in
            region) shot_region "$GEOMETRY" ;;
            full) shot_full ;;
            *)
                echo "usage: $0 shot <region|full> [geometry]" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        cat >&2 <<'EOF'
usage:
  capture.sh shot region [geometry]
  capture.sh shot full
EOF
        exit 1
        ;;
esac
