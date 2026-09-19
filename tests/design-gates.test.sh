#!/usr/bin/env bash
# Tests for the vendored design gates.
#
# Why this exists
# ---------------
# The design pipeline spent months as five advisory skills that asked the model
# to grade its own work. Nothing measured anything, so nothing ever failed —
# which is why `impeccable` aborting on NO_PRODUCT_MD in every project went
# unnoticed: a pipeline that only reports success has no way to report that a
# step never ran.
#
# These gates replace the self-report with a number. They come from
# plugin87/ux-ui-agent-skills, vendored at the commit in P87_PIN.
#
# THE BUG THIS SUITE EXISTS TO PREVENT
# ------------------------------------
# plugin87's SKILL.md files invoke their scripts as `python3 scripts/contrast.py`
# — a path relative to the CWD. That is character-for-character the defect that
# made `impeccable` unrunnable: its SKILL.md ran
# `node .agents/skills/impeccable/scripts/context.mjs`, a project-relative path
# against a global install, so every project raised "Cannot find module" and
# step 3 of the pipeline never executed, in any repo, for as long as it was
# installed. Installing these skills unpatched reproduces that exactly.
#
# So the vendoring rewrites those invocations to absolute paths, and the tests
# below assert both halves: that no relative invocation survives, and that the
# gates actually produce correct numbers when run from an unrelated directory.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATES="$REPO/shared/skills/design-gates"

pass=0
fail=0
ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "design-gates"

# --- the vendored tree -------------------------------------------------------

assert_eq "the design-gates skill exists" "yes" \
  "$([ -f "$GATES/SKILL.md" ] && echo yes || echo no)"

assert_eq "the upstream pin is recorded" "yes" \
  "$([ -f "$REPO/P87_PIN" ] && echo yes || echo no)"

MISSING=""
for s in contrast.py validate_tokens.py validate_contrast.py lint_hardcodes.py validate_theme_refs.py; do
  [ -f "$GATES/scripts/$s" ] || MISSING="$MISSING $s"
done
assert_eq "every static gate is vendored" "" "$MISSING"

# --- the impeccable bug, asserted directly -----------------------------------
# A relative invocation anywhere in the vendored skills means a global install
# breaks in every project, silently, exactly as impeccable did.
if [ -d "$GATES" ]; then
  RELATIVE="$(rg -l -e 'python3 scripts/' -e 'node scripts/' "$GATES" 2>/dev/null | head -3)"
  assert_eq "no skill invokes a gate by relative path" "" "$RELATIVE"
fi

# --- the gates actually run, from an unrelated cwd ---------------------------
# Running from /tmp is the point: it is the condition under which impeccable
# failed. A gate that only works when you happen to be inside its own repo is
# not installed, it is merely present.
if [ -f "$GATES/scripts/contrast.py" ]; then
  OUT="$(cd /tmp && python3 "$GATES/scripts/contrast.py" "#767676" "#ffffff" 2>&1)"
  # #767676 on white is 4.54:1 — the canonical darkest grey that clears AA.
  assert_eq "contrast gate returns the known-correct ratio" "yes" \
    "$(printf '%s' "$OUT" | rg -q '4\.5[0-9]?:1' && echo yes || echo no)"
  assert_eq "contrast gate reports AA pass for #767676" "yes" \
    "$(printf '%s' "$OUT" | rg -q 'Normal text  AA.*PASS' && echo yes || echo no)"

  (cd /tmp && python3 "$GATES/scripts/contrast.py" "#999999" "#ffffff" >/dev/null 2>&1)
  assert_eq "contrast gate exits non-zero on an AA failure" "yes" \
    "$([ $? -ne 0 ] && echo yes || echo no)"
fi

# --- the pipeline no longer runs on self-reported prose ----------------------
PIPELINE="$REPO/shared/skills/design-pipeline/SKILL.md"
if [ -f "$PIPELINE" ]; then
  for gone in impeccable frontend-design design-motion-principles; do
    assert_eq "the pipeline no longer requires $gone" "no" \
      "$(rg -q "^[0-9]\..*$gone" "$PIPELINE" && echo yes || echo no)"
  done
  assert_eq "the pipeline requires a gates step" "yes" \
    "$(rg -q '^2\. gates' "$PIPELINE" && echo yes || echo no)"
fi

# --- the design reference skill ---------------------------------------------
# ui-ux-pro-max is the reference oracle the pipeline's "direction" step reads.
# It was installed as a loose copy in ~/.claude/skills — unversioned, invisible
# to the manifest, and therefore never updated: measured 2026-09-19 it still
# carried 97 palette rows against upstream's 193, 50 font pairings against 74,
# and 9 stacks against 22. A skill nothing can update is a skill that rots.
#
# Vendoring it puts it under the same pin-and-sync discipline as the gates, and
# the fanout carries it to OpenCode, which the loose copy never reached.

UIUX="$REPO/shared/skills/ui-ux-pro-max"

assert_eq "ui-ux-pro-max is vendored" "yes" \
  "$([ -f "$UIUX/SKILL.md" ] && echo yes || echo no)"

assert_eq "its pin is recorded" "yes" \
  "$([ -f "$REPO/UIUX_PIN" ] && echo yes || echo no)"

# The numbers, not the prose. A stale copy is caught by row counts even when the
# SKILL.md text happens to match.
if [ -f "$UIUX/data/colors.csv" ]; then
  ROWS="$(wc -l <"$UIUX/data/colors.csv" | tr -d ' ')"
  assert_eq "the palette data is the current set, not the 97-row copy ($ROWS rows)" "yes" \
    "$([ "$ROWS" -gt 150 ] && echo yes || echo no)"
fi

assert_eq "the stale loose copy is gone from ~/.claude/skills" "yes" \
  "$([ ! -e "$HOME/.claude/skills/ui-ux-pro-max" ] || [ -L "$HOME/.claude/skills/ui-ux-pro-max" ] && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
