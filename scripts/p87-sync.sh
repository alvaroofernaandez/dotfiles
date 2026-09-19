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
# Five review skills (judge a surface) plus four refactor skills (improve one).
# The split matters: design-gates began as review-only, which is good for saying
# a screen is wrong and useless for making it right.
SKILLS=(design-doctrine design-review design-qa a11y-audit design-tokens
        redesign migrate-design-system design-component design-code)
STATIC_GATES=(contrast.py validate_tokens.py validate_contrast.py lint_hardcodes.py
              validate_theme_refs.py check_no_emoji.py validate_component_spec.py)
# Render gates need Playwright and its browser. They are vendored now because
# design-component's contract is "You must screenshot the harness and inspect it
# before claiming done" — vendoring that instruction without the scripts that
# carry it out would ship an order to verify with no way to verify.
RENDER_GATES=(verify_states.mjs axe_audit.mjs verify_focustrap.mjs verify_target_size.mjs
              verify_keyboard.mjs verify_reduced_motion.mjs verify_rtl.mjs
              verify_responsive.mjs verify_overflow.mjs verify_interactive.mjs
              measure_render.mjs taste_audit.mjs slop_tells.mjs lint_intent.mjs)
# Reference material the vendored skills route into by name. A skill whose first
# instruction points at a file that is not there is the impeccable failure.
REFERENCES=(workflows/redesign-audit.md taste/design-taste.md taste/aesthetic-systems.md
            frameworks/adapter-protocol.md frameworks/react-tailwind.md
            design-systems/interop-protocol.md design-systems/crosswalk.md)

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
for g in "${RENDER_GATES[@]}"; do
  [ -f "$TMP/src/scripts/$g" ] || continue
  sed -e "s#node scripts/#node $ABS/scripts/#g" \
      -e "s#python3 scripts/#python3 $ABS/scripts/#g" \
      "$TMP/src/scripts/$g" >"$DEST/scripts/$g"

  # Upstream launches Chrome by channel. Seven of these gates follow that with
  # `.catch(() => chromium.launch())` and seven do not, so on a machine with the
  # Playwright chromium but no desktop Google Chrome those seven throw:
  #   browserType.launch: Chromium distribution 'chrome' is not found
  # An uncaught launch error reads as "the tool is broken", unlike upstream's
  # deliberate SKIPPED path. Add the fallback only where it is missing.
  if rg -q "channel: *'chrome'" "$DEST/scripts/$g" 2>/dev/null &&
     ! rg -q "channel: *'chrome' *\} *\) *\.catch" "$DEST/scripts/$g" 2>/dev/null; then
    perl -0pi -e "s/(chromium\.launch\(\{\s*channel:\s*'chrome'\s*\}\))/\$1.catch(() => chromium.launch())/g" \
      "$DEST/scripts/$g"
  fi
done

cp "$TMP/src"/accessibility/*.md "$DEST/accessibility/" 2>/dev/null || true

mkdir -p "$DEST/reference"
for r in "${REFERENCES[@]}"; do
  [ -f "$TMP/src/$r" ] || continue
  mkdir -p "$DEST/reference/$(dirname "$r")"
  sed -e "s#node scripts/#node $ABS/scripts/#g" \
      -e "s#python3 scripts/#python3 $ABS/scripts/#g" \
      "$TMP/src/$r" >"$DEST/reference/$r"
done
# The one design system from upstream's library of 138 that this setup targets.
if [ -d "$TMP/src/design-systems/library/shadcn" ]; then
  mkdir -p "$DEST/reference/design-systems/shadcn"
  cp "$TMP/src"/design-systems/library/shadcn/*.md "$DEST/reference/design-systems/shadcn/" 2>/dev/null || true
fi

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

# --- the render gates need playwright to resolve -----------------------------
# The .mjs gates do `await import('playwright')`, which Node resolves by walking
# up from the script's own directory. A global npm install is therefore NOT
# enough for ESM — there has to be a node_modules beside them. Linking rather
# than installing keeps the ~300MB out of the repo, and doing it HERE rather
# than by hand means it survives the `rm -rf "$DEST"` at the top of this script.
#
# Without it the gates print "playwright not installed — SKIPPED" and exit 0,
# which is upstream's own guard against reporting green on nothing. Set
# DS_REQUIRE_BROWSER=1 to turn that skip into a failure.
GLOBAL_MODULES="$(npm root -g 2>/dev/null || true)"
if [ -n "$GLOBAL_MODULES" ] && [ -d "$GLOBAL_MODULES/playwright" ]; then
  mkdir -p "$DEST/node_modules"
  ln -sfn "$GLOBAL_MODULES/playwright" "$DEST/node_modules/playwright"
  [ -d "$GLOBAL_MODULES/playwright-core" ] &&     ln -sfn "$GLOBAL_MODULES/playwright-core" "$DEST/node_modules/playwright-core"
  say "  linked playwright for the render gates"
else
  say "  playwright not installed globally — render gates will report SKIPPED"
fi

cat >"$PIN_FILE" <<PIN_EOF
# Pin for the vendored design gates. Regenerate with scripts/p87-sync.sh.
upstream: $UPSTREAM
commit: $PIN
date: $DATE
vendored: ${SKILLS[*]}
PIN_EOF

say "vendored ${#SKILLS[@]} skills + ${#STATIC_GATES[@]} static + ${#RENDER_GATES[@]} render gates at ${PIN:0:12} ($DATE)"
