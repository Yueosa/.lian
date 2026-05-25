#!/usr/bin/env bash
set -euo pipefail

mode="${1:-quick}"
home_dir="${HOME}"
thumb_dir="${home_dir}/.cache/quickshell/clipboard_thumbs"

quick_cleanup() {
  rm -rf "${thumb_dir}" 2>/dev/null || true
  mkdir -p "${thumb_dir}"
}

case "${mode}" in
  quick)
    quick_cleanup
    notify-send "QS 内存清理" "已清理剪贴板缩略图缓存"
    ;;
  deep)
    quick_cleanup
    notify-send "QS 内存清理" "正在重载 Quickshell 以释放内存"
    pkill -x qs >/dev/null 2>&1 || true
    nohup qs >/tmp/qs.log 2>&1 &
    ;;
  *)
    echo "usage: qs_memory_cleanup.sh [quick|deep]" >&2
    exit 2
    ;;
esac
