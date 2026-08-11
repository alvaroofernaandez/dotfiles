#!/usr/bin/env bash
# Keeps the sidebar tree on the work pane's directory, without relying on the
# shell.
#
# The zsh chpwd hook is instant and costs nothing, but it only exists in shells
# that were started after it was installed. Any older shell, or a shell that is
# not zsh, would silently stop syncing. This loop covers those cases.
#
# It only runs while its sidebar exists: every iteration re-checks, and the loop
# exits as soon as the pane, the window option, or the tmux server is gone. An
# orphaned polling loop would keep waking up forever.
#
# Usage: sidebar-watch.sh <sidebar-pane-id> <client-id>
set -uo pipefail

pane="${1:-}"
client_id="${2:-}"
interval="${WATCH_INTERVAL:-2}"

[ -n "$pane" ] && [ -n "$client_id" ] || exit 1

resolve() {
  case "$1" in
    */*) printf '%s' "$1"; return ;;
  esac
  for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.nix-profile/bin" /usr/bin /bin; do
    [ -x "$dir/$1" ] && { printf '%s' "$dir/$1"; return; }
  done
  command -v "$1" 2>/dev/null || printf '%s' "$1"
}

TMUX_BIN="$(resolve "${TMUX_BIN:-tmux}")"
YA_BIN="$(resolve "${YA_BIN:-ya}")"

if [ -n "${TMUX_SOCKET:-}" ]; then
  tmux_cmd() { "$TMUX_BIN" -L "$TMUX_SOCKET" "$@"; }
else
  tmux_cmd() { "$TMUX_BIN" "$@"; }
fi

last=""

while true; do
  # Gone means gone: the sidebar pane closed, the option was cleared, or the
  # whole server died. Any of those ends the loop.
  tmux_cmd has-session 2>/dev/null || exit 0
  tmux_cmd display -p -t "$pane" '#{pane_id}' >/dev/null 2>&1 || exit 0
  [ "$(tmux_cmd display -p -t "$pane" '#{?@sidebar,1,0}' 2>/dev/null)" = "1" ] || exit 0

  # The work pane is the one in this window that is not the sidebar.
  work="$(tmux_cmd list-panes -t "$pane" -F '#{pane_id}|#{?@sidebar,1,0}|#{pane_current_path}' 2>/dev/null \
    | awk -F'|' '$2 != "1" { print $3; exit }')"

  if [ -n "$work" ] && [ "$work" != "$last" ]; then
    # Skipped on the first pass: the sidebar already opened in that directory,
    # so emitting there would be a pointless round trip.
    [ -n "$last" ] && "$YA_BIN" emit-to "$client_id" cd "$work" >/dev/null 2>&1
    last="$work"
  fi

  sleep "$interval"
done
