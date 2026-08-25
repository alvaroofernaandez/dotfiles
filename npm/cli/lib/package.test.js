// Verifies the packages that npm/build.mjs assembles.
//
// These run against a real build in a temp directory rather than against
// hand-written fixtures: the thing worth checking is what actually gets
// published, and a fixture would drift from the builder without anyone noticing.

import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { TARGETS, CLI_PACKAGE } from "./resolve.js";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
let out;

before(() => {
  const work = mkdtempSync(path.join(tmpdir(), "dotfiles-npm-"));
  const dist = path.join(work, "dist");
  mkdirSync(dist, { recursive: true });

  // Stub binaries: the packaging is what is under test, not the compiler.
  for (const t of TARGETS) {
    const ext = t.platform === "win32" ? ".exe" : "";
    writeFileSync(path.join(dist, `dotfiles-installer-${t.goos}-${t.goarch}${ext}`), "stub");
  }

  out = path.join(work, "dist-npm");
  execFileSync(
    process.execPath,
    [path.join(repoRoot, "npm/build.mjs"), "--version", "9.9.9", "--dist", dist, "--out", out],
    { stdio: "pipe" },
  );
});

const read = (p) => JSON.parse(readFileSync(p, "utf8"));

test("each platform package declares os and cpu", () => {
  // This is the entire delivery mechanism. Without these fields npm installs
  // all six binaries on every machine — six times the download, five useless.
  for (const t of TARGETS) {
    const dir = path.join(out, t.pkg.replace(/^@[^/]+\//, ""));
    const pkg = read(path.join(dir, "package.json"));

    assert.deepEqual(pkg.os, [t.platform], `${t.pkg} os field`);
    assert.deepEqual(pkg.cpu, [t.arch], `${t.pkg} cpu field`);
    assert.equal(pkg.name, t.pkg);
    assert.equal(pkg.version, "9.9.9");
  }
});

test("each platform package ships exactly its own binary", () => {
  for (const t of TARGETS) {
    const dir = path.join(out, t.pkg.replace(/^@[^/]+\//, ""));
    const ext = t.platform === "win32" ? ".exe" : "";
    assert.ok(
      existsSync(path.join(dir, "bin", `dotfiles-installer${ext}`)),
      `${t.pkg} is missing its binary`,
    );
  }
});

test("the CLI depends on every platform package optionally", () => {
  const pkg = read(path.join(out, "cli/package.json"));
  assert.equal(pkg.name, CLI_PACKAGE);

  // optionalDependencies, never dependencies: as hard dependencies the install
  // fails on every machine, because five of the six can never be satisfied.
  assert.ok(pkg.optionalDependencies, "no optionalDependencies");
  assert.equal(pkg.dependencies, undefined, "platform binaries must not be hard dependencies");

  for (const t of TARGETS) {
    assert.equal(pkg.optionalDependencies[t.pkg], "9.9.9", `${t.pkg} not pinned to the build version`);
  }
});

test("the CLI has no install scripts", () => {
  // A postinstall that downloads a binary breaks under --ignore-scripts, which
  // is the default in most CI. Nothing here may run at install time.
  const pkg = read(path.join(out, "cli/package.json"));
  for (const hook of ["preinstall", "install", "postinstall", "prepare"]) {
    assert.equal(pkg.scripts?.[hook], undefined, `${hook} script present`);
  }
});

test("the CLI exposes the binary and ships what it needs", () => {
  const pkg = read(path.join(out, "cli/package.json"));
  assert.equal(pkg.bin["dotfiles-installer"], "bin/dotfiles-installer.js");
  assert.equal(pkg.type, "module");

  // The launcher imports from lib/, so omitting it from files would publish a
  // package that throws on first run.
  assert.ok(pkg.files.includes("lib"), "lib must be published");
  assert.ok(pkg.files.includes("bin"), "bin must be published");
  assert.ok(existsSync(path.join(out, "cli/lib/resolve.js")), "resolve.js not copied");
  assert.ok(existsSync(path.join(out, "cli/bin/dotfiles-installer.js")), "launcher not copied");
});

test("every package is public and versioned alike", () => {
  const names = [...TARGETS.map((t) => t.pkg.replace(/^@[^/]+\//, "")), "cli"];
  for (const name of names) {
    const pkg = read(path.join(out, name, "package.json"));
    assert.equal(pkg.version, "9.9.9", `${name} version`);
    assert.equal(pkg.publishConfig?.access, "public", `${name} would publish private`);
    assert.equal(pkg.license, "MIT", `${name} license`);
  }
});

test("a non-semver version is rejected before anything is written", () => {
  // Better to fail at build time than to half-publish and have the registry
  // reject the second package.
  assert.throws(() => {
    execFileSync(
      process.execPath,
      [path.join(repoRoot, "npm/build.mjs"), "--version", "not-a-version", "--dist", "x", "--out", "y"],
      { stdio: "pipe" },
    );
  });
});
