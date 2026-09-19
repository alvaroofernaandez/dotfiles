#!/usr/bin/env bash
# Tests for the design-pipeline gate.
#
# The 4-skill design pipeline in config/claude/CLAUDE.md declares itself "STRICT"
# and "BLOCKING", but for months nothing blocked: it was prose inside ~42 KB of
# always-on instructions, competing with an SDD orchestrator that pushes the
# opposite way ("delegate ALL real work to sub-agents" — and sub-agents start
# with a clean context, without the checklist). A rule that cannot deny an edit
# is a reminder, not a gate.
#
# This suite covers the piece that turns it into a real gate: a PreToolUse hook
# that denies Edit/Write on a UI surface until the [design-pipeline] checklist
# has actually been emitted in the session.
#
# The discriminator is the interesting part. CLAUDE.md itself contains the
# literal string "[design-pipeline]" as a template, and CLAUDE.md is fed into
# every session — so a naive grep over the transcript matches on turn one and
# the gate is open forever. The hook therefore reads ONLY assistant-authored
# text (type=="assistant") and rejects the unfilled template. Tests 8 and 9
# below are that claim; if they ever go green for the wrong reason, the gate is
# decorative again.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO/config/claude/hooks/design-pipeline-gate.sh"
SETTINGS="$REPO/config/claude/settings.json"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "design-pipeline"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# --- fixtures ----------------------------------------------------------------

# A transcript line carrying assistant-authored text.
assistant_line() {
  jq -cn --arg t "$1" \
    '{type:"assistant", message:{role:"assistant", content:[{type:"text", text:$t}]}}'
}

# A transcript line carrying user-authored text. CLAUDE.md and system reminders
# reach the transcript this way, which is exactly what must NOT open the gate.
user_line() {
  jq -cn --arg t "$1" \
    '{type:"user", message:{role:"user", content:[{type:"text", text:$t}]}}'
}

FILLED_CHECKLIST='[design-pipeline]
0. laws-of-ux    → laws: Hick (5 nav items max), Fitts (44px targets), Von Restorff (one accent)
1. direction     → DESIGN.md §2 tokens; Inter/Fraunces, 8pt scale, bento grid
2. gates         → contrast on the new accent pair, hardcodes on Button.tsx'

# The unfilled template, verbatim from CLAUDE.md. Must never count as a run.
TEMPLATE_CHECKLIST='[design-pipeline]
0. laws-of-ux    → laws: <which laws govern this surface, with the number each forces>
1. direction     → <DESIGN.md section, or ui-ux-pro-max/design-shotgun outcome>
2. gates         → <which design-gates checks will run after the code exists>'

mk_transcript() { # $1 = out path, rest = jsonl lines
  local out="$1"; shift
  : >"$out"
  for line in "$@"; do printf '%s\n' "$line" >>"$out"; done
}

# Feed the hook a PreToolUse payload and print its stdout.
run_hook() { # $1 = tool_name, $2 = file_path, $3 = transcript_path, $4 = cwd
  jq -cn \
    --arg tool "$1" --arg fp "$2" --arg tp "$3" --arg cwd "$4" \
    '{session_id:"test", transcript_path:$tp, cwd:$cwd,
      hook_event_name:"PreToolUse", tool_name:$tool, tool_input:{file_path:$fp}}' \
    | "$HOOK" 2>/dev/null
}

decision() { # reads hook stdout, prints the permission decision or "none"
  local out="$1"
  [ -z "$out" ] && { printf 'none'; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null || printf 'none'
}

# --- the hook exists ---------------------------------------------------------

assert_eq "gate hook exists" "yes" "$([ -f "$HOOK" ] && echo yes || echo no)"
assert_eq "gate hook is executable" "yes" "$([ -x "$HOOK" ] && echo yes || echo no)"

if [ ! -x "$HOOK" ]; then
  printf '\n%d passed, %d failed\n' "$pass" "$((fail + 1))"
  exit 1
fi

# --- why there is no provisioning block here any more ----------------------
# This suite used to assert that the hook symlinked a vendored `impeccable` into
# each project, because that skill invoked `node .agents/skills/impeccable/
# scripts/context.mjs` — a project-relative path against a global install — and
# so raised "Cannot find module" in every repo.
#
# impeccable left the pipeline on 2026-09-19. The reason is worth keeping: a
# search of the whole machine found zero PRODUCT.md files, and impeccable halts
# on NO_PRODUCT_MD, so step 3 of five had aborted in every project for as long
# as it was installed and nothing surfaced it. That is the failure mode of a
# pipeline built on self-report — it has no way to report that a step never ran.
# The gates in tests/design-gates.test.sh replace it with something that exits
# non-zero.

PROJ="$TMP/proj"
mkdir -p "$PROJ"

# --- enforcement -------------------------------------------------------------

EMPTY="$TMP/empty.jsonl"
mk_transcript "$EMPTY" "$(assistant_line 'just talking about the weather')"

GREEN="$TMP/green.jsonl"
mk_transcript "$GREEN" "$(assistant_line "$FILLED_CHECKLIST")"

USERONLY="$TMP/useronly.jsonl"
mk_transcript "$USERONLY" "$(user_line "$FILLED_CHECKLIST")"

TEMPLATE="$TMP/template.jsonl"
mk_transcript "$TEMPLATE" "$(assistant_line "$TEMPLATE_CHECKLIST")"

assert_eq "UI file with no checklist is denied" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$EMPTY" "$PROJ")")"

assert_eq "UI file with an emitted checklist is allowed" "none" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$GREEN" "$PROJ")")"

# The discriminator. CLAUDE.md reaches the transcript as user-role content, so
# matching on it would open the gate on turn one of every session.
assert_eq "checklist in a USER message does not open the gate" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$USERONLY" "$PROJ")")"

# Echoing the template back with its <placeholders> intact is not a run.
assert_eq "the unfilled CLAUDE.md template does not open the gate" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$TEMPLATE" "$PROJ")")"

assert_eq "a stylesheet is a UI surface" "deny" \
  "$(decision "$(run_hook Write "$PROJ/src/app.css" "$EMPTY" "$PROJ")")"

# Caught live, against this repo's own transcript: the first version of the gate
# matched on the marker alone, so the DIAGNOSTIC PROSE that explained why the
# pipeline was broken opened it. Talking about the pipeline is not running it —
# and talking about it is common, which makes this the likeliest way the gate
# rots back into decoration. A run must carry the checklist's STRUCTURE: the
# marker plus all four numbered skill lines.
PROSE="$(cat <<'EOF'
The [design-pipeline] block is what CLAUDE.md asks for. It chains
frontend-design, then ui-ux-pro-max, then impeccable, and finally
design-motion-principles. Nothing enforced it, so it never ran.
EOF
)"
PROSEJSONL="$TMP/prose.jsonl"
mk_transcript "$PROSEJSONL" "$(assistant_line "$PROSE")"
assert_eq "prose ABOUT the pipeline does not count as running it" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$PROSEJSONL" "$PROJ")")"

# A checklist missing a step is not a completed pipeline either.
PARTIAL="$(cat <<'EOF'
[design-pipeline]
1. frontend-design   → intent: editorial, high-contrast
2. ui-ux-pro-max     → references: Inter/Fraunces, 8pt scale
EOF
)"
PARTIALJSONL="$TMP/partial.jsonl"
mk_transcript "$PARTIALJSONL" "$(assistant_line "$PARTIAL")"
assert_eq "a checklist missing steps 3 and 4 is denied" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$PARTIALJSONL" "$PROJ")")"

# --- step 0: the Laws of UX ---------------------------------------------------
# The 30 laws at lawsofux.com are constraints, not inspiration, so they are
# resolved BEFORE art direction rather than checked afterwards: Hick's Law caps
# how many nav items the direction may propose, Fitts's Law sets the minimum
# target size, Jakob's Law decides whether a novel pattern is even allowed.
# Running them after step 1 means discovering the direction was illegal once it
# already exists — which is when it stops getting fixed.
#
# A four-line checklist is therefore the PRE-laws pipeline, and it has to be
# denied, or every checklist written before this change keeps opening the gate
# and step 0 is decoration on arrival.
LEGACY="$(cat <<'EOF'
[design-pipeline]
1. frontend-design   → intent: editorial, high-contrast, no gradients
2. ui-ux-pro-max     → references: Inter/Fraunces, 8pt scale, bento grid
2.5 design-shotgun   → direction already set in DESIGN.md
3. impeccable        → output director engaged
4. design-motion-principles → motion plan: 180ms ease-out on hover only
EOF
)"

# The five-step advisory form is legacy too: impeccable and frontend-design are
# no longer in the pipeline, so a checklist naming them describes a run that
# cannot have happened.
FIVESTEP="$(cat <<'EOF'
[design-pipeline]
0. laws-of-ux        → laws: Hick (5 nav items), Fitts (44px)
1. frontend-design   → intent: editorial, high-contrast
2. ui-ux-pro-max     → references: Inter, 8pt scale
3. impeccable        → output director engaged
4. design-motion-principles → motion plan: 180ms ease-out
EOF
)"
FIVEJSONL="$TMP/fivestep.jsonl"
mk_transcript "$FIVEJSONL" "$(assistant_line "$FIVESTEP")"
assert_eq "the old five-step checklist no longer opens the gate" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$FIVEJSONL" "$PROJ")")"
LEGACYJSONL="$TMP/legacy.jsonl"
mk_transcript "$LEGACYJSONL" "$(assistant_line "$LEGACY")"
assert_eq "a checklist without step 0 laws-of-ux is denied" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$LEGACYJSONL" "$PROJ")")"

# The placeholder must be rejected for step 0 exactly as it is for steps 1, 2
# and 4 — naming the step without naming the laws is the template echoed back.
LAWS_TPL="$(cat <<'EOF'
[design-pipeline]
0. laws-of-ux    → laws: <which laws govern this surface, with the number each forces>
1. direction     → DESIGN.md §2 tokens
2. gates         → contrast on the accent pair
EOF
)"
LAWSTPLJSONL="$TMP/laws-template.jsonl"
mk_transcript "$LAWSTPLJSONL" "$(assistant_line "$LAWS_TPL")"
assert_eq "an unfilled step 0 does not open the gate" "deny" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$LAWSTPLJSONL" "$PROJ")")"

assert_eq "non-UI source is untouched" "none" \
  "$(decision "$(run_hook Edit "$PROJ/main.go" "$EMPTY" "$PROJ")")"

# A .test.tsx asserts behaviour; it is not a design surface, and blocking it
# would put the gate in direct conflict with the strict-TDD rule that demands
# the test be written FIRST — before any pipeline has run.
assert_eq "component tests are not design surfaces" "none" \
  "$(decision "$(run_hook Write "$PROJ/src/Button.test.tsx" "$EMPTY" "$PROJ")")"

assert_eq "spec files are not design surfaces" "none" \
  "$(decision "$(run_hook Write "$PROJ/src/Button.spec.tsx" "$EMPTY" "$PROJ")")"

assert_eq "tools other than Edit/Write pass through" "none" \
  "$(decision "$(run_hook Bash "$PROJ/src/Button.tsx" "$EMPTY" "$PROJ")")"

# --- fail-open paths ---------------------------------------------------------
# A gate that hard-fails when its inputs are missing takes the whole session
# down with it. Missing transcript means "cannot know", not "deny".

assert_eq "a missing transcript fails open" "none" \
  "$(decision "$(run_hook Edit "$PROJ/src/Button.tsx" "$TMP/does-not-exist.jsonl" "$PROJ")")"

assert_eq "an override env var fails open" "none" \
  "$(DESIGN_PIPELINE_OFF=1 decision "$(DESIGN_PIPELINE_OFF=1 run_hook Edit "$PROJ/src/Button.tsx" "$EMPTY" "$PROJ")")"

# --- the denial has to teach ------------------------------------------------
# A bare "denied" sends the model looking for a way around the gate. The reason
# has to name the pipeline so the next action is to run it.
DENY_REASON="$(run_hook Edit "$PROJ/src/Button.tsx" "$EMPTY" "$PROJ" \
  | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
for skill in laws-of-ux design-gates DESIGN.md; do
  assert_eq "denial reason names $skill" "yes" \
    "$(printf '%s' "$DENY_REASON" | rg -q -- "$skill" && echo yes || echo no)"
done
assert_eq "denial reason names the override" "yes" \
  "$(printf '%s' "$DENY_REASON" | rg -q -- 'DESIGN_PIPELINE_OFF' && echo yes || echo no)"

# --- wiring ------------------------------------------------------------------
# The hook is inert unless settings.json calls it. This is the assertion that
# would have caught the original bug: the pipeline was declared but never wired.

assert_eq "settings.json wires the gate as a PreToolUse hook" "yes" \
  "$(jq -e '.hooks.PreToolUse[]?.hooks[]?.command | select(test("design-pipeline-gate"))' \
      "$SETTINGS" >/dev/null 2>&1 && echo yes || echo no)"

assert_eq "the gate matches Edit and Write" "yes" \
  "$(jq -e '.hooks.PreToolUse[]? | select(.hooks[]?.command | test("design-pipeline-gate"))
            | .matcher | select(test("Edit") and test("Write"))' \
      "$SETTINGS" >/dev/null 2>&1 && echo yes || echo no)"

# --- the colliding plugin ----------------------------------------------------
# bencium-innovative-ux-designer ships a description that is a word-for-word
# subset of frontend-design's. Two skills competing for step 1 of the pipeline
# make the step ambiguous by construction, which is the same failure mode the
# gstack section of CLAUDE.md rejects nine other skill families for.

assert_eq "the bencium UX plugin is not enabled" "no" \
  "$(jq -r '.enabledPlugins["bencium-innovative-ux-designer@bencium-marketplace"] // false' \
      "$SETTINGS" | rg -q '^true$' && echo yes || echo no)"

# --- sub-agents ---------------------------------------------------------------
# The false negative that made this gate unrunnable for exactly the population
# it was written for.
#
# CLAUDE.md's own rationale for the gate names sub-agents as the reason it
# exists: "sub-agents start with a clean context, without the checklist". But a
# tool call made by a sub-agent arrives at the hook carrying the PARENT's
# identity — measured 2026-09-13 by logging the raw payload while a sub-agent
# wrote a .css file: parent `session_id`, parent `transcript_path`. And the
# parent transcript holds none of the sub-agent's messages; those live in
# <transcript-without-.jsonl>/subagents/agent-<id>.jsonl.
#
# So a sub-agent that ran the pipeline perfectly was denied anyway, every time,
# forever. Three writers in one day hit it; each reached for DESIGN_PIPELINE_OFF
# or edited through Bash (which this hook does not intercept) and declared it in
# their report. Declaring it is the only reason it surfaced. A gate that cannot
# be satisfied does not enforce a rule — it teaches people to route around it.
#
# These four tests are that claim. If the first goes red, the gate is back to
# denying every sub-agent; if the last goes red, it has stopped discriminating
# and any transcript on disk opens it.

PROJ5="$TMP/proj5"
mkdir -p "$PROJ5/src"
SESION="$TMP/sesion-con-subagentes.jsonl"
SUBS="$TMP/sesion-con-subagentes/subagents"
mkdir -p "$SUBS"

# The parent did NOT run the pipeline; only the sub-agent doing the UI work did.
mk_transcript "$SESION" "$(user_line 'sube el contraste de los botones')"
mk_transcript "$SUBS/agent-aaa.jsonl" "$(assistant_line "$FILLED_CHECKLIST")"

assert_eq "a sub-agent's checklist opens the gate" "none" \
  "$(decision "$(run_hook Edit "$PROJ5/src/Button.tsx" "$SESION" "$PROJ5")")"

# Same shape, but the sub-agent only echoed the template back.
SESION2="$TMP/sesion-plantilla.jsonl"
SUBS2="$TMP/sesion-plantilla/subagents"
mkdir -p "$SUBS2"
mk_transcript "$SESION2" "$(user_line 'sube el contraste de los botones')"
mk_transcript "$SUBS2/agent-bbb.jsonl" "$(assistant_line "$TEMPLATE_CHECKLIST")"

assert_eq "a sub-agent echoing the template does NOT open the gate" "deny" \
  "$(decision "$(run_hook Edit "$PROJ5/src/Button.tsx" "$SESION2" "$PROJ5")")"

# And user-role content inside a sub-agent transcript is still not a run:
# CLAUDE.md reaches sub-agents too, carrying the literal marker.
SESION3="$TMP/sesion-usuario.jsonl"
SUBS3="$TMP/sesion-usuario/subagents"
mkdir -p "$SUBS3"
mk_transcript "$SESION3" "$(user_line 'sube el contraste')"
mk_transcript "$SUBS3/agent-ccc.jsonl" "$(user_line "$FILLED_CHECKLIST")"

assert_eq "user-role text in a sub-agent transcript does NOT open the gate" "deny" \
  "$(decision "$(run_hook Edit "$PROJ5/src/Button.tsx" "$SESION3" "$PROJ5")")"

# A session with no sub-agents at all must behave exactly as before: the
# lookup is a fallback, not a new way in.
SESION4="$TMP/sesion-sin-subagentes.jsonl"
mk_transcript "$SESION4" "$(user_line 'sube el contraste')"

assert_eq "no subagents directory leaves the gate denying" "deny" \
  "$(decision "$(run_hook Edit "$PROJ5/src/Button.tsx" "$SESION4" "$PROJ5")")"

# --- the skill step 0 invokes -------------------------------------------------
# The gate can demand the line; only the skill makes the line mean something.
# It lives in shared/skills so the manifest's fanout installs it into every
# agent's skills directory (Claude Code AND OpenCode) rather than just this one.

LAWS_SKILL="$REPO/shared/skills/laws-of-ux/SKILL.md"

assert_eq "the laws-of-ux skill exists" "yes" \
  "$([ -f "$LAWS_SKILL" ] && echo yes || echo no)"

if [ -f "$LAWS_SKILL" ]; then
  assert_eq "the skill declares frontmatter name and description" "yes" \
    "$(rg -q '^name: laws-of-ux$' "$LAWS_SKILL" && rg -q '^description:' "$LAWS_SKILL" \
        && echo yes || echo no)"

  # All 30 laws from lawsofux.com, verbatim names. A skill that quietly drops
  # half of them is the failure this assertion exists to catch: the ones that
  # get dropped are the unglamorous ones (Postel, Tesler, Parkinson) which are
  # precisely the ones nobody applies from memory.
  MISSING=""
  while IFS= read -r law; do
    rg -qF -- "$law" "$LAWS_SKILL" || MISSING="$MISSING $law"
  done <<'LAWS'
Aesthetic-Usability Effect
Choice Overload
Chunking
Cognitive Bias
Cognitive Load
Doherty Threshold
Fitts's Law
Flow
Goal-Gradient Effect
Hick's Law
Jakob's Law
Law of Common Region
Law of Proximity
Law of Prägnanz
Law of Similarity
Law of Uniform Connectedness
Mental Model
Miller's Law
Occam's Razor
Paradox of the Active User
Pareto Principle
Parkinson's Law
Peak-End Rule
Postel's Law
Selective Attention
Serial Position Effect
Tesler's Law
Von Restorff Effect
Working Memory
Zeigarnik Effect
LAWS
  assert_eq "the skill carries all 30 laws" "" "$MISSING"
fi

# The document describing the pipeline has to carry the step the gate enforces,
# or the two drift and the model is told to run a four-step pipeline that a
# five-step gate denies. That document moved out of CLAUDE.md on 2026-09-19:
# the checklist and the DESIGN.md contract are now the `design-pipeline` skill,
# loaded on demand instead of on every turn. CLAUDE.md keeps only the blocking
# summary, so this assertion follows the checklist to where it actually lives.
PIPELINE_SKILL="$REPO/shared/skills/design-pipeline/SKILL.md"
assert_eq "the design-pipeline skill documents step 0 in the checklist template" "yes" \
  "$(rg -q '^0\. laws-of-ux' "$PIPELINE_SKILL" && echo yes || echo no)"

# CLAUDE.md must still point at the skill, or the move silently drops the rule
# for any session that never thinks to look for it.
CLAUDE_MD="$REPO/config/claude/CLAUDE.md"
assert_eq "CLAUDE.md still routes UI work to the design-pipeline skill" "yes" \
  "$(rg -q 'design-pipeline. skill' "$CLAUDE_MD" && echo yes || echo no)"

assert_eq "CLAUDE.md still states the gate is blocking" "yes" \
  "$(rg -q 'DESIGN_PIPELINE_OFF' "$CLAUDE_MD" && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
