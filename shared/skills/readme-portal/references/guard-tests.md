# Guard tests

Three guards, templates in `assets/` for Node (`node:test`, no dependencies). Copy to `tests/`, then adapt the CONFIG blocks and import paths.

| Guard | Template | Proves |
|-------|----------|--------|
| Images match generator | `brand-cards.test.mjs` | Committed SVGs equal generator output, no strays, deterministic, escaped, accessible, no scripts or external refs, overflow rejected |
| Markdown links | `docs-links.test.mjs` | Every relative link, image and `#anchor` in git-tracked `*.md` resolves (code blocks ignored) |
| Units manifest | `units-manifest.test.mjs` | Manifest and unit files match, SemVer, guide and changelog repeat the version |

Run with an explicit glob: `node --test tests/*.test.mjs` (a bare directory argument fails on some Node versions).

## Non-Node repos

Keep the generator in Node (it is a dev tool, one command) or port it, but port the three guards to the repo's runner (Go `testing`, pytest, bats). Reuse the same assertions: regenerate-and-compare, walk `git ls-files '*.md'`, parse the manifest. Wire them into the existing test command; never add CI the repo does not already have.

## Link checker notes

- GitHub slug: lowercase, strip punctuation and emoji, spaces to hyphens, duplicates get `-1`, `-2`.
- Exclude vendored, generated or scratch Markdown via `EXCLUDED`.
- Third-party Markdown in `node_modules` is not tracked, so `git ls-files` already skips it.
