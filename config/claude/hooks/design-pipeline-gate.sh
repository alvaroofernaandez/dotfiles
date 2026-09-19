#!/usr/bin/env bash
# PreToolUse gate for the 4-skill design pipeline declared in ~/.claude/CLAUDE.md.
#
# Why this exists
# ---------------
# The pipeline (laws-of-ux → frontend-design → ui-ux-pro-max → [design-shotgun]
# → impeccable → design-motion-principles) called itself "STRICT" and
# "BLOCKING", but nothing blocked. It was prose inside ~42 KB of always-on
# instructions, sitting next to an SDD orchestrator that pushes the opposite
# way — "delegate ALL real work to sub-agents" — and sub-agents start with a
# clean context, without the checklist. A rule with no enforcement point is a
# reminder. This is the enforcement point.
#
# What it does
# ------------
# Denies Edit/Write on a UI surface until the [design-pipeline] checklist has
# actually been emitted by the assistant in this session, and repairs the one
# prerequisite that made step 3 impossible to run (see --provision below).
#
# Reading the transcript is the only way to know whether the checklist was
# emitted, and it has one trap: CLAUDE.md carries the literal string
# "[design-pipeline]" as a template and is fed into every session, so a naive
# match opens the gate on turn one, forever. Two filters close that:
#
#   1. Only assistant-authored text counts (type == "assistant"). CLAUDE.md and
#      system reminders arrive as user-role content.
#   2. The unfilled template does not count — a block still carrying
#      "<1 sentence direction>" is the template echoed back, not a run.
#   3. The marker alone does not count. The gate's first version matched on it,
#      and the prose that DIAGNOSED the broken pipeline opened the gate: writing
#      "[design-pipeline]" in a sentence was enough. A run has to carry the
#      checklist's structure — the marker plus all five numbered skill lines.
#      Talking about the pipeline is common; running it is the rare event, and
#      the matcher has to tell them apart or it decays back into decoration.
#
# Failure policy
# --------------
# Fails OPEN on anything it cannot determine: no jq, no transcript, unparseable
# input. A gate that hard-fails on a missing dependency takes the session down
# with it, and the first thing anyone does with a gate like that is delete it.
# Set DESIGN_PIPELINE_OFF=1 to bypass deliberately.
#
# Tests: tests/design-pipeline.test.sh

set -uo pipefail

# --- provisioning ------------------------------------------------------------
# impeccable's SKILL.md opens with "You MUST do these steps before proceeding",
# and step 1 is:
#
#     node .agents/skills/impeccable/scripts/context.mjs
#
# a PROJECT-relative path. The skill is installed globally, at
# ~/.agents/skills/impeccable, so in every project that command raised
#
#     Error: Cannot find module '<project>/.agents/skills/impeccable/scripts/context.mjs'
#
# and step 3 of the pipeline could never run — not once, in any repo. impeccable
# is built to be vendored per project; installing it globally is what broke it.
#
# Rather than patch an upstream file this repo does not version (the edit would
# be invisible to git and wiped by the next reinstall), give each project the
# vendor path the skill expects, pointing at the global install. Idempotent, and
# it never touches a project that genuinely vendors its own copy.
provision_impeccable() {
  local project="$1"
  local src="${HOME}/.agents/skills/impeccable"
  local dest="$project/.agents/skills/impeccable"

  [ -d "$src" ] || return 0
  [ -e "$dest" ] || [ -L "$dest" ] && return 0

  mkdir -p "$(dirname "$dest")" 2>/dev/null || return 0
  ln -s "$src" "$dest" 2>/dev/null || return 0
}

if [ "${1:-}" = "--provision" ]; then
  [ -n "${2:-}" ] && provision_impeccable "$2"
  exit 0
fi

# --- impeccable's other blocker ----------------------------------------------
# With its vendor path repaired, impeccable's context script still halts on a
# project with no PRODUCT.md:
#
#     NO_PRODUCT_MD: ... Stop the current task, load reference/init.md, and
#     follow its instructions before resuming.
#
# That abort lands MID-PIPELINE, at step 3, after steps 1 and 2 have already
# done their work. Nothing here can write the file for you: impeccable's own
# init.md requires a real interview and says in as many words not to infer one.
# What the gate can do is say so in the denial, which is read before the
# pipeline starts instead of three skills into it.
#
# Search order mirrors impeccable's own: project root, .agents/context/, docs/.
has_product_md() {
  local project="$1" dir
  for dir in "$project" "$project/.agents/context" "$project/docs"; do
    [ -d "$dir" ] || continue
    # -maxdepth keeps this from walking node_modules; -iname matches the
    # case-insensitive lookup impeccable documents.
    if [ -n "$(find "$dir" -maxdepth 1 -iname 'PRODUCT.md' -print -quit 2>/dev/null)" ]; then
      return 0
    fi
  done
  return 1
}

# --- bypasses ----------------------------------------------------------------

[ -n "${DESIGN_PIPELINE_OFF:-}" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "[design-pipeline] jq not installed — gate inactive." >&2
  exit 0
fi

INPUT="$(cat)"
[ -n "$INPUT" ] || exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
case "$TOOL" in
  Edit | Write | NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$FILE" ] || exit 0

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"

# --- is this a design surface? -----------------------------------------------
# A test asserts behaviour; it is not a design surface. Blocking it would put
# this gate in direct conflict with the strict-TDD rule that demands the test be
# written FIRST — before any pipeline could have run — and the two rules would
# deadlock on the first component.
BASE="${FILE##*/}"
case "$BASE" in
  *.test.* | *.spec.* | *.stories.test.*) exit 0 ;;
esac
case "$FILE" in
  */__tests__/* | */node_modules/*) exit 0 ;;
esac

case "$FILE" in
  *.tsx | *.jsx | *.vue | *.svelte | *.astro) ;;
  *.css | *.scss | *.sass | *.less | *.styl) ;;
  *.html | *.htm) ;;
  *) exit 0 ;;
esac

# A UI edit is coming. Make sure step 3 can actually run when it is reached.
[ -n "$CWD" ] && provision_impeccable "$CWD"

# --- has the pipeline run? ---------------------------------------------------

[ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ] || {
  echo "[design-pipeline] transcript unreadable — gate inactive for this call." >&2
  exit 0
}

# -R + fromjson? tolerates a truncated or malformed line rather than aborting
# the whole scan; a half-written last line is normal in a live transcript.
MATCHER='
  fromjson? // empty
  | select(.type == "assistant")
  | .message.content[]?
  | select(.type == "text")
  | .text
  | select(contains("[design-pipeline]"))
  | select(test("0\\.\\s*laws-of-ux"))
  | select(test("1\\.\\s*frontend-design"))
  | select(test("2\\.\\s*ui-ux-pro-max"))
  | select(test("3\\.\\s*impeccable"))
  | select(test("4\\.\\s*design-motion-principles"))
  | select(
      (contains("<which laws govern this surface and how>")
       or contains("<1 sentence direction>")
       or contains("<palette / type / layout / pattern chosen>")
       or contains("<reason + curve>")) | not
    )
  | "EMITTED"
'

emitted_in() { [ -r "$1" ] && [ "$(jq -Rr "$MATCHER" "$1" 2>/dev/null | head -1)" = "EMITTED" ]; }

emitted_in "$TRANSCRIPT" && exit 0

# --- and the sub-agents' own transcripts -------------------------------------
#
# THE FALSE NEGATIVE THAT MADE THIS GATE UNRUNNABLE FOR SUB-AGENTS.
#
# A tool call made by a sub-agent arrives here carrying the PARENT's identity:
# measured on 2026-09-13 by logging the raw hook input while a sub-agent wrote a
# .css file, the payload came back with the parent's `session_id` (16d8b94c…)
# and the parent's `transcript_path`, and the parent transcript holds ZERO
# entries from the sub-agent — `isSidechain` lines are not written there. The
# sub-agent's messages live in a separate file:
#
#   <projects>/<slug>/<session-id>/subagents/agent-<id>.jsonl
#
# So a sub-agent could emit a perfect checklist and this gate would still deny
# every UI edit it attempted, forever. That is worse than not gating at all: a
# rule that cannot be satisfied gets routed around, and it was — three writers
# in one day reached for DESIGN_PIPELINE_OFF or edited through Bash, which this
# hook does not intercept. Each of them declared it, which is the only reason it
# was caught. The next one might not.
#
# Scanning every sub-agent transcript of this session — rather than trying to
# guess WHICH sub-agent is calling — is deliberate, and it does not loosen the
# rule. The gate has always been session-scoped: one checklist from the main
# thread opens it for the rest of the session, exactly as CLAUDE.md describes
# ("you may cache skill directives ONCE per session"). Sub-agents of that
# session are part of the same run. The alternative — matching the calling agent
# — is not available: the payload carries no agent id, and PreToolUse fires
# BEFORE the call is written to any transcript, so there is nothing to correlate
# `tool_use_id` against.
SUBAGENTES="${TRANSCRIPT%.jsonl}/subagents"
if [ -d "$SUBAGENTES" ]; then
  for t in "$SUBAGENTES"/*.jsonl; do
    emitted_in "$t" && exit 0
  done
fi

# --- deny --------------------------------------------------------------------
# The reason has to teach, not just refuse. A bare "denied" sends the model
# looking for a way around the gate; naming the pipeline makes running it the
# obvious next move.
REASON="Blocked: $BASE is a UI surface and the 5-skill design pipeline has not run in this session.

Before editing it:
  1. Read .agents/DESIGN.md — it is the source of truth and overrides default taste.
  2. Run the pipeline: laws-of-ux → frontend-design → ui-ux-pro-max
     → (design-shotgun if the direction is still open) → impeccable
     → design-motion-principles.
  3. Emit the [design-pipeline] checklist with real content in each line.

Step 0 is not a formality. laws-of-ux resolves the constraints the other four
steps work inside: Hick's Law caps how many options the direction may offer,
Fitts's Law sets the minimum target size, Jakob's Law decides whether a novel
pattern is allowed at all. Name the specific laws governing THIS surface and
what each one dictates — not the skill's name.

Then this edit goes through. To bypass deliberately, set DESIGN_PIPELINE_OFF=1."

if [ -n "$CWD" ] && ! has_product_md "$CWD"; then
  REASON="$REASON

Heads-up before you start: this project has no PRODUCT.md, and impeccable
(step 3) halts on NO_PRODUCT_MD rather than running. Write it first — via
impeccable's init flow, which interviews you for it — or steps 1 and 2 will be
spent before the pipeline stops."
fi

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
