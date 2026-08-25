import { test } from "node:test";
import assert from "node:assert/strict";

import { TARGETS, packageFor, binaryName, describeUnsupported } from "./resolve.js";

test("every Go build target has an npm package", () => {
  // npm uses process.platform / process.arch names, which differ from GOOS and
  // GOARCH (win32 vs windows, x64 vs amd64). A mismatch here means npm installs
  // nothing on that platform and the CLI fails at run time with no clue why.
  const expected = [
    ["darwin", "arm64", "darwin", "arm64"],
    ["darwin", "x64", "darwin", "amd64"],
    ["linux", "arm64", "linux", "arm64"],
    ["linux", "x64", "linux", "amd64"],
    ["win32", "arm64", "windows", "arm64"],
    ["win32", "x64", "windows", "amd64"],
  ];
  assert.equal(TARGETS.length, expected.length);

  for (const [platform, arch, goos, goarch] of expected) {
    const t = TARGETS.find((t) => t.platform === platform && t.arch === arch);
    assert.ok(t, `no target for ${platform}/${arch}`);
    assert.equal(t.goos, goos, `${platform}/${arch} maps to the wrong GOOS`);
    assert.equal(t.goarch, goarch, `${platform}/${arch} maps to the wrong GOARCH`);
  }
});

test("package names are unique and derived from the target", () => {
  const names = TARGETS.map((t) => t.pkg);
  assert.equal(new Set(names).size, names.length, "duplicate package name");
  for (const t of TARGETS) {
    assert.ok(
      t.pkg.endsWith(`-${t.platform}-${t.arch}`),
      `${t.pkg} does not name its platform`,
    );
  }
});

test("packageFor finds the current platform", () => {
  const pkg = packageFor("darwin", "arm64");
  assert.equal(pkg, "@alvaroofernaandez/dotfiles-installer-darwin-arm64");
});

test("packageFor returns null for an unsupported platform", () => {
  // Returning null rather than throwing lets the caller produce one good error
  // message instead of a stack trace.
  assert.equal(packageFor("aix", "ppc64"), null);
  assert.equal(packageFor("darwin", "mips"), null);
});

test("binaryName carries .exe only on Windows", () => {
  assert.equal(binaryName("darwin"), "dotfiles-installer");
  assert.equal(binaryName("linux"), "dotfiles-installer");
  assert.equal(binaryName("win32"), "dotfiles-installer.exe");
});

test("the unsupported message names the platform and offers a way out", () => {
  // Someone on an unsupported platform must not be left guessing: the repo has
  // a shell installer that needs nothing but bash.
  const msg = describeUnsupported("aix", "ppc64");
  assert.match(msg, /aix/);
  assert.match(msg, /ppc64/);
  assert.match(msg, /install\.sh/, "must point at the fallback installer");
});
