# Layout guards

`render.mjs` runs five checks before writing the PDF. All five must read `none`.
They exist because reviewing thumbnails misses exactly these failures.

```
ICONS: all resolved
OVERFLOW: none
SPARSE (>150px dead space): none
ORPHAN BLOCKS: none
LOW CONTRAST: none
rendered 16 pages -> informe.pdf
```

## ICONS

An `.ico-*` class used in the HTML with no rule in `brand.css`. It renders as an empty
box: invisible in a thumbnail, obvious in print.

**Fix:** typo in the icon name, or the icon is not in the `ICONS` list. Add it to
`build-assets.py` and rebuild `brand.css`.

## OVERFLOW

Content taller than its A4 box. Reports `by` in pixels.

**Fix, in order:**
1. Add `class="dense"` to the page. Usually enough for under 100px.
2. Move a block to the next page.
3. Cut a whole block, not words.

Do **not** trim sentences. Reflow rarely removes a line, so you lose meaning and keep
the overflow. Under 30px, `dense` always solves it.

## SPARSE

More than 150px of dead space between the last block and the footer. The page looks
unfinished.

**Fix:** add content that earns its place, merge with an adjacent page, or relax the
typography globally. A closing or cover page is exempt (the guard skips them): air is
intentional there.

If several pages are sparse at once, the document is over-paginated. Relax body size and
spacing instead of padding with filler.

## ORPHAN BLOCKS

A short trailing block (under 40px) after a big one, with a gap. A stranded paragraph.

**Fix:** merge it into the block above, or give it enough substance to stand alone.

## LOW CONTRAST

Computed WCAG ratio below 4.5:1 for body text (3:1 for large). Walks up the tree for the
first opaque background.

**Fix:** darken the background or lighten the text. Two recurring causes:

- **`strong` inheriting the ink colour on a dark surface.** The stylesheet overrides it
  for `.panel-ink`, `.answer`, `.closing` and `.cover`. A new dark component needs
  adding to that selector list.
- **Variant losing on specificity.** `.gantt .bar` (0,2,0) beats `.b-ghost` (0,1,0), so
  the bar keeps white text on a light background. Declare variants at the same
  specificity as the base.

### Gradients

Gradients are `background-image` and cannot be read from the tree, so the guard would
report false positives. `.cover` and `.closing` carry `data-bg="#A03349"`, the lightest
stop, and the guard measures against that worst case.

**Any new element on a gradient needs `data-bg`.** Over the brand gradient small white
text needs at least 75% opacity: `rgba(255,255,255,.5)` and `.6` both fail.

## Verifying the real PDF

The guards run on the DOM. Some failures only appear in the exported PDF, because a
viewer resolved a clip or a transform differently.

```bash
pdftoppm -f 16 -l 16 -r 130 -png informe.pdf /tmp/check
```

Then read `/tmp/check-16.png`. Do this at least once per document, on the pages carrying
images or clipping.
