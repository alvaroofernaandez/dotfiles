// Live capture pipeline.
// Authenticates against the target app, walks the user flow, captures the screenshots,
// records click coordinates, and creates traceable test data. Falls back to previously
// captured PNGs on any step failure.
//
// Safe: no destructive ops. Leaves test data in place for the user to review.
//
// Credentials come from the environment, never from this file. A capture script is a
// template that travels between projects and machines, so anything written into its body
// is published with it:
//
//   DEMO_BASE_URL=https://app.example.com/ \
//   DEMO_EMAIL=... DEMO_PASSWORD=... node capture_live.mjs
//
// Keep them in a git-ignored .env, or pull them from your password manager.

import { chromium } from "playwright";
import fs from "node:fs/promises";
import path from "node:path";
import { existsSync } from "node:fs";

const BASE = process.env.DEMO_BASE_URL;
const EMAIL = process.env.DEMO_EMAIL;
const PASS = process.env.DEMO_PASSWORD;

if (!BASE || !EMAIL || !PASS) {
  console.error(
    "Missing credentials. Set DEMO_BASE_URL, DEMO_EMAIL and DEMO_PASSWORD in the environment."
  );
  process.exit(1);
}
const HERE = path.dirname(new URL(import.meta.url).pathname);
const PROJECT = path.resolve(HERE, "..");
const LIVE_DIR = path.join(PROJECT, "assets/captures-live");
const FALLBACK_DIR = path.join(PROJECT, "assets/captures");

await fs.mkdir(LIVE_DIR, { recursive: true });

const targets = {};
const status = {}; // file -> "live" | "fallback"
const errors = {};

// Fallback map: live filename -> V4 PNG filename (when present)
const FALLBACK_MAP = {
  "01_dashboard.png": "01_dashboard.png",
  "02_knowledge_empty.png": "02_knowledge_base.png",
  "03_knowledge_new_menu.png": "07_knowledge_new_menu.png",
  "04_create_folder_modal.png": "10_create_folder_modal.png",
  "05_folder_typed.png": "10_create_folder_modal.png",
  "06_knowledge_with_folder.png": "02_knowledge_base.png",
  "07_agents_empty.png": "03_agents.png",
  "08_agent_modal.png": "08_agent_modal.png",
  "09_agent_filled.png": "08_agent_modal.png",
  "10_link_folders.png": "14_link_folders_modal.png",
  "11_inboxes.png": "04_inboxes.png",
  "12_channel_modal.png": "09_inbox_modal.png",
  "13_conversation.png": "05_conversation.png",
  "14_ai_settings.png": "06_ai_settings.png",
};

// Default click targets (cursor lands here in scenes 3/4/5)
const DEFAULT_TARGETS = {
  "01_dashboard.png": { click_x: 140, click_y: 240, label: "Base de Conocimiento (sidebar)" },
  "02_knowledge_empty.png": { click_x: 1700, click_y: 200, label: "Nueva carpeta" },
  "03_knowledge_new_menu.png": { click_x: 1700, click_y: 260, label: "Crear carpeta" },
  "04_create_folder_modal.png": { click_x: 960, click_y: 540, label: "Campo nombre carpeta" },
  "05_folder_typed.png": { click_x: 1500, click_y: 720, label: "Botón Crear" },
  "06_knowledge_with_folder.png": { click_x: 140, click_y: 290, label: "Agentes IA (sidebar)" },
  "07_agents_empty.png": { click_x: 1700, click_y: 200, label: "Nuevo agente" },
  "08_agent_modal.png": { click_x: 960, click_y: 480, label: "Campo nombre del agente" },
  "09_agent_filled.png": { click_x: 1500, click_y: 760, label: "Botón Crear agente" },
  "10_link_folders.png": { click_x: 960, click_y: 540, label: "Carpeta enlazada" },
  "11_inboxes.png": { click_x: 1700, click_y: 200, label: "Nuevo canal" },
  "12_channel_modal.png": { click_x: 1500, click_y: 720, label: "Crear canal" },
  "13_conversation.png": { click_x: 960, click_y: 900, label: "Campo de mensaje" },
  "14_ai_settings.png": { click_x: 960, click_y: 540, label: "Modelo IA" },
};

async function snap(page, name, target) {
  const dest = path.join(LIVE_DIR, name);
  try {
    await page.waitForTimeout(700);
    await page.screenshot({ path: dest, fullPage: false });
    status[name] = "live";
    targets[name] = target || DEFAULT_TARGETS[name];
    console.log("  ✓ live", name);
    return true;
  } catch (e) {
    errors[name] = e.message;
    return false;
  }
}

async function fallback(name) {
  const src = path.join(FALLBACK_DIR, FALLBACK_MAP[name] || "01_dashboard.png");
  const dest = path.join(LIVE_DIR, name);
  if (existsSync(src)) {
    await fs.copyFile(src, dest);
    status[name] = "fallback";
    targets[name] = DEFAULT_TARGETS[name];
    console.log("  ⤵ fallback", name, "←", path.basename(src));
  } else {
    console.log("  ✗ MISSING fallback for", name);
    status[name] = "missing";
  }
}

async function safe(label, fn) {
  try {
    await fn();
  } catch (e) {
    console.log(`  ! step failed: ${label}: ${e.message}`);
    errors[label] = e.message;
  }
}

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
});
const page = await ctx.newPage();
page.setDefaultTimeout(15000);

// ─── LOGIN ───────────────────────────────────────────────────────────────────
console.log("→ login");
await page.goto(BASE, { waitUntil: "domcontentloaded", timeout: 30000 });
await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
await page.waitForTimeout(800);
await page.locator('input[type="email"]').first().fill(EMAIL);
const passInput = page.locator('input[type="password"]').first();
await passInput.fill(PASS);
await passInput.press("Enter");
await page.waitForLoadState("networkidle", { timeout: 20000 }).catch(() => {});
await page.waitForTimeout(2500);
console.log("  url:", page.url());

// ─── 01: Dashboard ───────────────────────────────────────────────────────────
console.log("→ 01 dashboard");
await safe("dashboard", async () => {
  // Navigate to root if not already there
  if (!page.url().match(/\/(dashboard)?\/?$/)) {
    await page.goto(BASE, { waitUntil: "networkidle", timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(1200);
  }
  await snap(page, "01_dashboard.png", { click_x: 140, click_y: 240, label: "Base de Conocimiento" });
});

// Helper: click sidebar link by visible text
async function clickSidebar(label) {
  const link = page.locator(`text=${label}`).first();
  await link.click({ timeout: 8000 });
  await page.waitForLoadState("networkidle", { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(1200);
}

// ─── 02: Knowledge empty ─────────────────────────────────────────────────────
console.log("→ 02 knowledge_empty");
let knowledgeOk = false;
await safe("knowledge_empty", async () => {
  await clickSidebar("Base de Conocimiento");
  knowledgeOk = true;
  // Get bounding box of "Nueva" button if present, otherwise default
  const newBtn = page.locator('button:has-text("Nueva"), button:has-text("Nuevo"), button:has-text("Crear")').first();
  let target = { click_x: 1700, click_y: 200, label: "Nueva carpeta" };
  try {
    const box = await newBtn.boundingBox({ timeout: 3000 });
    if (box) target = { click_x: Math.round(box.x + box.width / 2), click_y: Math.round(box.y + box.height / 2), label: "Nueva carpeta" };
  } catch {}
  await snap(page, "02_knowledge_empty.png", target);
});

// ─── 03: Knowledge new menu (click "Nueva" / "Crear") ────────────────────────
console.log("→ 03 knowledge_new_menu");
let newMenuClicked = false;
await safe("knowledge_new_menu", async () => {
  if (!knowledgeOk) throw new Error("knowledge not reached");
  const btn = page.locator('button:has-text("Nueva"), button:has-text("Nuevo"), button:has-text("Crear")').first();
  await btn.click({ timeout: 5000 });
  newMenuClicked = true;
  await page.waitForTimeout(900);
  await snap(page, "03_knowledge_new_menu.png", { click_x: 1700, click_y: 260, label: "Crear carpeta" });
});

// ─── 04 + 05: Create folder modal + typed ────────────────────────────────────
console.log("→ 04/05 create_folder_modal");
let folderCreated = false;
await safe("create_folder_modal", async () => {
  // Look for "Crear carpeta" / "Carpeta" item in dropdown, otherwise rely on already-open modal
  const folderItem = page.locator('text=/Crear carpeta|Nueva carpeta|Carpeta/i').first();
  try {
    await folderItem.click({ timeout: 3000 });
  } catch {}
  await page.waitForTimeout(800);
  // Modal name field
  const nameInput = page.locator('input[type="text"], input:not([type])').first();
  await nameInput.waitFor({ timeout: 5000 });
  await snap(page, "04_create_folder_modal.png", { click_x: 960, click_y: 540, label: "Campo nombre" });
  await nameInput.fill("DEMO-VIDEO Carpeta Temporal");
  await page.waitForTimeout(600);
  await snap(page, "05_folder_typed.png", { click_x: 1500, click_y: 720, label: "Botón Crear" });

  // Submit
  const submit = page.locator('button:has-text("Crear"), button:has-text("Guardar"), button[type="submit"]').last();
  await submit.click({ timeout: 5000 });
  folderCreated = true;
  await page.waitForLoadState("networkidle", { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(2000);
});

// ─── 06: Knowledge with folder ───────────────────────────────────────────────
console.log("→ 06 knowledge_with_folder");
await safe("knowledge_with_folder", async () => {
  await snap(page, "06_knowledge_with_folder.png", { click_x: 140, click_y: 290, label: "Agentes IA" });
});

// ─── 07: Agents empty ────────────────────────────────────────────────────────
console.log("→ 07 agents_empty");
let agentsOk = false;
await safe("agents_empty", async () => {
  await clickSidebar("Agentes IA");
  agentsOk = true;
  const newBtn = page.locator('button:has-text("Nuevo"), button:has-text("Crear"), button:has-text("Nueva")').first();
  let target = { click_x: 1700, click_y: 200, label: "Nuevo agente" };
  try {
    const box = await newBtn.boundingBox({ timeout: 3000 });
    if (box) target = { click_x: Math.round(box.x + box.width / 2), click_y: Math.round(box.y + box.height / 2), label: "Nuevo agente" };
  } catch {}
  await snap(page, "07_agents_empty.png", target);
});

// ─── 08 + 09: Agent modal + filled ───────────────────────────────────────────
console.log("→ 08/09 agent_modal");
let agentCreated = false;
await safe("agent_modal", async () => {
  if (!agentsOk) throw new Error("agents not reached");
  const btn = page.locator('button:has-text("Nuevo"), button:has-text("Crear")').first();
  await btn.click({ timeout: 5000 });
  await page.waitForTimeout(1000);
  await snap(page, "08_agent_modal.png", { click_x: 960, click_y: 480, label: "Campo nombre" });

  // Fill agent fields
  const nameInput = page.locator('input[type="text"], input:not([type])').first();
  await nameInput.fill("DEMO-VIDEO Asistente Temporal");
  const textareas = await page.locator("textarea").all();
  if (textareas[0]) await textareas[0].fill("Asistente de ejemplo creado para grabar el vídeo de demo. Responde con datos verificados a partir de las fuentes cargadas.");
  await page.waitForTimeout(600);
  await snap(page, "09_agent_filled.png", { click_x: 1500, click_y: 760, label: "Crear agente" });

  const submit = page.locator('button:has-text("Crear"), button:has-text("Guardar"), button[type="submit"]').last();
  await submit.click({ timeout: 5000 });
  agentCreated = true;
  await page.waitForLoadState("networkidle", { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(2500);
});

// ─── 10: Link folders ────────────────────────────────────────────────────────
console.log("→ 10 link_folders");
await safe("link_folders", async () => {
  // Try to find "fuentes" / "conocimiento" tab inside agent detail
  const linkTab = page.locator('text=/Fuentes|Conocimiento|Vincular|Carpetas/i').first();
  try {
    await linkTab.click({ timeout: 3000 });
    await page.waitForTimeout(1200);
  } catch {}
  await snap(page, "10_link_folders.png", { click_x: 960, click_y: 540, label: "Carpeta vinculada" });
});

// ─── 11: Inboxes ─────────────────────────────────────────────────────────────
console.log("→ 11 inboxes");
let inboxesOk = false;
await safe("inboxes", async () => {
  await clickSidebar("Bandejas");
  inboxesOk = true;
  await snap(page, "11_inboxes.png", { click_x: 1700, click_y: 200, label: "Nuevo canal" });
});

// ─── 12: Channel modal ───────────────────────────────────────────────────────
console.log("→ 12 channel_modal");
await safe("channel_modal", async () => {
  if (!inboxesOk) throw new Error("inboxes not reached");
  const btn = page.locator('button:has-text("Nuevo"), button:has-text("Crear"), button:has-text("Nueva")').first();
  await btn.click({ timeout: 5000 });
  await page.waitForTimeout(1000);
  await snap(page, "12_channel_modal.png", { click_x: 1500, click_y: 720, label: "Crear canal" });
  // Close modal by pressing Escape (no destructive action)
  await page.keyboard.press("Escape").catch(() => {});
  await page.waitForTimeout(500);
});

// ─── 13: Conversation ────────────────────────────────────────────────────────
console.log("→ 13 conversation");
await safe("conversation", async () => {
  await clickSidebar("Conversaciones");
  await snap(page, "13_conversation.png", { click_x: 960, click_y: 900, label: "Mensaje" });
});

// ─── 14: AI settings ─────────────────────────────────────────────────────────
console.log("→ 14 ai_settings");
await safe("ai_settings", async () => {
  await clickSidebar("Configuración");
  await snap(page, "14_ai_settings.png", { click_x: 960, click_y: 540, label: "Modelo IA" });
});

// ─── FALLBACKS ───────────────────────────────────────────────────────────────
const all = Object.keys(FALLBACK_MAP);
for (const f of all) {
  if (status[f] !== "live") {
    await fallback(f);
  }
}

// ─── Write artifacts ─────────────────────────────────────────────────────────
await fs.writeFile(path.join(LIVE_DIR, "cursor_targets.json"), JSON.stringify(targets, null, 2));

const manifestLines = ["# Live Capture Manifest (V5)\n"];
manifestLines.push(`Generated at: ${new Date().toISOString()}\n`);
manifestLines.push("| File | Source | Click target |");
manifestLines.push("|------|--------|-------------|");
for (const f of all) {
  const t = targets[f];
  manifestLines.push(`| ${f} | ${status[f] || "?"} | (${t?.click_x},${t?.click_y}) ${t?.label || ""} |`);
}
if (Object.keys(errors).length) {
  manifestLines.push("\n## Errors\n");
  for (const [k, v] of Object.entries(errors)) manifestLines.push(`- **${k}**: ${v}`);
}
manifestLines.push("\n## Test data created\n");
manifestLines.push(`- Folder: \`DEMO-VIDEO Carpeta Temporal\` — created=${folderCreated}`);
manifestLines.push(`- Agent: \`DEMO-VIDEO Asistente Temporal\` — created=${agentCreated}`);
await fs.writeFile(path.join(LIVE_DIR, "MANIFEST.md"), manifestLines.join("\n"));

console.log("\n=== Summary ===");
const live = all.filter((f) => status[f] === "live").length;
const fb = all.filter((f) => status[f] === "fallback").length;
console.log(`live: ${live} / fallback: ${fb} / total: ${all.length}`);
console.log(`Folder created: ${folderCreated}, Agent created: ${agentCreated}`);

await browser.close();
