#!/usr/bin/env bash
# Tests for open-file.sh, run against an isolated tmux server so the user's
# live session is never touched.
#
# Contract: opening a file from the sidebar creates a NEW tmux window. Whatever
# is running in the current window — a build, a REPL, an editor with unsaved
# work — is never touched, never has keys sent into it, and never loses focus
# state. That is the whole point of using a window instead of the work pane.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/open-file.sh"
SOCKET="openfile-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"
ARGS_FILE="$WORKDIR/args.txt"

pass=0
fail=0

cleanup() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  rm -rf "$WORKDIR"
}
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

# A fake editor that records the argv it received and then blocks, so the
# window stays open exactly as a real editor would.
mkdir -p "$WORKDIR/bin"
cat > "$WORKDIR/bin/fakeedit" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$ARGS_FILE"
sleep 600
EOF
chmod +x "$WORKDIR/bin/fakeedit"
FAKE_EDITOR="$WORKDIR/bin/fakeedit"

windows() { "${TMUX_TEST[@]}" list-windows -F '#{window_id}' 2>/dev/null | wc -l | tr -d ' '; }
wait_for_args() {
  local i
  for i in $(seq 1 60); do [ -s "$ARGS_FILE" ] && return 0; sleep 0.1; done
  return 1
}

setup_session() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  rm -f "$ARGS_FILE"
  "${TMUX_TEST[@]}" new-session -d -s main -c "$WORKDIR" -x 200 -y 50
  sleep 0.4
}

open_file() {
  TMUX_SOCKET="$SOCKET" EDITOR="$FAKE_EDITOR" bash "$SCRIPT" "$@" 2>&1
}

echo "open-file"

# --- opens in a new window ---------------------------------------------------
setup_session
printf 'PORT=3000\n' > "$WORKDIR/.env"
before_win="$(windows)"
before_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
open_file "$WORKDIR/.env" >/dev/null
wait_for_args

assert_eq "creates a new window" "$((before_win + 1))" "$(windows)"
assert_eq "runs the editor with the right argv" \
  "$WORKDIR/.env" "$(tail -1 "$ARGS_FILE" 2>/dev/null)"

# --- the current work is untouched -------------------------------------------
assert_eq "does not split the original window" "1" \
  "$("${TMUX_TEST[@]}" list-panes -t "$before_pane" -F '#{pane_id}' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "leaves the original pane alive" "$before_pane" \
  "$("${TMUX_TEST[@]}" list-panes -t "$before_pane" -F '#{pane_id}' 2>/dev/null)"
assert_eq "sends no keystrokes into the original pane" "" \
  "$("${TMUX_TEST[@]}" capture-pane -p -t "$before_pane" 2>/dev/null | rg -o 'fakeedit' | head -1)"

# --- a busy window is irrelevant now -----------------------------------------
# The old design refused when the work pane was busy. Opening a window sidesteps
# that entirely: a running process is simply never involved.
setup_session
busy_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
"${TMUX_TEST[@]}" send-keys -t "$busy_pane" "sleep 600" Enter
sleep 0.8
busy_before="$("${TMUX_TEST[@]}" capture-pane -p -t "$busy_pane")"
open_file "$WORKDIR/.env" >/dev/null
wait_for_args

assert_eq "opens even while the current window is busy" "2" "$(windows)"
# Anchored to the pane id, not to the session: new-window moves focus, so a
# session target would capture the newly opened window instead.
assert_eq "the busy process is left undisturbed" \
  "$busy_before" "$("${TMUX_TEST[@]}" capture-pane -p -t "$busy_pane")"
assert_eq "the busy command is still running" "sleep" \
  "$("${TMUX_TEST[@]}" display -p -t "$busy_pane" '#{pane_current_command}' 2>/dev/null)"

# --- window naming -----------------------------------------------------------
setup_session
open_file "$WORKDIR/.env" >/dev/null
wait_for_args
assert_contains "names the window after the file" ".env" \
  "$("${TMUX_TEST[@]}" list-windows -F '#{window_name}' 2>/dev/null | tr '\n' ' ')"

# --- paths with spaces -------------------------------------------------------
setup_session
spaced="$WORKDIR/my notes.md"
printf '# hi\n' > "$spaced"
open_file "$spaced" >/dev/null
wait_for_args
assert_eq "a path with spaces arrives as one argument" \
  "$spaced" "$(tail -1 "$ARGS_FILE" 2>/dev/null)"

# --- multiple files ----------------------------------------------------------
setup_session
printf 'a\n' > "$WORKDIR/a.md"; printf 'b\n' > "$WORKDIR/b.md"
open_file "$WORKDIR/a.md" "$WORKDIR/b.md" >/dev/null
wait_for_args
assert_eq "passes every selected file" \
  "$(printf '%s\n%s' "$WORKDIR/a.md" "$WORKDIR/b.md")" \
  "$(cat "$ARGS_FILE" 2>/dev/null)"

# --- runs under launchd's minimal PATH ---------------------------------------
# yazi's opener inherits the tmux server's environment, which is launchd's
# minimal PATH when Ghostty started the server.
setup_session
env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" \
  TMUX_SOCKET="$SOCKET" EDITOR="$FAKE_EDITOR" /bin/bash "$SCRIPT" "$WORKDIR/.env" >/dev/null 2>&1
sleep 1.5
assert_eq "opens a window under minimal PATH" "2" "$(windows)"

# --- fallback outside tmux ---------------------------------------------------
rm -f "$ARGS_FILE"
TMUX_SOCKET="" TMUX="" TMUX_BIN="/nonexistent/tmux" EDITOR="$FAKE_EDITOR" \
  timeout 3 bash "$SCRIPT" "$WORKDIR/.env" >/dev/null 2>&1
assert_eq "falls back to running the editor directly" \
  "$WORKDIR/.env" "$(tail -1 "$ARGS_FILE" 2>/dev/null)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
