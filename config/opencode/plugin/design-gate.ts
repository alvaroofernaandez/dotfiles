import type { Plugin } from "@opencode-ai/plugin"

/**
 * The OpenCode half of the design-pipeline gate.
 *
 * Claude Code enforces this with a PreToolUse shell hook that reads the session
 * transcript from disk (config/claude/hooks/design-pipeline-gate.sh). OpenCode
 * has no JSON hook system and keeps its sessions in SQLite rather than JSONL,
 * so the shell hook cannot be shared — only its contract can:
 *
 *   an edit to a UI surface is denied until the [design-pipeline] checklist has
 *   been emitted by the assistant in this session.
 *
 * `tool.execute.before` throwing is upstream's own documented way to deny a
 * call (their .env-protection example does exactly this), and the `event` hook
 * sees assistant messages as they stream, which is how the plugin knows whether
 * the checklist was emitted without reading any store.
 *
 * FAIL-OPEN, deliberately. The event payload's exact shape is not pinned by
 * @opencode-ai/plugin's types — it comes from the SDK and is read defensively
 * below, the same way config/opencode/plugin/terax-hooks.ts reads its own. If
 * the text cannot be extracted, the gate lets the edit through rather than
 * deadlocking the session. A gate that hard-fails on a payload change is a gate
 * people delete; a gate that misses one edit is one they keep.
 */

const UI_EXT = [
  ".tsx", ".jsx", ".vue", ".svelte", ".astro",
  ".css", ".scss", ".sass", ".less", ".styl",
  ".html", ".htm",
]

/**
 * Tests are not design surfaces. Blocking them would deadlock against the
 * strict-TDD rule, which requires the test to be written FIRST — before any
 * pipeline could have run. The bash gate carves out the same exception.
 */
export function isUISurface(filePath: string): boolean {
  if (!filePath) return false
  const base = filePath.split("/").pop() ?? ""
  if (/\.(test|spec|stories)\./.test(base)) return false
  if (filePath.includes("/__tests__/") || filePath.includes("/node_modules/")) return false
  return UI_EXT.some((e) => base.toLowerCase().endsWith(e))
}

/**
 * A run of the pipeline, not a mention of it.
 *
 * Three filters, each earned by a way the Claude Code gate was fooled:
 *   - the marker alone is not enough; prose diagnosing the pipeline once opened
 *     that gate, so all three numbered steps must be present;
 *   - the unfilled template is the template echoed back, not a run;
 *   - the old five-step form names skills that left the pipeline, so it
 *     describes a run that cannot have happened.
 */
export function matchesChecklist(text: string): boolean {
  if (!text || !text.includes("[design-pipeline]")) return false
  if (!/0\.\s*laws-of-ux/.test(text)) return false
  if (!/1\.\s*direction/.test(text)) return false
  if (!/2\.\s*gates/.test(text)) return false
  const placeholders = [
    "<which laws govern this surface, with the number each forces>",
    "<DESIGN.md section, or ui-ux-pro-max/design-shotgun outcome>",
    "<which design-gates checks will run after the code exists>",
  ]
  return !placeholders.some((p) => text.includes(p))
}

const REASON = `Blocked: this is a UI surface and the design pipeline has not run in this session.

Invoke the design-pipeline skill and emit its checklist first:

  0. laws-of-ux    -> which of the 30 Laws of UX govern THIS surface, and the
                      number each one forces (Hick caps the option count, Fitts
                      the target size, Jakob whether a novel pattern is allowed).
  1. direction     -> the .agents/DESIGN.md section that settles it, or the
                      ui-ux-pro-max / design-shotgun outcome if it is still open.
                      DESIGN.md outranks your default taste; read it first.
  2. gates         -> which design-gates checks will run once the code exists.

Name real content in each line; skill names alone and the template placeholders
are both rejected. Afterwards run the gates and report their real output as
[design-audit] — a gate you did not run is reported as not run, never as a pass.

To bypass deliberately, set DESIGN_PIPELINE_OFF=1.`

/** Pull assistant text out of an event payload without assuming one shape. */
function extract(event: any): { sessionID?: string; text?: string } {
  const p = event?.properties ?? {}
  const part = p.part ?? p.info ?? {}
  const text =
    typeof part.text === "string" ? part.text :
    typeof p.text === "string" ? p.text :
    undefined
  return { sessionID: part.sessionID ?? p.sessionID ?? part.id, text }
}

export const DesignGate: Plugin = async () => {
  // Sessions that have emitted a real checklist. Session-scoped, exactly like
  // the bash gate: one checklist opens the gate for the rest of the session,
  // which is what CLAUDE.md means by caching skill directives once per session.
  const emitted = new Set<string>()

  return {
    event: async ({ event }: any) => {
      if (event?.type !== "message.part.updated" && event?.type !== "message.updated") return
      try {
        const { sessionID, text } = extract(event)
        if (sessionID && text && matchesChecklist(text)) emitted.add(sessionID)
      } catch {
        // Payload shape changed; stay quiet and fail open.
      }
    },

    "tool.execute.before": async (input: any, output: any) => {
      if (process.env.DESIGN_PIPELINE_OFF) return
      if (!["edit", "write", "patch"].includes(input?.tool)) return

      const fp = output?.args?.filePath ?? output?.args?.path ?? output?.args?.file
      if (typeof fp !== "string" || !isUISurface(fp)) return

      if (!emitted.has(input.sessionID)) throw new Error(REASON)
    },
  }
}
