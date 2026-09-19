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

## Design Architecture (STRICT — BLOCKING for any UI/UX/Frontend work)

This rule is **STRICT** and **BLOCKING**. No exceptions, no shortcuts, no "just a tiny tweak". If the requested change touches a component, a screen, a layout, a style, a token, copy that lives in a UI, an animation, a hover state, an empty state, an error state, a form, a button, a modal, a navbar, a sidebar, a card, a table, a chart, an icon system, spacing, color, typography, motion, accessibility, or ANY visible surface in any project — you MUST run the full 5-skill pipeline BEFORE writing a single line of code.

If you skip even one of the 5 skills, that is a discipline failure. Treat every UI/UX request as a gate that does not open until the pipeline has run.

### The 5-Skill Design Stack (mandatory order)

| Order | Skill | Role | Cannot be skipped because… |
| ----- | ----- | ---- | -------------------------- |
| 0 | `laws-of-ux` | The 30 Laws of UX as binding constraints. Resolves which laws govern the surface and what number each one forces. | Without it the direction is set first and the laws get rationalised around instead of applied. |
| 1 | `frontend-design` | Strategic direction & intent BEFORE code. Art direction, distinctive look. | Without it you fall into generic AI aesthetics. |
| 2 | `ui-ux-pro-max` | Inspiration & reference: 50 styles, 21 palettes, 50 font pairings, 9 stacks, shadcn/ui MCP. | Without it you reinvent inferior versions of solved patterns. |
| 2.5 | `design-shotgun` | **Conditional.** Generates 4–6 variants in parallel, opens a comparison board, records what was chosen via `~/.gstack/bin/gstack-taste-update`. | Only when the visual direction is not yet settled. Committing to the first idea is how a design ends up merely acceptable. |
| 3 | `impeccable` | Output director: hierarchy, IA, polish, anti-patterns, taste. | Without it you ship "acceptable" instead of "impeccable". |
| 4 | `design-motion-principles` | Motion & micro-interactions (Kowalski / Krehel / Tompkins) — build or audit. | Without it any motion becomes AI-slop. |

### Hard Gate Protocol (STRICT)

Before producing ANY UI/UX output, emit a `[design-pipeline]` checklist confirming each skill has been consulted:

```
[design-pipeline]
0. laws-of-ux        → laws: <which laws govern this surface and how>
1. frontend-design   → intent: <1 sentence direction>
2. ui-ux-pro-max     → references: <palette / type / layout / pattern chosen>
2.5 design-shotgun   → <variants explored + which won> or "direction already set in DESIGN.md"
3. impeccable        → output director engaged (hierarchy/spacing/taste rules cached)
4. design-motion-principles → motion plan: <reason + curve> or "no motion needed"
```

**On step 2.5 — `DESIGN.md` outranks the variants, always.** `design-shotgun`
carries a taste memory of its own that learns from what gets picked, and that
memory is NOT a second source of truth. The project's `.agents/DESIGN.md` is,
and it wins every time they disagree.

So the variants are generated INSIDE the constraints `DESIGN.md` already
records — its palette, its type scale, its spacing, its banned patterns — never
as a way to reopen decisions that file has already settled. A variant that
violates `DESIGN.md` is not a bold option, it is out of scope: discard it, or
change `DESIGN.md` first, deliberately, with a dated Decision Log entry.

Step 2.5 is skipped outright when the direction is already locked. Run it when
the visual direction is genuinely open — a new surface, a redesign, a project
with no `DESIGN.md` yet. Whatever wins gets written back into `DESIGN.md` in
the same change; a taste memory that knows something the project file does not
is exactly the divergence this rule exists to prevent.

**On step 0 — the laws are constraints, not a review pass.** The 30 Laws of UX
(<https://lawsofux.com>, Jon Yablonski) are resolved BEFORE art direction
because they cap what the direction is allowed to propose. Hick's Law decides
how many items the navigation may carry. Fitts's Law sets the floor on target
size and where a destructive action may not sit. Jakob's Law decides whether a
novel pattern is permitted at all. Working Memory decides what has to be carried
across a screen boundary. Run them afterwards and you are auditing a direction
that already exists — which is the point at which a violation stops getting
fixed and starts getting argued with.

Step 0 has to produce NUMBERS, not names. "laws-of-ux → applied" is the
placeholder wearing a different hat; "Hick (5 nav items max), Fitts (44px
targets, CTA on the bottom edge), Von Restorff (one accent, not colour-only)" is
a run. The `laws-of-ux` skill carries the routing table from surface to
governing laws, and `reference/laws.md` inside it holds all 30 verbatim.

Where the laws and `DESIGN.md` disagree, `DESIGN.md` wins — it is the project's
source of truth, and the same rule that governs step 2.5 governs this. Surface
the conflict rather than silently resolving it: either the law is being traded
away deliberately, which belongs in the Decision Log with its reason, or
`DESIGN.md` is wrong and gets changed first.

Several of these laws are persuasion mechanisms — Goal-Gradient, Zeigarnik,
Choice Overload, Von Restorff, Cognitive Bias. They become dark patterns the
moment they serve the business against the user's own goal. Endowed progress
toward a purchase nobody asked for, a profile permanently "incomplete" to farm
data, a cancel button hidden behind deliberate contrast failure. Use them to
help someone finish what they came to do, and refuse them otherwise.

Rules:
- The 5 skills are MANDATORY even for "trivial" tweaks. A button color is not trivial — it is a token decision.
- The ONLY exception is pure non-UI work (backend logic, infra, scripts with no UI surface). When in doubt → run the pipeline.
- You may cache skill directives ONCE per session and reuse them, but the `[design-pipeline]` checklist MUST be emitted every time UI work begins, even with cached directives.
- After the build, run `impeccable` audit pass. If motion was added, also run `design-motion-principles` in audit mode. Both audits MUST appear in the final output as `[design-audit]`.
- If you find yourself writing UI code without having emitted `[design-pipeline]`, STOP and restart the task properly.

### The gate is enforced, not requested

`config/claude/hooks/design-pipeline-gate.sh` runs on every `Edit`/`Write`/
`NotebookEdit` and **denies** the call when the target is a UI surface
(`.tsx .jsx .vue .svelte .astro .css .scss .sass .less .styl .html`) and no
`[design-pipeline]` checklist has been emitted in the session.

This exists because for months the rule above said "STRICT" and "BLOCKING" and
nothing blocked. It was prose inside ~42 KB of always-on instructions, competing
with an SDD orchestrator that pushes the opposite way — *delegate ALL real work
to sub-agents* — and sub-agents start clean, without the checklist. A rule with
no enforcement point is a reminder.

What the gate will and will not accept:

- The **marker alone is not enough.** The first version matched on
  `[design-pipeline]` anywhere, and the prose diagnosing this very bug opened
  the gate. A run must carry all five numbered skill lines.
- The **unfilled template is not a run.** A block still holding
  `<1 sentence direction>` — or `<which laws govern this surface and how>` — is
  the template echoed back.
- **Step 0 is enforced like the rest.** A four-line checklist is the pre-laws
  pipeline and is denied. This deliberately invalidates every checklist written
  before the laws were added: grandfathering them would have left step 0 as
  decoration from the day it shipped, which is the exact failure the rest of
  this section exists to describe.
- Only **assistant-authored** text counts. This file reaches the transcript as
  user-role content, so matching it would open the gate on turn one, forever.
- **Tests are not design surfaces.** `*.test.tsx` and `*.spec.tsx` pass through:
  blocking them would deadlock against the strict-TDD rule, which demands the
  test be written FIRST — before any pipeline could have run.
- It **fails open** with a warning when it cannot tell (no `jq`, unreadable
  transcript). `DESIGN_PIPELINE_OFF=1` bypasses it deliberately.
- **Sub-agent transcripts count too**, and this is the correction that made the
  gate usable at all. A tool call made by a sub-agent arrives carrying the
  PARENT's `session_id` and `transcript_path` — measured 2026-09-13 by logging
  the raw payload while a sub-agent wrote a `.css` file — and the parent
  transcript holds none of the sub-agent's messages; those live in
  `<transcript-without-.jsonl>/subagents/agent-<id>.jsonl`. So for months the
  gate denied **every** UI edit by a sub-agent, no matter how well it had run
  the pipeline. That is worse than no gate: three writers hit it in a single
  day and each routed around it (`DESIGN_PIPELINE_OFF=1`, or editing through
  Bash, which the hook does not intercept). They declared it, which is the only
  reason it surfaced. The gate now scans the parent transcript **and every
  sub-agent transcript of the same session** — the same session scope the rule
  already had, extended to the agents that session spawned.

Note the irony worth remembering: the section above justifies this gate by
naming sub-agents as the reason it exists ("sub-agents start clean, without the
checklist"), and sub-agents were precisely the population it could never let
through. A rule that cannot be satisfied does not enforce anything; it teaches
people to route around it.

Tests: `tests/design-pipeline.test.sh`.

### impeccable needs PRODUCT.md, and needs to be vendored per project

Two traps, both of which made step 3 impossible to run for as long as it has
been installed:

1. Its `## Setup` runs `node .agents/skills/impeccable/scripts/context.mjs` — a
   **project-relative** path. Installed globally at `~/.agents/skills/impeccable`,
   that raised `Cannot find module` in every repo. The gate now links
   `<project>/.agents/skills/impeccable` → the global install on first UI edit,
   which satisfies the skill's own contract without patching a file this repo
   does not version. It never touches a project that vendors its own copy.
2. Even then it halts on `NO_PRODUCT_MD`. impeccable wants **PRODUCT.md**
   (who/what/why) as well as `DESIGN.md` (how it looks) — its `init.md` is
   explicit that PRODUCT.md comes from a real interview and must not be
   inferred. The gate warns about a missing one in its denial, so the abort
   lands before the pipeline starts instead of three skills into it.

So `DESIGN.md` remains this configuration's source of truth for how things look;
`PRODUCT.md` is impeccable's required companion, not a competing authority.

### Output discipline

- No generic AI aesthetics. No purple gradient + glassmorphism unless explicitly intentional and justified.
- Hierarchy, spacing, alignment, type scale, and color contrast are non-negotiable.
- Motion must have a reason. If you can't state the reason, remove the motion.
- Every design output must be defensible against an `impeccable` critique pass.

This pipeline applies to **every project, globally, without exception**.

## Project DESIGN.md (STRICT — single source of truth per project)

Every project — without exception — MUST maintain a `DESIGN.md` file at `.agents/DESIGN.md` (relative to the project root). This file is the **absolute source of truth** for that project's design system. Each project has its own; never share `DESIGN.md` across projects.

### When you MUST read or write DESIGN.md

- **Read FIRST** at the start of ANY UI/UX/design/frontend task in a project. Treat its contents as binding constraints — they override your default taste.
- **Create** `.agents/DESIGN.md` the FIRST time any UI work happens in a project that doesn't have one. Bootstrap it from the 5-skill pipeline output (governing laws + intent + references + tokens + motion plan).
- **Update incrementally** every time a new design decision is made: a token added, a palette refined, a component pattern locked, a motion curve standardized, a typography scale chosen, an anti-pattern banned. Append or upsert — never silently overwrite history; if a decision supersedes a previous one, mark the previous entry as superseded.
- **Cite it** in every design output: which sections of `DESIGN.md` governed the decisions you just made.

### Required sections (minimum schema)

```
# DESIGN.md — <Project Name>

## 1. Intent & North Star
<frontend-design output: art direction, voice, anti-references>

## 2. Tokens
- Color palette (named, with hex + semantic role)
- Typography scale (font families, sizes, weights, line-heights)
- Spacing scale
- Radius scale
- Shadow / elevation
- Z-index layers

## 3. Layout Primitives
- Grid, breakpoints, container widths

## 4. Component Patterns
- For each: purpose, anatomy, states, accessibility notes, code reference

## 5. Motion System
- Curves, durations, choreography rules, prefers-reduced-motion strategy

## 6. Accessibility Baselines
- WCAG level, contrast minimums, focus rules, keyboard rules

## 7. Anti-patterns (banned in this project)
- List of things explicitly NOT allowed and WHY

## 8. Decision Log
- Dated entries: decision, rationale, supersedes (if any)
```

### Rules

- `DESIGN.md` is the truth. If your output conflicts with `DESIGN.md`, your output is wrong — fix it.
- If the user requests something that conflicts with `DESIGN.md`, STOP and surface the conflict before proceeding. Either update `DESIGN.md` deliberately or reject the request.
- Never let `DESIGN.md` rot. Every UI/UX commit that introduces a new decision MUST update it in the same change.
- Keep it concise but complete. Link to component files for code; do not duplicate large code blocks inside it.
