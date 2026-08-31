#!/usr/bin/env bash
# Tests for scripts/gstack-patch.sh — the filter that makes gstack's skills
# safe to run inside this configuration.
#
# Why a patch exists at all
# -------------------------
# Every gstack skill above tier 2 ships ~31 KB of shared preamble, and that
# preamble is not neutral instruction: it carries its own voice, its own commit
# discipline, its own question format and its own memory system. Loading one of
# those skills therefore injects a second, competing doctrine into a session
# that already has CLAUDE.md — and the two disagree on concrete points:
#
#   Voice                      imposes a house voice over the configured persona
#   Continuous Checkpoint Mode auto-commits `WIP:` against work-unit-commits
#   Question Tuning            its own AskUserQuestion format, against "one at a time"
#   Telemetry                  runs gstack-skill-end when the skill closes
#   Artifacts Sync             drains a sync queue into gstack's own store
#   Brain Context              reads GBrain, a second memory beside engram
#   Operational Self-Improvement  lets the skill rewrite its own file
#   Plan Status Footer         appends a status block to every reply
#
# A second group is removed for a different reason: in a vendored install it is
# not rival doctrine but dead code. These sections address infrastructure that
# only exists inside a full gstack setup, which this is not:
#
#   AskUserQuestion Format     10.9 KB — a quarter of a tier-3 file — of tool
#                              resolution for Conductor, plan-tune and
#                              question-log, none of which are installed here
#   Preamble (run first)       execs gstack-skill-start out of
#                              ~/.claude/skills/gstack/bin/, a path a vendored
#                              install never creates, so it always fails; it is
#                              also the channel for GSTACK_INSTRUCTION_BEGIN
#                              one-time directives
#   Writing Style              a second style ruling over the persona
#   Model-Specific Behavioral Patch   rewrites model behaviour per host
#   Skill Invocation During Plan Mode gstack's own plan-mode protocol
#
# Two sections survive deliberately. Context Recovery is what lets a skill
# resume after compaction, and Search Before Building is what stops it
# reimplementing code that already exists. Neither collides with anything here,
# and both are load-bearing, so the patch must leave them alone.
#
# The contract these tests defend:
#   1. every colliding section is removed, including the ones whose heading
#      carries a parenthetical suffix
#   2. the two keep-sections survive verbatim
#   3. the YAML frontmatter is preserved byte for byte — Claude Code reads the
#      skill's name and description from it, and a mangled frontmatter makes the
#      skill vanish silently rather than fail loudly
#   4. the filter is idempotent, because sync re-runs it over already-patched
#      output whenever the pin moves
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$REPO/scripts/gstack-patch.sh"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "gstack-patch"

# --- it exists and runs ------------------------------------------------------
assert_eq "scripts/gstack-patch.sh exists" "yes" \
  "$([ -f "$PATCH" ] && echo yes || echo no)"
assert_eq "scripts/gstack-patch.sh is executable" "yes" \
  "$([ -x "$PATCH" ] && echo yes || echo no)"

# Bail out early rather than emit thirty confusing failures downstream.
[ -x "$PATCH" ] || { printf '\n%d passed, %d failed\n' "$pass" $((fail + 1)); exit 1; }

# --- fixture -----------------------------------------------------------------
# A miniature SKILL.md carrying one of each: a plain colliding heading, a
# colliding heading with a parenthetical suffix, both keep-sections, and real
# task content that must survive.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/SKILL.md" <<'FIXTURE'
---
name: fixture
version: 1.0.0
description: "A fixture skill: commas, colons — and an em dash. (gstack)"
allowed-tools:
  - Bash
  - Read
---

Intro paragraph that belongs to no section and must survive.

## When to invoke this skill

Invoke when testing the patch.

## Preamble (run first)

Run gstack-skill-start and read the STATUS lines it echoes.

## Skill Invocation During Plan Mode

Follow the gstack plan-mode protocol.

## AskUserQuestion Format

Branch on SESSION_KIND and prefer the mcp variant.

## Writing Style (skip entirely if `EXPLAIN_LEVEL: terse` appears in the preamble echo)

Write in this specific register instead.

## Model-Specific Behavioral Patch (claude)

Adjust behaviour for this host model.

## Voice

House voice that overrides the configured persona.

## Context Recovery

Resume after compaction by re-reading the plan file.

## Continuous Checkpoint Mode

Auto-commit with a WIP prefix after every edit.

## Question Tuning (skip entirely if `QUESTION_TUNING: false`)

Ask questions in this specific format instead.

## Search Before Building

Grep for an existing implementation before writing a new one.

## Artifacts Sync (skill start)

Drain the artifacts queue into the gstack store.

## Brain Context (preflight)

Query GBrain for prior context.

## Operational Self-Improvement

Rewrite this file when you notice a better phrasing.

## Telemetry (run last)

Run gstack-skill-end with the outcome.

## Plan Status Footer

Append a plan status block to the reply.

## Step 1: The actual work

This is the payload. It must survive the patch intact.

Call `~/.claude/skills/gstack/bin/gstack-config get telemetry` for settings.
Read `$HOME/.claude/skills/gstack/qa/sections/qa-patterns.md` for patterns.
Run `$_ROOT/.claude/skills/gstack/browse/dist/browse open`.
FIXTURE

out="$TMP/out.md"
"$PATCH" "$TMP/SKILL.md" >"$out" 2>"$TMP/err"
rc=$?
assert_eq "exits 0 on a well-formed skill" "0" "$rc"

# --- colliding sections are gone --------------------------------------------
# Matched on the heading, not on body text: a section is removed only when its
# heading disappears, and asserting on the body alone would pass even if the
# heading survived with an empty body.
for h in "Voice" "Continuous Checkpoint Mode" "Question Tuning" \
         "Artifacts Sync" "Brain Context" "Operational Self-Improvement" \
         "Telemetry" "Plan Status Footer" \
         "AskUserQuestion Format" "Preamble" "Writing Style" \
         "Model-Specific Behavioral Patch" "Skill Invocation During Plan Mode"; do
  assert_eq "strips section: $h" "0" \
    "$(rg -c "^## $h" "$out" 2>/dev/null || echo 0)"
done

# The dead-code group must lose its bodies too. The Preamble body is the one
# that matters most: it is a bash block that execs a binary from a path a
# vendored install never creates, so leaving it behind means every skill opens
# by running a command that cannot succeed.
assert_eq "strips the Preamble body too" "0" \
  "$(rg -c 'gstack-skill-start' "$out" 2>/dev/null || echo 0)"
assert_eq "strips the AskUserQuestion body too" "0" \
  "$(rg -c 'Branch on SESSION_KIND' "$out" 2>/dev/null || echo 0)"
assert_eq "strips the Writing Style body too" "0" \
  "$(rg -c 'Write in this specific register' "$out" 2>/dev/null || echo 0)"

# The bodies must go with the headings. A filter that drops the heading and
# leaves the paragraph behind would still inject the instruction.
assert_eq "strips the Voice body too" "0" \
  "$(rg -c 'House voice that overrides' "$out" 2>/dev/null || echo 0)"
assert_eq "strips the checkpoint body too" "0" \
  "$(rg -c 'Auto-commit with a WIP prefix' "$out" 2>/dev/null || echo 0)"
assert_eq "strips the telemetry body too" "0" \
  "$(rg -c 'Run gstack-skill-end' "$out" 2>/dev/null || echo 0)"

# --- keep-sections survive ---------------------------------------------------
assert_eq "keeps Context Recovery" "1" \
  "$(rg -c '^## Context Recovery' "$out" 2>/dev/null || echo 0)"
assert_eq "keeps the Context Recovery body" "1" \
  "$(rg -c 'Resume after compaction' "$out" 2>/dev/null || echo 0)"
assert_eq "keeps Search Before Building" "1" \
  "$(rg -c '^## Search Before Building' "$out" 2>/dev/null || echo 0)"
assert_eq "keeps the Search Before Building body" "1" \
  "$(rg -c 'Grep for an existing implementation' "$out" 2>/dev/null || echo 0)"

# --- task content survives ---------------------------------------------------
assert_eq "keeps the invocation section" "1" \
  "$(rg -c '^## When to invoke this skill' "$out" 2>/dev/null || echo 0)"
assert_eq "keeps the payload section" "1" \
  "$(rg -c '^## Step 1: The actual work' "$out" 2>/dev/null || echo 0)"
assert_eq "keeps the payload body" "1" \
  "$(rg -c 'It must survive the patch intact' "$out" 2>/dev/null || echo 0)"
assert_eq "keeps the section-less intro" "1" \
  "$(rg -c 'belongs to no section' "$out" 2>/dev/null || echo 0)"

# --- frontmatter is preserved byte for byte ----------------------------------
# Claude Code reads name: and description: from here. Mangling the block does
# not fail loudly — the skill simply stops being discovered, which is far worse
# than a crash.
src_fm="$(sed -n '/^---$/,/^---$/p' "$TMP/SKILL.md" | head -20)"
out_fm="$(sed -n '/^---$/,/^---$/p' "$out" | head -20)"
assert_eq "frontmatter survives unchanged" "$src_fm" "$out_fm"
assert_eq "frontmatter name: survives" "1" \
  "$(rg -c '^name: fixture' "$out" 2>/dev/null || echo 0)"
assert_eq "the description's punctuation is untouched" "1" \
  "$(rg -cF 'commas, colons — and an em dash' "$out" 2>/dev/null || echo 0)"

# --- runtime paths are repointed --------------------------------------------
# The skills call their own binaries and read their own reference files through
# ~/.claude/skills/gstack/, which is where upstream's ./setup plants the repo.
# A vendored install never creates that path, so roughly 110 references across
# the fifteen skills would resolve to nothing — and the failure is not cosmetic:
# qa opens by shelling out to gstack-config, and half its body reads sections
# out of qa/sections/. They are repointed at ~/.gstack, a stable symlink the
# sync step creates, so the skills keep working without the full upstream
# install and without planting a repo inside the skills directory.
assert_eq "no reference to the upstream install path survives" "0" \
  "$(rg -c '\.claude/skills/gstack' "$out" 2>/dev/null || echo 0)"
assert_eq "the binary call is repointed" "1" \
  "$(rg -c '~/\.gstack/bin/gstack-config' "$out" 2>/dev/null || echo 0)"
assert_eq "the \$HOME form is repointed" "1" \
  "$(rg -c '\$HOME/\.gstack/qa/sections/qa-patterns\.md' "$out" 2>/dev/null || echo 0)"
assert_eq "the browse binary path is repointed" "1" \
  "$(rg -c '\.gstack/browse/dist/browse' "$out" 2>/dev/null || echo 0)"
# Repointing must not disturb the surrounding sentence.
assert_eq "the text around a repointed path is intact" "1" \
  "$(rg -c 'get telemetry\` for settings' "$out" 2>/dev/null || echo 0)"

# --- provenance header -------------------------------------------------------
# The output lands in shared/skills/ beside hand-written skills. Without a
# marker the next person to read it cannot tell it is generated, edits it, and
# loses the edit on the next sync.
assert_eq "marks the file as generated" "1" \
  "$(rg -c 'generated by scripts/gstack-patch.sh' "$out" 2>/dev/null || echo 0)"
# The marker must sit AFTER the frontmatter: a comment above it makes the YAML
# block stop being frontmatter at all.
first_line="$(head -1 "$out")"
assert_eq "the file still opens with the frontmatter delimiter" "---" "$first_line"

# --- idempotence -------------------------------------------------------------
# sync re-runs the patch over its own output whenever the pin moves. A filter
# that is not idempotent accumulates provenance headers or eats a section more
# on each pass, and the drift is invisible until a skill misbehaves.
twice="$TMP/twice.md"
"$PATCH" "$out" >"$twice" 2>/dev/null
assert_eq "patching twice changes nothing" "identical" \
  "$(cmp -s "$out" "$twice" && echo identical || echo differs)"

# --- it refuses bad input rather than emitting garbage -----------------------
"$PATCH" "$TMP/does-not-exist.md" >/dev/null 2>&1
assert_eq "exits non-zero on a missing file" "yes" \
  "$([ $? -ne 0 ] && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
