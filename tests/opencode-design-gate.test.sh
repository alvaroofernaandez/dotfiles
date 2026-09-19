#!/usr/bin/env bash
# Tests for the OpenCode port of the design-pipeline gate.
#
# Why a second implementation exists
# ----------------------------------
# The Claude Code gate is a PreToolUse shell hook that decides by reading the
# session transcript from disk. OpenCode has no JSON hook system and stores its
# sessions in SQLite, not JSONL, so the shell hook cannot be reused — only its
# contract can. This plugin reimplements that contract on OpenCode's plugin API:
# `tool.execute.before` can throw to deny a call (upstream's own .env-protection
# example works this way), and the `event` hook observes assistant messages so
# the plugin can tell whether the checklist was emitted this session.
#
# The logic worth testing is pure: which paths count as UI surfaces, and which
# text counts as a real checklist rather than the template echoed back. Those
# two predicates are the whole gate; the rest is plumbing around them.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$REPO/config/opencode/plugin/design-gate.ts"

pass=0
fail=0
ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "opencode-design-gate"

assert_eq "the plugin exists" "yes" "$([ -f "$PLUGIN" ] && echo yes || echo no)"

if ! command -v bun >/dev/null 2>&1; then
  echo "  bun not installed — logic assertions skipped"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]; exit $?
fi
[ -f "$PLUGIN" ] || { printf '\n%d passed, %d failed\n' "$pass" "$((fail))"; exit 1; }

run() { bun run "$REPO/tests/fixtures/opencode-gate-probe.ts" "$1" 2>/dev/null; }

mkdir -p "$REPO/tests/fixtures"
cat > "$REPO/tests/fixtures/opencode-gate-probe.ts" <<'PROBE'
// Exercises the gate's two pure predicates plus the deny path, so the bash
// suite can assert on them without standing up an OpenCode session.
import { isUISurface, matchesChecklist, DesignGate } from "../../config/opencode/plugin/design-gate.ts"

const FILLED = `[design-pipeline]
0. laws-of-ux    → laws: Hick (5 nav items max), Fitts (44px targets)
1. direction     → DESIGN.md §2 tokens; Inter, 8pt scale
2. gates         → contrast on the accent pair, hardcodes on Button.tsx`

const TEMPLATE = `[design-pipeline]
0. laws-of-ux    → laws: <which laws govern this surface, with the number each forces>
1. direction     → <DESIGN.md section, or ui-ux-pro-max/design-shotgun outcome>
2. gates         → <which design-gates checks will run after the code exists>`

const FIVESTEP = `[design-pipeline]
0. laws-of-ux        → laws: Hick (5 nav items)
1. frontend-design   → intent: editorial
2. ui-ux-pro-max     → references: Inter
3. impeccable        → engaged
4. design-motion-principles → 180ms`

async function denies(emit: string | null): Promise<boolean> {
  const hooks: any = await (DesignGate as any)({ directory: "/tmp" })
  if (emit) {
    await hooks.event({ event: { type: "message.part.updated",
      properties: { part: { type: "text", sessionID: "s1", text: emit } } } })
  }
  try {
    await hooks["tool.execute.before"]({ tool: "edit", sessionID: "s1", callID: "c1" },
      { args: { filePath: "/tmp/proj/src/Button.tsx" } })
    return false
  } catch { return true }
}

const which = process.argv[2]
const out: Record<string, () => Promise<string> | string> = {
  "ui-tsx":      () => String(isUISurface("src/Button.tsx")),
  "ui-css":      () => String(isUISurface("app/main.css")),
  "ui-go":       () => String(isUISurface("cmd/main.go")),
  "ui-test":     () => String(isUISurface("src/Button.test.tsx")),
  "ck-filled":   () => String(matchesChecklist(FILLED)),
  "ck-template": () => String(matchesChecklist(TEMPLATE)),
  "ck-five":     () => String(matchesChecklist(FIVESTEP)),
  "ck-prose":    () => String(matchesChecklist("we should run the [design-pipeline] first")),
  "deny-none":   async () => String(await denies(null)),
  "allow-ck":    async () => String(await denies(FILLED)),
  "deny-tpl":    async () => String(await denies(TEMPLATE)),
}
console.log(await out[which]())
PROBE

assert_eq "a .tsx is a UI surface"            "true"  "$(run ui-tsx)"
assert_eq "a .css is a UI surface"            "true"  "$(run ui-css)"
assert_eq "a .go file is not"                 "false" "$(run ui-go)"
assert_eq "a component test is not"           "false" "$(run ui-test)"

assert_eq "a filled three-step checklist counts"     "true"  "$(run ck-filled)"
assert_eq "the unfilled template does not"           "false" "$(run ck-template)"
assert_eq "the old five-step checklist does not"     "false" "$(run ck-five)"
assert_eq "prose mentioning the marker does not"     "false" "$(run ck-prose)"

assert_eq "a UI write with no checklist is denied"   "true"  "$(run deny-none)"
assert_eq "a UI write after the checklist is allowed" "false" "$(run allow-ck)"
assert_eq "the template does not open the gate"      "true"  "$(run deny-tpl)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
