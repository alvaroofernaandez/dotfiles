#!/usr/bin/env bash
# Tests for Ghostty's split navigation keybindings.
#
# The 8 panels in a Ghostty window are Ghostty SPLITS, each running its own tmux
# session, so moving between them is Ghostty's job — tmux never sees those keys.
#
# Ghostty offers no "go to split N": goto_split takes directions and previous /
# next only, verified against the binary (goto_split:1 → error.InvalidFormat).
# So navigation has to be directional plus cycling, and the bindings must not
# collide with macOS system shortcuts or with vim-tmux-navigator inside tmux.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$REPO/config/ghostty/config"
GHOSTTY="/Applications/Ghostty.app/Contents/MacOS/ghostty"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "ghostty-keys"

# --- directional navigation without leaving the home row ---------------------
for dir in left down up right; do
  assert_eq "a home-row key moves $dir" "yes" \
    "$(rg -q "^keybind = .*[hjkl]=goto_split:$dir" "$CONF" 2>/dev/null && echo yes || echo no)"
done

# --- cycling, for sweeping through many splits -------------------------------
for way in previous next; do
  assert_eq "a key cycles to the $way split" "yes" \
    "$(rg -q "^keybind = .*=goto_split:$way" "$CONF" 2>/dev/null && echo yes || echo no)"
done

# --- must not shadow macOS system shortcuts ----------------------------------
# cmd+h hides the app, cmd+m minimises, cmd+q quits. Binding those inside a
# terminal takes them away everywhere else in the window.
for sys in 'cmd\+h=' 'cmd\+m=' 'cmd\+q='; do
  assert_eq "does not bind bare ${sys%=}" "yes" \
    "$(rg -q "^keybind = $sys" "$CONF" 2>/dev/null && echo no || echo yes)"
done

# --- must not steal vim-tmux-navigator's keys --------------------------------
# Ghostty receives keys BEFORE tmux, so binding ctrl+h/j/k/l here would break
# pane navigation inside every tmux session.
assert_eq "leaves ctrl+hjkl to tmux and vim" "yes" \
  "$(rg -q '^keybind = ctrl\+[hjkl]=' "$CONF" 2>/dev/null && echo no || echo yes)"

# --- Option must stay a composition modifier ---------------------------------
# On the "Spanish - ISO" layout this machine uses, Option composes the whole
# programming character set: @ (opt+2), | (opt+1), # (opt+3), [ ] { } \ and
# ~ (opt+ñ). Turning it into Alt/meta makes every one of them untypable, and
# nothing here needs meta — the only <A-…> maps in Neovim are <Nop>.
assert_eq "Option is not turned into Alt" "yes" \
  "$(rg -q '^macos-option-as-alt = (true|left|right)' "$CONF" 2>/dev/null && echo no || echo yes)"

# --- no duplicate bindings ----------------------------------------------------
dupes="$(rg -o '^keybind = [^=]+' "$CONF" 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ')"
assert_eq "no key is bound twice" "0" "$dupes"

# --- Ghostty itself accepts the file -----------------------------------------
if [ -x "$GHOSTTY" ]; then
  out="$("$GHOSTTY" +validate-config --config-file="$CONF" 2>&1)"
  assert_eq "ghostty accepts the config" "" "$out"
else
  printf '  \033[33mSKIP\033[0m config validation (ghostty binary not found)\n'
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
