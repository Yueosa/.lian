#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_PATH="${1:-}"
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
QSL_CONFIG="${REPO_ROOT}/qsl/config.json"
mkdir -p "${TMP_DIR}"
mkdir -p "$(dirname "${OUT_JSON}")"
mkdir -p "${CACHE_ROFI_DIR}"

if [[ -z "${WALLPAPER_PATH}" ]]; then
  exit 0
fi

if [[ ! -f "${WALLPAPER_PATH}" ]]; then
  exit 0
fi

# 归一成真实路径：lianwall hook 传壁纸原路径，QML 侧重跑时传的是
# ~/.cache/wallpaper_rofi/current 这个软链。不统一的话两边写进
# __qs_wallpaper_path 的值不同，同壁纸短路永远不命中
WALLPAPER_PATH="$(readlink -f "${WALLPAPER_PATH}" 2>/dev/null || printf '%s' "${WALLPAPER_PATH}")"

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

# ---- qsl/config.json 里的 matugen 参数 ----
# 脚本自己读文件而不是等 QML 传参：换壁纸这条链是 lianwall hook 触发的，
# qs 没在跑的时候也得出正确的配色，所以配置不能只活在 QML 里。
# 默认值的真源在 qsl/data/state/Config.qml，这里的回退值要和那边对齐。
cfg_get() {
  local path="$1" fallback="$2" value
  [[ -f "${QSL_CONFIG}" ]] || { printf '%s\n' "${fallback}"; return 0; }
  command -v jq >/dev/null 2>&1 || { printf '%s\n' "${fallback}"; return 0; }
  value="$(jq -r --arg p "${path}" 'getpath($p | split(".")) // empty' "${QSL_CONFIG}" 2>/dev/null || true)"
  if [[ -n "${value}" && "${value}" != "null" ]]; then
    printf '%s\n' "${value}"
  else
    printf '%s\n' "${fallback}"
  fi
}

# 白名单在这里再过一遍（QML 侧已经过了一次）：配置文件是用户手写的，
# matugen 收到非法 --type 会整条命令失败，那就成了"改个配置全屏没色"
normalize_scheme() {
  local value="${1:-tonal-spot}"
  value="${value,,}"
  case "${value}" in
    content|expressive|fidelity|fruit-salad|monochrome|neutral|rainbow|smart|tonal-spot|vibrant)
      printf '%s\n' "${value}" ;;
    *) printf '%s\n' "tonal-spot" ;;
  esac
}

# matugen 的 --source-color-index 只认 0-4，非数字或超范围一律退回 0
normalize_source_index() {
  local value="${1:-0}"
  if [[ "${value}" =~ ^[0-4]$ ]]; then
    printf '%s\n' "${value}"
  else
    printf '%s\n' "0"
  fi
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

# GTK3/4 应用（thunar、blueman、pavucontrol…）的明暗变体看 settings.ini 的
# gtk-application-prefer-dark-theme；只设 gsettings color-scheme 不够，
# settings.ini 里的旧值会强制 Adwaita 用浅色变体 → 深色壁纸下浅字白底看不清。
set_gtk_prefer_dark() {
  local want="${1:-1}"
  local f
  for f in "${HOME}/.config/gtk-3.0/settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"; do
    [[ -f "${f}" ]] || continue
    if grep -q '^gtk-application-prefer-dark-theme=' "${f}"; then
      sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=${want}/" "${f}"
    elif grep -q '^\[Settings\]' "${f}"; then
      sed -i "/^\[Settings\]/a gtk-application-prefer-dark-theme=${want}" "${f}"
    else
      printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "${want}" >> "${f}"
    fi
  done
}

sync_gtk_color_scheme() {
  local mode="${1:-dark}"
  local scheme="prefer-dark"
  local prefer_dark=1
  case "${mode}" in
    light) scheme="prefer-light"; prefer_dark=0 ;;
    dark) scheme="prefer-dark"; prefer_dark=1 ;;
  esac

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "${scheme}" >/dev/null 2>&1 || true
  fi
  set_gtk_prefer_dark "${prefer_dark}"
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
ln -sf "${SOURCE_IMAGE}" "${DISPLAY_PREVIEW}" 2>/dev/null || true

# 命令行第二参优先（留给手动调试：`... 壁纸 light`），否则读 config.json。
# hooks.toml 那边只传 $1，故意的——模式的真源是配置文件，不该在 hook 里再存一份
FORCED_MODE="$(normalize_mode "${2:-$(cfg_get theme.mode auto)}")"
SCHEME="$(normalize_scheme "$(cfg_get theme.scheme tonal-spot)")"
SRC_INDEX="$(normalize_source_index "$(cfg_get theme.sourceColorIndex 0)")"

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

# 同壁纸短路：省掉一次 matugen。判断里必须带上 scheme/取色下标，只比壁纸路径的
# 话，改 config.json 里的配色方案会被这里静默跳过，表现成"改了没反应"
if [[ "$(normalize_mode "${FORCED_MODE}")" == "auto" && -f "${OUT_JSON}" ]]; then
  if jq -e --arg path "${SOURCE_IMAGE}" --arg scheme "${SCHEME}" --argjson idx "${SRC_INDEX}" \
       '."__qs_request_mode" == "auto" and ."__qs_wallpaper_path" == $path
        and ."__qs_scheme" == $scheme and ."__qs_source_index" == $idx' "${OUT_JSON}" >/dev/null 2>&1; then
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
  matugen_args=(image "${SOURCE_IMAGE}" --type "scheme-${SCHEME}" \
    --source-color-index "${SRC_INDEX}" --mode "${MODE}" --json hex --old-json-output)
  if [[ -f "${MATUGEN_CONFIG}" ]]; then
    matugen_args+=(-c "${MATUGEN_CONFIG}")
  fi
  if matugen "${matugen_args[@]}" > "${tmp_json}" 2>/dev/null; then
    if jq -e '.colors' "${tmp_json}" >/dev/null 2>&1; then
      jq --arg mode "${MODE}" --arg request_mode "$(normalize_mode "${FORCED_MODE}")" --argjson request_seq "${REQUEST_SEQ:-0}" \
        --arg wallpaper_path "${SOURCE_IMAGE}" --arg scheme "${SCHEME}" --argjson idx "${SRC_INDEX}" \
        '(.colors | with_entries(.value = (.value[$mode] // .value.default // .value.dark // .value.light // .value)))
         + {"__qs_request_mode": $request_mode, "__qs_request_seq": $request_seq, "__qs_wallpaper_path": $wallpaper_path,
            "__qs_scheme": $scheme, "__qs_source_index": $idx}' \
        "${tmp_json}" > "${OUT_JSON}"
      sync_gtk_color_scheme "${MODE}"
      nudge_qt6ct
      exit 0
    fi
  fi
fi

# 兜底路径也记下参数：不是为了声称"这套色是 matugen 按此方案生成的"，而是
# 记"这组参数试过了"，好让上面的短路和 QML 侧的重跑判断都不必反复重试
avg_hex="$(extract_average_hex "${SOURCE_IMAGE}" || true)"
if [[ -n "${avg_hex}" ]]; then
  printf '{"source_color":"%s","primary":"%s","__qs_request_mode":"%s","__qs_request_seq":%s,"__qs_scheme":"%s","__qs_source_index":%s}\n' \
    "${avg_hex}" "${avg_hex}" "$(normalize_mode "${FORCED_MODE}")" "${REQUEST_SEQ:-0}" "${SCHEME}" "${SRC_INDEX}" > "${OUT_JSON}"
  jq --arg wallpaper_path "${SOURCE_IMAGE}" '. + {"__qs_wallpaper_path": $wallpaper_path}' "${OUT_JSON}" > "${OUT_JSON}.tmp"
  mv "${OUT_JSON}.tmp" "${OUT_JSON}"
else
  printf '{"__qs_request_mode":"%s","__qs_request_seq":%s,"__qs_scheme":"%s","__qs_source_index":%s}\n' \
    "$(normalize_mode "${FORCED_MODE}")" "${REQUEST_SEQ:-0}" "${SCHEME}" "${SRC_INDEX}" > "${OUT_JSON}"
  jq --arg wallpaper_path "${SOURCE_IMAGE}" '. + {"__qs_wallpaper_path": $wallpaper_path}' "${OUT_JSON}" > "${OUT_JSON}.tmp"
  mv "${OUT_JSON}.tmp" "${OUT_JSON}"
fi

sync_gtk_color_scheme "${MODE}"
nudge_qt6ct
