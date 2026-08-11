#!/usr/bin/env bash
# Tests for the clickable sidebar button in the tmux status bar.
#
# The button exists because the keyboard route is fragile on this machine: on a
# Spanish ISO layout Option+E is a dead key, and Option handling in general
# depends on macos-option-as-alt. A mouse target depends on none of that.
set -uo pipefail

CONF="$HOME/.tmux.conf"
SOCKET="btn-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")

pass=0
fail=0

cleanup() { "${TMUX_TEST[@]}" kill-server 2>/dev/null; }
trap cleanup EXIT

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }
assert_contains() {
  case "$3" in
    *"$2"*) ok "$1" ;;
    *) ko "$1" "text containing: $2" "$3" ;;
  esac
}

echo "sidebar-button"

"${TMUX_TEST[@]}" -f "$CONF" new-session -d -x 200 -y 24 2>/dev/null
sleep 1.5

left="$("${TMUX_TEST[@]}" show -gv status-left 2>/dev/null)"
root_keys="$("${TMUX_TEST[@]}" list-keys -T root 2>/dev/null)"

# --- the button is present and clickable -------------------------------------
assert_contains "status-left declares a clickable range" "range=user|sidebar" "$left"
assert_contains "the range is closed with norange" "norange" "$left"
assert_contains "the button carries a readable label" "FILES" "$left"

# --- mouse handling ----------------------------------------------------------
assert_contains "a status click is bound" "MouseDown1Status" "$root_keys"
assert_eq "the click handler checks which range was hit" "yes" \
  "$(printf '%s' "$root_keys" | rg -q 'MouseDown1Status.*mouse_status_range' && echo yes || echo no)"
assert_eq "clicking the button runs the toggle" "yes" \
  "$(printf '%s' "$root_keys" | rg -q 'MouseDown1Status.*sidebar-toggle' && echo yes || echo no)"
assert_eq "mouse support is enabled" "on" \
  "$("${TMUX_TEST[@]}" show -gv mouse 2>/dev/null)"

# --- clicking elsewhere on the bar must keep working -------------------------
# The default MouseDown1Status action selects a window. Overriding it blindly
# would break clicking on the window list.
assert_eq "clicking outside the button still selects a window" "yes" \
  "$(printf '%s' "$root_keys" | rg -q 'MouseDown1Status.*select-window' && echo yes || echo no)"

# --- DESIGN.md: a control must not look like a metric ------------------------
# Metric segments are solid blocks (bg=colourNNN). The button is not.
button="$(printf '%s' "$left" | rg -o 'range=user\|sidebar.*?norange' | head -1)"
assert_eq "the button is not painted as a solid metric block" "yes" \
  "$(printf '%s' "$button" | rg -q 'bg=colour[0-9]' && echo no || echo yes)"
assert_eq "the button renders in plain ASCII" "yes" \
  "$(LC_ALL=C printf '%s' "$button" | rg -q '[^\x00-\x7F]' && echo no || echo yes)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
