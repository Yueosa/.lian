#!/usr/bin/env bash
# ----------------------------------------------------------------------
# 脚本：logoutlaunch.sh
# 用途：wlogout 的“切换”入口——已开就关，没开就开。
# 使用位置：~/.local/bin/wlogout/wlogout 软链 → 此脚本
#         Hyprland 快捷键 SUPER+SPACE
# 调用：wlogout 本体（带本仓库的 layout / style.css）
# 依赖：wlogout
# ----------------------------------------------------------------------

if pgrep -x "wlogout" >/dev/null; then
    pkill -x "wlogout"
    exit 0
fi


confDir="${confDir:-$HOME/.config}"
wLayout="${confDir}/wlogout/layout"
wlTmplt="${confDir}/wlogout/style.css"


if [ ! -f "${wLayout}" ] || [ ! -f "${wlTmplt}" ]; then
    echo "ERROR: Config not found..."
    wLayout="${confDir}/wlogout/layout"
    wlTmplt="${confDir}/wlogout/style.css"
fi


x_mon=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .width')
y_mon=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .height')
hypr_scale=$(hyprctl -j monitors | jq '.[] | select (.focused == true) | .scale' | sed 's/\.//')


wlColms=4
export mgn=$((y_mon * 28 / hypr_scale))
export hvr=$((y_mon * 23 / hypr_scale))
export fntSize=$((y_mon * 2 / 100))

theme_mode="$(tr '[:upper:]' '[:lower:]' < "$HOME/.cache/quickshell_theme_mode" 2>/dev/null | head -n1)"
[ -n "$theme_mode" ] || theme_mode="auto"

auto_primary="$(jq -r '.primary // .source_color // empty' "$HOME/.cache/quickshell_colors.json" 2>/dev/null | head -n1)"
auto_background="$(jq -r '.background // .surface // empty' "$HOME/.cache/quickshell_colors.json" 2>/dev/null | head -n1)"
auto_surface="$(jq -r '.surface_container // .surface // empty' "$HOME/.cache/quickshell_colors.json" 2>/dev/null | head -n1)"
auto_on_surface="$(jq -r '.on_surface // .on_background // empty' "$HOME/.cache/quickshell_colors.json" 2>/dev/null | head -n1)"
auto_primary_container="$(jq -r '.primary_container // .secondary_container // empty' "$HOME/.cache/quickshell_colors.json" 2>/dev/null | head -n1)"
auto_on_primary_container="$(jq -r '.on_primary_container // .on_secondary_container // empty' "$HOME/.cache/quickshell_colors.json" 2>/dev/null | head -n1)"

case "$theme_mode" in
    dark)
        export BtnCol="white"
        export WLOGOUT_BAR_BG="#0f1416"
        export WLOGOUT_MAIN_BG="#0f1416"
        export WLOGOUT_MAIN_FG="#dee3e6"
        export WLOGOUT_ACT_BG="#88d0ec"
        export WLOGOUT_ACT_FG="#003544"
        export WLOGOUT_HVR_BG="#354a53"
        export WLOGOUT_HVR_FG="#cfe6f1"
        ;;
    light)
        export BtnCol="black"
        export WLOGOUT_BAR_BG="#f7f8ff"
        export WLOGOUT_MAIN_BG="#fbf8ff"
        export WLOGOUT_MAIN_FG="#1b1d2a"
        export WLOGOUT_ACT_BG="#b53f80"
        export WLOGOUT_ACT_FG="#ffffff"
        export WLOGOUT_HVR_BG="#ffd9ea"
        export WLOGOUT_HVR_FG="#5b1e57"
        ;;
    *)
        export BtnCol="white"
        export WLOGOUT_BAR_BG="${auto_background:-#16171f}"
        export WLOGOUT_MAIN_BG="${auto_surface:-${auto_background:-#16171f}}"
        export WLOGOUT_MAIN_FG="${auto_on_surface:-#ece6f0}"
        export WLOGOUT_ACT_BG="${auto_primary:-#ddbce4}"
        export WLOGOUT_ACT_FG="#1d1122"
        export WLOGOUT_HVR_BG="${auto_primary_container:-#4c475c}"
        export WLOGOUT_HVR_FG="${auto_on_primary_container:-#e5def5}"
        ;;
esac


hypr_border="${hypr_border:-10}"
export active_rad=$((hypr_border * 5))
export button_rad=$((hypr_border * 8))


wlStyle="$(envsubst <"${wlTmplt}")"


wlogout -b "${wlColms}" -c 0 -r 0 -m 0 --layout "${wLayout}" --css <(echo "${wlStyle}") --protocol layer-shell
