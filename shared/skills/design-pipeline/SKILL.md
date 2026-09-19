---
name: design-pipeline
description: >
  The blocking design pipeline and the per-project DESIGN.md contract: the
  mandatory skill order, the [design-pipeline] checklist the PreToolUse gate
  enforces, how DESIGN.md outranks default taste, and the required schema for
  it. Invoke before ANY work on a visible surface — component, screen, layout,
  token, style, motion, copy in a UI — and before creating or updating a
  project's DESIGN.md.
---

# Design pipeline

Any change to a visible surface runs this before code is written, and proves
itself with measured output after. The PreToolUse gate
(`config/claude/hooks/design-pipeline-gate.sh`) denies `Edit`/`Write` on a UI
file until the checklist has been emitted in this session.

## Why it is three steps now, not five

It used to be five advisory skills — `frontend-design`, `ui-ux-pro-max`,
`design-shotgun`, `impeccable`, `design-motion-principles` — each asking the
model to report on its own work. Two things were measured on 2026-09-19 and
both argue against that shape:

- **`impeccable` had never run.** It halts on `NO_PRODUCT_MD`, and a search of
  the whole machine found zero `PRODUCT.md` files. Step 3 of five aborted in
  every project, for as long as it was installed, and nothing surfaced it —
  because a pipeline built on self-report has no way to report that a step
  never happened.
- **The prose cost ~12.2K tokens on every turn**, including turns with no UI in
  them at all.

A self-report cannot fail. A gate that exits non-zero can. So the direction
steps collapse into one and the quality step becomes something that runs.

## The pipeline

**0 — `laws-of-ux`.** Resolve which of the 30 Laws of UX govern this surface and
what number each one forces. Constraints first: Hick's Law caps how many items
the navigation may carry, Fitts's Law sets the minimum target size, Jakob's Law
decides whether a novel pattern is allowed at all. Run after the direction
exists and they get rationalised around instead of applied.

**1 — direction.** Read `.agents/DESIGN.md` first; it outranks everything here.
Where the direction is already settled, cite the section that settles it. Where
it is genuinely open — a new surface, a redesign, a project with no `DESIGN.md`
— use `ui-ux-pro-max` for references (79 styles, 192 palettes, 74 pairings) and
`design-shotgun` to generate variants and pick one. Whatever wins is written
back into `DESIGN.md` in the same change.

**2 — gates.** Name which `design-gates` checks will run once the code exists.
Pick the ones that can actually fail for this surface: contrast for anything
with colour, hardcodes for a component, token validation for a token change.

### Checklist

Emit this before writing UI code. The gate matches on it.

```
[design-pipeline]
0. laws-of-ux    → laws: <which laws govern this surface, with the number each forces>
1. direction     → <DESIGN.md section, or ui-ux-pro-max/design-shotgun outcome>
2. gates         → <which design-gates checks will run after the code exists>
```

Placeholders left intact do not count as a run — the gate rejects them.

### Audit

Close the work with real output from `design-gates`. A gate you did not run is
reported as not run, never as a pass.

```
[design-audit]
contrast     #1d1d1f on #ffffff → 17.4:1  AA PASS  AAA PASS
hardcodes    src/Button.tsx → 0 findings
render gates not run (Playwright not installed)
```

## DESIGN.md — the project's source of truth

Every project keeps `.agents/DESIGN.md`. It is binding: if your output conflicts
with it, your output is wrong. If the user asks for something that conflicts
with it, surface the conflict rather than silently picking a side — either the
decision is being changed deliberately, which belongs in the Decision Log with
its reason, or the request is out of scope.

Create it the first time UI work happens in a project. Update it in the same
change that introduces a decision; never let it rot. Mark superseded entries
rather than deleting them.

### Schema

```
# DESIGN.md — <Project Name>

## 1. Intent & North Star
<art direction, voice, anti-references>

## 2. Tokens
Colour (hex + semantic role) · Typography (family, size, weight, line-height)
· Spacing · Radius · Shadow/elevation · Z-index layers

## 3. Layout Primitives
Grid, breakpoints, container widths

## 4. Component Patterns
Per component: purpose, anatomy, states, accessibility notes, code reference

## 5. Motion System
Curves, durations, choreography, prefers-reduced-motion strategy

## 6. Accessibility Baselines
WCAG level, contrast minimums, focus rules, keyboard rules

## 7. Anti-patterns (banned here, and why)

## 8. Decision Log
Dated: decision, rationale, supersedes
```

## Ethics

Several Laws of UX are persuasion mechanisms — Goal-Gradient, Zeigarnik, Choice
Overload, Von Restorff, Cognitive Bias. They become dark patterns the moment
they serve the business against the user's own goal: endowed progress toward a
purchase nobody asked for, a permanently "incomplete" profile to farm data, a
cancel button hidden behind deliberate contrast failure. Use them to help
someone finish what they came to do, and refuse them otherwise.

## Output discipline

No generic AI aesthetics; no purple-gradient glassmorphism unless it is a stated
decision. Hierarchy, spacing, alignment, type scale and contrast are
non-negotiable. Motion needs a reason you can state, or it is removed.
