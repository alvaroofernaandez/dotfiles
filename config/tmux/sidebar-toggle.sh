#!/usr/bin/env bash
# Toggle a file-tree sidebar pane in the current tmux window.
#
# Open  -> splits a narrow pane on the left running $SIDEBAR_CMD (default: yazi),
#          inheriting the working pane's directory, and focuses it.
# Close -> kills that pane and returns focus to the working pane.
#
# The pane is tagged with the @sidebar pane option, so the toggle never has to
# guess which pane is the sidebar and never touches a pane the user opened.
set -euo pipefail

SIDEBAR_CMD="${SIDEBAR_CMD:-yazi}"
SIDEBAR_WIDTH="${SIDEBAR_WIDTH:-30%}"
SIDEBAR_CONFIG_HOME="${SIDEBAR_CONFIG_HOME:-$HOME/.config/yazi-sidebar}"

# A bare command name is resolved to an absolute path. split-window runs the
# command with the tmux SERVER's PATH — launchd's minimal one when Ghostty
# started the server — so an unresolvable name makes tmux open the pane and then
# close it the instant the exec fails. That reads as the sidebar flickering
# open and vanishing, not as an error.
case "$SIDEBAR_CMD" in
  */* | *' '*) : ;;   # already a path, or carries arguments: leave it alone
  *)
    for candidate in \
      "$HOME/.nix-profile/bin/$SIDEBAR_CMD" \
      /opt/homebrew/bin/"$SIDEBAR_CMD" \
      /usr/local/bin/"$SIDEBAR_CMD" \
      /usr/bin/"$SIDEBAR_CMD" \
      /bin/"$SIDEBAR_CMD"
    do
      [ -x "$candidate" ] && { SIDEBAR_CMD="$candidate"; break; }
    done
    ;;
esac

# tmux is resolved by absolute path. run-shell inherits the SERVER's
# environment, and when Ghostty starts the server that PATH is launchd's minimal
# one with no /opt/homebrew/bin — a bare `tmux` there is not found and the whole
# script exits 127, which reads as "the keybinding does nothing".
TMUX_BIN="${TMUX_BIN:-}"
if [ -z "$TMUX_BIN" ]; then
  for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux \
                   "$HOME/.nix-profile/bin/tmux" /usr/bin/tmux; do
    [ -x "$candidate" ] && { TMUX_BIN="$candidate"; break; }
  done
  [ -n "$TMUX_BIN" ] || TMUX_BIN="$(command -v tmux 2>/dev/null)"
fi
[ -n "$TMUX_BIN" ] || { echo "sidebar-toggle: tmux not found" >&2; exit 127; }

# TMUX_SOCKET lets the test suite drive an isolated server.
if [ -n "${TMUX_SOCKET:-}" ]; then
  tmux() { "$TMUX_BIN" -L "$TMUX_SOCKET" "$@"; }
else
  tmux() { "$TMUX_BIN" "$@"; }
fi

# Anchor every lookup to the window the toggle was fired from, so other
# windows and sessions are never considered.
window="${TMUX_PANE:-$(tmux display -p '#{window_id}')}"

# TMUX_PANE can be stale when inherited from another tmux server. Acting on a
# fallback target would open the sidebar in the wrong window, so refuse loudly
# instead: a keybind that silently does nothing is impossible to diagnose.
if ! tmux display -p -t "$window" '#{window_id}' >/dev/null 2>&1; then
  echo "sidebar-toggle: no such pane or window: $window" >&2
  exit 1
fi

# @sidebar is normalised to 1/0 rather than read raw: an unset option renders
# as an empty field, and whitespace-splitting silently shifts later columns.
sidebar="$(tmux list-panes -t "$window" -F '#{pane_id}|#{?@sidebar,1,0}' \
  | awk -F'|' '$2 == "1" { print $1; exit }')"

if [ -n "$sidebar" ]; then
  tmux kill-pane -t "$sidebar"
else
  # Point yazi at the sidebar-only config (narrow, tree-only layout). Skipped
  # when that directory is absent: yazi would silently fall back to its built-in
  # defaults and lose the opener, so plain ~/.config/yazi is the safer choice.
  env_args=()
  [ -d "$SIDEBAR_CONFIG_HOME" ] && env_args=(-e "YAZI_CONFIG_HOME=$SIDEBAR_CONFIG_HOME")

  # A per-window client id lets sidebar-follow.sh steer THIS instance as the
  # work pane changes directory. yazi requires it to be globally unique.
  #
  # Only appended for yazi: --client-id is its flag, and passing it to any other
  # SIDEBAR_CMD makes that command fail its argument parsing and the pane dies
  # instantly.
  client_id="$(( (RANDOM % 60000) + 2000 ))"
  launch="$SIDEBAR_CMD"
  case "$SIDEBAR_CMD" in
    *yazi) launch="$SIDEBAR_CMD --client-id $client_id" ;;
    *) client_id="" ;;
  esac

  pane="$(tmux split-window -t "$window" -h -b -l "$SIDEBAR_WIDTH" \
    -c '#{pane_current_path}' "${env_args[@]}" -P -F '#{pane_id}' "$launch")"

  if [ -n "$client_id" ]; then
    tmux set -w -t "$pane" @sidebar_client_id "$client_id"

  fi
  tmux set -p -t "$pane" @sidebar 1

  # Started only after @sidebar is set: the watcher checks that tag on its first
  # iteration and exits at once if it is missing, so launching it any earlier
  # means it dies immediately.
  if [ -n "$client_id" ]; then
    # Safety net for shells that predate the chpwd hook, or are not zsh. It
    # exits on its own as soon as this sidebar is gone.
    watcher="$(cd "$(dirname "$0")" && pwd)/sidebar-watch.sh"
    if [ -x "$watcher" ]; then
      # stdin is closed and the job disowned as well as redirecting output: a
      # background child that keeps the parent's descriptors blocks whoever
      # reads them, which hangs run-shell and any pipeline around the toggle.
      TMUX_SOCKET="${TMUX_SOCKET:-}" TMUX_BIN="$TMUX_BIN" \
        YA_BIN="${YA_BIN:-}" WATCH_INTERVAL="${WATCH_INTERVAL:-2}" \
        nohup "$watcher" "$pane" "$client_id" </dev/null >/dev/null 2>&1 &
      disown 2>/dev/null || true
    fi
  fi
fi
