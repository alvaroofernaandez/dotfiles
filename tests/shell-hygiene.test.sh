#!/usr/bin/env bash
# Hygiene checks on the versioned shell and git configuration.
#
# These catch the kind of rot that accumulates silently: installers appending
# the same PATH line on every run, paths inherited from someone else's machine,
# and tools installed but never wired up.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSHRC="$REPO/home/zshrc"
GITCONFIG="$REPO/home/gitconfig"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "shell-hygiene"

# --- no duplicated PATH exports ----------------------------------------------
# Installers that append on every run leave the same line many times over. Each
# copy is re-evaluated at every shell start for no benefit.
dupes="$(rg -o 'export PATH="[^"]*"' "$ZSHRC" 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ')"
assert_eq "no PATH export appears more than once" "0" "$dupes"

worst="$(rg -o 'export PATH="[^"]*"' "$ZSHRC" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | rg -o '^\s*[0-9]+' | tr -d ' ')"
assert_eq "the most repeated PATH line appears exactly once" "1" "${worst:-0}"

# --- no directory repeated within a single PATH assignment -------------------
assert_eq "no directory listed twice in the same PATH export" "yes" \
  "$(rg -o 'export PATH="[^"]*"' "$ZSHRC" 2>/dev/null \
     | while read -r line; do
         printf '%s' "$line" | sd 'export PATH="' '' | sd '"$' '' | tr ':' '\n' \
           | rg -v '^\$PATH$' | rg -v '^$' | sort | uniq -d
       done | head -1 | rg -q . && echo no || echo yes)"

# --- no paths belonging to another user or machine ---------------------------
assert_eq "no home directory of another user" "yes" \
  "$(rg -q '/(home|Users)/(?!alvaroofernaandez)[a-z][a-z0-9_-]+' "$ZSHRC" 2>/dev/null && echo no || echo yes)"

assert_eq "no orphan variable pointing at a foreign path" "yes" \
  "$(rg -q 'PROJECT_PATHS=.*/(home|Users)/(?!alvaroofernaandez)' "$ZSHRC" 2>/dev/null && echo no || echo yes)"

# --- installed tools are actually wired up -----------------------------------
# delta only affects git if git is told to use it; installing it does nothing on
# its own.
if command -v delta >/dev/null 2>&1; then
  assert_eq "git uses delta as its pager" "yes" \
    "$(rg -q 'pager\s*=\s*delta' "$GITCONFIG" 2>/dev/null && echo yes || echo no)"
  assert_eq "interactive diffs go through delta" "yes" \
    "$(rg -q 'diffFilter\s*=\s*delta' "$GITCONFIG" 2>/dev/null && echo yes || echo no)"
else
  printf '  \033[33mSKIP\033[0m delta wiring (delta not installed)\n'
fi

# --- the file still parses ---------------------------------------------------
zsh -n "$ZSHRC" 2>/dev/null
assert_eq "zshrc is still valid zsh" "0" "$?"

git config --file "$GITCONFIG" --list >/dev/null 2>&1
assert_eq "gitconfig is still valid" "0" "$?"

# --- PATH stays deduplicated at runtime, not just in the file ----------------
# The file declaring each entry once is not enough: nested shells prepend to an
# inherited PATH that already contains them.
assert_eq "zsh is told to keep PATH unique" "yes" \
  "$(rg -q 'typeset -U path' "$ZSHRC" 2>/dev/null && echo yes || echo no)"

assert_eq "an interactive shell has no repeated PATH entry" "0" \
  "$(zsh -ic 'echo $PATH' 2>/dev/null | tr ':' '\n' | rg -v '^$' | sort | uniq -d | wc -l | tr -d ' ')"

printf '\n%d passed, %d failed\n' "$pass" "$fail"

[ "$fail" -eq 0 ]
