#!/usr/bin/env bash
# Close a file that was opened from the sidebar, without typing the editor's own
# quit command.
#
# Two rules make this safe:
#
#   1. Only windows tagged @file_window by open-file.sh are eligible. A window
#      you were working in is never closed, whatever is running in it.
#   2. A vim-family editor is ASKED to quit (:q) rather than killed, so unsaved
#      changes stay the editor's decision. If it refuses, the window stays and
#      the editor says why.
#
# Anything else is closed directly: it was opened here and holds nothing the
# editor itself would object to losing.
set -uo pipefail

resolve() {
  case "$1" in
    */* | *' '*) printf '%s' "$1"; return ;;
  esac
  for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.nix-profile/bin" /usr/bin /bin; do
    [ -x "$dir/$1" ] && { printf '%s' "$dir/$1"; return; }
  done
  command -v "$1" 2>/dev/null || printf '%s' "$1"
}

TMUX_BIN="$(resolve "${TMUX_BIN:-tmux}")"

if [ -n "${TMUX_SOCKET:-}" ]; then
  tmux_cmd() { "$TMUX_BIN" -L "$TMUX_SOCKET" "$@"; }
else
  tmux_cmd() { "$TMUX_BIN" "$@"; }
fi

pane="${TMUX_PANE:-}"
if [ -z "$pane" ]; then
  pane="$(tmux_cmd display -p '#{pane_id}' 2>/dev/null)"
fi
[ -n "$pane" ] || { echo "close-file: no target pane" >&2; exit 1; }

tagged="$(tmux_cmd display -p -t "$pane" '#{?@file_window,1,0}' 2>/dev/null)"
if [ "$tagged" != "1" ]; then
  echo "close-file: this window was not opened from the sidebar — refusing to close it" >&2
  exit 1
fi

current="$(tmux_cmd display -p -t "$pane" '#{pane_current_command}' 2>/dev/null)"

case "$current" in
  nano | pico)
    # ^X is nano's own Exit. With unsaved changes it asks "Save modified
    # buffer?" and waits, so nothing is discarded behind the user's back.
    tmux_cmd send-keys -t "$pane" C-x
    echo "asked $current to quit"
    ;;
  nvim | vim | view | vi)
    # Leave whatever mode it is in, then ask it to quit. An editor with unsaved
    # changes will refuse and say so, which is the point.
    tmux_cmd send-keys -t "$pane" Escape
    tmux_cmd send-keys -t "$pane" ':q' Enter
    echo "asked $current to quit"
    ;;
  *)
    tmux_cmd kill-window -t "$pane"
    ;;
esac
