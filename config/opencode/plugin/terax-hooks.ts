import type { Plugin } from "@opencode-ai/plugin"

/**
 * Ports the shell hooks that previously lived (invalidly) under the
 * Claude-Code-style `hooks` key in opencode.json. opencode has no JSON hook
 * system; lifecycle behaviour belongs in a plugin like this one.
 *
 * Mapping from the old Claude Code hooks:
 *   SessionStart      -> plugin load (runs once when opencode boots)
 *   PostToolUse       -> tool.execute.after (edit | write | bash)
 *   Stop              -> session.idle
 *   Notification      -> permission.asked
 *   UserPromptSubmit  -> message.updated (role: user)
 */

/**
 * Emit an OSC 777 notification to the controlling terminal, mirroring the
 * `]777;notify;Terax;<state>` sequence the old hooks produced.
 * Only fires inside a Terax terminal, and never throws.
 */
async function teraxNotify(state: string): Promise<void> {
  if (!process.env.TERAX_TERMINAL) return
  try {
    await Bun.write("/dev/tty", `]777;notify;Terax;${state}`)
  } catch {
    // No controlling TTY available — silently ignore, just like the old `|| true`.
  }
}

export const TeraxHooks: Plugin = async ({ $, directory }) => {
  // SessionStart: refresh the code-review graph status once on boot.
  $`code-review-graph status`
    .cwd(directory)
    .quiet()
    .nothrow()
    .catch(() => {})

  // Dedupe UserPromptSubmit work: message.updated fires repeatedly per message.
  const seenPrompts = new Set<string>()

  return {
    // PostToolUse: keep the code-review graph in sync after mutating tools.
    "tool.execute.after": async (input) => {
      if (!["edit", "write", "bash"].includes(input.tool)) return
      await $`code-review-graph update --skip-flows`
        .cwd(directory)
        .quiet()
        .nothrow()
        .catch(() => {})
    },

    event: async ({ event }) => {
      switch (event.type) {
        // Stop: the agent finished responding.
        case "session.idle":
          await teraxNotify("finished")
          break

        // Notification: opencode is asking for a permission decision.
        case "permission.asked":
          await teraxNotify("attention")
          break

        // UserPromptSubmit: a user message landed.
        case "message.updated": {
          const info = (event.properties as { info?: { id?: string; role?: string } })?.info
          if (info?.role !== "user" || !info.id || seenPrompts.has(info.id)) return
          seenPrompts.add(info.id)
          await $`gentle-ai skill-registry refresh --quiet --no-gitignore --cwd ${directory}`
            .quiet()
            .nothrow()
            .catch(() => {})
          await teraxNotify("working")
          break
        }
      }
    },
  }
}
