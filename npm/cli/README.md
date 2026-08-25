# dotfiles-installer

Cross-platform installer for [alvaroofernaandez/dotfiles](https://github.com/alvaroofernaandez/dotfiles) — a terminal environment (tmux, yazi, Ghostty, zsh) plus Claude Code and OpenCode configuration.

## Use it

```sh
npx @alvaroofernaandez/dotfiles-installer
```

`npx` always resolves the latest published version, so this is the way to stay current: every push to `main` publishes a new build.

## Or install it

```sh
npm install -g @alvaroofernaandez/dotfiles-installer
dotfiles-installer
```

A globally installed copy does **not** update itself — npm never pushes updates to a machine. The binary checks for a newer version when it starts and tells you when there is one:

```sh
npm update -g @alvaroofernaandez/dotfiles-installer
```

## What it does

Opens a TUI that detects your platform and offers only what applies to it:

- **macOS / Linux** — everything, symlinked into `$HOME`.
- **Windows** — Claude Code, OpenCode and git natively; the terminal environment is shown greyed out with the reason, and installed in full if WSL is detected.

Existing files are never deleted. Anything in the way is moved to `~/.dotfiles-backup/<timestamp>/` first, and re-running is a no-op for everything already linked.

## Commands

```sh
dotfiles-installer              # interactive TUI
dotfiles-installer --dry-run    # show what would happen, change nothing
dotfiles-installer --yes        # install everything applicable, no TUI
dotfiles-installer update       # pull the repo and re-link what is new
dotfiles-installer --version
```

## How the binary is delivered

Each platform's binary ships as a separate package, pulled in through `optionalDependencies` with `os`/`cpu` constraints — the esbuild pattern. npm downloads only the one that matches your machine.

There is **no postinstall script**. Nothing executes at install time, so this works under `npm ci --ignore-scripts` and in environments that forbid install scripts.

## Without Node

```sh
curl -fsSL https://raw.githubusercontent.com/alvaroofernaandez/dotfiles/main/scripts/install.sh | sh
```

## License

MIT
