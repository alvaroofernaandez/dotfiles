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

/**
 * Only ASSISTANT-authored text counts, and establishing that takes both events.
 *
 * `message.part.updated` carries the text as a TextPart — which has `id`,
 * `sessionID`, `messageID` and `text`, but deliberately no role; the role lives
 * on the Message, delivered separately by `message.updated` as
 * `properties.info.role`.
 *
 * The discriminator matters here for the same reason it does in the bash gate:
 * AGENTS.md reaches OpenCode as user-role context and, since
 * scripts/sync-agent-rules.sh mirrors the blocking block into it, now contains
 * the checklist template verbatim. Counting user text would let the instruction
 * file open the gate on turn one, forever — the exact bug the Claude Code hook
 * was built to avoid.
 *
 * The SDK promises no ordering between the two events, so a checklist whose
 * role has not arrived yet is held as pending and resolved either way later.
 */

export const DesignGate: Plugin = async () => {
  // Sessions that have emitted a real checklist. Session-scoped, exactly like
  // the bash gate: one checklist opens the gate for the rest of the session,
  // which is what CLAUDE.md means by caching skill directives once per session.
  const emitted = new Set<string>()
  // messageIDs already known to be assistant-authored.
  const fromAssistant = new Set<string>()
  // Checklists seen before their message's role arrived: messageID -> sessionID.
  const pending = new Map<string, string>()

  return {
    event: async ({ event }: any) => {
      try {
        if (event?.type === "message.updated") {
          const info = event.properties?.info
          if (!info?.id) return
          if (info.role === "assistant") {
            fromAssistant.add(info.id)
            const sid = pending.get(info.id)
            if (sid) {
              emitted.add(sid)
              pending.delete(info.id)
            }
          } else {
            // A user message can never open the gate; drop anything held for it.
            pending.delete(info.id)
          }
          return
        }

        if (event?.type !== "message.part.updated") return
        const part = event.properties?.part
        if (part?.type !== "text" || typeof part.text !== "string") return
        if (!matchesChecklist(part.text)) return

        const sid = part.sessionID
        const mid = part.messageID
        if (!sid || !mid) return
        if (fromAssistant.has(mid)) emitted.add(sid)
        else pending.set(mid, sid)
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
