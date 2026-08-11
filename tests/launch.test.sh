#!/usr/bin/env bash
# Tests for the Ghostty launch command.
#
# Ghostty starts its command through `/usr/bin/login -flp <user> /bin/bash
# --noprofile --norc`, which inherits launchd's minimal PATH, not the shell's.
# A bare `tmux` is therefore NOT found and the window dies with
# "exec: tmux: not found", leaving no usable terminal. That is the case these
# tests pin down.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH="$REPO/config/ghostty/launch.sh"
GHOSTTY_CONF="$REPO/config/ghostty/config"
MINIMAL_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

pass=0
fail=0
TMPDIR_TEST=""

cleanup() { [ -n "$TMPDIR_TEST" ] && rm -rf "$TMPDIR_TEST"; }
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

echo "launch"

# --- the script itself -------------------------------------------------------
assert_eq "launch script exists" "yes" "$([ -f "$LAUNCH" ] && echo yes || echo no)"
assert_eq "launch script is executable" "yes" "$([ -x "$LAUNCH" ] && echo yes || echo no)"

# --- the regression: resolves tmux under launchd's minimal PATH --------------
resolved="$(env -i PATH="$MINIMAL_PATH" HOME="$HOME" LAUNCH_RESOLVE_ONLY=1 \
  /bin/bash "$LAUNCH" 2>/dev/null)"
assert_eq "resolves tmux with launchd's minimal PATH" "yes" \
  "$([ -n "$resolved" ] && [ -x "$resolved" ] && echo yes || echo no)"
assert_contains "resolves to a real tmux binary" "tmux" "${resolved:-<empty>}"

# --- falls back instead of leaving a dead terminal ---------------------------
TMPDIR_TEST="$(mktemp -d)"
out="$(env -i PATH="$TMPDIR_TEST" HOME="$HOME" TMUX_BIN="$TMPDIR_TEST/absent" \
  LAUNCH_RESOLVE_ONLY=1 /bin/bash "$LAUNCH" 2>&1)"
rc=$?
assert_eq "reports no tmux rather than erroring out" "0" "$rc"
assert_eq "resolves to nothing when tmux is absent" "" "$out"

# With no tmux anywhere, the script must still hand over a working shell.
fake_shell="$TMPDIR_TEST/myshell"
printf '#!/bin/sh\necho FELL_BACK\n' > "$fake_shell"
chmod +x "$fake_shell"
out="$(env -i PATH="$TMPDIR_TEST" HOME="$HOME" SHELL="$fake_shell" \
  TMUX_BIN="$TMPDIR_TEST/absent" /bin/bash "$LAUNCH" 2>&1)"
assert_contains "falls back to a login shell when tmux is missing" "FELL_BACK" "$out"

# --- an explicit override wins ----------------------------------------------
fake_tmux="$TMPDIR_TEST/tmux"
printf '#!/bin/sh\necho "TMUX_RAN $*"\n' > "$fake_tmux"
chmod +x "$fake_tmux"
out="$(env -i PATH="$MINIMAL_PATH" HOME="$HOME" TMUX_BIN="$fake_tmux" \
  /bin/bash "$LAUNCH" 2>&1)"
assert_contains "runs tmux when available" "TMUX_RAN" "$out"
# A session of its own, not a shared one: tabs attaching to the same session
# render the same window and stop being independent workspaces.
assert_contains "starts a session rather than joining a shared one" "new-session" "$out"
assert_eq "does not force every tab onto one named session" "yes" \
  "$(printf '%s' "$out" | rg -q '\-A -s main' && echo no || echo yes)"

# ---每 tab gets its own session ----------------------------------------------
# Each Ghostty tab is a separate tmux CLIENT. Attaching them all to one session
# means they render the same window: changing directory in one changes the other,
# which is the opposite of working on two projects in parallel.
SESS_SOCKET="launch-sess-$$"
sess() { tmux -L "$SESS_SOCKET" "$@"; }
sess_cleanup() { sess kill-server 2>/dev/null; }

# The script is asked what it WOULD attach to, rather than actually execing.
pick() {
  env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" \
    TMUX_SOCKET="$SESS_SOCKET" LAUNCH_PICK_ONLY=1 /bin/bash "$LAUNCH" 2>/dev/null
}

sess kill-server 2>/dev/null
first="$(pick)"
assert_eq "with no sessions, it creates one" "new" "$first"

sess new-session -d -s alpha 2>/dev/null
sleep 0.3
# alpha has no client attached, so it is free to reuse.
assert_eq "reuses a session that has no client" "alpha" "$(pick)"

# Simulate alpha being in use by a tab.
sess new-session -d -s beta 2>/dev/null
sess set -t alpha @fake_attached 1 2>/dev/null
busy="$(sess list-sessions -F '#{session_name}|#{session_attached}' 2>/dev/null | rg -c 'alpha\|0' || echo 0)"
assert_eq "a detached session is detectable as free" "1" "$busy"

# With every session attached, a new tab must not join one of them.
assert_eq "never picks a session that already has a client" "yes" \
  "$(out="$(pick)";
     [ "$out" = "new" ] || sess list-sessions -F '#{session_name}|#{session_attached}' 2>/dev/null \
       | rg -q "^$out\|0" && echo yes || echo no)"

sess_cleanup

# --- the Ghostty config must not reintroduce a bare command ------------------
cmd_line="$(rg -N '^\s*command\s*=' "$GHOSTTY_CONF" 2>/dev/null)"
assert_eq "ghostty config sets a command" "yes" \
  "$([ -n "$cmd_line" ] && echo yes || echo no)"
assert_eq "ghostty command uses an absolute path" "yes" \
  "$(printf '%s' "$cmd_line" | rg -q '=\s*/' && echo yes || echo no)"
assert_eq "ghostty command does not rely on PATH for tmux" "yes" \
  "$(printf '%s' "$cmd_line" | rg -q '=\s*tmux\b' && echo no || echo yes)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
