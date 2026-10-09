// Every relative link and image of every git-tracked Markdown file must point
// at a file that exists, and every #anchor into a Markdown file at a heading
// that exists. Keeps the docs portal honest as files move.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
// Adjust: folders whose Markdown is not part of the portal (vendored, generated, scratch).
const EXCLUDED = /(^|\/)(node_modules|third_party|vendor)\//;

const markdownFiles = execFileSync("git", ["ls-files", "-z", "--", "*.md"], { cwd: ROOT, encoding: "utf8" })
  .split("\0")
  .filter((f) => f && !EXCLUDED.test(f) && fs.existsSync(path.join(ROOT, f)));

/** Removes fenced code blocks and inline code, which hold examples, not links. */
const stripCode = (text) => text.replace(/^(```|~~~)[^\n]*\n[\s\S]*?^\1[^\n]*$/gm, "").replace(/`[^`\n]*`/g, "");

/** GitHub's heading slug: lowercase, drop punctuation and emoji, spaces to hyphens. */
export function slug(heading) {
  return heading.trim().toLowerCase().replace(/<[^>]+>/g, "").replace(/[^\p{L}\p{N}\p{M} _-]/gu, "").replace(/ /g, "-");
}

function anchorsOf(file) {
  const text = stripCode(fs.readFileSync(path.join(ROOT, file), "utf8"));
  const seen = new Map();
  const anchors = new Set();
  for (const m of text.matchAll(/^#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$/gm)) {
    const base = slug(m[1].replace(/\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\*/g, ""));
    const n = seen.get(base) ?? 0;
    seen.set(base, n + 1);
    anchors.add(n === 0 ? base : `${base}-${n}`);
  }
  for (const m of text.matchAll(/<a\s+[^>]*(?:name|id)="([^"]+)"/g)) anchors.add(m[1]);
  return anchors;
}

/** All link targets: [text](t), ![alt](t), src="t", href="t". */
export function targetsOf(text) {
  const body = stripCode(text);
  const out = [];
  for (const m of body.matchAll(/!?\[[^\]\n]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)/g)) out.push(m[1]);
  for (const m of body.matchAll(/\b(?:src|href)="([^"]+)"/g)) out.push(m[1]);
  return out;
}

const isExternal = (t) => /^([a-z][a-z0-9+.-]*:|\/\/)/i.test(t);

test("the checker finds the usual link formats and ignores code", () => {
  const sample = ["[a](x.md) ![b](img/y.svg \"t\") <a href=\"z/\"><img src=\"w.png\"></a>", "```", "[no](none.md)", "```", "`[no](nope.md)`"].join("\n");
  assert.deepEqual(targetsOf(sample), ["x.md", "img/y.svg", "z/", "w.png"]);
});

test("there is tracked Markdown to check", () => {
  assert.ok(markdownFiles.includes("README.md"));
});

test("every relative link and image points at something that exists", () => {
  const broken = [];
  for (const file of markdownFiles) {
    const text = fs.readFileSync(path.join(ROOT, file), "utf8");
    for (const raw of targetsOf(text)) {
      if (isExternal(raw) || raw.startsWith("#")) continue;
      const target = decodeURIComponent(raw.split("#")[0].split("?")[0]);
      if (target === "") continue;
      const resolved = path.resolve(ROOT, path.dirname(file), target);
      if (!resolved.startsWith(ROOT) || !fs.existsSync(resolved)) broken.push(`${file}: ${raw}`);
    }
  }
  assert.deepEqual(broken, [], `broken links:\n${broken.join("\n")}`);
});

test("every #anchor into a tracked Markdown file points at an existing heading", () => {
  const cache = new Map();
  const anchors = (f) => cache.get(f) ?? cache.set(f, anchorsOf(f)).get(f);
  const broken = [];
  for (const file of markdownFiles) {
    const text = fs.readFileSync(path.join(ROOT, file), "utf8");
    for (const raw of targetsOf(text)) {
      if (isExternal(raw) || !raw.includes("#")) continue;
      const pathPart = raw.split("#")[0];
      const fragment = decodeURIComponent(raw.split("#")[1]);
      if (fragment === "" || /^L\d+/.test(fragment)) continue;
      const targetFile = pathPart === "" ? file : path.relative(ROOT, path.resolve(ROOT, path.dirname(file), decodeURIComponent(pathPart)));
      if (!markdownFiles.includes(targetFile)) continue;
      if (!anchors(targetFile).has(fragment.toLowerCase())) broken.push(`${file}: ${raw}`);
    }
  }
  assert.deepEqual(broken, [], `broken anchors:\n${broken.join("\n")}`);
});
