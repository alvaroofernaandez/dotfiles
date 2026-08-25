# Music synthesis — numpy rock onboarding pattern

The V6 rock track is generated entirely with numpy + deterministic seed. No samples, no external dependencies beyond Python + numpy + ffmpeg.

## Architecture

```
Drums kit (numpy):
  kick(t)       sine 110→48 Hz pitch sweep + noise click + exp envelope
  snare(t)      filtered noise + 210/340 Hz tones + exp envelope
  hihat(t)      high-passed noise + short envelope (open vs closed)
  crash(t)      filtered noise + long decay

Harmonic kit (numpy):
  power_chord(root, oct)   sawtooth root + 5th (1.4983x) across octaves, tanh soft-clip
  bass(root)               sawtooth + sub-sine, tanh warmth

Sequencer:
  124 BPM, 4/4
  Kick on beats 1,3
  Snare on beats 2,4
  Hihat on 8ths
  Open hihat accent every 4 bars
  Crash on bar 0 of each 8-bar block
  Power chord on each bar (Em-Em-C-C-G-G-D-D loop)
  Bass on each bar (same root)
  Snare flam on last beat of each 8-bar block
```

## Output characteristics

- 75 seconds, 124 BPM, 16 bars × 8-bar progression cycles
- Em → C → G → D (rock onboarding classic, builds energy)
- Stereo, 44.1 kHz, 16-bit PCM
- Peak: 0.92, RMS: ~0.20
- Fade-in 2.5s, fade-out 4s
- Deterministic seed (42) — re-runs produce bit-identical output

## Volume balance with voice

| Music style | Source RMS | Recommended `data-volume` | Resulting mix RMS |
|---|---|---|---|
| Ambient pad (V4-V5) | ~0.05 | `0.85` | ~-40 dB |
| Rock onboarding (V6) | ~0.20 | `0.38` | ~-22 dB |
| Voice-only (V7-V8) | — | (remove `<audio id="music">`) | n/a |

Voice baseline RMS is around -20 dB (peak -9 dB). For the music to feel PRESENT but not fight the voice:
- Mix RMS target: 6-10 dB below voice
- Mix peak target: stay below -3 dB to leave headroom

If you change the source loudness in the synthesizer, you MUST retune `data-volume` proportionally. A 6 dB jump in source RMS = halve the data-volume.

## When to use music vs voice-only

Use rock music for:
- Onboarding videos for energetic, self-serve products
- Internal demos / sales tools where energy = engagement
- Videos played in offices or expo booths where ambient noise competes

Use voice-only for:
- B2B technical demos for compliance-oriented or high-trust products
- Demos shared via email where the viewer is likely alone
- Content that gets transcribed or translated
- When the user explicitly asks (V7 reason)

## Tuning the rock pattern

To change MOOD without rewriting the synthesizer:

| Mood | BPM | Chord progression |
|---|---|---|
| Onboarding energetic (default) | 124 | Em-C-G-D |
| Epic anthem | 118 | Dm-Bb-F-C |
| Heavy / aggressive | 138 | Em-Em-D-D-C-C-B-B (single-bar pattern) |
| Chill rock / lo-fi | 95 | Am-F-C-G with kick on 1 only, hihat on 16ths |

Edit `BPM` constant and `CHORDS` list in `templates/build_music_rock.py`.

## Common pitfalls

### Music too quiet (V4 → V5 lesson)
Symptom: `ffmpeg astats` shows music-only RMS below -50 dB.
Fix: rebuild music source at higher base level (`volume=1.0` final, not `volume=0.35`) AND raise `data-volume` proportionally.

### Music too loud / drowns voice
Symptom: voice intelligibility drops; user complains can't hear narration.
Fix: drop `data-volume` by 30% (e.g. `0.38` → `0.27`) and re-render. Verify with ffmpeg astats: music-only RMS should be 6-10 dB below voice peak.

### Music clips
Symptom: `max_volume` from `ffmpeg volumedetect` reads `0.0 dB` or positive.
Fix: the source already soft-clips with `tanh` but if you raised the data-volume too high, the SUM with voice may clip. Drop data-volume.

### Music is "synthetic-sounding" / cheap
Limitation: numpy synthesis without samples will always sound electronic. If the user wants REAL rock guitars/drums, you need:
- A CC0 stock track (Pixabay Music, FreeSound, Bensound) — verify license per project.
- Or hire a composer / use Suno/Udio with rights cleared.

The synthesized track is GOOD ENOUGH for internal demos and quick iterations. For final customer-facing pieces, recommend stock.

## Template

[../templates/build_music_rock.py](../templates/build_music_rock.py) is the canonical V6 implementation. Re-run produces the exact same WAV thanks to the seed.
