#!/usr/bin/env bash
# Collect official + AUR update counts and cache them for quick UI reads.

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
CACHE_FILE="$CACHE_DIR/updates.json"
LEGACY_CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/updates.json"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

count_lines() { sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]'; }

now=$(date +%s)

official_raw=""
official=""
if command -v checkupdates >/dev/null 2>&1; then
    raw=$(timeout 30s checkupdates 2>/dev/null)
    rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then
        official_raw="$raw"
        official=$(printf '%s\n' "$raw" | count_lines)
    fi
elif command -v pacman >/dev/null 2>&1; then
    raw=$(timeout 15s pacman -Qu 2>/dev/null)
    rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
        official_raw="$raw"
        official=$(printf '%s\n' "$raw" | count_lines)
    fi
fi

aur_raw=""
aur=""
if command -v paru >/dev/null 2>&1; then
    raw=$(timeout 30s paru -Qua 2>/dev/null)
    rc=$?
    if [ "$rc" -ne 124 ]; then
        aur_raw="$raw"
        aur=$(printf '%s\n' "$raw" | count_lines)
    fi
fi

READ_CACHE_FILE="$CACHE_FILE"
if [ ! -r "$READ_CACHE_FILE" ] && [ -r "$LEGACY_CACHE_FILE" ]; then
    READ_CACHE_FILE="$LEGACY_CACHE_FILE"
fi

prev_official=0
prev_aur=0
prev_updated_at=0
if [ -r "$READ_CACHE_FILE" ] && command -v python3 >/dev/null 2>&1; then
    eval "$(python3 - "$READ_CACHE_FILE" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(f"prev_official={int(d.get('official',0))}")
    print(f"prev_aur={int(d.get('aur',0))}")
    print(f"prev_updated_at={int(d.get('updated_at',0))}")
except Exception:
    pass
PY
)"
fi

ok="true"
if [ -z "$official" ]; then official=$prev_official; ok="false"; fi
if [ -z "$aur" ]; then aur=$prev_aur; ok="false"; fi

total=$((official + aur))

if [ "$ok" = "true" ]; then
    updated_at=$now
    last_error_at=0
else
    updated_at=$prev_updated_at
    last_error_at=$now
fi

off_tmp=$(mktemp /tmp/qs_upd_off.XXXXXX)
aur_tmp=$(mktemp /tmp/qs_upd_aur.XXXXXX)
printf '%s\n' "$official_raw" > "$off_tmp"
printf '%s\n' "$aur_raw" > "$aur_tmp"

python3 - "$CACHE_FILE" "$READ_CACHE_FILE" "$official" "$aur" "$total" "$updated_at" "$last_error_at" "$ok" "$off_tmp" "$aur_tmp" <<'PY'
import json, os, sys

cache_file, read_cache_file, official, aur, total, updated_at, last_error_at, ok_str, off_file, aur_file = sys.argv[1:]

def extract_pkgs(path, limit=100):
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        return [l.split()[0] for l in lines if l.strip()][:limit]
    except Exception:
        return []

official_pkgs = extract_pkgs(off_file)
aur_pkgs = extract_pkgs(aur_file)

if ok_str != "true":
    try:
        prev = json.load(open(read_cache_file, encoding="utf-8"))
        official_pkgs = official_pkgs or prev.get("official_packages", [])
        aur_pkgs = aur_pkgs or prev.get("aur_packages", [])
    except Exception:
        pass

data = {
    "official": int(official),
    "aur": int(aur),
    "total": int(total),
    "updated_at": int(updated_at),
    "last_error_at": int(last_error_at),
    "ok": ok_str == "true",
    "official_packages": official_pkgs,
    "aur_packages": aur_pkgs,
}

tmp = cache_file + ".tmp." + str(os.getpid())
try:
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, cache_file)
finally:
    try:
        os.unlink(tmp)
    except OSError:
        pass
PY

rm -f "$off_tmp" "$aur_tmp"

exit 0
