#!/usr/bin/env bash
# Tests for the always-on context budget.
#
# Why this exists
# ---------------
# Measured 2026-09-19: the global instruction set cost ~24.6K tokens on EVERY
# turn before the user typed anything — ~12.2K from CLAUDE.md plus its @imports,
# and ~12.4K from the frontmatter of 117 installed skills. The @import mechanism
# is the expensive half and the easy half to fix: an @import is expanded in full
# on every single turn, whether or not the conversation touches its subject,
# while a skill costs only its description until it is invoked.
#
# sdd-orchestrator.md was 19KB / 310 lines of SDD delegation protocol loaded
# unconditionally — paid in full during sessions that never mention SDD. Moving
# it to a skill is worth ~4.7K tokens per turn and changes no behaviour: the
# orchestrator rules apply when orchestrating, which is exactly when the skill
# gets invoked.
#
# The budget assertions at the end are the part that keeps this from regressing.
# A file with no ceiling grows back; CLAUDE.md reached 454 lines against
# Anthropic's documented ~200-line guidance precisely because nothing measured it.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_MD="$REPO/config/claude/CLAUDE.md"
SKILLS="$REPO/shared/skills"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "context-budget"

# --- the @import that cost the most ------------------------------------------

assert_eq "CLAUDE.md does not @import sdd-orchestrator" "no" \
  "$(rg -q '^@sdd-orchestrator\.md' "$CLAUDE_MD" && echo yes || echo no)"

assert_eq "the sdd-orchestrator skill exists" "yes" \
  "$([ -f "$SKILLS/sdd-orchestrator/SKILL.md" ] && echo yes || echo no)"

assert_eq "the skill declares frontmatter name" "yes" \
  "$(rg -q '^name: sdd-orchestrator$' "$SKILLS/sdd-orchestrator/SKILL.md" 2>/dev/null \
      && echo yes || echo no)"

# Moving a file must not quietly lose its content. These are the load-bearing
# rules an orchestrator cannot work without; if the move drops one, the skill is
# a stub wearing the old file's name.
if [ -f "$SKILLS/sdd-orchestrator/SKILL.md" ]; then
  MISSING=""
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    rg -qF -- "$rule" "$SKILLS/sdd-orchestrator/SKILL.md" || MISSING="$MISSING | $rule"
  done <<'RULES'
Mandatory Delegation Triggers
Review Workload Guard
Model Assignments
Sub-Agent Context Protocol
Strict TDD Forwarding
Apply-Progress Continuity
Engram Topic Key Format
UI delegation carries the laws
RULES
  assert_eq "the skill keeps every load-bearing section" "" "$MISSING"
fi

# --- the budget --------------------------------------------------------------
# Anthropic's own guidance is ~200 lines for CLAUDE.md. This ceiling is set
# where the file actually lands after the move, not at an aspirational number,
# so it fails on the next unplanned growth rather than being permanently red.

LINES="$(wc -l <"$CLAUDE_MD" | tr -d ' ')"
CEILING=320
assert_eq "CLAUDE.md stays under $CEILING lines (is $LINES)" "yes" \
  "$([ "$LINES" -le "$CEILING" ] && echo yes || echo no)"

# The always-on instruction set as a whole. RTK.md is small enough to leave
# imported; this ceiling is what catches a new 19KB file joining it.
BYTES=0
for f in "$CLAUDE_MD" "$REPO/config/claude/RTK.md"; do
  [ -f "$f" ] && BYTES=$((BYTES + $(wc -c <"$f" | tr -d ' ')))
done
MAXB=26000
assert_eq "always-on instructions stay under ${MAXB}B (are ${BYTES}B)" "yes" \
  "$([ "$BYTES" -le "$MAXB" ] && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
