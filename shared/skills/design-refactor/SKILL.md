---
name: design-refactor
description: >
  Improve an EXISTING UI rather than design a new one: normalise components so a
  product looks coherent, migrate a codebase onto shadcn/ui + Radix, replace native
  controls with custom accessible ones, add purposeful micro-interactions, and raise
  a screen to professional SaaS quality without breaking behaviour. Invoke for
  "improve/polish/modernise this view", design-debt cleanup, inconsistent spacing or
  colour across pages, or any native <select>, date input or dialog that must become
  a shadcn component.
---

# Design refactor

The improve-what-exists half of the design pipeline. `design-pipeline` governs
new surfaces; this one takes a surface that already works and makes it good,
without changing routes, data flow or markup semantics — except to fix
accessibility.

## The rule that overrides taste here

**Native interactive elements are never acceptable.** No native date picker, no
raw `<select>`, no browser `<dialog>`, no `confirm()`. Always a custom
shadcn/Radix component. `reference/native-to-shadcn.md` gives the replacement
for each one, the `Select`-vs-`Combobox` decision, the react-hook-form
`Controller` pitfall, and the behaviour a swap must not lose.

```bash
python3 ~/.claude/skills/design-refactor/scripts/lint_native_elements.py src/
```

Exits non-zero on any hit. `components/ui/**` is exempt — that is where the
Radix wrappers legitimately live.

## Procedures

Read the one that matches the task, from `design-gates`:

| Task | Procedure |
| ---- | --------- |
| Audit and upgrade an existing screen | `skills/redesign` |
| Move a UI onto shadcn/Radix or another system | `skills/migrate-design-system` |
| Spec a component to the quality bar | `skills/design-component` |
| Write the component code | `skills/design-code` |
| Judge the result | `skills/design-review`, `skills/a11y-audit` |

`redesign` is the usual entry point: Scan → Diagnose → Direct → Apply → Verify,
applying in order — tokens, then typography and spacing, then component states,
then motion. Never the reverse: restyling components before the tokens are
consolidated just re-hardcodes the same drift in new places.

## Consistency is the whole job

> Consolidate to ONE shared token theme and make every page consume it. A
> redesign that leaves different pages on different palettes has failed.

Verify it, do not assert it:

```bash
G=~/.claude/skills/design-gates/scripts
python3 $G/lint_hardcodes.py src/          # literal colours/sizes that should be tokens
python3 $G/validate_theme_refs.py          # theme keys pointing at nothing
python3 $G/validate_contrast.py            # every fg/bg pair in the token set
```

## Micro-interactions

Motion is added last and only with a stated reason. Defaults that survive
review: 100ms for a state echo, 200ms for an entrance, ease-out on enter and
ease-in on exit, `transform` and `opacity` only — never `width`, `height` or
`top`. Every animation needs a `prefers-reduced-motion` branch;
`verify_reduced_motion.mjs` checks it.

## Verification is not optional

The render gates need Playwright. Run them against a states harness:

```bash
G=~/.claude/skills/design-gates/scripts
node $G/verify_states.mjs <harness> [--dark]   # contrast in default/hover/focus/disabled
node $G/axe_audit.mjs <harness>                # ARIA, role, name, label
node $G/verify_focustrap.mjs <harness> --open=<trigger>
node $G/verify_target_size.mjs <harness>       # 44x44 CSS px minimum
```

Then screenshot the harness and look at it. `design-component` is explicit that
this is required before claiming done, and it is the step that catches what no
gate does: mismatched stroke weights, a control that reads too heavy, a
transition artefact mid-animation.

Report real output as `[design-audit]`. A gate you did not run is reported as
not run, never as a pass.
