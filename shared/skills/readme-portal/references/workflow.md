# Portal layout and generator notes

## Layout (root README)

1. Centered block: banner or logo, badges, one-sentence promise in bold, primary links, quick-nav anchors, divider. Everything inside `<div align="center">`.
2. "Portals" section: 2-column tables, header row = group name, each cell `<a href><img width="100%"></a>`. One card per documented area; link to the doc, folder README or in-page anchor.
3. Divider, then "At a glance": a Need / What it does / How table linking to folders.
4. All pre-existing sections, preserved.
5. "Repository map": folder -> one verified line.

## Docs hub (`docs/README.md`)

Hero `docs-hero.svg`, quick-nav, "Choose your path" card tables by audience (users, architecture, integrations, distribution, maintainers, quality), then an index with one line per document. Links are relative to `docs/`; images live in `docs/assets/readme/`.

## Folder READMEs

Hero `hero-<id>.svg`, back link to the docs hub, "What this folder is", and a content table. When a build, test or manifest consumes the files, say they must not be renamed or moved.

## Generator

- `cards.config.json`: `outDir`, `palette` (brand, light, accent, gradientFrom, bgDeep, bgMid: six `#RRGGBB`), `cards[]` and `heroes[]` of `{id, icon, eyebrow, title, subtitle}`.
- Files: `card-<id>.svg`, `hero-<id>.svg`, `docs-hero.svg` (hero id `docs`), `divider.svg`.
- Palette: bgDeep/bgMid are near-black tints of the brand hue, brand is the mid tone, accent and gradientFrom are lighter, light is near-white. Check contrast of light on bgMid.
- Limits: titles about 28 chars, subtitles about 45, eyebrows about 30 on cards; the generator throws on overflow. Shorten the text, never the font.
- Icons: 24 grid stroked paths in `ICONS`; add new ones there. Unknown icon names throw.
- Regenerate: `node scripts/brand/cards.mjs`; verify: `--check`. Other repo root layout: edit `ROOT` in the script.
- Preview: `rsvg-convert docs/assets/readme/card-x.svg -o /tmp/x.png`.
