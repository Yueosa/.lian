#!/usr/bin/env bash


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
export BtnCol="black"


hypr_border="${hypr_border:-10}"
export active_rad=$((hypr_border * 5))
export button_rad=$((hypr_border * 8))


wlStyle="$(envsubst <"${wlTmplt}")"


wlogout -b "${wlColms}" -c 0 -r 0 -m 0 --layout "${wLayout}" --css <(echo "${wlStyle}") --protocol layer-shell
