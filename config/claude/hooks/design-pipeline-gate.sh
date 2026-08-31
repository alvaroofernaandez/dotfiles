#!/usr/bin/env bash
# PreToolUse gate for the 4-skill design pipeline declared in ~/.claude/CLAUDE.md.
#
# Why this exists
# ---------------
# The pipeline (frontend-design → ui-ux-pro-max → [design-shotgun] → impeccable
# → design-motion-principles) called itself "STRICT" and "BLOCKING", but nothing
# blocked. It was prose inside ~42 KB of always-on instructions, sitting next to
# an SDD orchestrator that pushes the opposite way — "delegate ALL real work to
# sub-agents" — and sub-agents start with a clean context, without the checklist.
# A rule with no enforcement point is a reminder. This is the enforcement point.
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
#      checklist's structure — the marker plus all four numbered skill lines.
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
EMITTED="$(
  jq -Rr '
    fromjson? // empty
    | select(.type == "assistant")
    | .message.content[]?
    | select(.type == "text")
    | .text
    | select(contains("[design-pipeline]"))
    | select(test("1\\.\\s*frontend-design"))
    | select(test("2\\.\\s*ui-ux-pro-max"))
    | select(test("3\\.\\s*impeccable"))
    | select(test("4\\.\\s*design-motion-principles"))
    | select(
        (contains("<1 sentence direction>")
         or contains("<palette / type / layout / pattern chosen>")
         or contains("<reason + curve>")) | not
      )
    | "EMITTED"
  ' "$TRANSCRIPT" 2>/dev/null | head -1
)"

[ "$EMITTED" = "EMITTED" ] && exit 0

# --- deny --------------------------------------------------------------------
# The reason has to teach, not just refuse. A bare "denied" sends the model
# looking for a way around the gate; naming the pipeline makes running it the
# obvious next move.
REASON="Blocked: $BASE is a UI surface and the 4-skill design pipeline has not run in this session.

Before editing it:
  1. Read .agents/DESIGN.md — it is the source of truth and overrides default taste.
  2. Run the pipeline: frontend-design → ui-ux-pro-max → (design-shotgun if the
     direction is still open) → impeccable → design-motion-principles.
  3. Emit the [design-pipeline] checklist with real content in each line.

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
