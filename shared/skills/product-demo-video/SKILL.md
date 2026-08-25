---
name: product-demo-video
description: Build professional 60-90s product demo videos for any SaaS product using HyperFrames (HTML+GSAP). Pipeline includes TTS narration, live Playwright captures of the authenticated app, Ken Burns zoom-to-click motion, success toasts, Lucide icons, optional synthesized music, and full validation. Use when the user asks to "create a demo video", "make a video for X product", "grabar una demo del producto", or "iterate the video".
---

# Product Demo Video — Skill

This skill encodes a full E2E pipeline distilled over many iterations of a real demo video, from a crude first pass to a production-grade cut. It is a repeatable way to build a 60-90s product demo video for any SaaS product.

The output is a 1920x1080 H.264 MP4 of ~75 seconds, designed for commercial pitches, internal onboarding, and product validation.

## Quick-start workflow

1. **Confirm scope with the user.** Always ask FOUR questions before writing code (see [references/discovery.md](references/discovery.md) for the exact question set).
2. **Storyboard first, code second.** Write the 8-scene storyboard in a markdown block and get user approval BEFORE building. Reuse the structure from [references/storyboard-template.md](references/storyboard-template.md).
3. **Scaffold the HyperFrames project** in `<project-root>/demo-video/vN/` where `N` is the iteration number. Use `npx hyperframes init` then move files up one level.
4. **Generate narration** via edge-tts (Spanish, voice `es-ES-AlvaroNeural`, rate `-4%`). See [templates/synth_voice.py](templates/synth_voice.py).
5. **Capture the live app** via Playwright authenticated session. Ask the user for credentials during discovery and pass them through the environment — never hardcode them. See [references/playwright-capture.md](references/playwright-capture.md).
6. **Build the composition** scene-by-scene following [references/hyperframes-patterns.md](references/hyperframes-patterns.md) hard rules — CSS scoping, sub-comp timeline duration extension, no `repeat: -1`, etc.
7. **Use Ken Burns zoom-to-click** for click events, NOT green border highlight boxes. See [references/zoom-to-click.md](references/zoom-to-click.md).
8. **Music is optional.** If the user wants music, synthesize a rock onboarding track with numpy (template included) or leave voice-only. Default to voice-only unless asked.
9. **Validate**: `npx hyperframes lint` (0 errors), `npx hyperframes validate --no-contrast` (no console errors), then render.
10. **Verify visually**: extract frames with ffmpeg at key timestamps and Read them yourself. `npx hyperframes snapshot` and `preview` do NOT work for this pipeline — see [references/qa-pattern.md](references/qa-pattern.md).

## Versioning convention

Each iteration gets its own folder: `v3/`, `v4/`, `v5/`, etc. Bootstrap each new version from the previous one (`cp -R vN v(N+1) && rm -rf v(N+1)/{outputs,node_modules,.venv}/*`) so older versions remain reproducible. Final MP4 of each version goes in BOTH `vN/outputs/` and the project root `outputs/`.

## Skill dependencies

This skill REQUIRES the `hyperframes` skill (from heygen-com) to be installed in the project. Install with:

```bash
cd <project>
npx skills add heygen-com/hyperframes
```

The `hyperframes` skill provides the framework knowledge (data attributes, GSAP patterns, composition structure, references library). This skill (`product-demo-video`) sits ON TOP of it with the demo-specific patterns: brand tokens, storyboard structure, live-capture pipeline, zoom-to-click motion, music synthesis, audio mixing rules.

## Brand

See [references/brand.md](references/brand.md) for the full token system. Its colour values
are **placeholders** — replace them with the product's brand before building. TL;DR:
- Semantic tokens: `--brand`, `--brand-2`, `--brand-glow`, `--ink`, `--ink-2`, `--text`, `--muted`
- Typography: Inter (built-in to HyperFrames). Headlines 130-160px, scene titles 64-80px, body 28-32px.
- Logo: use the icon-only transparent variant for animations. Ask the user where the brand assets live.

NOTE: live app captures may use a DIFFERENT runtime palette than the video chrome. That contrast is INTENTIONAL. Don't try to recolor live captures.

## Architecture — what each piece does

| Layer | Responsibility | Tool |
| --- | --- | --- |
| Storyboard | Narrative arc, scene timings, callouts | Markdown + user approval |
| Narration | Per-scene voice WAVs in Spanish | `edge-tts` (Python) |
| Audio mix | Concatenate voice with silence padding to scene starts | `ffmpeg` |
| Music (optional) | Rock onboarding bed at -22dB below voice | `numpy` synthesis OR voice-only |
| Live captures | Authenticated screenshots of the real product | `playwright` (Node) |
| Visual composition | 8 scenes with GSAP timelines | `hyperframes` (HTML+CSS+JS) |
| Cursor motion | Synthetic SVG pointer with bezier easing | GSAP inline |
| Click highlight | Ken Burns zoom-to-click 1.6x with cursor + ripple | GSAP transform + CSS |
| Render | 30fps 1920x1080 H.264 + AAC | `npx hyperframes render` |
| QA | Frame extraction + visual review by the assistant | `ffmpeg` + Read tool |

## Hard rules (learned the hard way — DO NOT violate)

1. **CSS scoping in sub-compositions**: every selector MUST be prefixed with `[data-composition-id="X"]` (e.g. `[data-composition-id="scene-3-dashboard"] .callout-title`). Bare class selectors silently fail because the bundler can't match them. The `#scene-X .class` form (with space) also works but is less robust. NEVER use `#scene-X.class` without the space — that means "element with id AND class on same element" and matches nothing.
2. **Sub-comp timeline duration**: every sub-composition's GSAP timeline MUST end with a no-op tween extending its duration to match the host's `data-duration`:
   ```js
   tl.to({}, { duration: SCENE_DURATION }, 0);
   ```
   Without this, the runtime hides the clip when `currentTime > inner_timeline.duration()`. SKILL.md from hyperframes discourages empty tweens, but this is a documented runtime requirement.
3. **Class `clip` is mandatory** on every timed element.
4. **Timelines paused at construction**: `gsap.timeline({ paused: true })` and registered on `window.__timelines[id]`.
5. **Determinism**: NO `Math.random()`, NO `Date.now()`. Use a mulberry32 seeded PRNG for any pseudo-random visual effect (particles, jitter, etc).
6. **No infinite repeats**: `repeat: -1` breaks the capture engine. Calculate finite repeats from duration.
7. **No exit animations except scene 8**. The transition handles the cut. Outgoing scene content MUST be fully visible at the moment the transition starts.
8. **Synchronous timeline construction**. No `async`, `setTimeout`, `Promise`. The capture engine reads `window.__timelines` synchronously after page load.
9. **No `<br>` in long text**. Use `max-width` for wrapping. `<br>` causes overlap with naturally-wrapped text.
10. **Sub-compositions use `<template>` wrapper**; root `index.html` does NOT.
11. **Lint pass ≠ visuals working**. Always extract frames from the rendered MP4 and verify with the Read tool. `npx hyperframes preview` and `npx hyperframes snapshot` do NOT show a working preview for this pipeline.

## Files in this skill

- [references/discovery.md](references/discovery.md) — the 4 questions to ask the user before starting
- [references/storyboard-template.md](references/storyboard-template.md) — 8-scene arc (Hook → Product → 5 flow scenes → Outro)
- [references/pipeline.md](references/pipeline.md) — full E2E pipeline diagram + commands
- [references/playwright-capture.md](references/playwright-capture.md) — authentication + capture for the live app
- [references/hyperframes-patterns.md](references/hyperframes-patterns.md) — CSS scoping, sub-comp timelines, gotchas
- [references/zoom-to-click.md](references/zoom-to-click.md) — Ken Burns motion with cursor + ripple
- [references/music-synthesis.md](references/music-synthesis.md) — numpy rock onboarding pattern
- [references/audio-mixing.md](references/audio-mixing.md) — voice/music balance, data-volume tuning
- [references/qa-pattern.md](references/qa-pattern.md) — frame extraction + Read-based visual QA
- [references/brand.md](references/brand.md) — colors, typography, logos
- [templates/synth_voice.py](templates/synth_voice.py) — edge-tts narration generator
- [templates/build_music_rock.py](templates/build_music_rock.py) — numpy rock track generator
- [templates/build_audio.py](templates/build_audio.py) — narration concatenator
- [templates/capture_live.mjs](templates/capture_live.mjs) — Playwright capture template
- [templates/index-template.html](templates/index-template.html) — root composition scaffold
- [templates/scene-template.html](templates/scene-template.html) — blank scene scaffold

## Keeping a working reference

Keep the most recent finished version of a video around as the canonical working example —
it is far easier to copy a composition that renders than to rebuild one from the rules.
The versioning convention above exists for exactly this reason.

## When NOT to use this skill

- Marketing reels or social-first 9:16 vertical videos (different aspect ratio, different storyboard). Ask the user first.
- 2-3 minute extended onboarding tutorials (this is for 60-90s).
- Static screenshots, infographics, or non-video deliverables.
- Customer-facing branded content where a third party is the brand. Swap the palette in `references/brand.md` before building anything that carries someone else's identity.
