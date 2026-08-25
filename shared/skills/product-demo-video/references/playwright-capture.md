# Playwright live capture

Authenticated screenshot pipeline for a SaaS product. The captures replace static PNGs in
the flow scenes of the video.

## Login flow

Most web apps share the same login shape. Start here and adapt if the target differs:
- Email input: `input[type="email"]`
- Password input: `input[type="password"]`
- Submit: pressing **Enter on the password field** triggers form submit. The submit BUTTON
  selector is fragile across releases — DO NOT rely on it.

```js
import { chromium } from "playwright";

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
const page = await ctx.newPage();

await page.goto(process.env.DEMO_BASE_URL, { waitUntil: "domcontentloaded" });
await page.waitForLoadState("networkidle").catch(() => {});

await page.locator('input[type="email"]').first().fill(process.env.DEMO_EMAIL);
await page.locator('input[type="password"]').first().fill(process.env.DEMO_PASSWORD);
await page.locator('input[type="password"]').first().press("Enter");
await page.waitForLoadState("networkidle", { timeout: 20000 }).catch(() => {});
```

After login the URL usually drops its `?reason=auth-required`-style query param. That's
your signal that authentication succeeded.

## Credentials — never in the skill, never in the script

Ask the user for credentials during discovery. Then:

- Put them in a **git-ignored `.env`** in the project, or export them in the shell.
- Read them via `process.env` (`DEMO_BASE_URL`, `DEMO_EMAIL`, `DEMO_PASSWORD`).
- **Never** write a URL, an email or a password into the script body or into this skill.

The reason is concrete: a capture script is a template that gets copied between projects
and committed alongside them. Anything in its body travels with it and ends up published.
A demo account is still an account, and a demo host is still a host someone can reach.

If the target is production infrastructure, say so out loud to the user before running,
and prefer a staging environment when one exists.

## Target URL

The environment supplies it (`DEMO_BASE_URL`). Ask the user which environment to capture —
production, staging, or a local instance — and confirm the tenant has enough data to make
the screenshots worth showing. An empty tenant produces empty screenshots.

## Capture pattern

For each step of the user flow:

1. Navigate to the route.
2. Wait for `networkidle` plus an extra 500-800ms for animations to settle.
3. Optional: dismiss any "first-time" tooltips or onboarding overlays via known selectors.
4. `page.screenshot({ path: "assets/captures-live/NN_<step>.png" })`.
5. Compute the bounding rect of the next click target and store it in `cursor_targets.json`.

## Cursor targets file

```json
{
  "01_dashboard.png": { "click_x": 1120, "click_y": 460, "label": "Sidebar section" },
  "02_list_empty.png": { "click_x": 1620, "click_y": 240, "label": "Nuevo" },
  "...": "..."
}
```

The video composition reads this file to drive the Ken Burns zoom-to-click coordinates.
Without it, the zoom motion has no anchor.

## Creating test data live

For "rich" captures (a populated list, a configured entity), the script must CREATE data
via the UI:

```js
// Open the create modal
await page.locator('button:has-text("Nuevo")').click();
await page.locator('text=Crear Carpeta').click();

// Fill name
await page.locator('input[placeholder*="nombre" i]').fill("DEMO-VIDEO Carpeta Temporal");

// Submit — use role+name matching, NOT text:
await page.getByRole('button', { name: /^(Crear|Guardar|Confirmar)/ }).click();
```

An early build failed to persist test data because text-only selectors didn't match.
Always use `getByRole('button', { name: /regex/ })` for action buttons.

## Safety

- Treat the target as LIVE infrastructure. NEVER delete data. NEVER run destructive operations.
- Create test data with traceable names (prefix everything `DEMO-VIDEO`) so the user can
  find and clean it up later.
- Skip cleanup in the script. Leave it for the user to decide.
- If a capture step fails, fall back to a PNG from `assets/captures/` and note it in `MANIFEST.md`.

## Manifest format

`assets/captures-live/MANIFEST.md`:

```markdown
| File | Source | Status |
|------|--------|--------|
| 01_dashboard.png | Live | OK |
| 02_list_empty.png | Live | OK |
| 08_entity_modal.png | Fallback (previous PNG) | Submit button selector failed |
```

## Pitfalls

- The live app may use a DIFFERENT palette than the demo's chrome. Don't try to recolor —
  the contrast is intentional.
- Empty tenants produce empty screenshots. Either populate via the create-data script, or
  accept the empty state as "honest" — a real "SIN RESULTADOS" frame can be compelling
  because it proves the UI is real.
- Playwright headless captures the OS cursor unreliably across versions. Render a SYNTHETIC
  cursor in the composition; do NOT rely on the screenshot containing one.
- `await page.waitForLoadState("networkidle")` can hang indefinitely on apps with long
  polls. ALWAYS chain `.catch(() => {})` and a `waitForTimeout` fallback.

## Template

See [../templates/capture_live.mjs](../templates/capture_live.mjs) for a working example.
Adapt its capture steps to the product flow you're building.
