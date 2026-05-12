#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"
SHOT_DIR="$HOME/Pictures/Screenshots"
RECORD_SCRIPT="$HOME/.config/quickshell/scripts/record.sh"

mkdir -p "$TMP_DIR" "$SHOT_DIR"

ACTION="${1:-}"
ARG1="${2:-}"
ARG2="${3:-}"
ARG3="${4:-}"

notify_capture() {
  local title="$1"
  local body="${2:-}"
  local icon="${3:-camera-photo}"
  notify-send -a "quickshell-capture" -i "$icon" "$title" "$body"
}

call_capture_menu() {
  local action="${1:-toggle}"
  if ! command -v qs >/dev/null 2>&1; then
    return 1
  fi

  qs ipc call capturemenu "$action" >/dev/null 2>&1
}

record_state() {
  local pid_file="$TMP_DIR/record.pid"
  local paused_file="$TMP_DIR/record.paused"

  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      if [[ -f "$paused_file" ]]; then
        echo "paused"
      else
        echo "recording"
      fi
      return 0
    fi
    rm -f "$pid_file" "$paused_file"
  fi

  echo "idle"
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

record_toggle() {
  local kind scope coords state mode
  kind="${1:-video}"
  scope="${2:-full}"
  coords="${3:-}"
  state="$(record_state)"

  if [[ "$state" == "idle" ]]; then
    mode="${kind}_${scope}"
    if [[ -n "$coords" ]]; then
      bash "$RECORD_SCRIPT" start "$mode" "$coords"
    else
      bash "$RECORD_SCRIPT" start "$mode"
    fi
    return 0
  fi

  bash "$RECORD_SCRIPT" stop
}

state_key() {
  local state
  state="$(record_state)"

  case "$state" in
    recording)
      bash "$RECORD_SCRIPT" pause
      ;;
    paused)
      bash "$RECORD_SCRIPT" resume
      ;;
    idle)
      if ! call_capture_menu toggle; then
        notify_capture "万能菜单打开失败" "请确认 quickshell 正在运行" "dialog-error"
      fi
      ;;
    *)
      notify_capture "未知录制状态" "state=$state" "dialog-error"
      ;;
  esac
}

force_stop() {
  local state
  state="$(record_state)"
  if [[ "$state" == "idle" ]]; then
    notify_capture "没有正在进行的录制" "无需停止" "camera-video"
    return 0
  fi
  bash "$RECORD_SCRIPT" stop
}

menu_action() {
  local action
  action="${1:-toggle}"

  if ! call_capture_menu "$action"; then
    notify_capture "万能菜单控制失败" "action=$action" "dialog-error"
  fi
}

case "$ACTION" in
  shot)
    case "${ARG1:-region}" in
      region) shot_region "${ARG2:-}" ;;
      full) shot_full ;;
      *)
        echo "usage: $0 shot <region|full>" >&2
        exit 1
        ;;
    esac
    ;;
  record-toggle)
    record_toggle "${ARG1:-video}" "${ARG2:-full}" "${ARG3:-}"
    ;;
  state-key)
    state_key
    ;;
  force-stop)
    force_stop
    ;;
  menu)
    menu_action "${ARG1:-toggle}"
    ;;
  status)
    record_state
    ;;
  status-detail)
    bash "$RECORD_SCRIPT" status-detail
    ;;
  *)
    cat >&2 <<'EOF'
usage:
  capture.sh shot <region|full> [geometry]
  capture.sh record-toggle <video|gif> <region|full> [geometry]
  capture.sh state-key
  capture.sh force-stop
  capture.sh menu [show|hide|toggle]
  capture.sh status
  capture.sh status-detail
EOF
    exit 1
    ;;
esac
