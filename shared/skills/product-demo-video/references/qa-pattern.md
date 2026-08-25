# QA pattern — visual verification with extracted frames

## The problem

`npx hyperframes lint` and `npx hyperframes validate` can both pass with ZERO errors while the rendered video shows blank scenes or wildly broken layouts. This bit V3 (full pipeline lint-clean, scenes 1 and 2 rendered black) and would have bit V4-V8 too if not for the QA loop.

`npx hyperframes preview` exposes a Studio SPA that does NOT serve the composition at a stable URL — Playwright can't drive it cross-origin.

`npx hyperframes snapshot` renders all clips stacked without applying the timeline — also useless for visual QA.

The ONLY reliable QA is: render the MP4, extract frames with ffmpeg at key timestamps, and Read them in the agent loop.

## QA loop

```bash
# 1. Render
npx hyperframes render --output outputs/<file>.mp4

# 2. Copy to project-level outputs (for the user)
cp outputs/<file>.mp4 ../outputs/

# 3. Extract frames at scene midpoints + transition moments
mkdir -p review
for t in 3 11 17 21 28 32 35 40 50 53 60 72; do
  ffmpeg -y -ss $t -i outputs/<file>.mp4 -frames:v 1 -q:v 3 review/frame_${t}s.jpg
done
```

Then Read each frame:

```
Read /path/to/review/frame_3s.jpg
Read /path/to/review/frame_11s.jpg
...
```

## Timestamps to check (V8 scene layout)

| Timestamp | Scene | What to verify |
|---|---|---|
| 3s | 1 Hook | Headline visible, chips visible, particles, NO text clipping at edges |
| 11s | 2 Product | Logo centered with glow, wordmark visible, trust chips |
| 17s | 3 Dashboard | Top bar with logo, captured screenshot, bottom-right callout, progress line |
| 21s | 3 Dashboard | Cursor visible on target (zoomed in) |
| 28s | 4 Knowledge | Sub-shot crossfade in progress, zoom visible |
| 32s | 4 Knowledge | Success toast "Carpeta creada" visible top-right |
| 35s | 5 Agent | Modal zoomed with highlight on key field |
| 40s | 5 Agent | Stat chips visible at bottom |
| 50s | 6 Chat | User bubble + bot response (mid-stream) |
| 53s | 6 Chat | Metric strip visible at end of bot answer |
| 60s | 7 Channels | Split layout with channel chips at top |
| 72s | 8 Outro | Logo big with glow, tagline, CTA, URL typewriter |

## What to look for in each frame

### Layout issues
- [ ] Any text running off the right edge of the canvas
- [ ] Two text blocks overlapping (titles colliding, body covering label)
- [ ] Glass cards with content overflowing past their border
- [ ] Cursor visible but in wrong position (not over the click target)
- [ ] Top bar text breaking onto multiple lines

### Animation issues
- [ ] Element visible at scene start that should still be animating in (means `gsap.from` started from current state, see hyperframes-patterns.md rule 12)
- [ ] Element invisible at the moment it should be the hero (means scene duration extension tween is missing, rule 2)
- [ ] Zoom-to-click shows void/black on one edge of the wrap (clamping issue, see zoom-to-click.md)

### Content issues
- [ ] Wrong text (typos, outdated copy, leftover placeholder)
- [ ] Wrong URL in outro typewriter (V7 → V8 lesson)
- [ ] Stale stat chips that shouldn't be there ("+12 ayuntamientos" without verification — V8 lesson)
- [ ] Screenshot showing test/staging artifacts (e.g. "QA Test Folder" leftover from previous capture runs)

### Brand issues
- [ ] Color drift (green not matching #11A83F / #2ADC71 across scenes)
- [ ] Logo broken / missing alt text showing
- [ ] Font fallback active (text in Times New Roman or system default instead of Inter)
- [ ] Inconsistent typography sizes across same-role elements

## When to fix vs ship

| Severity | Action |
|---|---|
| Blank scene, missing critical text | FIX immediately, re-render |
| Text overlap, off-canvas text | FIX immediately, re-render |
| Cursor in slightly-wrong position | Fix if time permits, otherwise ship — note in delivery |
| Stat chip with unverified data | FIX immediately (V8 "+12 ayuntamientos" lesson) |
| Color drift < 5% between scenes | Ship — re-render not worth it for tiny drift |

## Render budget per iteration

A full render is ~30s at 1920x1080@30fps. Budget 2-3 renders per iteration max:
1. First render after building the iteration
2. Re-render after fixing issues found in QA loop
3. Optional final render after user feedback

If the agent finds 5+ issues in the first QA pass, that's a sign the work was rushed — fix multiple issues, then re-render ONCE.

## Audio QA (after visual is clean)

```bash
# Overall levels
ffmpeg -i outputs/<file>.mp4 -af "volumedetect" -vn -sn -f null /dev/null 2>&1 | grep -E "mean|max"

# Per-segment (sampled)
ffmpeg -i outputs/<file>.mp4 \
  -af "astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level" \
  -vn -f null /dev/null 2>&1 | grep RMS | awk 'NR%30==0' | head -10
```

See [audio-mixing.md](audio-mixing.md) for target levels.

## Delivery checklist

Before saying "done":
- [ ] Visual QA passed (every key frame Read'd and approved by you)
- [ ] Audio levels in target range
- [ ] MP4 copied to project-level `outputs/`
- [ ] Engram memory saved with `topic_key: <product>/demo-video-v<N>`
- [ ] Final report includes: file path, size, duration, audio levels, visual diff vs previous version, any known issues
- [ ] One-line CTA for the user: "Reprodúcelo y dime"
