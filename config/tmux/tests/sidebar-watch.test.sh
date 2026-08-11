#!/usr/bin/env bash
# Tests for sidebar-watch.sh — the safety net that keeps the tree in sync even
# when the shell has no chpwd hook.
#
# The zsh hook is instant and free, but it only exists in shells started after
# it was installed. This watcher covers every other case. Two properties decide
# whether it is acceptable: it must die with the sidebar (no orphan loops), and
# it must stay quiet when nothing changed.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCH="$DIR/sidebar-watch.sh"
TOGGLE="$DIR/sidebar-toggle.sh"
SOCKET="watch-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"
CALLS="$WORKDIR/ya-calls.txt"

pass=0
fail=0

cleanup() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  pkill -f "sidebar-watch.sh.*$SOCKET" 2>/dev/null
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

mkdir -p "$WORKDIR/bin"
cat > "$WORKDIR/bin/ya" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$CALLS"
EOF
chmod +x "$WORKDIR/bin/ya"
# Named yazi so the toggle takes its real code path and assigns a client id.
printf '#!/usr/bin/env bash\nsleep 600\n' > "$WORKDIR/bin/yazi"
chmod +x "$WORKDIR/bin/yazi"

mkdir -p "$WORKDIR/a" "$WORKDIR/b"

# Counts running watchers only. A bare match on "sidebar-watch.sh" also counts
# THIS test file, whose own name contains it, so the count never appeared to
# change.
watchers() { pgrep -fl 'sidebar-watch\.sh' 2>/dev/null | rg -v '\.test\.sh' | wc -l | tr -d ' '; }

echo "sidebar-watch"

# --- the toggle starts a watcher --------------------------------------------
"${TMUX_TEST[@]}" new-session -d -s main -c "$WORKDIR/a" -x 200 -y 50
sleep 0.4
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
before_watchers="$(watchers)"

SIDEBAR_CMD="$WORKDIR/bin/yazi" YA_BIN="$WORKDIR/bin/ya" \
  TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" WATCH_INTERVAL=0.3 \
  bash "$TOGGLE" >/dev/null 2>&1
sleep 1.2

assert_eq "opening the sidebar starts a watcher" "yes" \
  "$([ "$(watchers)" -gt "$before_watchers" ] && echo yes || echo no)"

# --- it syncs a directory change without any shell hook ----------------------
# No chpwd hook is involved here at all: the cwd is changed by the pane's own
# shell and only the watcher can notice.
rm -f "$CALLS"
"${TMUX_TEST[@]}" send-keys -t "$work_pane" "cd '$WORKDIR/b'" Enter
sleep 2

calls="$(cat "$CALLS" 2>/dev/null)"
assert_eq "notices the change with no shell hook" "yes" \
  "$([ -s "$CALLS" ] && echo yes || echo no)"
assert_contains "emits cd to the new directory" "$WORKDIR/b" "$calls"

# --- it stays quiet when nothing moves ---------------------------------------
rm -f "$CALLS"
sleep 2
assert_eq "emits nothing while the directory is unchanged" "no" \
  "$([ -s "$CALLS" ] && echo yes || echo no)"

# --- it dies with the sidebar ------------------------------------------------
# An orphaned polling loop would keep waking up forever after the panel closed.
SIDEBAR_CMD="$WORKDIR/bin/yazi" YA_BIN="$WORKDIR/bin/ya" \
  TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" bash "$TOGGLE" >/dev/null 2>&1
sleep 2.5

assert_eq "closing the sidebar stops the watcher" "$before_watchers" "$(watchers)"

# --- and dies if the whole server goes away ----------------------------------
SIDEBAR_CMD="$WORKDIR/bin/yazi" YA_BIN="$WORKDIR/bin/ya" \
  TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" WATCH_INTERVAL=0.3 \
  bash "$TOGGLE" >/dev/null 2>&1
sleep 1
"${TMUX_TEST[@]}" kill-server 2>/dev/null
sleep 2.5
assert_eq "killing tmux stops the watcher" "$before_watchers" "$(watchers)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
