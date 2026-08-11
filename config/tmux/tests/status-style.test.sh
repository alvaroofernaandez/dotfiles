#!/usr/bin/env bash
# Tests for the status bar's own styling, as resolved by a real tmux server.
#
# These assert the EFFECTIVE value after the whole config has loaded, including
# TPM plugins. Asserting on the text of tmux.conf would miss the actual failure
# mode here: the kanagawa theme assigns during plugin load and overwrites
# anything set earlier in the file.
set -uo pipefail

CONF="$HOME/.tmux.conf"
SOCKET="style-test-$$"
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

echo "status-style"

"${TMUX_TEST[@]}" -f "$CONF" new-session -d -x 200 -y 24 2>/dev/null
sleep 2   # TPM loads plugins asynchronously; styles settle after it finishes.

style="$("${TMUX_TEST[@]}" show -gv status-style 2>/dev/null)"

# --- DESIGN.md §2: the bar inherits the terminal background -------------------
assert_contains "status background is default (inherits the terminal)" \
  "bg=default" "$style"
assert_eq "status background is not tmux's green default" "yes" \
  "$(printf '%s' "$style" | rg -q 'bg=green' && echo no || echo yes)"
assert_eq "status foreground is set explicitly" "yes" \
  "$(printf '%s' "$style" | rg -q 'fg=' && echo yes || echo no)"

for opt in status-left-style status-right-style; do
  v="$("${TMUX_TEST[@]}" show -gv "$opt" 2>/dev/null)"
  assert_eq "$opt does not paint a green band" "yes" \
    "$(printf '%s' "$v" | rg -q 'bg=green' && echo no || echo yes)"
done

# --- window list stays readable on a transparent bar -------------------------
cur="$("${TMUX_TEST[@]}" show -gv window-status-current-style 2>/dev/null)"
assert_eq "current window is distinguishable" "yes" \
  "$([ -n "$cur" ] && [ "$cur" != "default" ] && echo yes || echo no)"

# --- the segments still render -----------------------------------------------
right="$("${TMUX_TEST[@]}" show -gv status-right 2>/dev/null)"
assert_contains "status-right still runs the segment bar" "statusbar.sh" "$right"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
