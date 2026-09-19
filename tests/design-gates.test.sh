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

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

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

# --- the refactor half of the pipeline --------------------------------------
# design-gates started as five review skills plus seven static checks: good for
# judging a surface, useless for improving one. These four are the other half —
# they read an existing codebase and rewrite it. `redesign` audits and applies
# in order (tokens, typography, states, motion) without touching routes or data;
# `migrate-design-system` crosswalks an existing UI onto shadcn/ui or Radix;
# `design-component` and `design-code` replace raw native elements with one
# shared accessible primitive layer.
#
# They are the reason the render gates get vendored too. design-component's own
# contract is "You must screenshot the harness and inspect it before claiming
# done", and it runs verify_states / axe_audit / verify_focustrap to do it.
# Vendoring the skills without those scripts would ship the instruction to
# verify with no way to verify — the shape of failure this whole pipeline was
# rebuilt to get away from.

MISSING=""
for s in redesign migrate-design-system design-component design-code; do
  [ -f "$GATES/skills/$s/SKILL.md" ] || MISSING="$MISSING $s"
done
assert_eq "the four refactor skills are vendored" "" "$MISSING"

MISSING=""
for g in verify_states.mjs axe_audit.mjs verify_focustrap.mjs verify_target_size.mjs verify_reduced_motion.mjs measure_render.mjs; do
  [ -f "$GATES/scripts/$g" ] || MISSING="$MISSING $g"
done
assert_eq "the render gates are vendored" "" "$MISSING"

# The references those skills route into. redesign step 1 reads the audit
# workflow; a vendored skill whose first instruction points at a missing file is
# the impeccable failure again.
MISSING=""
for r in workflows/redesign-audit.md taste/design-taste.md design-systems/interop-protocol.md; do
  [ -f "$GATES/reference/$r" ] || MISSING="$MISSING $r"
done
assert_eq "the references those skills read are vendored" "" "$MISSING"

# The gap plugin87 does not close. Its 16 framework adapters cover Vue, Svelte,
# Angular, Solid, Lit, React Native, Flutter and Compose — none is shadcn, and
# Radix appears only as a crosswalk target. The decision doc is this repo's own
# work, written because the alternative (Impertio-Studio's 42-skill package) 
# would have added tens of KB of always-on frontmatter for one narrow concern.
SHADCN="$REPO/shared/skills/design-refactor/reference/native-to-shadcn.md"
assert_eq "the native-to-shadcn decision doc exists" "yes" \
  "$([ -f "$SHADCN" ] && echo yes || echo no)"

if [ -f "$SHADCN" ]; then
  MISSING=""
  for el in "<select>" "<dialog>" "Combobox" "Radix" "register" "aria-"; do
    rg -qF -- "$el" "$SHADCN" || MISSING="$MISSING $el"
  done
  assert_eq "it covers the native elements and the RHF pitfall" "" "$MISSING"
fi

# One entry point, one description. Four more top-level skills would have cost
# four more always-on descriptions; the budget test exists to stop exactly that.
REFACTOR="$REPO/shared/skills/design-refactor/SKILL.md"
assert_eq "design-refactor is a single entry point" "yes" \
  "$([ -f "$REFACTOR" ] && echo yes || echo no)"

if [ -f "$REFACTOR" ]; then
  FM="$(awk '/^---$/{c++;next} c==1{print} c==2{exit}' "$REFACTOR" | wc -c | tr -d ' ')"
  assert_eq "its description stays under 700B (is ${FM}B)" "yes" \
    "$([ "$FM" -le 700 ] && echo yes || echo no)"
fi

# --- every render gate must run on the vendored browser ---------------------
# Upstream launches Chrome by channel: `chromium.launch({ channel: 'chrome' })`.
# Seven of the fourteen render gates follow it with `.catch(() => chromium.launch())`
# and seven do not — and those seven crash outright on a machine that has the
# Playwright chromium but not desktop Google Chrome:
#
#   browserType.launch: Chromium distribution 'chrome' is not found at
#   /Applications/Google Chrome.app/...
#
# Caught by running verify_target_size.mjs for real after installing Playwright.
# A gate that throws instead of reporting is worse than one that skips: the skip
# path is deliberate upstream design (it prints SKIPPED and exits 0 unless
# DS_REQUIRE_BROWSER=1), while an uncaught launch error just looks like the tool
# is broken. p87-sync.sh adds the missing fallback.

UNGUARDED=""
for f in "$GATES"/scripts/*.mjs; do
  [ -f "$f" ] || continue
  rg -q "channel: *'chrome'" "$f" || continue
  rg -q "channel: *'chrome' *\} *\) *\.catch" "$f" || UNGUARDED="$UNGUARDED $(basename "$f")"
done
assert_eq "every render gate falls back to the vendored chromium" "" "$UNGUARDED"

# --- the no-native-components rule ------------------------------------------
# Standing rule, stated by the maintainer on 2026-09-19: native interactive
# elements are never acceptable — no native date picker, no raw <select>, no
# browser <dialog>, no confirm()/alert(). Always a custom shadcn/Radix
# component.
#
# Written into CLAUDE.md it would be a reminder; the whole point of today's work
# is that reminders do not hold. So it is also a gate: lint_native_elements.py
# reads the source and exits non-zero on a hit, which is the difference between
# a rule and a preference.

# Lives under design-refactor, not design-gates, and the reason is mechanical:
# scripts/p87-sync.sh starts with `rm -rf "$DEST"`, so anything hand-written
# inside design-gates is destroyed on the next sync. That already happened once,
# to the root SKILL.md, and the suite caught it. Upstream's files live in
# design-gates; this repo's own work lives in design-refactor.
NATIVE_GATE="$REPO/shared/skills/design-refactor/scripts/lint_native_elements.py"
assert_eq "the native-element gate exists" "yes" \
  "$([ -f "$NATIVE_GATE" ] && echo yes || echo no)"

if [ -f "$NATIVE_GATE" ]; then
  FIX="$TMPD/native"
  mkdir -p "$FIX"
  cat >"$FIX/Bad.tsx" <<'BAD'
export function Bad() {
  return (
    <form>
      <select name="country"><option>ES</option></select>
      <input type="date" name="when" />
      <dialog open>hi</dialog>
    </form>
  )
}
BAD
  cat >"$FIX/Good.tsx" <<'GOOD'
import { Select, SelectTrigger } from "@/components/ui/select"
import { Calendar } from "@/components/ui/calendar"
export function Good() {
  return (
    <form>
      <Select name="country"><SelectTrigger /></Select>
      <Calendar />
    </form>
  )
}
GOOD

  OUT="$(cd /tmp && python3 "$NATIVE_GATE" "$FIX/Bad.tsx" 2>&1)"; RC=$?
  assert_eq "it flags a native <select>" "yes" \
    "$(printf '%s' "$OUT" | rg -qi 'select' && echo yes || echo no)"
  assert_eq "it flags a native date input" "yes" \
    "$(printf '%s' "$OUT" | rg -qi 'date' && echo yes || echo no)"
  assert_eq "it flags a native <dialog>" "yes" \
    "$(printf '%s' "$OUT" | rg -qi 'dialog' && echo yes || echo no)"
  assert_eq "it exits non-zero on a violation" "yes" \
    "$([ "$RC" -ne 0 ] && echo yes || echo no)"

  (cd /tmp && python3 "$NATIVE_GATE" "$FIX/Good.tsx" >/dev/null 2>&1)
  assert_eq "it passes clean shadcn components" "yes" \
    "$([ $? -eq 0 ] && echo yes || echo no)"
fi

# The rule has to be stated where both agents read it, not only in the gate.
assert_eq "CLAUDE.md states the no-native-components rule" "yes" \
  "$(rg -qi 'never.{0,40}native' "$REPO/config/claude/CLAUDE.md" && echo yes || echo no)"
assert_eq "AGENTS.md carries it too" "yes" \
  "$(rg -qi 'never.{0,40}native' "$REPO/config/opencode/AGENTS.md" && echo yes || echo no)"

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
