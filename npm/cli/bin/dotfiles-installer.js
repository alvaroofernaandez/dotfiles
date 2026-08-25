#!/usr/bin/env node
// Launches the platform binary that npm installed alongside this package.
//
// The binaries ship as optionalDependencies with `os`/`cpu` constraints, so npm
// downloads only the one matching the machine — the esbuild pattern. That is
// deliberate: the alternative, a postinstall script that downloads a binary,
// breaks under `npm ci --ignore-scripts` and in any environment that forbids
// install scripts, which is most CI. Nothing here runs at install time.

import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { existsSync } from "node:fs";
import path from "node:path";

import { packageFor, binaryName, describeUnsupported, CLI_PACKAGE } from "../lib/resolve.js";

const require = createRequire(import.meta.url);

function resolveBinary() {
  const pkg = packageFor(process.platform, process.arch);
  if (!pkg) {
    console.error(describeUnsupported(process.platform, process.arch));
    process.exit(1);
  }

  const file = binaryName(process.platform);

  // require.resolve on the package's own package.json, not on the binary: the
  // binary is not a module and has no "exports" entry, so resolving it directly
  // fails under modern Node resolution.
  try {
    const manifest = require.resolve(`${pkg}/package.json`);
    const candidate = path.join(path.dirname(manifest), "bin", file);
    if (existsSync(candidate)) return candidate;
  } catch {
    // Fall through to the shared error below.
  }

  console.error(
    [
      `dotfiles-installer: the binary for ${process.platform}/${process.arch} is missing.`,
      ``,
      `This usually means the optional dependency was skipped. Reinstall with:`,
      `  npm install ${CLI_PACKAGE} --force`,
      ``,
      `If you installed with --no-optional, that flag is the cause.`,
    ].join("\n"),
  );
  process.exit(1);
}

const binary = resolveBinary();

// stdio: "inherit" so the TUI owns the real terminal. Without it bubbletea sees
// a pipe rather than a tty, and renders nothing usable.
const child = spawn(binary, process.argv.slice(2), { stdio: "inherit" });

// Signals are forwarded rather than left to the shell: the child must get the
// chance to restore the terminal out of the alternate screen buffer, or the
// user is left with a corrupted prompt.
for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => child.kill(signal));
}

child.on("error", (err) => {
  console.error(`dotfiles-installer: could not run ${binary}: ${err.message}`);
  process.exit(1);
});

child.on("close", (code, signal) => {
  // A process killed by a signal reports code null. Exiting 0 there would tell
  // a CI job that an interrupted install succeeded.
  if (signal) {
    process.exit(1);
  }
  process.exit(code ?? 0);
});
