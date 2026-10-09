// The README/docs image cards are generated (scripts/brand/cards.mjs): the
// committed SVGs must be exactly what the generator emits, so nobody edits an
// image by hand and the docs never point at a stale card.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import { ICONS, escapeXml, loadConfig, outDirOf, renderAll, renderCard } from "../scripts/brand/cards.mjs";

const config = loadConfig();
const dir = outDirOf(config);
const assets = renderAll(config);

test("every committed SVG is identical to the generator output", () => {
  for (const [name, svg] of assets) {
    const file = path.join(dir, name);
    assert.ok(fs.existsSync(file), `${name} is missing: run node scripts/brand/cards.mjs`);
    assert.equal(fs.readFileSync(file, "utf8"), svg, `${name} is stale: run node scripts/brand/cards.mjs`);
  }
});

test("no stray SVGs in the output folder", () => {
  const onDisk = fs.readdirSync(dir).filter((f) => f.endsWith(".svg"));
  assert.deepEqual(onDisk.sort(), [...assets.keys()].sort());
});

test("output is deterministic", () => {
  assert.deepEqual([...renderAll(config)], [...assets]);
});

test("every SVG is accessible and self-contained", () => {
  for (const [name, svg] of assets) {
    assert.match(svg, /^<svg xmlns="http:\/\/www\.w3\.org\/2000\/svg" /, `${name}: root`);
    assert.match(svg, /<title[ >]/, `${name}: no <title>`);
    assert.doesNotMatch(svg, /&(?!(amp|lt|gt|quot|apos|#\d+);)/, `${name}: unescaped &`);
    assert.doesNotMatch(svg, /<script|<image|href=|url\(http|@import/i, `${name}: external reference or script`);
  }
});

test("text is XML-escaped and overflow is rejected", () => {
  assert.equal(escapeXml(`a & b < c`), "a &amp; b &lt; c");
  const svg = renderCard(config.palette, { id: "x", icon: "book", eyebrow: "A&B", title: "<b>Hi</b>", subtitle: "x & y" });
  assert.doesNotMatch(svg, /<b>/);
  assert.throws(() => renderCard(config.palette, { id: "x", icon: "book", eyebrow: "A", title: "x".repeat(80), subtitle: "y" }), /needs ~/);
});

test("every icon exists and the divider and docs hero are present", () => {
  for (const spec of [...config.cards, ...config.heroes]) assert.ok(ICONS[spec.icon], `${spec.id}: unknown icon ${spec.icon}`);
  assert.ok(assets.has("divider.svg"));
});
