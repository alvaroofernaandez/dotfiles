#!/usr/bin/env bash
# Tests for close-file.sh — closing a file opened from the sidebar without
# typing the editor's own quit command.
#
# The safety property that matters: it must NEVER close a window the user was
# working in. Only windows this setup opened are eligible, and they are tagged
# at creation rather than guessed at.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLOSE="$DIR/close-file.sh"
OPEN="$DIR/open-file.sh"
SOCKET="closefile-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"

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

mkdir -p "$WORKDIR/bin"
# Blocking stand-in for a generic editor.
printf '#!/usr/bin/env bash\nsleep 600\n' > "$WORKDIR/bin/fakeedit"
chmod +x "$WORKDIR/bin/fakeedit"
# A binary literally named nvim, so tmux reports it as the pane command.
HAVE_NVIM=0
if command -v cc >/dev/null 2>&1; then
  printf '#include <unistd.h>\nint main(void){for(;;)pause();return 0;}\n' > "$WORKDIR/nvim.c"
  cc -o "$WORKDIR/bin/nvim" "$WORKDIR/nvim.c" 2>/dev/null && HAVE_NVIM=1
fi

windows() { "${TMUX_TEST[@]}" list-windows -F '#{window_id}' 2>/dev/null | wc -l | tr -d ' '; }

setup_session() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  "${TMUX_TEST[@]}" new-session -d -s main -c "$WORKDIR" -x 200 -y 50
  sleep 0.4
}

close_current() {
  TMUX_SOCKET="$SOCKET" TMUX_PANE="$1" bash "$CLOSE" 2>&1
}

printf 'PORT=3000\n' > "$WORKDIR/.env"

echo "close-file"

# --- opened windows are tagged ----------------------------------------------
setup_session
TMUX_SOCKET="$SOCKET" EDITOR="$WORKDIR/bin/fakeedit" bash "$OPEN" "$WORKDIR/.env" >/dev/null 2>&1
sleep 1
opened_win="$("${TMUX_TEST[@]}" list-windows -F '#{window_id}|#{?@file_window,1,0}' 2>/dev/null | awk -F'|' '$2=="1"{print $1}')"
assert_eq "open-file tags the window it creates" "yes" \
  "$([ -n "$opened_win" ] && echo yes || echo no)"

# --- closes a tagged window --------------------------------------------------
opened_pane="$("${TMUX_TEST[@]}" list-panes -t "$opened_win" -F '#{pane_id}' 2>/dev/null | head -1)"
close_current "$opened_pane" >/dev/null
sleep 1
assert_eq "closes the window opened from the sidebar" "1" "$(windows)"

# --- NEVER closes a working window -------------------------------------------
setup_session
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
out="$(close_current "$work_pane")"
rc=$?
sleep 0.6
assert_eq "refuses to close an untagged window" "1" "$(windows)"
assert_eq "the working pane survives" "$work_pane" \
  "$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}' 2>/dev/null)"
assert_eq "says why it refused" "yes" \
  "$(printf '%s' "$out" | rg -qi 'not.*opened|refus|only' && echo yes || echo no)"

# --- an editor with unsaved work decides for itself --------------------------
if [ "$HAVE_NVIM" -eq 1 ]; then
  setup_session
  TMUX_SOCKET="$SOCKET" EDITOR="$WORKDIR/bin/nvim" bash "$OPEN" "$WORKDIR/.env" >/dev/null 2>&1
  sleep 1.2
  win="$("${TMUX_TEST[@]}" list-windows -F '#{window_id}|#{?@file_window,1,0}' 2>/dev/null | awk -F'|' '$2=="1"{print $1}')"
  pane="$("${TMUX_TEST[@]}" list-panes -t "$win" -F '#{pane_id}' 2>/dev/null | head -1)"
  out="$(close_current "$pane")"
  sleep 0.8

  # It must ask the editor to quit rather than killing it, so unsaved changes
  # are the editor's call and not silently discarded.
  assert_eq "asks a vim-family editor to quit instead of killing it" "yes" \
    "$(printf '%s' "$out" | rg -qi 'quit|:q' && echo yes || echo no)"
  assert_eq "does not force-kill the editor window" "2" "$(windows)"
  assert_eq "sends the quit sequence to the editor" "yes" \
    "$("${TMUX_TEST[@]}" capture-pane -p -t "$pane" 2>/dev/null | rg -q ':q' && echo yes || echo no)"
else
  printf '  \033[33mSKIP\033[0m editor-decides case (no cc to build the nvim double)\n'
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
