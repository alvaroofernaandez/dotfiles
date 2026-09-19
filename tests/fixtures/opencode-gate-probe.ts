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
