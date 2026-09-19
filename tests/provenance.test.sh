#!/usr/bin/env bash
# Attribution for vendored skills must not silently disappear.
#
# Why this exists
# ---------------
# 47 of the skills under shared/skills are third-party work carrying MIT or
# Apache-2.0 licences. Both permit redistribution; both require the notice to
# travel with the work. Once a skill is reached through the symlink farm the
# licence stops being visible at the point of use, so the obligation is easy to
# forget — especially since these arrived as loose copies in ~/.claude/skills
# where nothing tracked them at all.
#
# Two failure modes are guarded: a licensed skill that never made it into
# PROVENANCE.md, and a SKILL.md whose license/author frontmatter was stripped
# while the skill itself stayed.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="$REPO/shared/skills"
DOC="$SKILLS/PROVENANCE.md"

pass=0
fail=0
ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "provenance"

assert_eq "PROVENANCE.md exists" "yes" "$([ -f "$DOC" ] && echo yes || echo no)"
[ -f "$DOC" ] || { printf '\n%d passed, %d failed\n' "$pass" "$((fail))"; exit 1; }

# Every skill declaring a licence must appear in the table.
MISSING=""
COUNT=0
for d in "$SKILLS"/*/; do
  n="$(basename "$d")"
  f="$d/SKILL.md"
  [ -f "$f" ] || continue
  rg -q '^license: ' "$f" || continue
  COUNT=$((COUNT + 1))
  rg -qF -- "\`$n\`" "$DOC" || MISSING="$MISSING $n"
done
assert_eq "every licensed skill is attributed ($COUNT licensed)" "" "$MISSING"

# The frontmatter is the authoritative notice; the table only mirrors it.
STRIPPED=""
while read -r n; do
  [ -z "$n" ] && continue
  f="$SKILLS/$n/SKILL.md"
  [ -f "$f" ] || { STRIPPED="$STRIPPED $n(gone)"; continue; }
  rg -q '^license: ' "$f" || STRIPPED="$STRIPPED $n"
done <<<"$(rg -o '^\| `([a-z0-9-]+)` \|' -r '$1' "$DOC" 2>/dev/null)"
assert_eq "no attributed skill has lost its licence frontmatter" "" "$STRIPPED"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
