#!/usr/bin/env bash
# Keep the sidebar tree on the directory the work pane is actually in.
#
# Called from a zsh chpwd hook, so it fires on EVERY directory change. Two
# properties matter as much as the feature: it must cost nothing when there is
# no sidebar, and it must never fail loudly — an error here would surface in the
# user's prompt on every cd.
#
# Usage: sidebar-follow.sh <directory>
set -uo pipefail

target="${1:-$PWD}"

# Nothing to do outside tmux. Checked first because it is the cheapest exit.
[ -n "${TMUX:-}${TMUX_SOCKET:-}${TMUX_PANE:-}" ] || exit 0

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

pane="${TMUX_PANE:-}"

# No sidebar in this window means no work and no output.
client_id="$(tmux_cmd display -p ${pane:+-t "$pane"} '#{@sidebar_client_id}' 2>/dev/null)"
[ -n "$client_id" ] || exit 0

# From here on every failure is swallowed: yazi may have been closed, the id may
# be stale, `ya` may not exist. None of that is worth interrupting a cd for.
[ -x "$YA_BIN" ] || exit 0
"$YA_BIN" emit-to "$client_id" cd "$target" >/dev/null 2>&1 || true
exit 0
