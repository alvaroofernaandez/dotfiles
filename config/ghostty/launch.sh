#!/bin/sh
# Ghostty's startup command: hand the window to tmux, or to a shell if tmux is
# unavailable.
#
# Ghostty runs this through `/usr/bin/login -flp <user> /bin/bash --noprofile
# --norc`, which inherits launchd's PATH (/usr/bin:/bin:/usr/sbin:/sbin) rather
# than the shell's. A bare `tmux` is NOT found there: the window dies with
# "exec: tmux: not found" and there is no terminal left to fix it from. So the
# binary is resolved by absolute path, and anything unexpected falls back to a
# login shell instead of leaving a dead window.
#
# TMUX_BIN overrides the binary. LAUNCH_RESOLVE_ONLY=1 prints what would run and
# exits, which is how the tests inspect resolution without execing.

SESSION="main"

if [ -n "${TMUX_BIN:-}" ]; then
  # An explicit override is authoritative: if it is not usable, fall back rather
  # than quietly running some other tmux the caller did not ask for.
  [ -x "$TMUX_BIN" ] && TMUX_RESOLVED="$TMUX_BIN"
else
  # Homebrew on Apple Silicon, Homebrew on Intel, Nix, then whatever PATH offers.
  for candidate in \
    /opt/homebrew/bin/tmux \
    /usr/local/bin/tmux \
    "$HOME/.nix-profile/bin/tmux" \
    /usr/bin/tmux
  do
    if [ -x "$candidate" ]; then
      TMUX_RESOLVED="$candidate"
      break
    fi
  done

  if [ -z "${TMUX_RESOLVED:-}" ]; then
    found="$(command -v tmux 2>/dev/null)"
    [ -n "$found" ] && [ -x "$found" ] && TMUX_RESOLVED="$found"
  fi
fi

if [ "${LAUNCH_RESOLVE_ONLY:-}" = "1" ]; then
  [ -n "${TMUX_RESOLVED:-}" ] && printf '%s\n' "$TMUX_RESOLVED"
  exit 0
fi

if [ -n "${TMUX_RESOLVED:-}" ]; then
  if [ -n "${TMUX_SOCKET:-}" ]; then
    tmux_cmd() { "$TMUX_RESOLVED" -L "$TMUX_SOCKET" "$@"; }
  else
    tmux_cmd() { "$TMUX_RESOLVED" "$@"; }
  fi

  # Every Ghostty tab is a separate tmux client. Attaching them all to one
  # session makes them render the SAME window: a cd in one tab moves the other,
  # which defeats working on two projects side by side.
  #
  # So each tab takes a session of its own. A session with no client attached is
  # reused first, which is what makes work survive closing a tab; only when they
  # are all in use is a new one created.
  target="$(tmux_cmd list-sessions -F '#{session_name}|#{session_attached}' 2>/dev/null \
    | awk -F'|' '$2 == "0" { print $1; exit }')"

  if [ "${LAUNCH_PICK_ONLY:-}" = "1" ]; then
    printf '%s\n' "${target:-new}"
    exit 0
  fi

  if [ -n "$target" ]; then
    exec "$TMUX_RESOLVED" ${TMUX_SOCKET:+-L "$TMUX_SOCKET"} attach -t "$target"
  fi
  exec "$TMUX_RESOLVED" ${TMUX_SOCKET:+-L "$TMUX_SOCKET"} new-session
fi

# No tmux: never leave the user without a terminal.
exec "${SHELL:-/bin/zsh}" -l
