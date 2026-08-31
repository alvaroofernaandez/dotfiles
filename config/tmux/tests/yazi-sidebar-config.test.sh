#!/usr/bin/env bash
# Tests for the sidebar-specific yazi config.
#
# The sidebar runs yazi with its own YAZI_CONFIG_HOME so it can drop the parent
# and preview columns, which do not fit in ~60 cols. yazi does NOT merge that
# directory with ~/.config/yazi, so the opener and show_hidden must be repeated
# there — and are therefore asserted to stay identical to the main config.
set -uo pipefail

MAIN_CONFIG="$HOME/.config/yazi/yazi.toml"
SIDEBAR_CONFIG_HOME="$HOME/.config/yazi-sidebar"
SIDEBAR_CONFIG="$SIDEBAR_CONFIG_HOME/yazi.toml"
TOGGLE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sidebar-toggle.sh"

SOCKET="yazicfg-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")
WORKDIR="$(mktemp -d)"

# Bounded waits, so the end-to-end assertions poll for the pane to settle
# instead of betting a fixed sleep on how fast the machine is.
# shellcheck source=lib/wait.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/wait.sh"

pass=0
fail=0

cleanup() {
  "${TMUX_TEST[@]}" kill-server 2>/dev/null
  # The e2e block runs on its own socket; leaving that server behind would keep
  # a yazi process alive past the suite.
  [ -n "${SOCKET_E2E:-}" ] && tmux -L "$SOCKET_E2E" kill-server 2>/dev/null
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

# Value of a simple `key = value` line within a TOML file.
toml_value() { rg -N --no-heading "^\s*$2\s*=" "$1" 2>/dev/null | head -1 | sd '^\s*[^=]+=\s*' '' | sd '\s+$' ''; }

echo "yazi-sidebar-config"

# --- the config exists and yazi accepts it ----------------------------------
assert_eq "sidebar config exists" "yes" \
  "$([ -f "$SIDEBAR_CONFIG" ] && echo yes || echo no)"

# yazi moved this introspection between releases: newer builds answer with
# `ya env` and reduce `yazi --debug` to a deprecation notice, older ones only
# have `--debug`. Both are tried, newest first, because which yazi is installed
# is the machine's business and not this repo's.
debug="$(YAZI_CONFIG_HOME="$SIDEBAR_CONFIG_HOME" ya env 2>/dev/null || true)"
if ! printf '%s' "$debug" | rg -qi 'yazi'; then
  debug="$(YAZI_CONFIG_HOME="$SIDEBAR_CONFIG_HOME" yazi --debug 2>&1 || true)"
fi

# A build that answers neither is reported as a skip, not a failure. Asserting
# against an empty string would claim the sidebar config is broken when the
# only thing that changed is how yazi reports its paths.
if printf '%s' "$debug" | rg -qi 'deprecated' || [ -z "$debug" ]; then
  printf '  \033[33mSKIP\033[0m yazi loads the sidebar config (this yazi reports no config paths)\n'
  printf '  \033[33mSKIP\033[0m yazi reports no config error (this yazi reports no config paths)\n'
else
  assert_contains "yazi loads the sidebar config" "$SIDEBAR_CONFIG" "$debug"
  assert_eq "yazi reports no config error" "clean" \
    "$(printf '%s' "$debug" | rg -qi 'invalid|failed to parse|error.*toml' && echo dirty || echo clean)"
fi

# --- layout: tree only ------------------------------------------------------
ratio="$(toml_value "$SIDEBAR_CONFIG" ratio)"
assert_contains "ratio hides the parent column" "0," "$ratio"
assert_eq "ratio hides the preview column" "yes" \
  "$(printf '%s' "$ratio" | rg -q '0\s*\]$' && echo yes || echo no)"
assert_eq "ratio keeps the current column visible" "yes" \
  "$(printf '%s' "$ratio" | sd '[^0-9]' ' ' | awk '{print ($2 > 0) ? "yes" : "no"}')"

# --- no divergence from the main config -------------------------------------
assert_eq "opener matches the main config" \
  "$(rg -N --no-heading 'open-in-work-pane' "$MAIN_CONFIG" | sd '^\s+' '')" \
  "$(rg -N --no-heading 'open-in-work-pane' "$SIDEBAR_CONFIG" | sd '^\s+' '')"

assert_eq "show_hidden matches the main config" \
  "$(toml_value "$MAIN_CONFIG" show_hidden)" \
  "$(toml_value "$SIDEBAR_CONFIG" show_hidden)"

# --- the toggle injects YAZI_CONFIG_HOME ------------------------------------
# A stand-in for yazi that records the env var it was launched with.
cat > "$WORKDIR/probe.sh" <<EOF
#!/usr/bin/env bash
printf '%s' "\${YAZI_CONFIG_HOME:-unset}" > "$WORKDIR/env.txt"
sleep 600
EOF
chmod +x "$WORKDIR/probe.sh"

"${TMUX_TEST[@]}" new-session -d -s main -c "$WORKDIR" -x 200 -y 50
work_pane="$("${TMUX_TEST[@]}" list-panes -t main -F '#{pane_id}')"
for _ in $(seq 1 60); do
  [ -n "$("${TMUX_TEST[@]}" display -p -t "$work_pane" '#{pane_current_command}')" ] && break
  sleep 0.1
done
SIDEBAR_CMD="$WORKDIR/probe.sh" TMUX_SOCKET="$SOCKET" TMUX_PANE="$work_pane" bash "$TOGGLE"
for _ in $(seq 1 60); do [ -s "$WORKDIR/env.txt" ] && break; sleep 0.1; done

assert_eq "toggle launches the sidebar with YAZI_CONFIG_HOME" \
  "$SIDEBAR_CONFIG_HOME" "$(cat "$WORKDIR/env.txt" 2>/dev/null)"

# --- e2e: long names are not truncated at sidebar width ---------------------
# On a socket of its own rather than kill-server on the shared one followed by
# a rebuild. That pattern is a race: kill-server only STARTS the shutdown, so
# the new-session after it can land on a server that is still dying, which then
# finishes and unlinks the socket, taking the new session with it. Everything
# after fails with "no server running", every variable reads empty, and the
# assertion reports a sidebar that was never built. It is what made CI red.
#
# Waiting cannot fix that shape — it waits for something that will never come.
# A fresh socket cannot collide with a server that is shutting down.
SOCKET_E2E="$SOCKET-e2e"
TMUX_E2E=(tmux -L "$SOCKET_E2E")
long="un-nombre-de-archivo-bastante-largo.md"
E2E="$(mktemp -d)"
printf '# hi\n' > "$E2E/$long"
"${TMUX_E2E[@]}" new-session -d -s e2e -c "$E2E" -x 200 -y 50
e2e_pane="$("${TMUX_E2E[@]}" list-panes -t e2e -F '#{pane_id}')"
for _ in $(seq 1 60); do
  [ -n "$("${TMUX_E2E[@]}" display -p -t "$e2e_pane" '#{pane_current_command}')" ] && break
  sleep 0.1
done
TMUX_SOCKET="$SOCKET_E2E" TMUX_PANE="$e2e_pane" bash "$TOGGLE"

# Two waits, because there are two races here and a fixed sleep covered
# neither reliably. First the sidebar pane has to exist and carry the @sidebar
# flag; reading the pane list straight after the toggle can return nothing at
# all. Then yazi has to paint its first frame into it.
#
# This assertion is the one that failed on CI with an empty capture while
# passing locally every time — the 2.5s sleep it used to rely on was simply a
# bet on runner speed. `find_sidebar` is polled rather than read once, and the
# capture retries until the filename appears or ten seconds pass.
find_sidebar() {
  "${TMUX_E2E[@]}" list-panes -t e2e -F '#{pane_id}|#{?@sidebar,1,0}' \
    | awk -F'|' '$2=="1"{print $1}'
}
sidebar="$(wait_until 10 '%' find_sidebar)"

assert_contains "shows the full filename at sidebar width" \
  "$long" "$(wait_until 10 "$long" "${TMUX_E2E[@]}" capture-pane -p -t "$sidebar")"
rm -rf "$E2E"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
