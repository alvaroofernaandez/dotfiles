#!/usr/bin/env bash
# Tests for the bounded-wait helpers used by the tmux end-to-end suites.
#
# The suites drive a real tmux server and then read the result back with
# capture-pane or display -p. Between the action and the read sits work the
# test does not control: a pane spawning, a shell starting, yazi painting, a
# directory change landing. That gap used to be bridged with a fixed `sleep`.
#
# A fixed sleep is a bet on machine speed, and CI loses it. The same commit
# failed twice in a row on GitHub's runners in two DIFFERENT suites — once with
# capture-pane returning an empty pane, once with a path that had not updated
# yet — while passing every time locally. Rotating failures on an unchanged
# commit are a race, and raising the sleep only moves the threshold.
#
# These helpers replace the bet with a poll. The contract they must honour:
#
#   1. return as soon as the condition holds, WITHOUT burning the timeout —
#      otherwise every suite pays the worst case on every assertion and the
#      test run becomes too slow to sit through
#   2. keep retrying while it does not hold, and still succeed if it becomes
#      true late — the actual bug being fixed
#   3. on timeout, hand back the LAST value seen rather than an empty string,
#      so the failing assertion reports what the pane really contained. A
#      timeout that reports nothing sends you off to re-run the suite by hand,
#      and a race may not reproduce when you do.
set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/wait.sh"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "wait-helpers"

assert_eq "config/tmux/tests/lib/wait.sh exists" "yes" \
  "$([ -f "$LIB" ] && echo yes || echo no)"
[ -f "$LIB" ] || { printf '\n%d passed, %d failed\n' "$pass" $((fail + 1)); exit 1; }

# shellcheck source=/dev/null
. "$LIB"

assert_eq "wait_until is defined" "function" "$(type -t wait_until 2>/dev/null)"
assert_eq "wait_for is defined" "function" "$(type -t wait_for 2>/dev/null)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- returns immediately when the condition already holds --------------------
# The speed claim is the one that decides whether these helpers are usable at
# all: 37 sleeps across the suites, each paying its full budget, would turn a
# 90-second run into a multi-minute one.
start=$SECONDS
out="$(wait_until 10 "ready" printf 'the pane is ready\n')"
elapsed=$(( SECONDS - start ))
assert_eq "matches text already present" "the pane is ready" "$out"
assert_eq "returns without burning the timeout" "yes" \
  "$([ "$elapsed" -lt 2 ] && echo yes || echo no)"
wait_until 10 "ready" printf 'the pane is ready\n' >/dev/null
assert_eq "exits 0 on a match" "0" "$?"

# --- retries until the condition becomes true --------------------------------
# The real scenario: the value is wrong at first read and right a moment later.
# A counter file stands in for the pane, returning the wrong thing twice before
# settling — a fixed sleep shorter than that settling time is exactly the bug.
printf '0' >"$TMP/count"
late_value() {
  local n
  n="$(cat "$TMP/count")"
  printf '%s' $((n + 1)) >"$TMP/count"
  if [ "$n" -ge 2 ]; then printf 'settled path\n'; else printf 'stale path\n'; fi
}
out="$(wait_until 10 "settled" late_value)"
assert_eq "keeps polling until the value settles" "settled path" "$out"

# --- times out, and reports what it last saw ---------------------------------
never() { printf 'still empty\n'; }
out="$(wait_until 1 "never appears" never)"
rc=$?
assert_eq "exits non-zero on timeout" "yes" "$([ "$rc" -ne 0 ] && echo yes || echo no)"
assert_eq "returns the last value seen, not an empty string" "still empty" "$out"

# A pane that never paints returns nothing at all; the helper must not hang or
# error on that, it must simply time out with the empty value.
empty() { printf ''; }
out="$(wait_until 1 "anything" empty)"
assert_eq "tolerates a command that outputs nothing" "" "$out"

# --- respects the deadline ---------------------------------------------------
start=$SECONDS
wait_until 1 "never appears" never >/dev/null
elapsed=$(( SECONDS - start ))
assert_eq "gives up close to the deadline" "yes" \
  "$([ "$elapsed" -ge 1 ] && [ "$elapsed" -le 3 ] && echo yes || echo no)"

# --- wait_for polls an exit status -------------------------------------------
# For conditions that are not a substring of any output: two pane ids being
# distinct, a pane having appeared at all.
printf '0' >"$TMP/count2"
becomes_true() {
  local n
  n="$(cat "$TMP/count2")"
  printf '%s' $((n + 1)) >"$TMP/count2"
  [ "$n" -ge 2 ]
}
wait_for 10 becomes_true
assert_eq "wait_for retries until the command exits 0" "0" "$?"

wait_for 1 false
assert_eq "wait_for exits non-zero on timeout" "yes" \
  "$([ $? -ne 0 ] && echo yes || echo no)"

start=$SECONDS
wait_for 10 true
elapsed=$(( SECONDS - start ))
assert_eq "wait_for returns immediately when already true" "yes" \
  "$([ "$elapsed" -lt 2 ] && echo yes || echo no)"

# --- arguments are passed through, not re-parsed -----------------------------
# The suites call these with tmux argument arrays that contain spaces and
# format strings like '#{pane_current_path}'. Passing the command as a string
# through eval would mangle those; taking it as "$@" keeps them intact.
out="$(wait_until 5 "two words" printf '%s\n' "two words here")"
assert_eq "passes arguments containing spaces intact" "two words here" "$out"
out="$(wait_until 5 "pane_current" printf '%s\n' '#{pane_current_path}')"
assert_eq "passes a tmux format string intact" '#{pane_current_path}' "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
