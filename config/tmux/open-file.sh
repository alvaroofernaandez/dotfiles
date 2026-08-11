#!/usr/bin/env bash
# Open files from the yazi sidebar in a NEW tmux window.
#
# A new window rather than the current one on purpose: whatever is running where
# you were — a build, a REPL, an editor with unsaved changes — is never touched,
# never receives keystrokes, and never has to be interrupted. Closing the editor
# closes the window and returns you exactly where you were.
#
# Outside tmux it falls back to running $EDITOR here, so plain fullscreen `yazi`
# keeps working.
set -uo pipefail

[ "$#" -gt 0 ] || { echo "usage: ${0##*/} <file>..." >&2; exit 2; }

EDITOR_CMD="${EDITOR:-vi}"

# Absolute paths throughout: this runs from yazi, which inherits the tmux
# server's environment — launchd's minimal PATH when Ghostty started the server.
# An unresolvable name would make tmux open the window and close it instantly.
resolve() {
  case "$1" in
    */* | *' '*) printf '%s' "$1"; return ;;
  esac
  for dir in "$HOME/.nix-profile/bin" /opt/homebrew/bin /usr/local/bin /usr/bin /bin; do
    [ -x "$dir/$1" ] && { printf '%s' "$dir/$1"; return; }
  done
  command -v "$1" 2>/dev/null || printf '%s' "$1"
}

TMUX_BIN="$(resolve "${TMUX_BIN:-tmux}")"
EDITOR_BIN="$(resolve "$EDITOR_CMD")"

if [ -n "${TMUX_SOCKET:-}" ]; then
  tmux_cmd() { "$TMUX_BIN" -L "$TMUX_SOCKET" "$@"; }
else
  tmux_cmd() { "$TMUX_BIN" "$@"; }
fi

# No usable tmux: run the editor right here rather than doing nothing.
if [ ! -x "$TMUX_BIN" ] || ! tmux_cmd has-session 2>/dev/null; then
  # shellcheck disable=SC2086 # EDITOR may legitimately carry arguments.
  exec $EDITOR_BIN "$@"
fi

# Shell-quote every path so spaces and metacharacters survive the command line.
quoted=""
for f in "$@"; do
  quoted+=" $(printf '%q' "$f")"
done

# Named after the first file, so the window list stays readable.
name="$(basename -- "$1")"

tmux_cmd new-window -n "$name" "$(printf '%q' "$EDITOR_BIN")$quoted"
