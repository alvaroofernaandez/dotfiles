#!/usr/bin/env bash
# Tests for sidebar-toggle.sh, run against an isolated tmux server so the
# user's live session is never touched.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sidebar-toggle.sh"
SOCKET="sidebar-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"

# Bounded waits, so the end-to-end assertions poll for panes to settle instead
# of betting a fixed sleep on how fast the machine is.
# shellcheck source=lib/wait.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/wait.sh"

# Run these tests inside tmux — which is how they are actually run — and the
# developer's own TMUX_PANE leaks into every invocation of the script. The
# script honours it, so it resolves a pane id belonging to the REAL server
# while talking to the isolated one, and every assertion about panes fails
# with "can't find pane". Each case that needs a target sets TMUX_PANE
# explicitly; the rest must fall back to the test server's active window.
unset TMUX TMUX_PANE

pass=0
fail=0

cleanup() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  # The multi-window block runs on its own socket; without this the server it
  # started outlives the suite, and run-all.sh then waits on a pipe held open
  # by a `sleep 600` parked inside one of its panes.
  [ -n "${SOCKET_MW:-}" ] && tmux -L "$SOCKET_MW" kill-server 2>/dev/null
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

# --- runs under launchd's minimal PATH ---------------------------------------
# tmux's run-shell inherits the SERVER's environment. When Ghostty starts the
# server, that PATH is launchd's minimal one, with no /opt/homebrew/bin. A bare
# `tmux` inside the script is then not found and the whole thing exits 127,
# which is exactly how this failed in practice.
#
# launchd is macOS. On Linux this reconstructs an environment that machine
# never has, and the failure says nothing about the script — the binaries it
# looks for simply live elsewhere. Skipped there, loudly, rather than asserted
# against a scenario that cannot occur.
if [ "$(uname)" != "Darwin" ]; then
  for t in "runs under launchd's minimal PATH" \
           "does not fail with command-not-found" \
           "opens the sidebar under minimal PATH" \
           "the real sidebar command survives under minimal PATH" \
           "the sidebar pane is not dead"; do
    printf '  \033[33mSKIP\033[0m %s (launchd is macOS-only)\n' "$t"
  done
else
reset_session
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
minimal_out="$(env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" \
  SIDEBAR_CMD="sleep 600" TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" \
  /bin/bash "$SCRIPT" 2>&1)"
minimal_rc=$?

assert_eq "runs under launchd's minimal PATH" "0" "$minimal_rc"
assert_eq "does not fail with command-not-found" "yes" \
  "$(printf '%s' "$minimal_out" | rg -qi 'not found|command not found' && echo no || echo yes)"
assert_eq "opens the sidebar under minimal PATH" "2" "$(panes)"

# The pane surviving matters more than the pane being created. With the real
# SIDEBAR_CMD under a minimal PATH, tmux opens the pane, the command fails to
# resolve, and the pane dies immediately — which looks like the sidebar
# "flickering and closing". Using `sleep` as a stand-in hides this entirely,
# because /bin/sleep resolves anywhere.
reset_session
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" \
  TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" /bin/bash "$SCRIPT" >/dev/null 2>&1
sleep 2.5

assert_eq "the real sidebar command survives under minimal PATH" "2" "$(panes)"
assert_eq "the sidebar pane is not dead" "0" \
  "$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_dead}' 2>/dev/null | rg -c '^1$' || echo 0)"
fi   # end of the macOS-only launchd block

# --- two windows in parallel, each with its own sidebar ----------------------
# Working on two projects at once is the normal case. Each window's sidebar must
# start in ITS OWN directory: `split-window -t <pane> -c '#{pane_current_path}'`
# creates the pane in the right window but expands -c against the ACTIVE pane,
# so the second sidebar inherited the first project's directory.
#
# This block runs on a socket of its own instead of doing `kill-server` on the
# shared one and building back up. That pattern is a race, and it is the race
# that made CI red: kill-server only STARTS the shutdown, so the new-session
# that follows can create its session on a server that is still dying. The old
# server then finishes, unlinks the socket, and takes the new session with it.
# Every later command fails with "no server running", every variable comes back
# empty, and the assertions report a broken sidebar that was never built.
#
# No amount of waiting fixes that shape — polling waits for something that will
# never arrive. A fresh socket cannot collide with a server that is shutting
# down, so the race is removed rather than widened.
#
# Reproduced with: docker run --cpus 0.4, which fails this block roughly one run
# in six on the old code and never on this one.
SOCKET_MW="$SOCKET-multiwindow"
TMUX_MW=(tmux -L "$SOCKET_MW")
dir_a="$WORKDIR/proyecto-a"; dir_b="$WORKDIR/proyecto-b"
mkdir -p "$dir_a" "$dir_b"

# A shell has to be up before a pane reports its own directory, and there is no
# way to know in advance how long that takes. This block used to bridge the gap
# with a fixed sleep, raised once from 0.4s to 1.2s when a slower machine read
# the process working directory instead of the project one.
#
# Raising it again would not have helped. On CI these three assertions failed
# with exactly that symptom — /home/runner/work/dotfiles/dotfiles where the
# project path was expected — while passing locally every time, and a rerun of
# the same commit moved the failure to a different suite entirely. A fixed
# sleep is a bet on machine speed; the polls below wait for the condition
# itself, so a fast machine spends no time here and a slow one gets what it
# needs.
"${TMUX_MW[@]}" new-session -d -s main -c "$dir_a" -x 200 -y 50
win_a="$(wait_until 10 '@' "${TMUX_MW[@]}" list-windows -t main -F '#{window_id}')"
pane_a="$(wait_until 10 '%' "${TMUX_MW[@]}" list-panes -t "$win_a" -F '#{pane_id}')"

"${TMUX_MW[@]}" new-window -t main -c "$dir_b"
last_window() { "${TMUX_MW[@]}" list-windows -t main -F '#{window_id}' | tail -1; }
# Poll until the newest window id differs from A's. Reading the list too early
# returns A again, and every assertion below would then compare A with itself
# and pass for the wrong reason — worse than failing.
window_b_appeared() { [ "$(last_window)" != "$win_a" ]; }
wait_for 10 window_b_appeared
win_b="$(last_window)"
pane_b="$(wait_until 10 '%' "${TMUX_MW[@]}" list-panes -t "$win_b" -F '#{pane_id}')"

# Window B is active here, so opening A's sidebar is the case that used to break.
SIDEBAR_CMD="sleep 600" TMUX_SOCKET="$SOCKET_MW" TMUX_PANE="$pane_a" bash "$SCRIPT" >/dev/null 2>&1
SIDEBAR_CMD="sleep 600" TMUX_SOCKET="$SOCKET_MW" TMUX_PANE="$pane_b" bash "$SCRIPT" >/dev/null 2>&1

# A tmux pane id always starts with '%', so it doubles as the "not empty yet"
# marker: reading the pane list straight after the toggle can return nothing.
sidebar_of() {
  "${TMUX_MW[@]}" list-panes -t "$1" -F '#{pane_id}|#{?@sidebar,1,0}' \
    | awk -F'|' '$2=="1"{print $1}'
}
sb_a="$(wait_until 10 '%' sidebar_of "$win_a")"
sb_b="$(wait_until 10 '%' sidebar_of "$win_b")"

assert_eq "each window gets its own sidebar" "yes" \
  "$([ -n "$sb_a" ] && [ -n "$sb_b" ] && [ "$sb_a" != "$sb_b" ] && echo yes || echo no)"

# Resolved through `cd && pwd -P` because on macOS /tmp is a symlink to
# /private/tmp: tmux reports the unresolved path and the expectation is
# resolved, so comparing the raw strings fails on a correct sidebar.
sidebar_path() {
  local p
  p="$("${TMUX_MW[@]}" display -p -t "$1" '#{pane_current_path}' 2>/dev/null)"
  [ -n "$p" ] || return 1
  (cd "$p" 2>/dev/null && pwd -P)
}

want_a="$(cd "$dir_a" && pwd -P)"
want_b="$(cd "$dir_b" && pwd -P)"

assert_eq "window A's sidebar starts in project A" \
  "$want_a" "$(wait_until 10 "$want_a" sidebar_path "$sb_a")"

assert_eq "window B's sidebar starts in project B" \
  "$want_b" "$(wait_until 10 "$want_b" sidebar_path "$sb_b")"

# --- terminal passthrough for yazi -------------------------------------------
# yazi sends DA1/DSR probes at startup to detect terminal features. With
# allow-passthrough off, tmux blocks them, yazi waits for the timeout and prints
# "Terminal response timeout" over the panel for several seconds before drawing.
"${TMUX_TEST[@]}" kill-server 2>/dev/null
"${TMUX_TEST[@]}" -f "$HOME/.tmux.conf" new-session -d 2>/dev/null
sleep 1.5
# Read from the full installed ~/.tmux.conf, which runs TPM and its plugins.
# Where those are not installed the server does not reach this option and the
# read comes back empty — a statement about the plugin set, not about
# passthrough.
if [ "$(uname)" = "Darwin" ]; then
  assert_eq "allow-passthrough is enabled for yazi's probes" "on" \
    "$("${TMUX_TEST[@]}" show -gv allow-passthrough 2>/dev/null)"
else
  printf '  \033[33mSKIP\033[0m allow-passthrough (needs the full plugin set)\n'
fi

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
