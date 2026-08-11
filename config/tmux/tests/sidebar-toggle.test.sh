#!/usr/bin/env bash
# Tests for sidebar-toggle.sh, run against an isolated tmux server so the
# user's live session is never touched.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sidebar-toggle.sh"
SOCKET="sidebar-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"

pass=0
fail=0

cleanup() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }

assert_eq() {
  [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"
}

# A fresh single-pane window for every test.
reset_session() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  "${TMUX_TEST[@]}" new-session -d -s main -c "$WORKDIR" -x 200 -y 50
}

toggle() {
  # `sleep 600` stands in for yazi: same pane lifecycle, no TUI rendering.
  # Invoked directly rather than through `run-shell -b`, which detaches and
  # swallows both the exit status and stderr.
  SIDEBAR_CMD="sleep 600" TMUX_SOCKET="$SOCKET" bash "$SCRIPT"
}

panes() { "${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}' | wc -l | tr -d ' '; }

echo "sidebar-toggle"

# --- opening ---------------------------------------------------------------
reset_session
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
toggle
assert_eq "opens a second pane" "2" "$(panes)"

sidebar="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id} #{@sidebar}' | awk '$2=="1"{print $1}')"
[ -n "$sidebar" ] && ok "marks the new pane with @sidebar" || ko "marks the new pane with @sidebar" "a pane id" "(none)"

assert_eq "does not mark the working pane" \
  "" "$("${TMUX_TEST[@]}" display -p -t "$work_pane" '#{@sidebar}')"

# Leftmost pane => x offset 0 and narrower than the working pane.
assert_eq "places the sidebar on the left" \
  "0" "$("${TMUX_TEST[@]}" display -p -t "$sidebar" '#{pane_left}')"

sidebar_w="$("${TMUX_TEST[@]}" display -p -t "$sidebar" '#{pane_width}')"
work_w="$("${TMUX_TEST[@]}" display -p -t "$work_pane" '#{pane_width}')"
[ "$sidebar_w" -lt "$work_w" ] && ok "sidebar is narrower than the working pane" \
  || ko "sidebar is narrower than the working pane" "< $work_w" "$sidebar_w"

assert_eq "inherits the working directory" \
  "$(cd "$WORKDIR" && pwd -P)" \
  "$(cd "$("${TMUX_TEST[@]}" display -p -t "$sidebar" '#{pane_current_path}')" && pwd -P)"

assert_eq "focuses the sidebar so it is usable immediately" \
  "$sidebar" "$("${TMUX_TEST[@]}" display -p -t main '#{pane_id}')"

# --- closing ---------------------------------------------------------------
toggle
assert_eq "second toggle closes the sidebar" "1" "$(panes)"
assert_eq "keeps the working pane alive" \
  "$work_pane" "$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"

# --- idempotency -----------------------------------------------------------
toggle
assert_eq "reopens after closing" "2" "$(panes)"

# --- isolation -------------------------------------------------------------
# A sidebar belongs to its window; a second window must be unaffected.
"${TMUX_TEST[@]}" new-window -t main -c "$WORKDIR"
assert_eq "other windows have no sidebar" \
  "1" "$("${TMUX_TEST[@]}" list-panes -F '#{pane_id}' | wc -l | tr -d ' ')"

# --- failure reporting ------------------------------------------------------
# A stale TMUX_PANE (e.g. inherited from another tmux server) must not be
# swallowed: a keybind that silently does nothing is the worst outcome.
reset_session
SIDEBAR_CMD="sleep 600" TMUX_SOCKET="$SOCKET" TMUX_PANE="%999" bash "$SCRIPT" >/dev/null 2>&1
rc=$?
assert_eq "exits non-zero when the target pane is stale" \
  "nonzero" "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
