#!/usr/bin/env node
// Config-driven generator of README / docs image "portals": one card per area,
// a divider, a docs hub hero and small heroes that open folder READMEs.
//
// Everything project-specific lives in scripts/brand/cards.config.json
// (palette, cards, heroes, output dir). Output is self-contained, deterministic
// SVG: icons are drawn with paths (never glyphs), text uses the system-ui stack
// and every line is measured with a conservative width estimate; the generator
// throws instead of emitting text that could overflow. The only motion is a
// slow light sweep and icon glow, both CSS inside the SVG, disabled with
// prefers-reduced-motion.
//
// Usage:
//   node scripts/brand/cards.mjs                 # writes <outDir>/*.svg
//   node scripts/brand/cards.mjs --check         # exits 1 if files on disk are stale
//   node scripts/brand/cards.mjs --config path   # alternative config

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
/** Repo root: scripts/brand -> repo. Adjust if you place the script elsewhere. */
export const ROOT = path.join(HERE, "..", "..");
export const DEFAULT_CONFIG = path.join(HERE, "cards.config.json");

export const CARD_SIZE = Object.freeze({ width: 1200, height: 400 });
export const HERO_SIZE = Object.freeze({ width: 1200, height: 240 });
export const DIVIDER_SIZE = Object.freeze({ width: 1200, height: 24 });

const FONT = "system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif";
// Average glyph width as a fraction of the font size. Real system fonts sit
// around 0.5; 0.56 leaves room for wide fallbacks and for semibold weights.
const GLYPH_EM = 0.56;

const PALETTE_KEYS = ["brand", "light", "accent", "gradientFrom", "bgDeep", "bgMid"];

/** Icons on a 24x24 grid, drawn as stroked paths. Add more here when needed. */
export const ICONS = Object.freeze({
  download: "M12 3v12 M7 10l5 5 5-5 M4 20h16",
  layers: "M12 3l9 5-9 5-9-5z M3 12.5l9 5 9-5 M3 16.5l9 5 9-5",
  users: "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6 M16 4.3a3.5 3.5 0 0 1 0 6.4 M18 14.3c2.2.7 3.5 2.6 3.5 5.7",
  bolt: "M13 2L4 14h7l-1 8 9-12h-7z",
  window: "M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z M3 9h18 M7 6.5h.01 M10 6.5h.01",
  shield: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z M9 12l2 2 4-4",
  mail: "M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z M3 7l9 6 9-6",
  upload: "M9 4h6v3H9z M8 5.5H6a1 1 0 0 0-1 1V20a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V6.5a1 1 0 0 0-1-1h-2 M12 18v-6 M9 14.5l3-3 3 3",
  box: "M12 3l8 4.5v9L12 21l-8-4.5v-9z M4 7.5l8 4.5 8-4.5 M12 12v9",
  terminal: "M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z M7 10l3 2.5L7 15 M12 15h5",
  key: "M12 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0z M12 12h9 M18 12v3 M15 12v2",
  refresh: "M20 12a8 8 0 0 0-14-5.3 M5 3v4h4 M4 12a8 8 0 0 0 14 5.3 M19 21v-4h-4",
  tag: "M3 12V4h8l10 10-8 8z M7.5 8h.01",
  sliders: "M4 7h10 M18 7h2 M4 17h2 M10 17h10 M16 5v4 M8 15v4",
  book: "M12 6c-2-1.5-5-2-8-2v14c3 0 6 .5 8 2 2-1.5 5-2 8-2V4c-3 0-6 .5-8 2z M12 6v14",
  flask: "M9 3h6 M10 3v6L4.5 19a1.5 1.5 0 0 0 1.3 2.2h12.4a1.5 1.5 0 0 0 1.3-2.2L14 9V3 M7.5 15h9",
  compass: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M15.5 8.5l-2 5-5 2 2-5z",
  plug: "M9 3v5 M15 3v5 M6 8h12v3a6 6 0 0 1-12 0z M12 17v4",
  file: "M6 3h8l5 5v12a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z M14 3v5h5 M8 13h8 M8 17h6",
  lock: "M7 11V8a5 5 0 0 1 10 0v3 M6 11h12a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1z M12 15v2",
  slash: "M16 4L8 20 M4 9l-1.5 3L4 15 M20 9l1.5 3L20 15",
  bot: "M12 3v3 M6 8h12a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z M9 12.5h.01 M15 12.5h.01 M9.5 16h5",
  braces: "M8 4c-2 0-3 1-3 3v2c0 1.5-.8 3-2 3 1.2 0 2 1.5 2 3v2c0 2 1 3 3 3 M16 4c2 0 3 1 3 3v2c0 1.5.8 3 2 3-1.2 0-2 1.5-2 3v2c0 2-1 3-3 3",
});

const num = (n) => String(Math.round(n * 100) / 100);

/** XML-escapes text content and attribute values. */
export function escapeXml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

/** Conservative rendered width of `text` at `size` px, plus `tracking` px per glyph. */
export function estimateWidth(text, size, tracking = 0) {
  return [...text].length * (size * GLYPH_EM + tracking);
}

function assertFits(label, text, size, available, tracking = 0) {
  const needed = estimateWidth(text, size, tracking);
  if (needed > available) {
    throw new Error(`cards: ${label} "${text}" needs ~${Math.ceil(needed)}px at ${size}px but only ${available}px are available`);
  }
}

const iconPath = (name) => {
  const d = ICONS[name];
  if (!d) throw new Error(`cards: unknown icon "${name}"`);
  return d;
};

/** Reads and validates a config file. Throws with a precise message. */
export function loadConfig(file = DEFAULT_CONFIG) {
  const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
  for (const k of PALETTE_KEYS) {
    if (!/^#[0-9a-fA-F]{6}$/.test(cfg.palette?.[k] ?? "")) throw new Error(`cards: palette.${k} must be a #RRGGBB color`);
  }
  for (const list of ["cards", "heroes"]) {
    const ids = new Set();
    for (const spec of cfg[list] ?? []) {
      for (const f of ["id", "icon", "eyebrow", "title", "subtitle"]) {
        if (typeof spec[f] !== "string" || spec[f] === "") throw new Error(`cards: ${list} entry ${spec.id ?? "?"} lacks "${f}"`);
      }
      if (!/^[a-z0-9-]+$/.test(spec.id)) throw new Error(`cards: ${list} id "${spec.id}" must be kebab-case`);
      if (ids.has(spec.id)) throw new Error(`cards: duplicate ${list} id "${spec.id}"`);
      ids.add(spec.id);
    }
  }
  return {
    outDir: cfg.outDir ?? "docs/assets/readme",
    dividerLabel: cfg.dividerLabel ?? "Divider",
    palette: cfg.palette,
    cards: cfg.cards ?? [],
    heroes: cfg.heroes ?? [],
  };
}

/**
 * Shared panel: card (1200x400) and hero (1200x240) differ only in size.
 * @param {{width:number,height:number}} size
 * @param {{id:string, icon:string, eyebrow:string, title:string, subtitle:string}} spec
 * @param {{plate:number, titleSize:number, subtitleSize:number, eyebrowSize:number, arrow:boolean}} look
 */
function renderPanel(palette, size, spec, look) {
  const c = palette;
  const { width, height } = size;
  const radius = 28;
  const plate = look.plate;
  const plateX = 80;
  const plateY = (height - plate) / 2;
  const textX = plateX + plate + 50;
  const rightPad = look.arrow ? 140 : 70;
  const available = width - textX - rightPad;

  assertFits(`${spec.id} title`, spec.title, look.titleSize, available);
  assertFits(`${spec.id} subtitle`, spec.subtitle, look.subtitleSize, available);
  assertFits(`${spec.id} eyebrow`, spec.eyebrow, look.eyebrowSize, available, 3);

  const iconScale = (plate * 0.56) / 24;
  const iconOffset = (plate - 24 * iconScale) / 2;
  const cy = height / 2;
  const blockH = look.eyebrowSize + look.titleSize + look.subtitleSize + 30;
  const top = cy - blockH / 2;
  const eyebrowY = top + look.eyebrowSize;
  const titleY = eyebrowY + 14 + look.titleSize * 0.85;
  const subtitleY = titleY + 16 + look.subtitleSize;
  const strokeW = 1.7;
  const arrowCx = width - 84;
  const arrowCy = cy;
  const label = `${spec.title}. ${spec.subtitle}`;

  const arrow = look.arrow
    ? `
    <g class="arrow" transform="translate(${arrowCx} ${arrowCy})">
      <circle r="30" fill="${c.bgDeep}" fill-opacity="0.55" stroke="${c.accent}" stroke-opacity="0.55" stroke-width="2"/>
      <path d="M-11 0H11 M3 -8L11 0L3 8" fill="none" stroke="${c.light}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
    </g>`
    : "";

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="t d">
  <title id="t">${escapeXml(spec.title)}</title>
  <desc id="d">${escapeXml(label)}</desc>
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${c.bgMid}"/>
      <stop offset="1" stop-color="${c.bgDeep}"/>
    </linearGradient>
    <radialGradient id="glow" cx="${num(plateX + plate / 2)}" cy="${num(cy)}" r="${num(width * 0.55)}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${c.brand}" stop-opacity="0.7"/>
      <stop offset="0.5" stop-color="${c.brand}" stop-opacity="0.2"/>
      <stop offset="1" stop-color="${c.brand}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="plate" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${c.brand}"/>
      <stop offset="1" stop-color="${c.bgMid}"/>
    </linearGradient>
    <linearGradient id="ink" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${c.light}"/>
      <stop offset="1" stop-color="${c.gradientFrom}"/>
    </linearGradient>
    <linearGradient id="sweep" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${c.light}" stop-opacity="0"/>
      <stop offset="0.5" stop-color="${c.light}" stop-opacity="0.09"/>
      <stop offset="1" stop-color="${c.light}" stop-opacity="0"/>
    </linearGradient>
    <pattern id="dots" width="32" height="32" patternUnits="userSpaceOnUse">
      <circle cx="2" cy="2" r="1.1" fill="${c.accent}" fill-opacity="0.16"/>
    </pattern>
    <clipPath id="frame"><rect width="${width}" height="${height}" rx="${radius}"/></clipPath>
    <style>
      .sweep { transform: translateX(-420px) skewX(-18deg); animation: sweep 7s ease-in-out infinite; }
      .halo { animation: halo 5s ease-in-out infinite; }
      @keyframes sweep { 0%, 55% { transform: translateX(-420px) skewX(-18deg); } 100% { transform: translateX(${width + 420}px) skewX(-18deg); } }
      @keyframes halo { 0%, 100% { opacity: 0.35; } 50% { opacity: 0.75; } }
      @media (prefers-reduced-motion: reduce) { .sweep, .halo { animation: none; } }
    </style>
  </defs>

  <g clip-path="url(#frame)">
    <rect width="${width}" height="${height}" fill="url(#bg)"/>
    <rect width="${width}" height="${height}" fill="url(#dots)"/>
    <rect width="${width}" height="${height}" fill="url(#glow)"/>
    <rect class="sweep" x="0" y="-20" width="260" height="${height + 40}" fill="url(#sweep)"/>

    <g transform="translate(${num(plateX)} ${num(plateY)})">
      <rect class="halo" x="-14" y="-14" width="${plate + 28}" height="${plate + 28}" rx="38" fill="${c.gradientFrom}" fill-opacity="0.18"/>
      <rect width="${plate}" height="${plate}" rx="28" fill="url(#plate)" stroke="${c.accent}" stroke-opacity="0.6" stroke-width="2"/>
      <g transform="translate(${num(iconOffset)} ${num(iconOffset)}) scale(${num(iconScale)})" fill="none" stroke="url(#ink)" stroke-width="${strokeW}" stroke-linecap="round" stroke-linejoin="round">
        <path d="${iconPath(spec.icon)}"/>
      </g>
    </g>

    <text x="${textX}" y="${num(eyebrowY)}" font-family="${FONT}" font-size="${look.eyebrowSize}" font-weight="600" letter-spacing="3" fill="${c.accent}">${escapeXml(spec.eyebrow)}</text>
    <text x="${textX}" y="${num(titleY)}" font-family="${FONT}" font-size="${look.titleSize}" font-weight="700" fill="${c.light}">${escapeXml(spec.title)}</text>
    <text x="${textX}" y="${num(subtitleY)}" font-family="${FONT}" font-size="${look.subtitleSize}" fill="${c.gradientFrom}" fill-opacity="0.92">${escapeXml(spec.subtitle)}</text>${arrow}

    <rect x="1" y="1" width="${width - 2}" height="${height - 2}" rx="${radius - 1}" fill="none" stroke="${c.accent}" stroke-opacity="0.35" stroke-width="2"/>
  </g>
</svg>
`;
}

export function renderCard(palette, spec) {
  return renderPanel(palette, CARD_SIZE, spec, { plate: 150, titleSize: 50, subtitleSize: 28, eyebrowSize: 19, arrow: true });
}

export function renderHero(palette, spec) {
  return renderPanel(palette, HERO_SIZE, spec, { plate: 110, titleSize: 44, subtitleSize: 24, eyebrowSize: 17, arrow: false });
}

export function renderDivider(palette, label = "Divider") {
  const c = palette;
  const { width, height } = DIVIDER_SIZE;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-label="${escapeXml(label)}">
  <title>${escapeXml(label)}</title>
  <defs>
    <linearGradient id="lineL" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${c.accent}" stop-opacity="0"/>
      <stop offset="1" stop-color="${c.accent}" stop-opacity="0.85"/>
    </linearGradient>
    <linearGradient id="lineR" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${c.accent}" stop-opacity="0.85"/>
      <stop offset="1" stop-color="${c.accent}" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="60" y="${height / 2 - 1}" width="${width / 2 - 60 - 24}" height="2" fill="url(#lineL)"/>
  <rect x="${width / 2 + 24}" y="${height / 2 - 1}" width="${width / 2 - 60 - 24}" height="2" fill="url(#lineR)"/>
  <g transform="translate(${width / 2} ${height / 2})">
    <path d="M0 -8L8 0L0 8L-8 0Z" fill="${c.brand}" stroke="${c.gradientFrom}" stroke-width="1.5"/>
  </g>
</svg>
`;
}

/** Committed file names. Hero id "docs" becomes docs-hero.svg (the docs hub hero). */
export const heroFile = (spec) => (spec.id === "docs" ? "docs-hero.svg" : `hero-${spec.id}.svg`);
export const cardFile = (spec) => `card-${spec.id}.svg`;

/** Every generated asset as a name -> SVG map (sorted by name). */
export function renderAll(config = loadConfig()) {
  const out = new Map();
  for (const spec of config.cards) out.set(cardFile(spec), renderCard(config.palette, spec));
  for (const spec of config.heroes) out.set(heroFile(spec), renderHero(config.palette, spec));
  out.set("divider.svg", renderDivider(config.palette, config.dividerLabel));
  return new Map([...out.entries()].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)));
}

export const outDirOf = (config) => path.join(ROOT, config.outDir);

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const ci = args.indexOf("--config");
  const config = loadConfig(ci >= 0 ? path.resolve(args[ci + 1]) : DEFAULT_CONFIG);
  const dir = outDirOf(config);
  const assets = renderAll(config);
  if (args.includes("--check")) {
    const stale = [...assets].filter(([n, svg]) => !fs.existsSync(path.join(dir, n)) || fs.readFileSync(path.join(dir, n), "utf8") !== svg).map(([n]) => n);
    if (stale.length) {
      process.stderr.write(`stale or missing: ${stale.join(", ")}\nrun: node scripts/brand/cards.mjs\n`);
      process.exit(1);
    }
  } else {
    fs.mkdirSync(dir, { recursive: true });
    for (const [name, svg] of assets) {
      fs.writeFileSync(path.join(dir, name), svg);
      process.stdout.write(`${path.relative(process.cwd(), path.join(dir, name))}\n`);
    }
  }
}
