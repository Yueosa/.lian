#!/usr/bin/env bash
# qsl 截图 — 仅区域 / 全屏
# 不常驻、不进 qs；Hyprland 直接 exec 本脚本。
#
# 用法：
#   capture.sh shot region [geometry]
#   capture.sh shot full
#
# 注意：wl-copy / grim 偶发会用到 /tmp。/tmp 是 tmpfs，被撑满时
# wl-copy 会失败；旧脚本在 set -e 下会因此跳过通知，表现为
# 「没通知 + 剪贴板不更新」。剪贴板失败绝不能拖垮保存与通知。

set -euo pipefail

SHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SHOT_DIR"

# 把临时文件赶到 home 侧，躲开 /tmp 配额（Cursor sandbox cache 常驻几 GB）
CACHE_TMP="${XDG_CACHE_HOME:-$HOME/.cache}/qsl/tmp"
mkdir -p "$CACHE_TMP"
export TMPDIR="$CACHE_TMP"

ACTION="${1:-}"
SCOPE="${2:-}"
GEOMETRY="${3:-}"

notify_capture() {
    local title="$1"
    local body="${2:-}"
    # 不要用截图路径当 -i：大 PNG 当图标会拖慢 / 被部分通知服务拒收
    notify-send -a "qsl-capture" -i camera-photo "$title" "$body" 2>/dev/null || true
}

copy_image() {
    local path="$1"
    if ! command -v wl-copy >/dev/null 2>&1; then
        return 1
    fi
    # 必须声明 MIME，否则 cliphist / 部分粘贴端当文本处理
    # 失败返回非零，由调用方决定文案；绝不能让 set -e 把脚本打断
    wl-copy --type image/png < "$path" 2>/dev/null
}

shot_region() {
    local path coords copied=0
    coords="${1:-}"
    path="$SHOT_DIR/Area_$(date +%Y%m%d_%H%M%S).png"

    if [[ -z "$coords" ]]; then
        coords="$(slurp || true)"
        if [[ -z "$coords" ]]; then
            notify_capture "截图已取消" "未选择截图区域"
            return 0
        fi
    fi

    grim -g "$coords" "$path"
    if copy_image "$path"; then
        copied=1
    fi
    if [[ "$copied" -eq 1 ]]; then
        notify_capture "区域截图已保存" "已复制到剪贴板\n$path"
    else
        notify_capture "区域截图已保存" "剪贴板复制失败，文件仍在\n$path"
    fi
}

shot_full() {
    local path copied=0
    path="$SHOT_DIR/Screenshot_$(date +%Y%m%d_%H%M%S).png"

    grim "$path"
    if copy_image "$path"; then
        copied=1
    fi
    if [[ "$copied" -eq 1 ]]; then
        notify_capture "全屏截图已保存" "已复制到剪贴板\n$path"
    else
        notify_capture "全屏截图已保存" "剪贴板复制失败，文件仍在\n$path"
    fi
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
