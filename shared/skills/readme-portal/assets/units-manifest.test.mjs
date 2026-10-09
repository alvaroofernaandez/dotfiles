// Versioning of units (plugins, packages, services, skills...): the manifest
// lists exactly the unit files, each with a SemVer version that its guide and
// the unit CHANGELOG repeat. The manifest and changelog are repository
// documentation: they must never be shipped by a build.
// ADAPT the CONFIG block to the repo; keep the assertions.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// ---- CONFIG ---------------------------------------------------------------
const UNIT_DIR = "plugins"; // folder holding the units and the manifest
const MANIFEST = "units.json"; // <UNIT_DIR>/<MANIFEST>
const UNIT_FILE = /\.(tsx|mjs|js|ts)$/; // top-level files that count as units
const LIST_KEY = "units"; // array key inside the manifest
const VERSION_LINE = (u) => `**Unit:** \`${u.id}\``; // line in the unit doc carrying the version
const ROOT_VERSION_FILE = "package.json"; // current project version, for "since" (or null)
// ---------------------------------------------------------------------------

const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?$/;
const dir = path.join(ROOT, UNIT_DIR);
const manifest = JSON.parse(fs.readFileSync(path.join(dir, MANIFEST), "utf8"));
const changelog = fs.readFileSync(path.join(dir, "CHANGELOG.md"), "utf8");
const entries = manifest[LIST_KEY];
const key = (v) => v.split("-")[0].split(".").map(Number);
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

test("one manifest entry per unit file and vice versa, no duplicates", () => {
  const files = fs.readdirSync(dir).filter((f) => UNIT_FILE.test(f) && fs.statSync(path.join(dir, f)).isFile()).sort();
  assert.deepEqual(entries.map((e) => e.file).sort(), files);
  assert.equal(new Set(entries.map((e) => e.id)).size, entries.length, "duplicate id");
});

test("versions are SemVer and 'since' is not later than the project version", () => {
  const current = ROOT_VERSION_FILE ? JSON.parse(fs.readFileSync(path.join(ROOT, ROOT_VERSION_FILE), "utf8")).version : null;
  for (const e of entries) {
    assert.match(e.version, SEMVER, `${e.id}: version`);
    assert.match(e.since, SEMVER, `${e.id}: since`);
    if (!current) continue;
    const [a, b] = [key(e.since), key(current)];
    assert.ok(a[0] < b[0] || (a[0] === b[0] && (a[1] < b[1] || (a[1] === b[1] && a[2] <= b[2]))), `${e.id}: since ${e.since} is later than ${current}`);
  }
});

test("each unit guide exists and repeats the same version", () => {
  for (const e of entries) {
    const doc = path.join(ROOT, e.doc);
    assert.ok(fs.existsSync(doc), `${e.id}: missing ${e.doc}`);
    const line = fs.readFileSync(doc, "utf8").split("\n").find((l) => l.includes(VERSION_LINE(e)));
    assert.ok(line, `${e.doc} has no version line for ${e.id}`);
    assert.match(line, new RegExp(`\\*\\*Version:\\*\\* ${esc(e.version)}( |$)`), `${e.doc}: version differs from ${e.version}`);
  }
});

test("the CHANGELOG has one section per unit, newest version first and equal to the manifest", () => {
  for (const e of entries) {
    const start = changelog.indexOf(`\n## ${e.id}\n`);
    assert.ok(start >= 0, `CHANGELOG: missing section ${e.id}`);
    const rest = changelog.slice(start + 1);
    const next = rest.slice(3).search(/\n## /);
    const section = next < 0 ? rest : rest.slice(0, next + 3);
    const first = /^### \[(\d+\.\d+\.\d+[^\]]*)\]/m.exec(section);
    assert.ok(first, `CHANGELOG: ${e.id} has no version`);
    assert.equal(first[1], e.version, `CHANGELOG: newest version of ${e.id} is not ${e.version}`);
  }
});

// Add a test that your build/packaging step does NOT ship the manifest, the
// changelog or the folder README (see references/versioning-units.md).
