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
1. frontend-design   → intent: editorial, high-contrast, no gradients
2. ui-ux-pro-max     → references: Inter/Fraunces, 8pt scale, bento grid
2.5 design-shotgun   → direction already set in DESIGN.md
3. impeccable        → output director engaged
4. design-motion-principles → motion plan: 180ms ease-out on hover only'

# The unfilled template, verbatim from CLAUDE.md. Must never count as a run.
TEMPLATE_CHECKLIST='[design-pipeline]
1. frontend-design   → intent: <1 sentence direction>
2. ui-ux-pro-max     → references: <palette / type / layout / pattern chosen>
2.5 design-shotgun   → <variants explored + which won> or "direction already set in DESIGN.md"
3. impeccable        → output director engaged (hierarchy/spacing/taste rules cached)
4. design-motion-principles → motion plan: <reason + curve> or "no motion needed"'

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

# --- provisioning: impeccable's per-project vendor path ----------------------
# impeccable's own SKILL.md opens with "You MUST do these steps before
# proceeding" and step 1 runs `node .agents/skills/impeccable/scripts/context.mjs`
# — a PROJECT-relative path. The skill is installed globally at
# ~/.agents/skills/impeccable, so that command raised
# "Cannot find module .../<project>/.agents/skills/impeccable/scripts/context.mjs"
# in every project, and step 3 of the pipeline could never run.
#
# The fix satisfies the skill's own contract instead of editing it: give each
# project the vendor path it expects, as a link to the global install.

HOME_SKILL="$TMP/fake-home/.agents/skills/impeccable"
mkdir -p "$HOME_SKILL/scripts"
echo "console.log('ok')" >"$HOME_SKILL/scripts/context.mjs"

PROJ="$TMP/proj"
mkdir -p "$PROJ"

HOME="$TMP/fake-home" "$HOOK" --provision "$PROJ" >/dev/null 2>&1
assert_eq "--provision links the project vendor path" "yes" \
  "$([ -L "$PROJ/.agents/skills/impeccable" ] && echo yes || echo no)"
assert_eq "--provision makes impeccable's step 1 script resolvable" "yes" \
  "$([ -f "$PROJ/.agents/skills/impeccable/scripts/context.mjs" ] && echo yes || echo no)"

# Run twice: the hook fires on every UI edit, so a non-idempotent provision
# would either error or stack symlinks inside symlinks.
HOME="$TMP/fake-home" "$HOOK" --provision "$PROJ" >/dev/null 2>&1
assert_eq "--provision is idempotent" "yes" \
  "$([ -L "$PROJ/.agents/skills/impeccable" ] && echo yes || echo no)"

# A project that genuinely vendors impeccable must keep its own copy.
PROJ2="$TMP/proj2"
mkdir -p "$PROJ2/.agents/skills/impeccable/scripts"
echo "local" >"$PROJ2/.agents/skills/impeccable/scripts/context.mjs"
HOME="$TMP/fake-home" "$HOOK" --provision "$PROJ2" >/dev/null 2>&1
assert_eq "--provision never clobbers a real vendored copy" "local" \
  "$(cat "$PROJ2/.agents/skills/impeccable/scripts/context.mjs")"

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
for skill in frontend-design ui-ux-pro-max impeccable design-motion-principles; do
  assert_eq "denial reason names $skill" "yes" \
    "$(printf '%s' "$DENY_REASON" | rg -q -- "$skill" && echo yes || echo no)"
done
assert_eq "denial reason names the override" "yes" \
  "$(printf '%s' "$DENY_REASON" | rg -q -- 'DESIGN_PIPELINE_OFF' && echo yes || echo no)"

# --- impeccable's second blocker: PRODUCT.md ---------------------------------
# Even with its vendor path repaired, impeccable's context script halts:
#
#     NO_PRODUCT_MD: This project has no PRODUCT.md yet. Stop the current task,
#     load reference/init.md, and follow its instructions before resuming.
#
# So step 3 aborts the task MID-PIPELINE — after steps 1 and 2 have already
# spent their work. impeccable's init.md is explicit that PRODUCT.md comes from
# a real interview ("Do NOT turn a one-sentence request into a complete inferred
# PRODUCT.md"), so nothing here can write it. What the gate CAN do is surface
# the blocker in the denial, which is read BEFORE the pipeline starts rather
# than three skills into it.
assert_eq "denial names PRODUCT.md when the project has none" "yes" \
  "$(printf '%s' "$DENY_REASON" | rg -q -- 'PRODUCT\.md' && echo yes || echo no)"

PROJ3="$TMP/proj3"
mkdir -p "$PROJ3"
printf '# PRODUCT.md\n' >"$PROJ3/PRODUCT.md"
REASON3="$(run_hook Edit "$PROJ3/src/Button.tsx" "$EMPTY" "$PROJ3" \
  | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
assert_eq "denial stays quiet about PRODUCT.md when it exists" "no" \
  "$(printf '%s' "$REASON3" | rg -q -- 'PRODUCT\.md' && echo yes || echo no)"

# impeccable also accepts it under .agents/context/ and docs/.
PROJ4="$TMP/proj4"
mkdir -p "$PROJ4/.agents/context"
printf '# PRODUCT.md\n' >"$PROJ4/.agents/context/PRODUCT.md"
REASON4="$(run_hook Edit "$PROJ4/src/Button.tsx" "$EMPTY" "$PROJ4" \
  | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
assert_eq "PRODUCT.md under .agents/context counts" "no" \
  "$(printf '%s' "$REASON4" | rg -q -- 'PRODUCT\.md' && echo yes || echo no)"

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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
