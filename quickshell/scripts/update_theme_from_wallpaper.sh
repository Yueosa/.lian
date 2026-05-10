#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_PATH="${1:-}"
FORCED_MODE="${2:-auto}"
REQUEST_SEQ="${3:-0}"
OUT_JSON="${HOME}/.cache/quickshell_colors.json"
THUMB_DIR_PRIMARY="${HOME}/.cache/Lian/LianWall/thumbnails"
THUMB_DIR_FALLBACK="${HOME}/.cache/lianwall/thumbnails"
TMP_DIR="${HOME}/.cache/quickshell_theme"
CACHE_ROFI_DIR="${HOME}/.cache/wallpaper_rofi"
DISPLAY_PREVIEW="${CACHE_ROFI_DIR}/current_preview"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MATUGEN_CONFIG="${REPO_ROOT}/matugen/config.toml"
mkdir -p "${TMP_DIR}"
mkdir -p "$(dirname "${OUT_JSON}")"
mkdir -p "${CACHE_ROFI_DIR}"

if [[ -z "${WALLPAPER_PATH}" ]]; then
  exit 0
fi

if [[ ! -f "${WALLPAPER_PATH}" ]]; then
  exit 0
fi

lower_ext="${WALLPAPER_PATH##*.}"
lower_ext="${lower_ext,,}"

is_video=0
case "${lower_ext}" in
  mp4|mkv|webm|mov|avi|flv|wmv|m4v)
    is_video=1
    ;;
esac

pick_thumbnail() {
  local base name
  local thumb_dir
  base="$(basename "${WALLPAPER_PATH}")"
  name="${base%.*}"

  if [[ -d "${THUMB_DIR_PRIMARY}" ]]; then
    thumb_dir="${THUMB_DIR_PRIMARY}"
  elif [[ -d "${THUMB_DIR_FALLBACK}" ]]; then
    thumb_dir="${THUMB_DIR_FALLBACK}"
  else
    return 1
  fi

  local candidate
  for ext in jpg jpeg png webp; do
    candidate="${thumb_dir}/${name}.${ext}"
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  # Fallback: fuzzy match generated cache names.
  candidate="$(find "${thumb_dir}" -maxdepth 1 -type f | grep -F "${name}" | head -n1 || true)"
  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  return 1
}

extract_mid_frame() {
  local video="$1"
  local out="$2"
  local duration midpoint

  if [[ -f "${out}" ]]; then
    return 0
  fi

  duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "${video}" 2>/dev/null || true)"
  if [[ -z "${duration}" ]]; then
    return 1
  fi

  midpoint="$(awk -v d="${duration}" 'BEGIN { printf "%.3f", d/2.0 }')"
  timeout 8s ffmpeg -hide_banner -loglevel error -y -ss "${midpoint}" -i "${video}" -vframes 1 "${out}" >/dev/null 2>&1 || true
  [[ -f "${out}" ]]
}

read_average_rgb() {
  local input="$1"
  local rgb
  rgb="$(ffmpeg -hide_banner -loglevel error -i "${input}" -vf scale=1:1,format=rgb24 -frames:v 1 -f rawvideo - 2>/dev/null | od -An -tu1 | tr -s ' ' | sed 's/^ *//' | head -n1 || true)"
  if [[ -z "${rgb}" ]]; then
    return 1
  fi
  local r g b
  read -r r g b _ <<< "${rgb}"
  if [[ -z "${r}" || -z "${g}" || -z "${b}" ]]; then
    return 1
  fi
  printf "%s %s %s\n" "${r}" "${g}" "${b}"
}

extract_average_hex() {
  local rgb
  rgb="$(read_average_rgb "$1")" || return 1
  local r g b
  read -r r g b <<< "${rgb}"
  printf "#%02x%02x%02x\n" "${r}" "${g}" "${b}"
}

# 根据壁纸感知亮度决定明暗模式：luma > 140 (0..255) → light，否则 dark。
detect_mode() {
  local rgb
  rgb="$(read_average_rgb "$1")" || { echo dark; return 0; }
  local r g b
  read -r r g b <<< "${rgb}"
  awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN{
    luma = 0.299*r + 0.587*g + 0.114*b;
    print (luma > 140 ? "light" : "dark");
  }'
}

normalize_mode() {
  local value="${1:-auto}"
  value="${value,,}"
  case "${value}" in
    light|dark|auto) printf '%s\n' "${value}" ;;
    *) printf '%s\n' "auto" ;;
  esac
}

resolve_mode() {
  local forced
  forced="$(normalize_mode "${FORCED_MODE}")"
  case "${forced}" in
    light|dark)
      printf '%s\n' "${forced}"
      ;;
    auto)
      # AUTO 独立模式：壁纸亮就 light variant，壁纸暗就 dark variant。
      # QML 端 AUTO 直接走 cache，与 LIGHT/DARK 三套方案完全解耦。
      detect_mode "$1"
      ;;
  esac
}

sync_gtk_color_scheme() {
  local mode="${1:-dark}"
  local scheme="prefer-dark"
  case "${mode}" in
    light) scheme="prefer-light" ;;
    dark) scheme="prefer-dark" ;;
  esac

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "${scheme}" >/dev/null 2>&1 || true
  fi
}

SOURCE_IMAGE="${WALLPAPER_PATH}"

if [[ "${is_video}" -eq 1 ]]; then
  thumb="$(pick_thumbnail || true)"
  if [[ -n "${thumb}" ]]; then
    SOURCE_IMAGE="${thumb}"
  else
    fallback_frame="${TMP_DIR}/$(basename "${WALLPAPER_PATH}").mid.jpg"
    if extract_mid_frame "${WALLPAPER_PATH}" "${fallback_frame}"; then
      SOURCE_IMAGE="${fallback_frame}"
    fi
  fi
fi

# 统一为 UI 提供可显示的静态预览图路径。
ln -sf "${SOURCE_IMAGE}" "${DISPLAY_PREVIEW}"

MODE="$(resolve_mode "${SOURCE_IMAGE}" 2>/dev/null || echo dark)"
case "${MODE}" in
  light|dark) ;;
  *) MODE="dark" ;;
esac

# 确保 matugen 模板目标目录存在（如 qt6ct/colors）。
mkdir -p "${HOME}/.config/qt6ct/colors"

# qt6ct 监听的是 qt6ct.conf 自身：调色板文件改了不会触发热更，
# 用 touch 推一下让正在运行的 Qt 应用重新加载。
nudge_qt6ct() {
  local conf="${HOME}/.config/qt6ct/qt6ct.conf"
  [[ -f "${conf}" ]] && touch "${conf}" || true
}

if [[ "$(normalize_mode "${FORCED_MODE}")" == "auto" && -f "${OUT_JSON}" ]]; then
  if jq -e --arg path "${SOURCE_IMAGE}" '."__qs_request_mode" == "auto" and ."__qs_wallpaper_path" == $path' "${OUT_JSON}" >/dev/null 2>&1; then
    jq --arg request_mode "auto" --argjson request_seq "${REQUEST_SEQ:-0}" --arg wallpaper_path "${SOURCE_IMAGE}" \
      '. + {"__qs_request_mode": $request_mode, "__qs_request_seq": $request_seq, "__qs_wallpaper_path": $wallpaper_path}' \
      "${OUT_JSON}" > "${OUT_JSON}.tmp"
    mv "${OUT_JSON}.tmp" "${OUT_JSON}"
    sync_gtk_color_scheme "${MODE}"
    nudge_qt6ct
    exit 0
  fi
fi

if command -v matugen >/dev/null 2>&1; then
  tmp_json="${TMP_DIR}/matugen-colors.json"
  matugen_args=(image "${SOURCE_IMAGE}" --source-color-index 0 --mode "${MODE}" --json hex --old-json-output)
  if [[ -f "${MATUGEN_CONFIG}" ]]; then
    matugen_args+=(-c "${MATUGEN_CONFIG}")
  fi
  if matugen "${matugen_args[@]}" > "${tmp_json}" 2>/dev/null; then
    if jq -e '.colors' "${tmp_json}" >/dev/null 2>&1; then
      jq --arg mode "${MODE}" --arg request_mode "$(normalize_mode "${FORCED_MODE}")" --argjson request_seq "${REQUEST_SEQ:-0}" \
        --arg wallpaper_path "${SOURCE_IMAGE}" \
        '(.colors | with_entries(.value = (.value[$mode] // .value.default // .value.dark // .value.light // .value)))
         + {"__qs_request_mode": $request_mode, "__qs_request_seq": $request_seq, "__qs_wallpaper_path": $wallpaper_path}' \
        "${tmp_json}" > "${OUT_JSON}"
      sync_gtk_color_scheme "${MODE}"
      nudge_qt6ct
      exit 0
    fi
  fi
fi

avg_hex="$(extract_average_hex "${SOURCE_IMAGE}" || true)"
if [[ -n "${avg_hex}" ]]; then
  printf '{"source_color":"%s","primary":"%s","__qs_request_mode":"%s","__qs_request_seq":%s}\n' \
    "${avg_hex}" "${avg_hex}" "$(normalize_mode "${FORCED_MODE}")" "${REQUEST_SEQ:-0}" > "${OUT_JSON}"
  jq --arg wallpaper_path "${SOURCE_IMAGE}" '. + {"__qs_wallpaper_path": $wallpaper_path}' "${OUT_JSON}" > "${OUT_JSON}.tmp"
  mv "${OUT_JSON}.tmp" "${OUT_JSON}"
else
  printf '{"__qs_request_mode":"%s","__qs_request_seq":%s}\n' \
    "$(normalize_mode "${FORCED_MODE}")" "${REQUEST_SEQ:-0}" > "${OUT_JSON}"
  jq --arg wallpaper_path "${SOURCE_IMAGE}" '. + {"__qs_wallpaper_path": $wallpaper_path}' "${OUT_JSON}" > "${OUT_JSON}.tmp"
  mv "${OUT_JSON}.tmp" "${OUT_JSON}"
fi

sync_gtk_color_scheme "${MODE}"
nudge_qt6ct
