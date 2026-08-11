#!/usr/bin/env bash
# Open files from the yazi sidebar in the window's work pane instead of inside
# the narrow sidebar itself.
#
#   shell in the work pane   -> types "$EDITOR -- <files>" and focuses it
#   nvim/vim already running -> reuses it via :edit / :badd, never nests
#   anything else running    -> refuses, so a build or REPL is never clobbered
#   no tmux / no work pane   -> falls back to running $EDITOR right here
set -uo pipefail

[ "$#" -gt 0 ] || { echo "usage: ${0##*/} <file>..." >&2; exit 2; }

EDITOR_CMD="${EDITOR:-vi}"

# tmux is resolved by absolute path: yazi's opener inherits the tmux server's
# environment, whose PATH is launchd's minimal one when Ghostty started it.
TMUX_BIN="${TMUX_BIN:-}"
if [ -z "$TMUX_BIN" ]; then
  for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux \
                   "$HOME/.nix-profile/bin/tmux" /usr/bin/tmux; do
    [ -x "$candidate" ] && { TMUX_BIN="$candidate"; break; }
  done
  [ -n "$TMUX_BIN" ] || TMUX_BIN="$(command -v tmux 2>/dev/null)"
fi

# TMUX_SOCKET lets the test suite drive an isolated server.
if [ -n "${TMUX_SOCKET:-}" ]; then
  tmux() { "$TMUX_BIN" -L "$TMUX_SOCKET" "$@"; }
elif [ -n "$TMUX_BIN" ]; then
  tmux() { "$TMUX_BIN" "$@"; }
fi

# Run the editor in this pane. Used whenever delegation isn't possible.
open_locally() {
  # shellcheck disable=SC2086 # EDITOR may legitimately carry arguments.
  exec $EDITOR_CMD "$@"
}

# Outside tmux there is nothing to delegate to.
[ -n "${TMUX_PANE:-}" ] || open_locally "$@"

# The work pane is any pane in this window that isn't the sidebar and isn't us.
#
# Fields are pipe-delimited and @sidebar is normalised to 1/0: an unset option
# renders as an empty field, and whitespace-splitting would silently collapse
# it, shifting every later column by one.
work_pane=""
work_cmd=""
while IFS='|' read -r pane_id is_sidebar current_cmd; do
  [ "$is_sidebar" = "1" ] && continue
  [ "$pane_id" = "$TMUX_PANE" ] && continue
  work_pane="$pane_id"
  work_cmd="$current_cmd"
  break
done < <(tmux list-panes -t "$TMUX_PANE" \
  -F '#{pane_id}|#{?@sidebar,1,0}|#{pane_current_command}' 2>/dev/null)

[ -n "$work_pane" ] || open_locally "$@"

# Shell-quote every path so spaces and metacharacters survive send-keys.
quoted=""
for f in "$@"; do
  quoted+=" $(printf '%q' "$f")"
done

case "$work_cmd" in
  zsh | bash | fish | sh | dash | ksh | nu)
    tmux send-keys -t "$work_pane" "$EDITOR_CMD --$quoted" Enter
    tmux select-pane -t "$work_pane"
    echo "opened in $work_pane"
    ;;

  nvim | vim | view)
    # Leave whatever mode the editor is in, then load the files as buffers.
    tmux send-keys -t "$work_pane" Escape
    tmux send-keys -t "$work_pane" ":edit $(printf '%q' "$1")" Enter
    shift
    for f in "$@"; do
      tmux send-keys -t "$work_pane" ":badd $(printf '%q' "$f")" Enter
    done
    tmux select-pane -t "$work_pane"
    echo "reused $work_cmd in $work_pane via :edit"
    ;;

  *)
    echo "${0##*/}: work pane is busy running '$work_cmd' — refusing to send keys into it" >&2
    exit 1
    ;;
esac
