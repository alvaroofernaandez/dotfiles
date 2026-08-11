#!/usr/bin/env bash
# Tests for open-in-work-pane.sh, run against an isolated tmux server so the
# user's live session is never touched.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/open-in-work-pane.sh"
SOCKET="openwork-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"
ARGS_FILE="$WORKDIR/args.txt"

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
assert_contains() {
  case "$3" in
    *"$2"*) ok "$1" ;;
    *) ko "$1" "text containing: $2" "$3" ;;
  esac
}

# A fake editor that records the argv it actually received, so quoting is
# verified by behaviour rather than by scraping the rendered pane.
mkdir -p "$WORKDIR/bin"
cat > "$WORKDIR/bin/fakeedit" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$ARGS_FILE"
EOF
chmod +x "$WORKDIR/bin/fakeedit"
FAKE_EDITOR="$WORKDIR/bin/fakeedit"

# A blocking binary literally named "nvim", so tmux reports it as the pane's
# foreground command. Two things that do NOT work here: `exec -a nvim` (tmux
# reads the real executable name, not argv[0]) and a shell script (tmux would
# report the interpreter). Compiling a tiny binary is the only faithful double.
HAVE_FAKE_NVIM=0
if command -v cc >/dev/null 2>&1; then
  printf '#include <unistd.h>\nint main(void){for(;;)pause();return 0;}\n' > "$WORKDIR/nvim.c"
  cc -o "$WORKDIR/bin/nvim" "$WORKDIR/nvim.c" 2>/dev/null && HAVE_FAKE_NVIM=1
fi

work_pane=""
sidebar=""

# Panes report an empty current_command until their shell has actually
# started; polling avoids racing that startup.
wait_for_cmd() {
  local pane="$1" want="$2" i
  for i in $(seq 1 60); do
    [ "$("${TMUX_TEST[@]}" display -p -t "$pane" '#{pane_current_command}')" = "$want" ] && return 0
    sleep 0.1
  done
  return 1
}

# A window with a shell "work" pane plus a tagged sidebar pane, mirroring
# what sidebar-toggle.sh produces.
setup_window() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  rm -f "$ARGS_FILE"
  "${TMUX_TEST[@]}" new-session -d -s main -c "$WORKDIR" -x 200 -y 50
  work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
  sidebar="$("${TMUX_TEST[@]}" split-window -t main -h -b -l 30% -c "$WORKDIR" \
    -P -F '#{pane_id}' "sleep 600")"
  "${TMUX_TEST[@]}" set -p -t "$sidebar" @sidebar 1
  wait_for_cmd "$work_pane" "$(basename "$SHELL")" || wait_for_cmd "$work_pane" zsh
}

# Run the opener as yazi would: from inside the sidebar pane.
open_file() {
  TMUX_SOCKET="$SOCKET" TMUX_PANE="$sidebar" EDITOR="$FAKE_EDITOR" \
    bash "$SCRIPT" "$@" 2>&1
}

# Wait for the fake editor to record its argv.
wait_for_args() {
  local i
  for i in $(seq 1 60); do
    [ -s "$ARGS_FILE" ] && return 0
    sleep 0.1
  done
  return 1
}

echo "open-in-work-pane"

# --- happy path: work pane is a shell ---------------------------------------
setup_window
printf 'PORT=3000\n' > "$WORKDIR/.env"
open_file "$WORKDIR/.env" >/dev/null
wait_for_args

assert_eq "runs the editor in the work pane with the right argv" \
  "$(printf -- '--\n%s' "$WORKDIR/.env")" "$(cat "$ARGS_FILE" 2>/dev/null)"
assert_eq "moves focus to the work pane" \
  "$work_pane" "$("${TMUX_TEST[@]}" display -p -t main '#{pane_id}')"
assert_eq "leaves the sidebar alive" \
  "2" "$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}' | wc -l | tr -d ' ')"

# --- refuses to clobber a busy pane -----------------------------------------
setup_window
"${TMUX_TEST[@]}" send-keys -t "$work_pane" "sleep 600" Enter
wait_for_cmd "$work_pane" sleep
before="$("${TMUX_TEST[@]}" capture-pane -p -t "$work_pane")"
out="$(open_file "$WORKDIR/.env")"
rc=$?
sleep 0.4

assert_eq "exits non-zero when the work pane is busy" \
  "nonzero" "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)"
assert_eq "sends nothing into the running process" \
  "$before" "$("${TMUX_TEST[@]}" capture-pane -p -t "$work_pane")"
assert_contains "explains why it refused" "busy" "$out"
assert_eq "never invokes the editor when refusing" "absent" \
  "$([ -s "$ARGS_FILE" ] && echo present || echo absent)"

# --- reuses an existing editor instead of nesting ----------------------------
if [ "$HAVE_FAKE_NVIM" -eq 1 ]; then
  setup_window
  "${TMUX_TEST[@]}" respawn-pane -k -t "$work_pane" -c "$WORKDIR" "$WORKDIR/bin/nvim"
  wait_for_cmd "$work_pane" nvim
  out="$(open_file "$WORKDIR/.env")"
  rc=$?
  sleep 0.4

  assert_eq "succeeds when an editor is already open" "0" "$rc"
  assert_contains "reports reusing the editor" ":edit" "$out"
  assert_eq "does not launch a nested editor" "absent" \
    "$([ -s "$ARGS_FILE" ] && echo present || echo absent)"
else
  printf '  \033[33mSKIP\033[0m editor reuse (no cc to build the nvim double)\n'
fi

# --- fallback: no tmux -------------------------------------------------------
setup_window
TMUX_SOCKET="" TMUX="" TMUX_PANE="" EDITOR="$FAKE_EDITOR" bash "$SCRIPT" "$WORKDIR/.env" >/dev/null 2>&1
assert_eq "falls back to a local editor outside tmux" \
  "$WORKDIR/.env" "$(tail -1 "$ARGS_FILE" 2>/dev/null)"

# --- fallback: sidebar is the only pane --------------------------------------
"${TMUX_TEST[@]}" kill-server 2>/dev/null
rm -f "$ARGS_FILE"
"${TMUX_TEST[@]}" new-session -d -s solo -c "$WORKDIR" -x 200 -y 50
only="$("${TMUX_TEST[@]}" list-panes -t solo -F '#{pane_id}')"
"${TMUX_TEST[@]}" set -p -t "$only" @sidebar 1
TMUX_SOCKET="$SOCKET" TMUX_PANE="$only" EDITOR="$FAKE_EDITOR" bash "$SCRIPT" "$WORKDIR/.env" >/dev/null 2>&1
assert_eq "falls back when there is no work pane" \
  "$WORKDIR/.env" "$(tail -1 "$ARGS_FILE" 2>/dev/null)"

# --- paths with spaces -------------------------------------------------------
setup_window
spaced="$WORKDIR/my notes.md"
printf '# hi\n' > "$spaced"
open_file "$spaced" >/dev/null
wait_for_args
assert_eq "a path with spaces arrives as a single argument" \
  "$spaced" "$(tail -1 "$ARGS_FILE" 2>/dev/null)"

# --- multiple files ----------------------------------------------------------
setup_window
printf 'a\n' > "$WORKDIR/a.md"; printf 'b\n' > "$WORKDIR/b.md"
open_file "$WORKDIR/a.md" "$WORKDIR/b.md" >/dev/null
wait_for_args
assert_eq "passes every selected file" \
  "$(printf -- '--\n%s\n%s' "$WORKDIR/a.md" "$WORKDIR/b.md")" \
  "$(cat "$ARGS_FILE" 2>/dev/null)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
