#!/usr/bin/env bash
set -euo pipefail

THEME_PATH="${ROFI_THEME_PATH:-$HOME/.config/rofi/clipboard.rasi}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-rofi"
THUMB_DIR="$CACHE_DIR/thumbs"

mkdir -p "$THUMB_DIR"

find "$THUMB_DIR" -type f -mtime +14 -delete 2>/dev/null || true

pango_escape() {
	local s="${1-}"
	s=${s//&/&amp;}
	s=${s//</&lt;}
	s=${s//>/&gt;}
	echo "$s"
}

wipe_all() {
	cliphist wipe >/dev/null 2>&1 || true
	rm -rf "$CACHE_DIR" >/dev/null 2>&1 || true
	mkdir -p "$THUMB_DIR"
}

format_row() {
	local id="$1"
	local preview="$2"

	local p="$preview"
	p="${p//$'\t'/ }"
	p="${p//$'\n'/ }"
	while [[ "$p" == *"  "* ]]; do p="${p//  / }"; done

	local p_esc
	p_esc="$(pango_escape "$p")"
	printf '<span size="medium" alpha="90%%">%s</span>' "$p_esc"
}

make_thumb() {
	local id="$1"
	local kind="$2"
	local raw_path="$THUMB_DIR/$id.$kind"
	local thumb_path="$THUMB_DIR/$id.thumb.png"

	if [[ -s "$thumb_path" ]]; then
		echo "$thumb_path"
		return 0
	fi

	if ! cliphist decode "$id" >"$raw_path" 2>/dev/null; then
		return 1
	fi

	if command -v magick >/dev/null 2>&1; then
		magick "$raw_path" -auto-orient -thumbnail 320x180\> "$thumb_path" 2>/dev/null || cp -f "$raw_path" "$thumb_path"
	elif command -v convert >/dev/null 2>&1; then
		convert "$raw_path" -auto-orient -thumbnail 320x180\> "$thumb_path" 2>/dev/null || cp -f "$raw_path" "$thumb_path"
	else
		cp -f "$raw_path" "$thumb_path"
	fi

	echo "$thumb_path"
}

menu() {
	cliphist list | while IFS= read -r line; do
		[[ -z "$line" ]] && continue

		local id preview
		id="${line%%[[:space:]]*}"
		preview="${line#"$id"}"
		preview="${preview#${preview%%[![:space:]]*}}"
		if [[ "$preview" =~ \[\[\ binary\ data.*\ (png|jpe?g|webp|gif)\  ]]; then
			local kind icon
			kind="${BASH_REMATCH[1]}"
			[[ "$kind" == "jpg" ]] && kind="jpeg"

			if icon="$(make_thumb "$id" "$kind")"; then
				local display
				display="$(format_row "$id" "$preview")"
				printf '%s\x1f%s\0icon\x1f%s\n' "$id" "$display" "$icon"
				continue
			fi
		fi

		printf '%s\x1f%s\n' "$id" "$(format_row "$id" "$preview")"
	done
}

while true; do
	set +e
	selection="$({ menu; } | rofi -dmenu -i -markup-rows -theme "$THEME_PATH" -kb-custom-1 "Alt+BackSpace" -display-column-separator $'\x1f' -display-columns 2)"
	rofi_rc=$?
	set -e

	if [[ "$rofi_rc" -eq 10 ]]; then
		wipe_all
		continue
	fi

	[[ -z "${selection:-}" ]] && exit 0

	selected_id=""
	if [[ "$selection" == *$'\x1f'* ]]; then
		selected_id="${selection%%$'\x1f'*}"
	fi

	if [[ -z "${selected_id:-}" ]]; then
		selection_stripped="$(printf '%s' "$selection" | sed -E 's/<[^>]*>//g')"
		selected_id="$(cliphist list | awk -v s="$selection_stripped" '
			BEGIN { found = "" }
			{
				id=$1;
				$1="";
				sub(/^[ \t]+/, "", $0);
				if (index($0, s) == 1) { print id; exit }
			}
		')"
	fi

	[[ -z "${selected_id:-}" ]] && exit 0
	cliphist decode "$selected_id" | wl-copy
	exit 0
done
