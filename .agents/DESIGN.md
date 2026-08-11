# DESIGN.md — dotfiles

Design system for the visible surfaces in this repository. Today that means one
surface: the tmux status bar. Terminal UI, not web UI, so the constraints are
different and stricter.

## 1. Intent & North Star

**Instrumentation you read at a glance, never a dashboard you study.**

The status bar sits above every window all day. It must answer "is anything
wrong?" in peripheral vision, without ever competing with the terminal content
below it. Colour encodes *which metric*, not decoration.

Anti-references:
- Powerline arrow separators. They require patched Nerd Font glyphs, break in
  any unpatched terminal, and add three characters of chrome per segment.
- Live sparklines, animated bars, gradients. tmux repaints by polling; anything
  that implies continuity is lying about its own refresh rate.
- Emoji as metric icons. They render at inconsistent widths and misalign the row.

## 2. Tokens

### Colour — Kanagawa (matches the configured theme)

The theme is the source of truth. No invented palette.

| Role | Kanagawa | Hex | 256 | Contrast vs ink |
| --- | --- | --- | --- | --- |
| CPU | crystalBlue | `#7E9CD8` | 110 | 7.4:1 |
| GPU | oniViolet | `#957FB8` | 140 | 5.6:1 |
| RAM | springGreen | `#98BB6C` | 108 | 9.1:1 |
| Time | carpYellow | `#E6C384` | 179 | 11.6:1 |
| Date | sakuraPink | `#D27E99` | 174 | 7.1:1 |
| Segment text | sumiInk | `#1F1F28` | 235 | — |
| Alert | autumnRed | `#C34043` | 167 | 4.9:1 |

**Rule: every segment is a saturated background with `sumiInk` text.** Light text
on saturated mid-tones is where terminal bars usually fail contrast. All ratios
above are computed against `#1F1F28` and clear 4.5:1.

**Rule: the bar itself has no background.** `status-style bg=default` inherits
the terminal's own background, so Ghostty's `background-opacity` and blur show
through. The coloured blocks are the only painted surface; everything else is
the terminal. Bar text is `fujiWhite` (223), active window `springGreen` (108),
inactive windows muted grey (245).

Threshold colouring is reserved for *values*, never for chrome: a metric turns
`autumnRed` only when it actually crosses its alert threshold.

### Typography

The terminal's font, one cell per character. The only levers available are
**weight** (`bold`) and **case**.

- Metric labels: uppercase, ≤3 characters (`CPU`, `GPU`, `RAM`). Uppercase is
  permitted here precisely because these are labels, not prose.
- Values: bold. The number is the payload; the label is the key.

### Spacing

- One padding space inside each segment: `| CPU 32% |` renders as `␣CPU 32%␣`.
- One unstyled space between segments. That gap is the separator; no glyph does
  that job.
- No trailing space at the row's end.

## 3. Layout Primitives

Single row, two anchors:

- **Left**: session and window list (owned by the kanagawa theme).
- **Right**: metric segments, ordered by volatility — fastest-changing leftmost,
  so the eye lands on movement first: `CPU · GPU · RAM · time · date`.

Width budget: the right side must stay under 60 columns so it never collides
with the window list on a split screen.

## 4. Component Patterns

### Metric segment

- **Purpose**: one measurement, readable without focus.
- **Anatomy**: `#[fg=ink,bg=<role>,bold]␣LABEL VALUE␣#[default]`
- **States**: normal (role colour) · alert (`autumnRed` when over threshold).
- **Accessibility**: never encode meaning in colour alone. The label and the
  numeric value carry the information; colour only speeds up locating it.

## 5. Motion System

**None, deliberately.** tmux repaints on `status-interval` polling. Any
animation would be a stroboscopic artefact of the polling rate, not motion
design. There is nothing here to ease.

## 6. Accessibility Baselines

- Contrast ≥4.5:1 for every segment, verified numerically, not by eye.
- Information never carried by colour alone (colour blindness, monochrome
  terminals, screenshots).
- Degrades correctly: no glyph outside plain ASCII, so the bar stays intact in
  any terminal without a patched font.

## 7. Anti-patterns (banned in this project)

- **Powerline separators** — require patched fonts; break silently elsewhere.
- **Any status command over 100ms** — it runs forever, on every refresh. The
  kanagawa `cpu_info.sh` cost 5064ms because it slept to sample a delta.
- **Duplicated metrics** — two sources rendering CPU is how they drift apart.
- **Emoji or Nerd Font icons as labels** — inconsistent widths misalign the row.
- **Colour as the only signal** — always paired with a label and a value.
- **An opaque band behind the bar** — it would cover the terminal's own
  background and defeat its transparency and blur.

## 8. Decision Log

### 2026-08-11 — Segment bar for CPU / GPU / RAM / time / date
Solid colour blocks separated by a space, per the reference the maintainer
supplied. Colours taken from Kanagawa so the bar belongs to the configured
theme instead of introducing a second palette.

### 2026-08-11 — GPU read via `ioreg`, not `powermetrics`
`powermetrics` requires superuser and cannot run from a status hook.
`ioreg -r -d 1 -w 0 -c AGXAccelerator` exposes `Device Utilization %`
unprivileged in ~20ms.

### 2026-08-11 — nano as the file editor, so `Ctrl+X` closes
Files opened from the sidebar use nano, not `$EDITOR`. The requirement was
closing a file with `Ctrl+X`, which is nano's own Exit key — no invented
shortcut sits in between. nano also asks "Save modified buffer?" on unsaved
changes, so the safety property comes from the editor rather than being added
on top. `FILE_EDITOR` overrides it.

`$EDITOR` is ignored here on purpose: it is `nvim`, which needs `:q`.

**macOS note:** `/usr/bin/nano` is Apple's PICO build and tmux reports the
process as `pico`. Anything matching on the editor name must accept both.

### 2026-08-11 — Clickable `[FILES]` button in the status bar
Added because the keyboard route proved fragile on this machine (dead keys plus
`macos-option-as-alt` behaviour). A mouse target depends on neither.

It shows **no open/closed state**, deliberately: the state is already visible,
since the panel is either on screen or it is not. A second indicator would be
noise and would desynchronise the moment yazi is closed with `q`.

Rendered as bracketed text, never as a solid block — in this bar solid blocks
mean measurements, so a control has to read differently. Clicking anywhere else
on the bar keeps tmux's default window selection.

### 2026-08-11 — `allow-passthrough on` for yazi
yazi sends DA1/DSR probes at startup to detect terminal capabilities. With
passthrough off, tmux swallowed them and yazi waited out its full timeout,
printing "Terminal response timeout" over the panel for seconds before drawing.
Enabling passthrough lets the probes reach Ghostty.

### 2026-08-11 — Sidebar moved off `M-e` (dead-key collision)
`Alt+e` never reached tmux on a "Spanish - ISO" layout: `Option+E` is the dead
key for the acute accent, so macOS consumes it to compose `á`/`é`. The binding
was correct and the script worked; the keystroke simply never arrived.

Now bound twice: `M-t` (single press, no dead-key collision — those are `e`,
`i`, `u`, `n`) and `prefix` + `e` (never touches `Option`, so it is independent
of layout and of `macos-option-as-alt`). Supersedes the `M-e` binding.

**Rule for this project: never bind `Option` + `e`/`i`/`u`/`n`.**

### 2026-08-11 — Transparent bar (`status-style bg=default`)
The bar was rendering on a green band. That green is *tmux's own default*
(`bg=green,fg=black`); the kanagawa theme never assigns `status-style`, so
nothing was overriding it. Set to `bg=default` so the bar inherits the
terminal background and Ghostty's opacity and blur survive.

Related finding, not acted on: kanagawa emits its `status-left` with empty
colour fields (`#[fg=]`, `#[bg=]`), so its theme is not resolving. The window
list is styled explicitly here instead of relying on it.

### 2026-08-11 — CPU from load average, not sampled utilisation
Sampling utilisation needs two readings separated by a sleep. That is exactly
what made the previous implementation cost seconds per refresh. Load average is
a single instantaneous read. Supersedes nothing; it is the founding constraint.
