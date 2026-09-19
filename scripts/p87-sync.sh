#!/usr/bin/env bash
# Vendor the design gates from plugin87/ux-ui-agent-skills into shared/skills.
#
# Why vendored rather than installed
# ----------------------------------
# Upstream ships as a Claude Code plugin. A plugin reaches Claude Code only —
# and this setup fans every skill out to OpenCode as well, so a plugin install
# would silently make design enforcement Claude-only. Vendoring puts the gates
# in shared/skills where the manifest carries them to both.
#
# Why patched rather than copied
# ------------------------------
# Upstream's SKILL.md files invoke their scripts as `python3 scripts/contrast.py`
# — relative to the CWD. Installed globally that resolves against whatever
# project you happen to be in, so the gate raises "No such file" everywhere.
# This is not hypothetical: it is the exact defect that made `impeccable`
# unrunnable in every repo for as long as it was installed, because its SKILL.md
# ran a project-relative `node .agents/skills/impeccable/scripts/context.mjs`
# against a global install. The rewrite below points every invocation at the
# vendored copy's absolute location.
#
# What is deliberately NOT vendored
# ---------------------------------
# - design-systems/ (1.7MB, 138 brand systems) and the `apply-aesthetic` skill
#   that reads it. ui-ux-pro-max already covers that job with 192 palettes;
#   carrying a second library would be the duplication the gstack policy rejects.
# - The 16 render gates (verify_*.mjs, axe_audit.mjs, measure_render.mjs).
#   They need Playwright and its ~300MB browser download. They are listed in the
#   skill as opt-in, so the ones that need a browser announce that they do.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO/shared/skills/design-gates"
PIN_FILE="$REPO/P87_PIN"
UPSTREAM="https://github.com/plugin87/ux-ui-agent-skills.git"
SKILLS=(design-doctrine design-review design-qa a11y-audit design-tokens)
STATIC_GATES=(contrast.py validate_tokens.py validate_contrast.py lint_hardcodes.py
              validate_theme_refs.py check_no_emoji.py validate_component_spec.py)

say() { printf '\033[36m%s\033[0m\n' "$*"; }

PIN="${1:-}"
if [ -z "$PIN" ] && [ -f "$PIN_FILE" ]; then
  PIN="$(rg -o '^commit: (\S+)' -r '$1' "$PIN_FILE" 2>/dev/null | head -1)"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "cloning $UPSTREAM"
git clone -q "$UPSTREAM" "$TMP/src"
if [ -n "$PIN" ]; then
  git -C "$TMP/src" checkout -q "$PIN"
else
  PIN="$(git -C "$TMP/src" rev-parse HEAD)"
fi
DATE="$(git -C "$TMP/src" log -1 --format=%ad --date=short)"

ABS='$HOME/.claude/skills/design-gates'

rm -rf "$DEST"
mkdir -p "$DEST/scripts" "$DEST/skills" "$DEST/accessibility"

# The same rewrite is applied to the scripts' own --help text. Upstream's usage
# strings say `python3 scripts/contrast.py`, which is correct inside upstream's
# repo and wrong everywhere else; leaving them would hand anyone who runs --help
# a command that cannot work. Only the usage docstrings match this pattern —
# no executable line does.
for g in "${STATIC_GATES[@]}"; do
  [ -f "$TMP/src/scripts/$g" ] || continue
  sed -e "s#python3 scripts/#python3 $ABS/scripts/#g" \
      "$TMP/src/scripts/$g" >"$DEST/scripts/$g"
  chmod +x "$DEST/scripts/$g"
done
cp "$TMP/src"/accessibility/*.md "$DEST/accessibility/" 2>/dev/null || true

# The rewrite. `python3 scripts/x.py` -> `python3 <abs>/scripts/x.py`, using a
# path that resolves through the symlink farm the manifest builds, so it works
# from Claude Code and OpenCode alike.
for s in "${SKILLS[@]}"; do
  src="$TMP/src/.claude/skills/$s/SKILL.md"
  [ -f "$src" ] || { say "  skipped $s (not upstream)"; continue; }
  mkdir -p "$DEST/skills/$s"
  sed -e "s#python3 scripts/#python3 $ABS/scripts/#g" \
      -e "s#node scripts/#node $ABS/scripts/#g" \
      -e "s#\baccessibility/#$ABS/accessibility/#g" \
      "$src" >"$DEST/skills/$s/SKILL.md"
  say "  patched $s"
done

# --- our own integration document -------------------------------------------
# This file is NOT upstream's; it is how this setup presents the gates. The sync
# writes it rather than preserving it, because `rm -rf "$DEST"` above would
# otherwise delete a hand-written file on every run — caught by
# tests/design-gates.test.sh on the first sync after it was written. Generating
# it here also keeps the pin and the vendored skill list from drifting out of
# the document that describes them.
cat >"$DEST/SKILL.md" <<'SKILL_EOF'
---
name: design-gates
description: >
  Objective, runnable quality gates for UI work: WCAG contrast ratios, design-token
  validation, hardcoded-value linting, theme-reference checks and accessibility
  audits. Every gate prints a real measured number and exits non-zero on failure.
  Invoke after writing or changing any UI surface — component, stylesheet, token
  file, screen — to prove the result is correct instead of asserting that it is.
  Also invoke when asked whether a colour pair passes AA/AAA, whether a design
  system's tokens are valid, or whether a component hardcodes values it should
  be reading from tokens.
---

# Design gates

Vendored from plugin87/ux-ui-agent-skills at the commit in `P87_PIN`. Regenerate
with `scripts/p87-sync.sh` — **never edit `scripts/`, `skills/` or this file by
hand**, the next sync overwrites them.

## The rule these gates exist to enforce

> Never state a number you did not measure. Any contrast ratio, "WCAG pass", or
> "100%" must come from running a gate and reporting its real output.

The pipeline these replace was five advisory skills that asked the model to
grade its own work, and a self-report cannot fail — which is how `impeccable`
silently aborted on every project for months without anyone noticing. A gate
that exits non-zero cannot be talked around.

## Static gates — no browser, no dependencies

Pure Python stdlib. Run from anywhere; paths are absolute.

| Gate | What it measures |
| ---- | ---------------- |
| `contrast.py` | WCAG 2.2 ratio for a colour pair; AA/AAA for normal, large, UI |
| `validate_tokens.py` | DTCG token files parse and resolve |
| `validate_contrast.py` | every foreground/background pair in a token set |
| `lint_hardcodes.py` | literal colours/sizes that should be token references |
| `validate_theme_refs.py` | theme keys pointing at nothing |
| `validate_component_spec.py` | a component definition is complete |
| `check_no_emoji.py` | emoji used as UI iconography |

```
python3 ~/.claude/skills/design-gates/scripts/contrast.py "#767676" "#ffffff"
```

Exit 0 passes, non-zero fails. Report the **printed number**, not your reading
of it.

## Render gates — need Playwright, opt-in

Sixteen further gates measure a rendered page (`verify_states`,
`verify_keyboard`, `verify_focustrap`, `verify_target_size`,
`verify_reduced_motion`, `verify_rtl`, `verify_responsive`, `verify_overflow`,
`axe_audit`, `measure_render`…). They are **not vendored** — they need
Playwright and its ~300MB browser.

To use them, install upstream separately (`npx ux-ui-agent-skills`) and say so
in the audit. Never claim a render gate ran when only the static ones did.

## Reference

`accessibility/wcag-checklist.md` and `accessibility/aria-patterns.md` are
vendored alongside. `skills/<name>/SKILL.md` holds upstream's procedure for each
of `design-doctrine`, `design-review`, `design-qa`, `a11y-audit`,
`design-tokens`. Read the one matching the task, not all five.

## Reporting

```
[design-audit]
contrast     #1d1d1f on #ffffff → 17.4:1  AA PASS  AAA PASS
hardcodes    src/Button.tsx → 0 findings
tokens       tokens/core.json → valid, 48 resolved
render gates not run (Playwright not installed)
```

A gate you did not run is reported as not run. Never as a pass.
SKILL_EOF

cat >"$PIN_FILE" <<PIN_EOF
# Pin for the vendored design gates. Regenerate with scripts/p87-sync.sh.
upstream: $UPSTREAM
commit: $PIN
date: $DATE
vendored: ${SKILLS[*]}
PIN_EOF

say "vendored ${#SKILLS[@]} skills + ${#STATIC_GATES[@]} static gates at ${PIN:0:12} ($DATE)"
