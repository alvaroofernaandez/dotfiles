#!/usr/bin/env bash
# The blocking rules must be identical for Claude Code and OpenCode.
#
# Why this exists
# ---------------
# CLAUDE.md and config/opencode/AGENTS.md are two files carrying one set of
# rules to two agents. The README already records what happens when that is left
# to discipline: when skills were duplicated across the two tools, the copies
# drifted until one said "PRs over 400 changed lines" and the other said
# something else. Rules drift the same way, only more quietly, because nobody
# diffs their instruction files.
#
# The detail no longer needs copying — Design, TDD and gstack moved to skills on
# 2026-09-19, and the manifest fanout carries skills to OpenCode already. What
# still has to exist in both is the blocking summary: the part that must hold
# BEFORE any skill can load. So that block is delimited by markers in CLAUDE.md
# and injected into AGENTS.md by scripts/sync-agent-rules.sh, and this suite
# asserts the two are byte-identical.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_MD="$REPO/config/claude/CLAUDE.md"
AGENTS_MD="$REPO/config/opencode/AGENTS.md"
SYNC="$REPO/scripts/sync-agent-rules.sh"
BEGIN='<!-- shared:agent-rules -->'
END='<!-- /shared:agent-rules -->'

pass=0
fail=0
ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "agent-rules-sync"

block() { awk -v b="$BEGIN" -v e="$END" '$0==b{f=1;next} $0==e{f=0} f' "$1"; }

assert_eq "the sync script exists" "yes" "$([ -x "$SYNC" ] && echo yes || echo no)"
assert_eq "CLAUDE.md delimits the shared block" "yes" \
  "$(rg -qF -- "$BEGIN" "$CLAUDE_MD" && rg -qF -- "$END" "$CLAUDE_MD" && echo yes || echo no)"
assert_eq "AGENTS.md delimits the shared block" "yes" \
  "$(rg -qF -- "$BEGIN" "$AGENTS_MD" && rg -qF -- "$END" "$AGENTS_MD" && echo yes || echo no)"

C="$(block "$CLAUDE_MD")"
A="$(block "$AGENTS_MD")"
assert_eq "the shared block is non-empty" "yes" "$([ -n "$C" ] && echo yes || echo no)"
assert_eq "both agents carry byte-identical blocking rules" "yes" \
  "$([ "$C" = "$A" ] && echo yes || echo no)"

# The rules that must survive in both, whatever else changes.
MISSING=""
for rule in 'design-pipeline' 'design-gates' 'DESIGN_PIPELINE_OFF' 'tdd-gate' 'RED' 'strict-tdd'; do
  printf '%s' "$C" | rg -qF -- "$rule" || MISSING="$MISSING $rule"
done
assert_eq "the shared block keeps every blocking rule" "" "$MISSING"

# Running the sync must be a no-op when things are already in sync; if it is
# not idempotent it will churn the file on every install.
if [ -x "$SYNC" ]; then
  BEFORE="$(md5 -q "$AGENTS_MD" 2>/dev/null || md5sum "$AGENTS_MD" | cut -d' ' -f1)"
  "$SYNC" >/dev/null 2>&1
  AFTER="$(md5 -q "$AGENTS_MD" 2>/dev/null || md5sum "$AGENTS_MD" | cut -d' ' -f1)"
  assert_eq "the sync is idempotent" "$BEFORE" "$AFTER"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
