#!/usr/bin/env bash
# Collect official + AUR update counts and cache them for quick UI reads.

set -u
set -o pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
CACHE_FILE="$CACHE_DIR/updates.json"
LEGACY_CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/updates.json"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

count_lines() { sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]'; }

run_capture() {
    # Usage: run_capture <timeout-seconds> <cmd...>
    local timeout_s="$1"
    shift
    local out rc
    out=$(timeout "${timeout_s}" "$@" 2>/dev/null)
    rc=$?
    printf '%s' "$out"
    return "$rc"
}

now=$(date +%s)

official_raw=""
official=""
official_ok=0
if command -v checkupdates >/dev/null 2>&1; then
    raw=$(run_capture 30s checkupdates)
    rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then
        official_raw="$raw"
        official=$(printf '%s\n' "$raw" | count_lines)
        official_ok=1
    fi
fi

if [ "$official_ok" -ne 1 ] && command -v paru >/dev/null 2>&1; then
    # paru v2 在本机可稳定给出官方仓可升级列表
    raw=$(run_capture 30s paru -Qu --repo)
    rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
        official_raw="$raw"
        official=$(printf '%s\n' "$raw" | count_lines)
        official_ok=1
    fi
fi

if [ "$official_ok" -ne 1 ] && command -v pacman >/dev/null 2>&1; then
    raw=$(run_capture 15s pacman -Qu)
    rc=$?
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
        official_raw="$raw"
        official=$(printf '%s\n' "$raw" | count_lines)
        official_ok=1
    fi
fi

aur_raw=""
aur=""
aur_ok=0
if command -v paru >/dev/null 2>&1; then
    raw=$(run_capture 30s paru -Qua)
    rc=$?
    # paru 在无可升级 AUR 包时通常返回 1，这也属于成功（计数应为 0）
    if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
        aur_raw="$raw"
        aur=$(printf '%s\n' "$raw" | count_lines)
        aur_ok=1
    fi
fi

ok="true"
if [ -z "$official" ]; then official=0; ok="false"; fi
if [ -z "$aur" ]; then aur=0; ok="false"; fi

total=$((official + aur))

updated_at=$now
if [ "$ok" = "true" ]; then
    last_error_at=0
else
    last_error_at=$now
fi

off_tmp=$(mktemp /tmp/qs_upd_off.XXXXXX)
aur_tmp=$(mktemp /tmp/qs_upd_aur.XXXXXX)
printf '%s\n' "$official_raw" > "$off_tmp"
printf '%s\n' "$aur_raw" > "$aur_tmp"

python3 - "$CACHE_FILE" "$official" "$aur" "$total" "$updated_at" "$last_error_at" "$ok" "$off_tmp" "$aur_tmp" <<'PY'
import json, os, sys
from datetime import datetime

cache_file, official, aur, total, updated_at, last_error_at, ok_str, off_file, aur_file = sys.argv[1:]

def extract_pkgs(path, limit=100):
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        return [l.split()[0] for l in lines if l.strip()][:limit]
    except Exception:
        return []

def parse_log_epoch(line: str) -> int:
    # Pacman log format example:
    # [2026-05-11T10:15:30+0800] [ALPM] transaction started
    try:
        if not line.startswith("["):
            return 0
        end = line.find("]")
        if end <= 1:
            return 0
        ts = line[1:end]
        return int(datetime.fromisoformat(ts).timestamp())
    except Exception:
        return 0

def parse_last_transaction(path="/var/log/pacman.log"):
    last_ts = 0
    last_count = 0
    tx_active = False
    tx_ts = 0
    tx_count = 0

    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.strip()
                if "[ALPM] transaction started" in line:
                    tx_active = True
                    tx_ts = parse_log_epoch(line)
                    tx_count = 0
                    continue

                if not tx_active:
                    continue

                if "[ALPM] transaction completed" in line:
                    done_ts = parse_log_epoch(line)
                    last_ts = done_ts or tx_ts
                    last_count = tx_count
                    tx_active = False
                    continue

                if "[ALPM] upgraded " in line or "[ALPM] installed " in line or "[ALPM] downgraded " in line or "[ALPM] reinstalled " in line:
                    tx_count += 1
    except Exception:
        pass

    return last_count, last_ts

official_pkgs = extract_pkgs(off_file)
aur_pkgs = extract_pkgs(aur_file)
last_applied_count, last_applied_at = parse_last_transaction()

data = {
    "official": int(official),
    "aur": int(aur),
    "total": int(total),
    "updated_at": int(updated_at),
    "last_error_at": int(last_error_at),
    "ok": ok_str == "true",
    "official_packages": official_pkgs,
    "aur_packages": aur_pkgs,
    "last_applied_count": int(last_applied_count),
    "last_applied_at": int(last_applied_at),
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
