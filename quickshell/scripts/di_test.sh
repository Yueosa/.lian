#!/usr/bin/env bash
set -euo pipefail

# DynamicIsland notification-only test helper.
# This script intentionally tests ONLY the new notification pipeline.
# It does NOT open hub/switcher/overview/volume UI paths.

usage() {
  cat <<'EOF'
Usage: di_test.sh <command> [args]

Commands:
  all
    Run matrix + burst + phasee + phasee2 + phasee3 suite.

  phasee
    Run Phase E checks (cooldown + rate-limit + stress burst).

  phasee2
    Run Phase E round-2 checks (DND / quiet-hours / critical bypass).

  phasee3
    Run Phase E round-3 checks (priority / quiet-boundary / high-priority bypass).

  list
    Print all available notification presets.

  emit [preset]
    Emit one notification preset through IslandEventCenter debug path.
    default preset: resource_cpu

  emit-policy [preset]
    Policy-aware emit with stable key (used for cooldown checks).

  emit-policy-unique [preset]
    Policy-aware emit with unique key (used for rate-limit checks).

  stats
    Print IslandEventCenter debug stats JSON.

  reset-stats
    Reset IslandEventCenter debug stats.

  set-dnd [on|off|toggle]
    Set DND status for policy tests.

  set-quiet [on|off] [start] [end]
    Set quiet-hours config for policy tests.
    defaults: off 0 8

  burst [count] [interval] [preset] [mode]
    Emit repeated notifications.
    defaults: count=8 interval=0.20 preset=resource_cpu mode=force

  cooldown-check [preset] [interval]
    Emit policy mode twice and print stats.
    defaults: preset=resource_cpu interval=0.20

  rate-check [count] [interval] [preset]
    Emit policy-unique mode repeatedly and print stats.
    defaults: count=14 interval=0.05 preset=network_up

  matrix
    Emit one pass of all major categories (connection/lianclaw/resource/power).

  scenario-connection
    Emit connection-focused sequence.

  scenario-lianclaw
    Emit lianclaw-focused sequence.

  scenario-resource
    Emit resource-focused sequence.

  scenario-power
    Emit power/storage-focused sequence.

  priority-check
    Verify critical event preempts normal queue.

  quiet-boundary-check
    Verify quiet-hours does not block events outside configured window.

  high-bypass-check
    Verify high-priority events still emit under normal-event rate pressure.

Notes:
  - Requires: qs
  - Ensure quickshell is already running before executing this script.
  - This script only sends notification test events; it never opens island modes.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[di_test] missing command: $1" >&2
    exit 1
  fi
}

qs_ipc_call() {
  require_cmd qs
  qs ipc call island "$@"
}

latest_qs_log() {
  local f
  for f in $(ls -1t /run/user/"${UID}"/quickshell/by-id/*/log.qslog 2>/dev/null); do
    if grep -aqF "[IslandEventCenter] stats " "$f"; then
      echo "$f"
      return 0
    fi
  done

  ls -1t /run/user/"${UID}"/quickshell/by-id/*/log.qslog 2>/dev/null | head -n1 || true
}

emit_preset_mode() {
  local preset="$1"
  local mode="${2:-force}"
  qs_ipc_call notifytestmode "$preset" "$mode"
}

emit_preset() {
  local preset="$1"
  emit_preset_mode "$preset" force
}

get_stats_json() {
  qs_ipc_call notifystats >/dev/null || true

  local log
  log="$(latest_qs_log)"
  if [[ -z "$log" || ! -f "$log" ]]; then
    return 1
  fi

  if command -v strings >/dev/null 2>&1; then
    strings "$log" \
      | grep -F "[IslandEventCenter] stats " \
      | tail -n1 \
      | sed 's/^.*\[IslandEventCenter\] stats //'
  else
    grep -aF "[IslandEventCenter] stats " "$log" \
      | tail -n1 \
      | sed 's/^.*\[IslandEventCenter\] stats //'
  fi
}

reset_stats() {
  qs_ipc_call notifyreset >/dev/null
}

set_dnd() {
  local state="${1:-toggle}"
  qs_ipc_call notifysetdnd "$state" >/dev/null
}

set_quiet() {
  local state="${1:-off}"
  local start="${2:-0}"
  local end="${3:-8}"
  qs_ipc_call notifysetquiet "$state" "$start" "$end" >/dev/null
}

get_emit_lines_after_last_reset() {
  local log
  log="$(latest_qs_log)"
  if [[ -z "$log" || ! -f "$log" ]]; then
    return 1
  fi

  if command -v strings >/dev/null 2>&1; then
    strings "$log" \
      | awk '
          /\[IslandEventCenter\] stats reset/ { capture=1; lines=""; next }
          capture && /\[IslandEventCenter\] emit/ { lines = lines $0 "\n" }
          END { printf "%s", lines }
        '
  else
    grep -aE "\[IslandEventCenter\] (stats reset|emit )" "$log" \
      | sed 's/^.*\(\[IslandEventCenter\]\)/\1/' \
      | awk '
          /\[IslandEventCenter\] stats reset/ { capture=1; lines=""; next }
          capture && /\[IslandEventCenter\] emit/ { lines = lines $0 "\n" }
          END { printf "%s", lines }
        '
  fi
}

cmd_list() {
  cat <<'EOF'
resource_cpu
resource_mem
resource_gpu
resource_temp
network_up
network_down
bt_up
lian_confirm
lian_form
lian_done
lian_error
power_low
disk_high
EOF
}

cmd_emit() {
  local preset="${1:-resource_cpu}"
  emit_preset "$preset"
  echo "[di_test] emit done: preset=$preset"
}

cmd_emit_policy() {
  local preset="${1:-resource_cpu}"
  emit_preset_mode "$preset" policy
  echo "[di_test] emit-policy done: preset=$preset"
}

cmd_emit_policy_unique() {
  local preset="${1:-network_up}"
  emit_preset_mode "$preset" policy-unique
  echo "[di_test] emit-policy-unique done: preset=$preset"
}

cmd_stats() {
  local json
  json="$(get_stats_json || true)"
  if [[ -z "$json" ]]; then
    echo "[di_test] stats unavailable"
    return 0
  fi
  echo "$json"
}

cmd_reset_stats() {
  reset_stats
  echo "[di_test] stats reset"
}

cmd_set_dnd() {
  local state="${1:-toggle}"
  set_dnd "$state"
  echo "[di_test] dnd set: $state"
}

cmd_set_quiet() {
  local state="${1:-off}"
  local start="${2:-0}"
  local end="${3:-8}"
  set_quiet "$state" "$start" "$end"
  echo "[di_test] quiet set: state=$state start=$start end=$end"
}

cmd_burst() {
  local count="${1:-8}"
  local interval="${2:-0.20}"
  local preset="${3:-resource_cpu}"
  local mode="${4:-force}"

  local i
  for ((i = 1; i <= count; i++)); do
    emit_preset_mode "$preset" "$mode" >/dev/null || true
    sleep "$interval"
  done

  echo "[di_test] burst done: count=$count interval=${interval}s preset=$preset mode=$mode"
}

cmd_cooldown_check() {
  local preset="${1:-resource_cpu}"
  local interval="${2:-0.20}"

  reset_stats
  emit_preset_mode "$preset" policy >/dev/null || true
  sleep "$interval"
  emit_preset_mode "$preset" policy >/dev/null || true

  sleep 0.45

  echo "[di_test] cooldown-check done: preset=$preset interval=${interval}s"
  echo "[di_test] cooldown-check stats:"
  cmd_stats
}

cmd_rate_check() {
  local count="${1:-14}"
  local interval="${2:-0.05}"
  local preset="${3:-network_up}"

  reset_stats

  local i
  for ((i = 1; i <= count; i++)); do
    emit_preset_mode "$preset" policy-unique >/dev/null || true
    sleep "$interval"
  done

  # Dispatch timer is 180ms per item; wait for pending queue to flush.
  sleep 1.8

  echo "[di_test] rate-check done: count=$count interval=${interval}s preset=$preset"
  echo "[di_test] rate-check stats:"
  cmd_stats
}

cmd_matrix() {
  local seq=(
    network_down
    lian_confirm
    resource_cpu
    resource_temp
    power_low
    lian_done
    network_up
    bt_up
  )

  local p
  for p in "${seq[@]}"; do
    emit_preset "$p" >/dev/null || true
    sleep 0.24
  done

  echo "[di_test] matrix done"
}

cmd_scenario_connection() {
  emit_preset network_down >/dev/null || true
  sleep 0.22
  emit_preset network_up >/dev/null || true
  sleep 0.22
  emit_preset bt_up >/dev/null || true
  echo "[di_test] scenario-connection done"
}

cmd_scenario_lianclaw() {
  emit_preset lian_confirm >/dev/null || true
  sleep 0.24
  emit_preset lian_form >/dev/null || true
  sleep 0.24
  emit_preset lian_done >/dev/null || true
  sleep 0.24
  emit_preset lian_error >/dev/null || true
  echo "[di_test] scenario-lianclaw done"
}

cmd_scenario_resource() {
  emit_preset resource_cpu >/dev/null || true
  sleep 0.22
  emit_preset resource_mem >/dev/null || true
  sleep 0.22
  emit_preset resource_gpu >/dev/null || true
  sleep 0.22
  emit_preset resource_temp >/dev/null || true
  echo "[di_test] scenario-resource done"
}

cmd_scenario_power() {
  emit_preset power_low >/dev/null || true
  sleep 0.22
  emit_preset disk_high >/dev/null || true
  echo "[di_test] scenario-power done"
}

cmd_phasee() {
  echo "[di_test] phasee step 1/3: cooldown-check"
  cmd_cooldown_check resource_cpu 0.20

  echo "[di_test] phasee step 2/3: rate-check"
  cmd_rate_check 14 0.05 network_up

  echo "[di_test] phasee step 3/3: stress burst"
  cmd_burst 16 0.06 resource_temp force

  echo "[di_test] phasee done"
}

cmd_phasee2() {
  local hour
  local next
  hour=$((10#$(date +%H)))
  next=$(((hour + 1) % 24))

  echo "[di_test] phasee2 step 1/3: dnd block normal events"
  reset_stats
  set_dnd on
  cmd_burst 8 0.06 network_up policy-unique
  sleep 0.6
  echo "[di_test] phasee2 dnd stats:"
  cmd_stats
  set_dnd off

  echo "[di_test] phasee2 step 2/3: quiet-hours block normal events"
  reset_stats
  set_quiet on "$hour" "$hour"
  cmd_burst 8 0.06 network_up policy-unique
  sleep 0.6
  echo "[di_test] phasee2 quiet stats:"
  cmd_stats
  set_quiet off "$hour" "$next"

  echo "[di_test] phasee2 step 3/3: critical bypass check"
  reset_stats
  set_dnd on
  set_quiet on "$hour" "$hour"
  emit_preset_mode lian_confirm policy >/dev/null || true
  sleep 0.5
  echo "[di_test] phasee2 critical stats:"
  cmd_stats
  set_dnd off
  set_quiet off "$hour" "$next"

  echo "[di_test] phasee2 done"
}

cmd_priority_check() {
  reset_stats

  cmd_burst 10 0.01 network_up force >/dev/null || true
  emit_preset_mode lian_confirm force >/dev/null || true
  sleep 0.8

  local first_four
  first_four="$(get_emit_lines_after_last_reset | head -n4 || true)"

  if [[ -n "$first_four" && "$first_four" == *"key=debug_force_lian_confirm_"* ]]; then
    echo "[di_test] priority-check PASS"
  else
    echo "[di_test] priority-check WARN: critical event not observed in first 4 emits"
  fi

  if [[ -n "$first_four" ]]; then
    echo "[di_test] priority-check first emits:"
    printf '%s\n' "$first_four"
  fi
}

cmd_quiet_boundary_check() {
  local hour
  local start
  local end
  hour=$((10#$(date +%H)))
  start=$(((hour + 1) % 24))
  end=$(((hour + 2) % 24))

  set_dnd off
  reset_stats
  set_quiet on "$start" "$end"
  emit_preset_mode network_up policy-unique >/dev/null || true
  sleep 0.5

  local json
  local emitted
  local blocked_quiet
  json="$(get_stats_json || true)"
  emitted="$(printf '%s\n' "$json" | sed -n 's/.*"emitted":\([0-9][0-9]*\).*/\1/p')"
  blocked_quiet="$(printf '%s\n' "$json" | sed -n 's/.*"blocked_quiet":\([0-9][0-9]*\).*/\1/p')"
  emitted="${emitted:-0}"
  blocked_quiet="${blocked_quiet:-0}"

  if [[ "$emitted" -ge 1 && "$blocked_quiet" -eq 0 ]]; then
    echo "[di_test] quiet-boundary-check PASS"
  else
    echo "[di_test] quiet-boundary-check WARN: emitted=$emitted blocked_quiet=$blocked_quiet"
  fi

  echo "[di_test] quiet-boundary-check window: $start -> $end (now=$hour)"
  echo "[di_test] quiet-boundary-check stats:"
  echo "$json"

  set_quiet off "$hour" "$start"
}

cmd_high_bypass_check() {
  reset_stats

  cmd_burst 16 0.04 network_up policy-unique >/dev/null || true
  emit_preset_mode resource_temp policy-unique >/dev/null || true
  sleep 1.2

  local lines
  lines="$(get_emit_lines_after_last_reset || true)"
  if printf '%s\n' "$lines" | grep -Fq "key=debug_policy-unique_resource_temp_"; then
    echo "[di_test] high-bypass-check PASS"
  else
    echo "[di_test] high-bypass-check WARN: high-priority event not observed in emit log"
  fi

  echo "[di_test] high-bypass-check stats:"
  cmd_stats
}

cmd_phasee3() {
  echo "[di_test] phasee3 step 1/3: priority-check"
  cmd_priority_check

  echo "[di_test] phasee3 step 2/3: quiet-boundary-check"
  cmd_quiet_boundary_check

  echo "[di_test] phasee3 step 3/3: high-bypass-check"
  cmd_high_bypass_check

  echo "[di_test] phasee3 done"
}

cmd_all() {
  cmd_matrix
  cmd_burst 8 0.18 resource_cpu force
  cmd_phasee
  cmd_phasee2
  cmd_phasee3
  echo "[di_test] all done"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local cmd="$1"
  shift || true

  case "$cmd" in
    all)
      cmd_all "$@"
      ;;
    phasee)
      cmd_phasee "$@"
      ;;
    phasee2)
      cmd_phasee2 "$@"
      ;;
    phasee3)
      cmd_phasee3 "$@"
      ;;
    list)
      cmd_list "$@"
      ;;
    emit)
      cmd_emit "$@"
      ;;
    emit-policy)
      cmd_emit_policy "$@"
      ;;
    emit-policy-unique)
      cmd_emit_policy_unique "$@"
      ;;
    stats)
      cmd_stats "$@"
      ;;
    reset-stats)
      cmd_reset_stats "$@"
      ;;
    set-dnd)
      cmd_set_dnd "$@"
      ;;
    set-quiet)
      cmd_set_quiet "$@"
      ;;
    burst)
      cmd_burst "$@"
      ;;
    cooldown-check)
      cmd_cooldown_check "$@"
      ;;
    rate-check)
      cmd_rate_check "$@"
      ;;
    matrix)
      cmd_matrix "$@"
      ;;
    scenario-connection)
      cmd_scenario_connection "$@"
      ;;
    scenario-lianclaw)
      cmd_scenario_lianclaw "$@"
      ;;
    scenario-resource)
      cmd_scenario_resource "$@"
      ;;
    scenario-power)
      cmd_scenario_power "$@"
      ;;
    priority-check)
      cmd_priority_check "$@"
      ;;
    quiet-boundary-check)
      cmd_quiet_boundary_check "$@"
      ;;
    high-bypass-check)
      cmd_high_bypass_check "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "[di_test] unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
