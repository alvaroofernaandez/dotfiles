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
