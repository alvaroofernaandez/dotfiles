#!/usr/bin/env bash
# Tests for sidebar-follow.sh — keeping the sidebar tree on the directory the
# work pane is actually in.
#
# This runs from a zsh chpwd hook, so it fires on EVERY directory change. Two
# properties matter as much as the feature itself: it must do nothing at all
# when there is no sidebar, and it must never fail in a way that surfaces in the
# prompt.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOLLOW="$DIR/sidebar-follow.sh"
TOGGLE="$DIR/sidebar-toggle.sh"
SOCKET="follow-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"
CALLS="$WORKDIR/ya-calls.txt"

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

# A stand-in for `ya` that records how it was invoked.
mkdir -p "$WORKDIR/bin"
cat > "$WORKDIR/bin/ya" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$CALLS"
EOF
chmod +x "$WORKDIR/bin/ya"
FAKE_YA="$WORKDIR/bin/ya"

setup_session() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  rm -f "$CALLS"
  "${TMUX_TEST[@]}" new-session -d -s main -c "$WORKDIR" -x 200 -y 50
  sleep 0.4
}

follow() {
  TMUX_SOCKET="$SOCKET" TMUX_PANE="$1" YA_BIN="$FAKE_YA" bash "$FOLLOW" "$2" 2>&1
}

echo "sidebar-follow"

# --- no sidebar: do nothing, cheaply and quietly -----------------------------
setup_session
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
out="$(follow "$work_pane" "$WORKDIR")"
rc=$?

assert_eq "exits cleanly when there is no sidebar" "0" "$rc"
assert_eq "says nothing when there is no sidebar" "" "$out"
assert_eq "does not invoke ya when there is no sidebar" "no" \
  "$([ -s "$CALLS" ] && echo yes || echo no)"

# --- the toggle records the instance id --------------------------------------
setup_session
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
SIDEBAR_CMD="sleep 600" TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" bash "$TOGGLE" >/dev/null 2>&1
sleep 0.6

client_id="$("${TMUX_TEST[@]}" display -p -t "$work_pane" '#{@sidebar_client_id}' 2>/dev/null)"
assert_eq "the toggle stores a yazi client id" "yes" \
  "$([ -n "$client_id" ] && echo yes || echo no)"
assert_eq "the stored id is numeric" "yes" \
  "$(printf '%s' "$client_id" | rg -q '^[0-9]+$' && echo yes || echo no)"

# --- with a sidebar: send cd to that instance --------------------------------
rm -f "$CALLS"
target="$WORKDIR/some dir"
mkdir -p "$target"
follow "$work_pane" "$target" >/dev/null
sleep 0.3

calls="$(cat "$CALLS" 2>/dev/null)"
assert_contains "emits to the recorded instance" "emit-to $client_id" "$calls"
assert_contains "emits a cd command" "cd" "$calls"
assert_contains "passes the target directory" "$target" "$calls"

# --- a path with spaces survives ---------------------------------------------
# The fake records "$*", so the path landing intact proves it was passed as one
# argument rather than being split.
assert_eq "a directory with spaces arrives whole" "yes" \
  "$(printf '%s' "$calls" | rg -qF "$target" && echo yes || echo no)"

# --- must never break the prompt ---------------------------------------------
# The hook runs on every cd. If yazi died, or the id is stale, this still has to
# exit 0 and print nothing, or the failure shows up in the user's shell.
rm -f "$CALLS"
out="$(TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" YA_BIN="/nonexistent/ya" \
  bash "$FOLLOW" "$target" 2>&1)"
rc=$?
assert_eq "exits 0 even when ya is missing" "0" "$rc"
assert_eq "prints nothing when ya is missing" "" "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
