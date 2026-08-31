#!/usr/bin/env bash
# Bounded waits for the tmux end-to-end suites.
#
# These suites drive a real tmux server: they toggle a sidebar, open yazi, then
# read the result back with capture-pane or display -p. Between the action and
# the read sits work the test does not control — a pane spawning, a shell
# starting, yazi painting its first frame, a directory change landing.
#
# That gap used to be bridged with a fixed `sleep`, which is a bet on how fast
# the machine is. GitHub's shared runners lose that bet: the same commit failed
# twice in a row in two DIFFERENT suites, once with capture-pane returning an
# empty pane and once with a path that had not updated yet, while passing every
# time locally. Rotating failures on an unchanged commit are a race, and raising
# the sleep only moves the threshold rather than removing it.
#
# Polling removes it. Read the value until it is the one expected or a deadline
# passes, and the test is correct on a fast machine and a slow one alike: fast
# machines return at once instead of sleeping the whole budget, slow ones get
# the time they actually need.
#
# The command is taken as "$@" rather than a string through eval, because the
# callers pass tmux argument arrays holding spaces and format strings like
# '#{pane_current_path}' that eval would mangle.
#
# Usage:
#   out="$(wait_until 10 "expected text" tmux -L "$SOCKET" capture-pane -p -t "$pane")"
#   wait_for 10 some_predicate_function

# Poll a command until its stdout contains a string.
#
#   wait_until <timeout-seconds> <expected-substring> <command> [args...]
#
# Echoes the last stdout captured — matching or not — and returns 0 on match, 1
# on timeout. Returning the last value rather than an empty string on timeout is
# deliberate: it lets the assertion that follows report what the pane really
# held. A timeout that reports nothing sends you off to re-run the suite by
# hand, and a race may not reproduce when you do.
wait_until() {
  local timeout="$1" match="$2"
  shift 2

  local deadline=$(( SECONDS + timeout ))
  local out=""

  while :; do
    out="$("$@" 2>/dev/null)"
    case "$out" in
      *"$match"*) printf '%s' "$out"; return 0 ;;
    esac
    [ "$SECONDS" -ge "$deadline" ] && break
    sleep 0.1
  done

  printf '%s' "$out"
  return 1
}

# Poll a command until it exits 0.
#
#   wait_for <timeout-seconds> <command> [args...]
#
# For conditions that are not a substring of any output: two pane ids being
# distinct, a pane having appeared at all. Returns 0 once the command succeeds,
# 1 on timeout.
wait_for() {
  local timeout="$1"
  shift

  local deadline=$(( SECONDS + timeout ))

  while :; do
    "$@" >/dev/null 2>&1 && return 0
    [ "$SECONDS" -ge "$deadline" ] && return 1
    sleep 0.1
  done
}
