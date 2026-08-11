#!/usr/bin/env bash
# Tests for the sidebar keybindings, resolved from a real tmux server.
#
# Context that drove these: on a "Spanish - ISO" macOS layout, Option+E is the
# DEAD KEY for the acute accent. The OS consumes it to compose á/é/í, so M-e
# never reaches tmux. Any binding here must not collide with a dead key, and at
# least one route must work without Option at all.
set -uo pipefail

CONF="$HOME/.tmux.conf"
SOCKET="keys-test-$$"
TMUX_TEST=(tmux -L "$SOCKET")

# Option+<key> dead keys on Spanish ISO: acute, circumflex, diaeresis, tilde.
DEAD_KEYS=(e i u n)

pass=0
fail=0

cleanup() { "${TMUX_TEST[@]}" kill-server 2>/dev/null; }
trap cleanup EXIT

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "keybindings"

"${TMUX_TEST[@]}" -f "$CONF" new-session -d 2>/dev/null
sleep 1.5

root_keys="$("${TMUX_TEST[@]}" list-keys -T root 2>/dev/null)"
prefix_keys="$("${TMUX_TEST[@]}" list-keys -T prefix 2>/dev/null)"

# --- a route that never goes through Option ---------------------------------
assert_eq "prefix+e toggles the sidebar" "yes" \
  "$(printf '%s' "$prefix_keys" | rg -q 'bind-key\s+-T prefix\s+e\b.*sidebar-toggle' && echo yes || echo no)"

# --- a one-press route that avoids dead keys ---------------------------------
alt_binding="$(printf '%s' "$root_keys" | rg -o 'M-[a-z]\s+run-shell.*sidebar-toggle' | rg -o 'M-[a-z]' | head -1)"
assert_eq "a single-press Alt binding exists" "yes" \
  "$([ -n "$alt_binding" ] && echo yes || echo no)"

alt_key="${alt_binding#M-}"
collides=no
for dk in "${DEAD_KEYS[@]}"; do
  [ "$alt_key" = "$dk" ] && collides=yes
done
assert_eq "the Alt binding is not a Spanish-ISO dead key" "no" "$collides"

# --- the retired binding must be gone ----------------------------------------
assert_eq "M-e is no longer bound to the sidebar" "yes" \
  "$(printf '%s' "$root_keys" | rg -q 'M-e\s+run-shell.*sidebar-toggle' && echo no || echo yes)"

# --- no collision with the existing scratch popup ----------------------------
assert_eq "does not clash with the M-g scratch popup" "yes" \
  "$([ "$alt_binding" != "M-g" ] && echo yes || echo no)"

# --- both routes point at the same script ------------------------------------
assert_eq "both routes run the same toggle" "2" \
  "$(printf '%s\n%s' "$root_keys" "$prefix_keys" | rg -c 'sidebar-toggle\.sh')"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
