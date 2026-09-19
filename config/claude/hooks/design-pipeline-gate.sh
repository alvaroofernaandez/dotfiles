#!/usr/bin/env bash
# PreToolUse gate for the 4-skill design pipeline declared in ~/.claude/CLAUDE.md.
#
# Why this exists
# ---------------
# The pipeline (laws-of-ux → direction → gates) called itself "STRICT" and
# "BLOCKING", but nothing blocked. It was prose inside ~42 KB of always-on
# instructions, sitting next to an SDD orchestrator that pushes the opposite
# way — "delegate ALL real work to sub-agents" — and sub-agents start with a
# clean context, without the checklist. A rule with no enforcement point is a
# reminder. This is the enforcement point.
#
# What it does
# ------------
# Denies Edit/Write on a UI surface until the [design-pipeline] checklist has
# actually been emitted by the assistant in this session.
#
# It used to also symlink a vendored `impeccable` into each project, because
# that skill's SKILL.md ran a project-relative path against a global install and
# raised "Cannot find module" in every repo. impeccable left the pipeline on
# 2026-09-19 — it had never actually run, halting on NO_PRODUCT_MD in every
# project — so the provisioning went with it rather than keep seeding symlinks
# for a skill nothing invokes.
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
#      checklist's structure — the marker plus all three numbered steps.
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
  | select(test("1\\.\\s*direction"))
  | select(test("2\\.\\s*gates"))
  | select(
      (contains("<which laws govern this surface, with the number each forces>")
       or contains("<DESIGN.md section, or ui-ux-pro-max/design-shotgun outcome>")
       or contains("<which design-gates checks will run after the code exists>")) | not
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
REASON="Blocked: $BASE is a UI surface and the design pipeline has not run in this session.

Before editing it, invoke the design-pipeline skill and emit its checklist:

  0. laws-of-ux    -> which of the 30 Laws of UX govern THIS surface, and the
                      number each one forces (Hick caps the option count, Fitts
                      the target size, Jakob whether a novel pattern is allowed).
  1. direction     -> the .agents/DESIGN.md section that settles it, or the
                      ui-ux-pro-max / design-shotgun outcome if it is still open.
                      DESIGN.md outranks your default taste; read it first.
  2. gates         -> which design-gates checks will run once the code exists.

Name real content in each line. The skill names alone do not count, and the
template placeholders are rejected.

After the edit, run the gates and report their real output as [design-audit].
A gate you did not run is reported as not run, never as a pass.

To bypass deliberately, set DESIGN_PIPELINE_OFF=1."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
