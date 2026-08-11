#!/usr/bin/env bash
# Tests for statusbar.sh, the tmux status-right renderer.
#
# These encode .agents/DESIGN.md: segment colours, contrast pairing, the ASCII
# constraint, and the performance budget. This script runs on every status
# refresh, so its cost is paid continuously and is part of the contract.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/statusbar.sh"
BUDGET_MS=100

# DESIGN.md §2 — Kanagawa roles. Each segment owns one colour.
INK=235
declare -a ROLES=(110 140 108 179 174)   # CPU GPU RAM time date

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

echo "statusbar"

out="$(bash "$SCRIPT" 2>&1)"
rc=$?

# --- output contract ---------------------------------------------------------
assert_eq "exits successfully" "0" "$rc"
assert_eq "produces output" "yes" "$([ -n "$out" ] && echo yes || echo no)"
assert_eq "stays on a single row" "1" \
  "$(printf '%s' "$out" | wc -l | tr -d ' ' | sd '^0$' '1')"

for label in CPU GPU RAM; do
  assert_contains "labels the $label segment" "$label" "$out"
done

# --- DESIGN.md §2: one colour per segment, all on ink text -------------------
for role in "${ROLES[@]}"; do
  assert_contains "segment background colour$role is used" "bg=colour$role" "$out"
done

assert_eq "every segment pairs its background with ink text" "yes" \
  "$(bg_count=$(printf '%s' "$out" | rg -o 'bg=colour[0-9]+' | wc -l | tr -d ' ');
     ink_count=$(printf '%s' "$out" | rg -o "fg=colour$INK" | wc -l | tr -d ' ');
     [ "$bg_count" -gt 0 ] && [ "$bg_count" -eq "$ink_count" ] && echo yes || echo no)"

assert_eq "resets styling after each segment" "yes" \
  "$(seg=$(printf '%s' "$out" | rg -o 'bg=colour[0-9]+' | wc -l | tr -d ' ');
     rst=$(printf '%s' "$out" | rg -o '#\[default\]' | wc -l | tr -d ' ');
     [ "$rst" -ge "$seg" ] && echo yes || echo no)"

# --- DESIGN.md §7: plain ASCII only, no powerline glyphs ---------------------
assert_eq "renders in plain ASCII" "yes" \
  "$(LC_ALL=C rg -q '[^\x00-\x7F]' <<< "$out" && echo no || echo yes)"

# --- values are sane ---------------------------------------------------------
cpu="$(printf '%s' "$out" | rg -o 'CPU [0-9]+' | head -1 | sd 'CPU ' '')"
gpu="$(printf '%s' "$out" | rg -o 'GPU [0-9]+' | head -1 | sd 'GPU ' '')"
assert_eq "CPU percentage within 0-100" "yes" \
  "$(awk -v v="${cpu:--1}" 'BEGIN { print (v >= 0 && v <= 100) ? "yes" : "no" }')"
assert_eq "GPU percentage within 0-100" "yes" \
  "$(awk -v v="${gpu:--1}" 'BEGIN { print (v >= 0 && v <= 100) ? "yes" : "no" }')"

ram="$(printf '%s' "$out" | rg -o 'RAM [0-9]+\.[0-9]/[0-9]+\.[0-9]G' | head -1)"
assert_eq "RAM reported as used/total" "yes" \
  "$([ -n "$ram" ] && echo yes || echo no)"
u="$(printf '%s' "$ram" | sd 'RAM ([0-9.]+)/.*' '$1')"
t="$(printf '%s' "$ram" | sd '.*/([0-9.]+)G' '$1')"
assert_eq "RAM used never exceeds total" "yes" \
  "$(awk -v u="${u:--1}" -v t="${t:-0}" 'BEGIN { print (u >= 0 && u <= t) ? "yes" : "no" }')"

# --- clock and date ----------------------------------------------------------
assert_eq "renders a 24h clock" "yes" \
  "$(printf '%s' "$out" | rg -q '\b([01][0-9]|2[0-3]):[0-5][0-9]\b' && echo yes || echo no)"
assert_eq "renders a day and month" "yes" \
  "$(printf '%s' "$out" | rg -q '\b[0-9]{1,2} [A-Z][a-z]{2}\b' && echo yes || echo no)"

# --- DESIGN.md §3: width budget ----------------------------------------------
plain="$(printf '%s' "$out" | sd '#\[[^]]*\]' '')"
cols="${#plain}"
[ "$cols" -le 60 ] \
  && ok "fits the 60-column right-side budget (${cols} cols)" \
  || ko "fits the 60-column right-side budget" "<= 60 cols" "${cols} cols"

# DESIGN.md §2 — the row ends at the last segment. Its inner padding space is
# required, so what must not survive is the separator after it: the tell is a
# dangling gap after the final reset, i.e. two spaces at the end of the plain row.
assert_eq "leaves no separator dangling after the last segment" "yes" \
  "$(printf '%s' "$out" | rg -q '#\[default\] $' && echo no || echo yes)"
assert_eq "keeps exactly one padding space at the end" "yes" \
  "$(printf '%s' "$plain" | rg -q '  $' && echo no || echo yes)"

# --- locale independence -----------------------------------------------------
# tmux inherits whatever environment launched the server. Under es_ES awk emits
# a comma decimal separator and date emits Spanish month names of varying width.
es_out="$(LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8 bash "$SCRIPT" 2>/dev/null | sd '[0-9]' 'N')"
c_out="$(LANG=C LC_ALL=C bash "$SCRIPT" 2>/dev/null | sd '[0-9]' 'N')"
assert_eq "renders identically regardless of locale" "$c_out" "$es_out"
assert_eq "uses a dot as decimal separator" "yes" \
  "$(LANG=es_ES.UTF-8 bash "$SCRIPT" 2>/dev/null | rg -q 'RAM [0-9]+\.[0-9]' && echo yes || echo no)"

# --- DESIGN.md §7: performance budget ----------------------------------------
bash "$SCRIPT" >/dev/null 2>&1
t0="$(now_ms)"; bash "$SCRIPT" >/dev/null 2>&1; t1="$(now_ms)"
elapsed=$((t1 - t0))
[ "$elapsed" -lt "$BUDGET_MS" ] \
  && ok "runs in under ${BUDGET_MS}ms (took ${elapsed}ms)" \
  || ko "runs in under ${BUDGET_MS}ms" "< ${BUDGET_MS}ms" "${elapsed}ms"

# --- the expensive calls must stay gone --------------------------------------
# Comments are stripped: these names appear legitimately in the rationale.
code="$(rg -v '^\s*#' "$SCRIPT")"
assert_eq "does not shell out to top" "absent" \
  "$(printf '%s' "$code" | rg -q '\btop\b' && echo present || echo absent)"
assert_eq "does not start a python interpreter" "absent" \
  "$(printf '%s' "$code" | rg -q '\bpython3?\b' && echo present || echo absent)"
assert_eq "does not call powermetrics (needs sudo)" "absent" \
  "$(printf '%s' "$code" | rg -q '\bpowermetrics\b' && echo present || echo absent)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
