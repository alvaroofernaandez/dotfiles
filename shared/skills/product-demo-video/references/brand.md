# Demo-video brand tokens

**The values below are placeholders. Replace them with your own brand before building.**
What matters here is the token *system* — which role each colour plays and the rules that
keep the video coherent — not the specific hexes, which are deliberately neutral.

Note: this is the brand for the DEMO VIDEO, not necessarily the product's runtime palette.
It is common for the captured app to use a completely different palette. That contrast is
intentional: the video chrome is a wrapper around whatever colour the product shows.

## Palette

```css
:root {
  --ink:        #0B0F14;   /* deepest background */
  --ink-2:      #131A22;   /* panel background */
  --brand:      #3B82F6;   /* primary brand — REPLACE */
  --brand-2:    #60A5FA;   /* accent: hero stats, glows, success toasts — REPLACE */
  --brand-glow: rgba(96, 165, 250, 0.35);  /* glow shadows — match --brand-2 */
  --text:       #F5F7FA;   /* default text */
  --muted:      #C3CCD6;   /* secondary text, subtitles */
  --glass-bg:   rgba(11, 15, 20, 0.78);  /* callout cards, top bar */
  --glass-border: rgba(96, 165, 250, 0.35);
}
```

Swapping brand: change `--brand`, `--brand-2` and derive `--brand-glow` from `--brand-2`
at 35% alpha. Re-tint `--ink`/`--ink-2` toward the new hue if the brand is far from blue,
and keep `--glass-border` in step with `--brand-2`.

## Usage rules

- `--brand` for primary accents (overline text, scene indicators, chrome)
- `--brand-2` for hero moments (the headline stat, success toasts, CTA underlines)
- `--brand-glow` for shadows (`box-shadow: 0 0 32px var(--brand-glow)`)
- `--ink` for the canvas background
- `--ink-2` for panels and glass surfaces (combined with backdrop-filter blur)
- `--text` and `--muted` for typography
- NEVER use pure white (`#fff`) — use `--text` which is slightly off-white
- NEVER use pure black for shadows — use ink-tinted darks

## Typography

Font: **Inter** (built into HyperFrames — declare it as `font-family: 'Inter', sans-serif` and the compiler embeds the right weights).

Weights:
- 400 — body text
- 600 — chips, subtitle accents
- 700 — scene titles, callout titles
- 800 — display hero stats

Sizes:
- Display hero (the headline stat): **130-160px**, weight 800
- Hero subtitle / scene 2 wordmark: 100-120px, weight 800
- Scene title (in callouts): **32-40px**, weight 700
- Body / callout body: **22-28px**, weight 400-500
- Chips / small caps: **20-24px**, weight 600, letter-spacing 0.3em
- Overline (small caps above hero): **20-24px**, weight 700, letter-spacing 0.3em

Numbers in stats should use `font-variant-numeric: tabular-nums` for clean alignment.

## Logos

Products typically ship three logo variants (often under `apps/web/public/` or a brand
folder). Ask the user which is which, and look for:
- horizontal lockup (icon + wordmark side-by-side, on a solid background)
- square stacked (icon above wordmark)
- **icon only, transparent background** ⭐ — best for animations

For demo videos, ALWAYS use the transparent icon-only variant. Render the wordmark as TEXT
(Inter weight 800) so it stays crisp at any size and animates per-letter.

Logo positions:
- Scene 2 (product reveal): icon ~250px, centered, with a brand-coloured drop-shadow glow
- Top bar of scenes 3-7: icon 38px height + product name text inline, left-aligned
- Scene 8 (outro): icon ~280px, centered, with finite gentle bob (±6px y)

## Glass surfaces

For top bar, callout cards, and toasts:

```css
.glass {
  background: var(--glass-bg);
  backdrop-filter: blur(20px);
  border: 1px solid var(--glass-border);
  border-radius: 16px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.3),
              0 0 32px var(--brand-glow);
}
```

## Corner radius

- Cards / glass surfaces: 16-20px
- Hero containers (shot-wrap, logo bg): 24px
- Chips / pills: 999px (full pill)
- Small badges / icon buttons: 8px

## Icons

Use Lucide-style inline SVG (24x24 viewBox, stroke 2, currentColor, no fill). Common ones used in V4-V8:

| Icon | Use |
|---|---|
| users | customer-pain overlines |
| calendar | event-related chips |
| flag | campaign/initiative chips |
| book-open | knowledge/content chips |
| layout-dashboard | dashboard scene callout |
| folder-tree | knowledge base / docs callout |
| sparkles | AI / agent scenes |
| target | highlighted field marker |
| crosshair | precision indicator |
| message-circle | conversation / chat callout |
| message-square | WhatsApp-like channels |
| send | Telegram-like channels / submit actions |
| globe | web channels |
| arrow-right | CTA chevron |
| check | success toasts |
| zap | speed/performance metrics |

Inline Lucide SVG template:

```html
<svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none"
     stroke="currentColor" stroke-width="2"
     stroke-linecap="round" stroke-linejoin="round">
  <!-- paste path d from lucide.dev -->
</svg>
```

## Cursor

Synthetic Mac-style pointer rendered as SVG, white fill + 1px black stroke + drop-shadow:

```html
<div class="cursor">
  <svg viewBox="0 0 24 24" width="24" height="24">
    <path d="M2 2 L2 18 L7 14 L10 22 L13 21 L10 13 L17 13 Z"
          fill="#FFFFFF" stroke="#000000" stroke-width="1"/>
  </svg>
</div>
```

Position via GSAP transforms; never via the OS cursor.

## Click ripple

```css
.click-ripple {
  width: 60px; height: 60px;
  border: 2px solid var(--brand-2);
  border-radius: 50%;
  background: radial-gradient(circle, var(--brand-glow) 0%, transparent 60%);
}
```

Animated with `gsap.fromTo({scale: 0, opacity: 0.7}, {scale: 1.8, opacity: 0, duration: 0.6})`. Single fire, finite repeat 0.

## Success toast

```css
.success-toast {
  position: absolute; top: 60px; right: 60px;
  display: flex; align-items: center; gap: 12px;
  padding: 14px 22px;
  background: var(--glass-bg);
  backdrop-filter: blur(20px);
  border: 1px solid var(--brand-2);
  border-radius: 12px;
  color: var(--brand-2);
  font-weight: 600; font-size: 22px;
  box-shadow: 0 0 24px var(--brand-glow);
}
.success-toast .icon { color: var(--brand-2); }
```

Animation: slide+fade from `{x: 60, opacity: 0}` → `{x: 0, opacity: 1}` over 0.4s, hold 1.5s, slide out `{x: 60, opacity: 0}` over 0.3s.

## Particles (background ambience for scenes 1 and 8)

20-30 deterministic particles, 4 size buckets (2px / 3px / 5px / 8px), drifting up slowly:

```js
const rng = mulberry32(42);
const COUNT = 28;
const particles = Array.from({length: COUNT}, (_, i) => ({
  x: rng() * 1920,
  y: rng() * 1080,
  size: [2, 3, 5, 8][Math.floor(rng() * 4)],
  speed: 8 + rng() * 14,  // px/s upward
  opacity: 0.15 + rng() * 0.35,
}));
```

Color: `var(--brand-2)` with `opacity` baked in. NO blur — keeps file size small.

## Anti-patterns (DO NOT)

- DO NOT use pure saturated primaries (`#00FF00`, `#FF0000`) — they look cheap. Use the
  brand tokens only.
- DO NOT mix in accents from outside the palette — a single accent family keeps the video
  cohesive.
- DO NOT use multiple distinct font families — one family only.
- DO NOT add unverified social-proof stats ("+50 clientes", "1M usuarios"). If the number
  cannot be substantiated, it does not go on screen.
- DO NOT animate every element — restrain motion to meaningful moments.
