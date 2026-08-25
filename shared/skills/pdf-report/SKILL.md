---
name: pdf-report
description: "Build print-grade A4 PDF documents of any kind: reports, technical analyses, dossiers, manuals, guides, memos, whitepapers, one-pagers and internal documentation. Renders HTML to PDF via headless Chromium with embedded fonts, Lucide icons and automated layout guards (overflow, orphan paragraphs, WCAG contrast). Trigger: when the user asks for an informe, documento, dossier, análisis, memoria, manual or guía in PDF, says 'hazme un PDF como el de X', 'PDF bonito/presentable', 'documento imprimible', or wants to update an existing document built with this system."
version: "1.0.0"
---

# PDF Report

Produces A4 PDFs that read like consultancy work: dense with data, scannable without
effort, and branded with a real visual identity. The output is print-grade, not a
web page saved as PDF.

## When to use

Any deliverable that leaves the organization as a document: internal reports for partners,
client proposals, budgets, technical analyses, dossiers, one-pagers.

Do **not** use it for slide decks, web pages, or anything the reader will scroll.

## Quick path

```bash
SKILL=~/.claude/skills/pdf-report
$SKILL/scripts/init.sh <ruta>/propuestas/<nombre> \
  --brand-dir <ruta-a-tus-imagenes-de-marca> --people person-1,person-2
cd <ruta>/propuestas/<nombre>
# edit informe.html, then:
node render.mjs
```

`init.sh` copies the template, both scripts and a DESIGN.md, then builds
`assets/brand.css` (fonts, logos, portraits, 40 Lucide icons, all base64) and installs
Playwright. The brand directory is a parameter: it holds `logo.png`, `banner.png` and one
`<name>.jpg` per portrait, and nothing about it is baked into this skill. The HTML is self-contained afterwards: no network at print time.

Then iterate: edit `informe.html`, run `node render.mjs`, read the guards, fix, repeat.

## The three rules

1. **Never edit the `<style>` block.** It is the design system, extracted from a
   validated document. Structure goes in the body; if you need a new component, add it
   to `references/components.md` first so the next document inherits it.
2. **Every guard must read `none` before you ship.** They are in `render.mjs` and they
   catch what reviewing thumbnails does not. Details in `references/guards.md`.
3. **Verify on the rendered PDF, not the preview.** `pdftoppm -f N -l N -r 130 -png
   out.pdf /tmp/check` then read the image. The browser preview and a PDF viewer do not
   always agree.

## Writing for readers who will not read

The audience is technical and impatient. Structure carries more than prose.

- **Lead with the answer.** Every section opens with an `.answer` block stating the
  conclusion. The reasoning comes after, for whoever wants it.
- **Fixed shapes beat free prose.** Module cards always run Qué hace / Esfuerzo / La
  trampa / Decisión, in that order, so three of them can be compared diagonally.
- **Tables over paragraphs** whenever the content has more than one dimension.
- **One idea per block.** If a panel needs three paragraphs, it is two panels.
- **Numbers carry their method.** Every estimate states its basis somewhere in the doc.

Copy rules: no em dashes, no marketing verbs (potenciar, impulsar, revolucionar), no
adjectives doing the work of evidence. Spanish copy is **neutral Spanish, tuteo** with
no voseo, per the global rules.

## Page budget

One page is one argument. If a page holds two, split it; if it holds half, merge it or
give it real content. Add `class="dense"` to a `.page` that carries a long table plus
panels: it tightens spacing without touching hierarchy or colour.

Never solve an overflow by trimming words. Reflow rarely removes a line. Use `dense`,
or move content to another page.

## Figures and sources

The template is built for documents that carry data, so the layout assumes numbers are
present: figure blocks, total rows and meters all exist in the catalogue. Whatever the
subject, **every figure states where it comes from**. Put the basis in the document —
a method note, a source line, a footnote — rather than leaving a number unattributed.

Do not invent values to fill a component. If a figure is not available, remove the block
or mark it as pending; a placeholder that looks like data is worse than an empty slot.

## References

| File | Read it when |
| --- | --- |
| `references/components.md` | Building any page: the copy-paste catalogue |
| `references/guards.md` | A guard fires and you need to know what it means |
| `references/DESIGN.template.md` | Starting a project (init.sh copies it for you) |

## Known traps

These cost real debugging time. They are already handled in the template; do not
undo them.

- **Google Fonts subsets.** Taking only the first `woff2` from the CSS API drops
  accents, ñ and €. `build-assets.py` embeds every subset with its `unicode-range`.
- **`strong` on dark surfaces.** A global `strong { color: var(--ink) }` makes bold
  text vanish on `.panel-ink` and `.answer`. The override is in the stylesheet.
- **Variant specificity.** `.gantt .bar` (0,2,0) beats `.b-ghost` (0,1,0). Declare bar
  variants at the same specificity as the base.
- **Portraits.** The circle is baked into the PNG, not applied with `border-radius` +
  `cover`: some PDF viewers resolve that clip wrong and show the sitter's chest.
- **Gradients and the contrast guard.** Gradients are `background-image` and cannot be
  read from the tree. `.cover` and `.closing` declare their lightest stop via `data-bg`.
  Over the brand gradient, small white text needs at least 75% opacity to pass AA.
