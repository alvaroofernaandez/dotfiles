#!/usr/bin/env bash
# Tests for metrics.sh, the tmux status-right renderer.
#
# This script runs on every status refresh, so its cost is paid continuously.
# The budget below is part of the contract, not a nicety.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/metrics.sh"
BUDGET_MS=100

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }
assert_contains() {
  case "$3" in
    *"$2"*) ok "$1" ;;
    *) ko "$1" "text containing: $2" "$3" ;;
  esac
}

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time*1000'; }

echo "metrics"

out="$(bash "$SCRIPT" 2>&1)"
rc=$?

# --- output contract ---------------------------------------------------------
assert_eq "exits successfully" "0" "$rc"
assert_eq "produces output" "yes" "$([ -n "$out" ] && echo yes || echo no)"
assert_contains "reports CPU" "CPU" "$out"
assert_contains "reports RAM" "RAM" "$out"
assert_contains "emits tmux colour markup" "#[fg=" "$out"
assert_eq "stays on a single line" "1" "$(printf '%s' "$out" | wc -l | tr -d ' ' | sd '^0$' '1')"

# --- values are sane ---------------------------------------------------------
cpu="$(printf '%s' "$out" | rg -o '[0-9]+\.[0-9]+%' | head -1 | sd '%' '')"
assert_eq "CPU percentage is present" "yes" \
  "$([ -n "$cpu" ] && echo yes || echo no)"
assert_eq "CPU percentage is within 0-100" "yes" \
  "$(awk -v v="${cpu:--1}" 'BEGIN { print (v >= 0 && v <= 100) ? "yes" : "no" }')"

used="$(printf '%s' "$out" | rg -o '[0-9]+\.[0-9]+/[0-9]+\.[0-9]+G' | head -1 | sd 'G' '')"
u="${used%%/*}"; t="${used##*/}"
assert_eq "RAM is reported as used/total" "yes" \
  "$([ -n "$u" ] && [ -n "$t" ] && echo yes || echo no)"
assert_eq "RAM used never exceeds total" "yes" \
  "$(awk -v u="${u:--1}" -v t="${t:-0}" 'BEGIN { print (u >= 0 && u <= t) ? "yes" : "no" }')"

# --- performance contract ----------------------------------------------------
# Warm run, so the first-call page-in cost is not what is being measured.
bash "$SCRIPT" >/dev/null 2>&1
t0="$(now_ms)"
bash "$SCRIPT" >/dev/null 2>&1
t1="$(now_ms)"
elapsed=$((t1 - t0))
[ "$elapsed" -lt "$BUDGET_MS" ] \
  && ok "runs in under ${BUDGET_MS}ms (took ${elapsed}ms)" && pass=$((pass)) \
  || ko "runs in under ${BUDGET_MS}ms" "< ${BUDGET_MS}ms" "${elapsed}ms"
[ "$elapsed" -lt "$BUDGET_MS" ] || true

# --- the expensive calls must stay gone --------------------------------------
# Comment lines are stripped first: these names legitimately appear in the
# rationale at the top of the script, and matching those would be a false alarm.
code="$(rg -v '^\s*#' "$SCRIPT")"
assert_eq "does not shell out to top" "absent" \
  "$(printf '%s' "$code" | rg -q '\btop\b' && echo present || echo absent)"
assert_eq "does not start a python interpreter" "absent" \
  "$(printf '%s' "$code" | rg -q '\bpython3?\b' && echo present || echo absent)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
