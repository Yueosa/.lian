#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"
VIDEOS_DIR="$HOME/Videos/videos"
GIF_DIR="$HOME/Videos/gif"
AUDIO_SYS_DIR="$HOME/Music/audio_sys"
AUDIO_MIC_DIR="$HOME/Music/audio_mic"

mkdir -p "$VIDEOS_DIR" "$GIF_DIR" "$AUDIO_SYS_DIR" "$AUDIO_MIC_DIR" "$TMP_DIR"

ACTION="${1:-}"
MODE="${2:-}"
CAPTURE_GEOMETRY="${3:-}"

notify_capture() {
  local title="$1"
  local body="${2:-}"
  local icon="${3:-camera-video}"
  notify-send -a "quickshell-capture" -i "$icon" "$title" "$body"
}

require_command() {
  local cmd="$1"
  local feature="${2:-该功能}"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  notify_capture "缺少依赖：$cmd" "$feature不可用，请先安装 $cmd" "dialog-error"
  return 1
}

write_state() {
  local name="$1"
  local value="$2"
  printf '%s' "$value" > "$TMP_DIR/$name"
}

read_state() {
  local name="$1"
  local path="$TMP_DIR/$name"
  if [[ -f "$path" ]]; then
    cat "$path"
  fi
}

clear_capture_state() {
  rm -f "$TMP_DIR/capture_mode.txt" "$TMP_DIR/capture_output.txt" "$TMP_DIR/capture_tmp.txt" "$TMP_DIR/capture_start_epoch.txt" "$TMP_DIR/capture_pause_total_sec.txt" "$TMP_DIR/capture_paused_since_epoch.txt" "$TMP_DIR/record.pid" "$TMP_DIR/record.paused"
}

now_epoch() {
  date +%s
}

capture_elapsed_seconds() {
  local start pause_total paused_since now elapsed

  start="$(read_state "capture_start_epoch.txt")"
  pause_total="$(read_state "capture_pause_total_sec.txt")"

  if [[ -z "$start" ]]; then
    echo "0"
    return 0
  fi

  [[ -z "$pause_total" ]] && pause_total="0"

  now="$(now_epoch)"
  elapsed=$(( now - start - pause_total ))

  if [[ -f "$TMP_DIR/record.paused" ]]; then
    paused_since="$(read_state "capture_paused_since_epoch.txt")"
    if [[ -n "$paused_since" ]]; then
      elapsed=$(( elapsed - (now - paused_since) ))
    fi
  fi

  if (( elapsed < 0 )); then
    elapsed=0
  fi

  echo "$elapsed"
}

generate_video_thumbnail() {
  local input="$1"
  local thumb="$TMP_DIR/record_thumb_$(date +%Y%m%d_%H%M%S)_$$.jpg"

  if ! command -v ffmpeg >/dev/null 2>&1; then
    return 1
  fi

  if ffmpeg -y -ss 00:00:00.8 -i "$input" -frames:v 1 -vf "scale=720:-1:flags=lanczos" "$thumb" >"$TMP_DIR/thumb_ffmpeg.log" 2>&1; then
    if [[ -s "$thumb" ]]; then
      echo "$thumb"
      return 0
    fi
  fi

  rm -f "$thumb"
  return 1
}

scope_label() {
  case "$1" in
    region) echo "区域" ;;
    full) echo "全屏" ;;
    *) echo "未知" ;;
  esac
}

normalize_capture_mode() {
  case "$1" in
    video|video_region) echo "video_region" ;;
    video_full) echo "video_full" ;;
    gif|gif_region) echo "gif_region" ;;
    gif_full) echo "gif_full" ;;
    *) return 1 ;;
  esac
}

start_audio_record() {
  local kind="$1"
  local out mode_label

  require_command ffmpeg "录音功能" || return 1

  if [[ "$kind" == "audio_sys" ]]; then
    require_command pactl "系统音频录制" || return 1
    local sink_monitor
    sink_monitor="$(pactl get-default-sink).monitor"
    out="$AUDIO_SYS_DIR/SYS_$(date +%Y%m%d_%H%M%S).mp3"
    mode_label="系统音频"
    ffmpeg -f pulse -i "$sink_monitor" -y "$out" >"$TMP_DIR/audio_ffmpeg.log" 2>&1 &
  else
    out="$AUDIO_MIC_DIR/MIC_$(date +%Y%m%d_%H%M%S).mp3"
    mode_label="麦克风"
    ffmpeg -f pulse -i default -y "$out" >"$TMP_DIR/audio_ffmpeg.log" 2>&1 &
  fi

  write_state "audio_record.pid" "$!"
  write_state "audio_mode.txt" "$kind"
  write_state "audio_output.txt" "$out"
  notify_capture "开始录音（$mode_label）" "路径：$out" "audio-input-microphone"
}

stop_audio_record() {
  if [[ ! -f "$TMP_DIR/audio_record.pid" ]]; then
    notify_capture "没有正在进行的录音" "可执行 start audio_sys 或 start audio_mic" "audio-input-microphone"
    return 0
  fi

  local pid
  pid="$(cat "$TMP_DIR/audio_record.pid" 2>/dev/null || true)"
  if [[ -n "$pid" ]]; then
    kill -INT "$pid" >/dev/null 2>&1 || true
  fi

  rm -f "$TMP_DIR/audio_record.pid"

  local mode out mode_label
  mode="$(read_state "audio_mode.txt")"
  out="$(read_state "audio_output.txt")"

  if [[ "$mode" == "audio_sys" ]]; then
    mode_label="系统音频"
  else
    mode_label="麦克风"
  fi

  notify_capture "$mode_label录音已保存" "路径：$out" "audio-input-microphone"
  rm -f "$TMP_DIR/audio_mode.txt" "$TMP_DIR/audio_output.txt"
}

start_capture_record() {
  local raw_mode="$1"
  local preset_coords="${2:-}"
  local mode
  if ! mode="$(normalize_capture_mode "$raw_mode")"; then
    notify_capture "未知录制模式" "mode=$raw_mode" "dialog-error"
    exit 1
  fi

  require_command wf-recorder "屏幕录制" || exit 1

  local kind scope coords=""
  kind="${mode%%_*}"
  scope="${mode##*_}"

  if [[ "$scope" == "region" ]]; then
    if [[ -n "$preset_coords" ]]; then
      coords="$preset_coords"
    else
      require_command slurp "区域录制" || exit 1
      sleep 0.35
      coords="$(slurp || true)"
      if [[ -z "$coords" ]]; then
        notify_capture "录制已取消" "未选择录制区域" "camera-video"
        exit 0
      fi
    fi
  fi

  local output tmp="" mode_label scope_text
  scope_text="$(scope_label "$scope")"
  mode_label="视频"

  if [[ "$kind" == "gif" ]]; then
    output="$GIF_DIR/GIF_$(date +%Y%m%d_%H%M%S).gif"
    tmp="$TMP_DIR/record.mp4"
    mode_label="GIF"
    if [[ -n "$coords" ]]; then
      wf-recorder -g "$coords" -f "$tmp" >"$TMP_DIR/record.log" 2>&1 &
    else
      wf-recorder -f "$tmp" >"$TMP_DIR/record.log" 2>&1 &
    fi
    write_state "capture_tmp.txt" "$tmp"
  else
    output="$VIDEOS_DIR/REC_$(date +%Y%m%d_%H%M%S).mp4"
    if [[ -n "$coords" ]]; then
      wf-recorder -g "$coords" -f "$output" >"$TMP_DIR/record.log" 2>&1 &
    else
      wf-recorder -f "$output" >"$TMP_DIR/record.log" 2>&1 &
    fi
    rm -f "$TMP_DIR/capture_tmp.txt"
  fi

  write_state "record.pid" "$!"
  write_state "capture_mode.txt" "$mode"
  write_state "capture_output.txt" "$output"
  write_state "capture_start_epoch.txt" "$(now_epoch)"
  write_state "capture_pause_total_sec.txt" "0"
  rm -f "$TMP_DIR/capture_paused_since_epoch.txt"
  rm -f "$TMP_DIR/record.paused"

  notify_capture "开始录制（$scope_text）" "类型：$mode_label\n输出：$output" "camera-video"
}

stop_capture_record() {
  local requested_mode="${1:-}"
  local mode
  mode="$(read_state "capture_mode.txt")"

  if [[ -z "$mode" && -n "$requested_mode" ]]; then
    mode="$(normalize_capture_mode "$requested_mode" 2>/dev/null || true)"
  fi
  if [[ -z "$mode" ]]; then
    mode="video_region"
  fi

  local kind scope
  kind="${mode%%_*}"
  scope="${mode##*_}"

  if [[ ! -f "$TMP_DIR/record.pid" ]]; then
    notify_capture "没有正在进行的录制" "可执行 start video_region / start video_full / start gif_region / start gif_full" "camera-video"
    clear_capture_state
    return 0
  fi

  local pid
  pid="$(cat "$TMP_DIR/record.pid" 2>/dev/null || true)"
  if [[ -n "$pid" ]]; then
    kill -CONT "$pid" >/dev/null 2>&1 || true
    kill -INT "$pid" >/dev/null 2>&1 || true
    for _ in $(seq 1 120); do
      if ! kill -0 "$pid" >/dev/null 2>&1; then
        break
      fi
      sleep 0.05
    done
  fi

  rm -f "$TMP_DIR/record.pid"

  local output tmp scope_text
  output="$(read_state "capture_output.txt")"
  scope_text="$(scope_label "$scope")"

  if [[ "$kind" == "gif" ]]; then
    tmp="$(read_state "capture_tmp.txt")"
    [[ -z "$tmp" ]] && tmp="$TMP_DIR/record.mp4"
    [[ -z "$output" ]] && output="$GIF_DIR/GIF_$(date +%Y%m%d_%H%M%S).gif"

    if ! command -v ffmpeg >/dev/null 2>&1; then
      notify_capture "缺少依赖：ffmpeg" "无法压制 GIF，原始视频保留在：$tmp" "dialog-error"
      clear_capture_state
      return 1
    fi

    notify_capture "正在压制 GIF..." "路径：$output" "image-x-generic"
    if ffmpeg -y -i "$tmp" -vf "fps=15,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" "$output" >"$TMP_DIR/ffmpeg.log" 2>&1; then
      rm -f "$tmp"
      notify_capture "GIF 已保存（$scope_text）" "路径：$output" "$output"
    else
      notify_capture "GIF 压制失败" "请查看：$TMP_DIR/ffmpeg.log" "dialog-error"
    fi
  else
    local preview_icon
    [[ -z "$output" ]] && output="$VIDEOS_DIR/REC_$(date +%Y%m%d_%H%M%S).mp4"
    preview_icon="$output"

    if [[ "${output,,}" == *.mp4 ]]; then
      local thumb
      thumb="$(generate_video_thumbnail "$output" || true)"
      if [[ -n "$thumb" ]]; then
        preview_icon="$thumb"
      fi
    fi

    notify_capture "录屏已保存（$scope_text）" "路径：$output" "$preview_icon"
  fi

  clear_capture_state
}

pause_capture_record() {
  if [[ ! -f "$TMP_DIR/record.pid" ]]; then
    notify_capture "没有正在进行的录制" "无法暂停" "camera-video"
    return 0
  fi

  if [[ -f "$TMP_DIR/record.paused" ]]; then
    notify_capture "录制已处于暂停状态" "按状态键可继续" "camera-video"
    return 0
  fi

  local pid mode scope
  pid="$(cat "$TMP_DIR/record.pid" 2>/dev/null || true)"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
    clear_capture_state
    notify_capture "录制状态异常" "已自动清理状态" "dialog-error"
    return 1
  fi

  kill -STOP "$pid" >/dev/null 2>&1 || true
  : > "$TMP_DIR/record.paused"
  write_state "capture_paused_since_epoch.txt" "$(now_epoch)"

  mode="$(read_state "capture_mode.txt")"
  scope="${mode##*_}"
  notify_capture "录制已暂停" "范围：$(scope_label "$scope")\n按状态键可继续" "camera-video"
}

resume_capture_record() {
  if [[ ! -f "$TMP_DIR/record.pid" ]]; then
    notify_capture "没有正在进行的录制" "无法恢复" "camera-video"
    return 0
  fi

  if [[ ! -f "$TMP_DIR/record.paused" ]]; then
    notify_capture "录制未暂停" "当前已在录制中" "camera-video"
    return 0
  fi

  local pid mode scope
  pid="$(cat "$TMP_DIR/record.pid" 2>/dev/null || true)"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
    clear_capture_state
    notify_capture "录制状态异常" "已自动清理状态" "dialog-error"
    return 1
  fi

  kill -CONT "$pid" >/dev/null 2>&1 || true

  local paused_since pause_total now
  paused_since="$(read_state "capture_paused_since_epoch.txt")"
  pause_total="$(read_state "capture_pause_total_sec.txt")"
  [[ -z "$pause_total" ]] && pause_total="0"
  if [[ -n "$paused_since" ]]; then
    now="$(now_epoch)"
    pause_total=$(( pause_total + now - paused_since ))
    write_state "capture_pause_total_sec.txt" "$pause_total"
  fi

  rm -f "$TMP_DIR/capture_paused_since_epoch.txt"
  rm -f "$TMP_DIR/record.paused"

  mode="$(read_state "capture_mode.txt")"
  scope="${mode##*_}"
  notify_capture "录制已恢复" "范围：$(scope_label "$scope")" "camera-video"
}

capture_status() {
  if [[ -f "$TMP_DIR/record.pid" ]]; then
    local pid
    pid="$(cat "$TMP_DIR/record.pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      if [[ -f "$TMP_DIR/record.paused" ]]; then
        echo "paused"
      else
        echo "recording"
      fi
      return 0
    fi

    clear_capture_state
  fi
  echo "idle"
}

capture_status_detail() {
  local state mode kind scope elapsed
  state="$(capture_status)"

  if [[ "$state" == "idle" ]]; then
    echo "idle|||0"
    return 0
  fi

  mode="$(read_state "capture_mode.txt")"
  if [[ -z "$mode" ]]; then
    mode="video_full"
  fi

  kind="${mode%%_*}"
  scope="${mode##*_}"
  elapsed="$(capture_elapsed_seconds)"

  echo "${state}|${kind}|${scope}|${elapsed}"
}

if [[ "$ACTION" == "start" ]]; then
  case "$MODE" in
    audio_sys|audio_mic)
      start_audio_record "$MODE"
      ;;
    video|video_region|video_full|gif|gif_region|gif_full)
      start_capture_record "$MODE" "$CAPTURE_GEOMETRY"
      ;;
    *)
      echo "Usage: $0 start <audio_sys|audio_mic|video_region|video_full|gif_region|gif_full> [geometry]" >&2
      exit 1
      ;;
  esac
elif [[ "$ACTION" == "stop" ]]; then
  case "$MODE" in
    audio|audio_sys|audio_mic)
      stop_audio_record
      ;;
    ""|video|video_region|video_full|gif|gif_region|gif_full)
      stop_capture_record "$MODE"
      ;;
    *)
      stop_capture_record "$MODE"
      ;;
  esac
elif [[ "$ACTION" == "pause" ]]; then
  pause_capture_record
elif [[ "$ACTION" == "resume" ]]; then
  resume_capture_record
elif [[ "$ACTION" == "status" ]]; then
  capture_status
elif [[ "$ACTION" == "status-detail" ]]; then
  capture_status_detail
else
  echo "Usage: $0 <start|stop|pause|resume|status|status-detail> [mode] [geometry]" >&2
  exit 1
fi
