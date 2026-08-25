# Zoom-to-click — Ken Burns motion for click events

Replaces the V2-V4 "green border highlight box" pattern. Instead of drawing attention to a UI region with a colored rectangle, the SCREENSHOT itself zooms and pans so the click area fills the safe zone.

## Why this is better

- Looks like real screen recording, not "tutorial software".
- Pushes detail forward; the viewer doesn't need to hunt for the highlighted area.
- Pairs naturally with the synthetic cursor — the cursor lands at the center of frame after the zoom.
- The zoom IS the highlight. No extra UI chrome competing with the captured product.

## Layout

```html
<div class="shot-wrap" style="overflow: hidden; position: relative; width: 1700px; height: 760px;">
  <img class="shot" src="../assets/captures-live/03_knowledge_new_menu.png" />
  <div class="cursor"><!-- SVG pointer --></div>
  <div class="click-ripple"></div>
</div>
```

CSS:

```css
[data-composition-id="scene-4-knowledge"] .shot-wrap {
  position: absolute; left: 110px; top: 140px;
  width: 1700px; height: 760px;
  overflow: hidden; border-radius: 16px;
  box-shadow: 0 0 32px rgba(42, 220, 113, 0.15);
}

[data-composition-id="scene-4-knowledge"] .shot {
  position: absolute; top: 0; left: 0;
  width: 1920px; height: 1080px;
  transform-origin: top left;
  will-change: transform;
}

[data-composition-id="scene-4-knowledge"] .cursor {
  position: absolute; z-index: 3;
  width: 24px; height: 24px;
  pointer-events: none;
  filter: drop-shadow(0 2px 6px rgba(0,0,0,0.4));
}

[data-composition-id="scene-4-knowledge"] .click-ripple {
  position: absolute; z-index: 2;
  width: 60px; height: 60px;
  border: 2px solid #2ADC71;
  border-radius: 50%;
  opacity: 0;
  transform: translate(-50%, -50%) scale(0);
  pointer-events: none;
}
```

Cursor SVG (Mac-style pointer):

```html
<div class="cursor">
  <svg viewBox="0 0 24 24" width="24" height="24">
    <path d="M2 2 L2 18 L7 14 L10 22 L13 21 L10 13 L17 13 Z"
          fill="#FFFFFF" stroke="#000000" stroke-width="1"/>
  </svg>
</div>
```

## Motion sequence per click event

Assume `clickX, clickY` are coordinates in the SOURCE image (the 1920x1080 capture). The wrap is 1700x760 centered visually but rendered as a viewport into the image.

```js
const wrapW = 1700, wrapH = 760;
const zoomScale = 1.6;
const clickX = 1620, clickY = 240;  // from cursor_targets.json

// Compute translation: place clickX,clickY at the center of the wrap
// After scale, the image has wrapW*zoomScale, wrapH*zoomScale; offset to center the click
const tx = -(clickX * zoomScale - wrapW / 2);
const ty = -(clickY * zoomScale - wrapH / 2);

// At T_zoom (e.g. 2.5s into scene), zoom in
tl.to(".shot", {
  scale: zoomScale,
  x: tx, y: ty,
  duration: 1.2,
  ease: "expo.inOut"
}, T_zoom);

// Cursor flies in to center of wrap (where the click target now sits)
tl.fromTo(".cursor",
  { x: wrapW + 100, y: 100, opacity: 0 },
  { x: wrapW / 2, y: wrapH / 2, opacity: 1, duration: 1.0, ease: "power2.inOut" },
  T_zoom + 0.2
);

// Click ripple fires at the cursor position, ~0.2s after cursor lands
tl.fromTo(".click-ripple",
  { x: wrapW / 2, y: wrapH / 2, opacity: 0.7, scale: 0 },
  { scale: 1.8, opacity: 0, duration: 0.6, ease: "power2.out" },
  T_zoom + 1.1
);

// Hold the zoomed view for 1.5-2.5s while the voice narrates
// Then either:
//   (a) zoom out smoothly back to scale 1:
tl.to(".shot",
  { scale: 1, x: 0, y: 0, duration: 0.8, ease: "expo.out" },
  T_zoom + 3.5
);
//   (b) OR crossfade to next sub-shot
```

## Crossfade between zoomed sub-shots

When clicking opens a modal, the new screenshot should appear ALREADY zoomed at the same focal point, then settle.

```js
// Hide old shot, reveal new shot at the same scale/position
tl.to(".shot-a", { opacity: 0, duration: 0.3 }, T_crossfade);
tl.fromTo(".shot-b",
  { opacity: 0, scale: 1.4, x: tx_b, y: ty_b },
  { opacity: 1, duration: 0.4 },
  T_crossfade
);
// Then settle to scale 1 over 0.6s
tl.to(".shot-b",
  { scale: 1, x: 0, y: 0, duration: 0.6, ease: "expo.out" },
  T_crossfade + 0.5
);
```

## Common bugs

### The zoomed image shows void on one side
Cause: `tx` or `ty` pushes the image too far. The wrap's right/bottom edge shows blank background.

Fix: clamp the translation so the zoomed image always covers the wrap:

```js
const maxTx = 0;
const minTx = wrapW - (1920 * zoomScale);
const tx = Math.max(minTx, Math.min(maxTx, -(clickX * zoomScale - wrapW / 2)));
```

Same for `ty`.

### Cursor floats outside the wrap
Cause: cursor's parent is the wrap (overflow: hidden), but the cursor's entry tween starts at `x: wrapW + 100` which is outside the wrap.

Fix: either move cursor to a parent above the wrap (z-index higher), OR set cursor `opacity: 0` until it's inside the wrap.

### Ripple appears at top-left, not where the cursor is
Cause: ripple uses `transform: translate(-50%, -50%)` but the tween sets `x, y` as pixel values, which compose with the translate.

Fix: position the ripple absolutely with `left, top` properties (not transforms) and tween `left, top`:

```js
tl.fromTo(".click-ripple",
  { left: wrapW / 2, top: wrapH / 2, opacity: 0.7, scale: 0 },
  { scale: 1.8, opacity: 0, duration: 0.6 },
  T_zoom + 1.1
);
```

Or use a wrapper div positioned absolutely and only tween scale + opacity on the inner ripple.

## When NOT to use zoom-to-click

- Scenes with split layout (e.g. V8 scene 7 channels) where two panels must stay visible.
- Scenes that are NOT showing a UI interaction (hook, product reveal, outro).
- When the click target is genuinely the whole screen (e.g. "click anywhere to start").

## Optional: highlight box for non-zoom scenarios

If you DO need a highlight without a zoom (rare — typically scenes with split layouts), use a subtle GREEN border with a target/crosshair icon at the corner:

```html
<div class="highlight-box">
  <svg class="highlight-target" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#2ADC71" stroke-width="2">
    <circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="3"/>
  </svg>
</div>
```

But the rule is: zoom > highlight box. Default to zoom.
