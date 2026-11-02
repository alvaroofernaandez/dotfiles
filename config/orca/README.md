# Orca

Versioned snapshot of the declarative parts of [Orca](https://github.com/stablyai) (desktop app, captured at v1.4.246).
Nothing here is symlinked: Orca owns and rewrites these files, so a symlink would be replaced on the next write.

| File | Source on this Mac | Restore |
|---|---|---|
| `plugins.lock.json` | `~/Library/Application Support/orca/plugins/plugins.lock.json` | Reinstall the listed plugins from Orca's marketplace (pinned commits are recorded) |
| `agent-hooks/*.sh` | `~/.orca/agent-hooks/` | Reference only — Orca regenerates them on launch |

## Deliberately NOT versioned

This repo is public. These stay on the machine:

- **Settings** — `profiles/<id>/profile-state.db` (SQLite). Already synced by Orca's own cloud profile.
- **Key material** — `agent-session-authority.key`, `orca-e2ee-keypair.json`, `account-session.json.enc`.
- **Accounts and identity** — `Cookies`, `codex-pane-accounts.json`, `orca-devices.json`, `orca-profile-index.json` (account email and cloud ids).
- **State** — session journals, `orchestration.db`, usage analytics, terminal history, caches.
- **Skills** — `orca-cli`, `orchestration`, `computer-use` in `~/.agents/skills` are installed and updated by Orca itself.

`tests/orca-config.test.sh` fails if any of these lands in `config/orca/`.

## Refresh the snapshot

```bash
cp ~/Library/Application\ Support/orca/plugins/plugins.lock.json config/orca/
cp ~/.orca/agent-hooks/*.sh config/orca/agent-hooks/
bash tests/orca-config.test.sh
```
