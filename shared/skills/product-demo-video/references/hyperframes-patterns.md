# HyperFrames patterns — gotchas learned over V2-V8

These are NON-NEGOTIABLE rules distilled from 8 iterations. Violating any one of them produces silently-broken output (lint passes, render produces empty frames or stuck animations).

## 1. CSS scoping (the BIG one)

Every selector inside a sub-composition's `<style>` MUST be prefixed with `[data-composition-id="X"]`:

```css
/* ✅ CORRECT */
[data-composition-id="scene-3-dashboard"] .callout-title { font-size: 32px; }
[data-composition-id="scene-3-dashboard"] .shot-wrap img { transform-origin: top left; }

/* ❌ WRONG — bare classes silently fail */
.callout-title { font-size: 32px; }

/* ❌ WORST — id + class concatenated (no space) means "element with BOTH" — matches nothing */
#scene-3-dashboard.callout-title { ... }
```

Why: the HyperFrames bundler runs `scopeCssToComposition` which expects the attribute prefix. Bare classes match the global document fragment, which doesn't include the sub-comp content.

There's also the `#scene-3-dashboard .class` form (id selector + space). It works but triggers a lint warning (`composition_self_attribute_selector`) recommending the attribute form. Use the attribute form.

## 2. Sub-composition timeline duration

Every sub-comp's GSAP timeline MUST end with a no-op tween extending its duration to match the host's `data-duration`:

```js
const SCENE_DURATION = 8.5;
const tl = gsap.timeline({ paused: true });
// ... your real tweens ...
tl.to({}, { duration: SCENE_DURATION }, 0);  // <-- mandatory
window.__timelines["scene-3-dashboard"] = tl;
```

Why: the runtime hides the clip when `currentTime > inner_timeline.duration()`, EVEN if the host's `data-duration` is longer. Without this no-op, scene 3's content disappears at ~3s even though its host is 8.5s wide.

Yes, the upstream hyperframes SKILL.md discourages "empty tweens to set duration". This is a documented runtime workaround — measured behavior, not preference.

## 3. The `clip` class

Every timed element needs `class="clip"`:

```html
<div id="scene-3" data-composition-id="scene-3-dashboard"
     data-composition-src="compositions/scene-03-dashboard.html"
     data-start="14.5" data-duration="8.5" data-track-index="1"
     class="clip"></div>
```

Without `clip`, the framework can't hide/show the element on timeline ticks.

## 4. Determinism

NO `Math.random()`, NO `Date.now()`. Capture engine multi-passes the page; non-deterministic output produces frame jitter.

Use a seeded PRNG:

```js
function mulberry32(seed) {
  return function() {
    let t = seed += 0x6D2B79F5;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rng = mulberry32(42);
```

Use it for particle positions, jitter amounts, noise textures, etc.

## 5. No infinite repeats

`repeat: -1` on any tween breaks the render. Calculate a finite count from the scene duration:

```js
const cycleDuration = 1.6;
const repeats = Math.ceil(SCENE_DURATION / cycleDuration) - 1;
tl.to(".pulse", { scale: 1.1, duration: cycleDuration, repeat: repeats, yoyo: true }, 0);
```

## 6. No exits except scene 8

```js
// ❌ WRONG — empties the scene before its transition can use it
tl.to("#s3-title", { opacity: 0, duration: 0.5 }, 7.5);

// ✅ CORRECT — let the transition overlay handle the cut
// (just don't add any opacity:0 / y: offscreen tweens)
```

Scene 8 (outro) is the ONLY exception. It may fade to black at the end.

## 7. Synchronous timeline construction

```js
// ❌ WRONG
gsap.timeline().to(...);
await fetch('/api/data');
gsap.timeline().to(...);

// ❌ ALSO WRONG
setTimeout(() => gsap.timeline({paused: true}), 100);

// ✅ CORRECT
const tl = gsap.timeline({ paused: true });
tl.to(...);
window.__timelines[id] = tl;
```

The capture engine reads `window.__timelines` synchronously after page load.

## 8. No `<br>` in long text

```html
<!-- ❌ produces overlap when text wraps naturally -->
<p class="body">Lorem ipsum dolor sit amet <br/> consectetur adipiscing elit.</p>

<!-- ✅ let it wrap via max-width -->
<p class="body" style="max-width: 1200px">Lorem ipsum dolor sit amet consectetur adipiscing elit.</p>
```

Exception: short display titles where each word lives on its own line (e.g. hero stats split per-word).

## 9. Sub-comp `<template>` wrapper

Sub-compositions loaded via `data-composition-src` MUST be wrapped in a `<template>` block:

```html
<template id="scene-3-dashboard-template">
  <div data-composition-id="scene-3-dashboard" data-width="1920" data-height="1080">
    <!-- content -->
    <style>...</style>
    <script>...</script>
  </div>
</template>
```

Root `index.html` does NOT use `<template>`. It puts the composition div directly in `<body>`.

## 10. Layout before animation

Build the static end-state of every scene first (HTML+CSS for the "hero frame" of the scene), THEN add `gsap.from()` entrances. Skipping this step buries layout bugs that only show up after animation.

`.scene-content` containers MUST fill the scene with padding-based positioning, NOT `position: absolute; top: Npx`:

```css
/* ✅ CORRECT */
[data-composition-id="scene-3-dashboard"] .scene-content {
  width: 100%; height: 100%;
  display: flex; flex-direction: column;
  padding: 80px 100px; gap: 24px;
  box-sizing: border-box;
}

/* ❌ WRONG — overflows when content is taller than expected */
[data-composition-id="scene-3-dashboard"] .scene-content {
  position: absolute; top: 200px; left: 160px;
  width: 1920px; height: 1080px;
}
```

`position: absolute` is reserved for DECORATIVES (cursor overlay, success toast, particles), not content containers.

## 11. Lint pass ≠ visuals working

This bug bit me in V3 and V4. Lint reports 0 errors, render produces blank scenes. The CSS scoping rule (#1) is the most common cause but not the only one.

ALWAYS extract frames from the rendered MP4 with ffmpeg and Read them in the agent loop. `npx hyperframes preview` and `npx hyperframes snapshot` both fail for this pipeline (preview is an SPA shell, snapshot stacks clips without timeline).

```bash
for t in 3 11 17 21 28 35 40 50 60 72; do
  ffmpeg -y -ss $t -i outputs/<file>.mp4 -frames:v 1 -q:v 3 review/frame_${t}s.jpg
done
```

Read each frame. Look for: blank screens, text in wrong position, animations stuck at start state (opacity 0 visible), overflowing text, broken images.

## 12. `gsap.from` vs `gsap.fromTo` in sub-comps

Use `gsap.fromTo()` inside sub-compositions instead of `gsap.from()`. The hyperframes runtime may re-mount sub-comps on certain seek operations, and `gsap.from()` reads the CURRENT element state as the "to" value — which may be the post-animation state if the runtime already played the tween once.

```js
// ❌ FRAGILE in sub-comps
tl.from(".title", { y: 50, opacity: 0, duration: 0.7 }, 0.3);

// ✅ DETERMINISTIC
tl.fromTo(".title",
  { y: 50, opacity: 0 },
  { y: 0, opacity: 1, duration: 0.7, ease: "power3.out" },
  0.3
);
```

## Quick mental checklist before every render

- [ ] All CSS prefixed with `[data-composition-id="X"]`
- [ ] All timelines have `tl.to({}, { duration: SCENE_DURATION }, 0)` at the end
- [ ] All timed elements have `class="clip"`
- [ ] No `Math.random()`, no `Date.now()`
- [ ] No `repeat: -1`
- [ ] No exit animations except scene 8
- [ ] No `<br>` in long body text
- [ ] Sub-comps wrapped in `<template>`
- [ ] All entrances use `gsap.fromTo()`, not `gsap.from()`
- [ ] Lint passes, validate passes
- [ ] Extracted frames at 10+ timestamps, all look correct
