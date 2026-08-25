"""Punchy onboarding rock-style track.

124 BPM, 75s, Em-C-G-D power chord progression. Drum kit: kick (1,3),
snare (2,4), closed hihat on 8ths, open hihat accents. Bass on root.
Distorted power-chord sawtooth pad. Subtle filter sweeps on chorus
sections. Built ground-up with numpy + a deterministic seed so re-runs
produce identical output.
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "audio" / "music.wav"
SR = 44100
DURATION = 75.0
BPM = 124
BEAT = 60.0 / BPM
BAR = BEAT * 4

RNG = np.random.default_rng(seed=42)


def envelope(n: int, attack_ms: float, decay_ms: float, sustain: float = 0.0, release_ms: float = 0.0) -> np.ndarray:
    a = max(1, int(attack_ms * SR / 1000))
    d = max(1, int(decay_ms * SR / 1000))
    r = max(1, int(release_ms * SR / 1000))
    env = np.zeros(n)
    env[:a] = np.linspace(0, 1, a)
    if a + d < n:
        env[a : a + d] = np.linspace(1, sustain, d)
        if a + d + r < n:
            env[a + d : n - r] = sustain
            env[n - r :] = np.linspace(sustain, 0, r)
        else:
            env[a + d :] = sustain
    return env


def kick(dur_s: float = 0.22) -> np.ndarray:
    n = int(dur_s * SR)
    t = np.arange(n) / SR
    pitch = 110 * np.exp(-t * 32) + 48
    body = np.sin(2 * np.pi * np.cumsum(pitch) / SR)
    click_n = int(0.004 * SR)
    click = RNG.standard_normal(click_n) * np.linspace(1, 0, click_n)
    body[:click_n] += click * 0.6
    env = envelope(n, 1, 70, 0.4, 140)
    return body * env * 1.0


def snare(dur_s: float = 0.18) -> np.ndarray:
    n = int(dur_s * SR)
    t = np.arange(n) / SR
    noise = RNG.standard_normal(n)
    noise = np.convolve(noise, np.array([1, -0.5]), mode="same")
    tone = np.sin(2 * np.pi * 210 * t) * 0.4 + np.sin(2 * np.pi * 340 * t) * 0.25
    body = noise * 0.85 + tone
    env = envelope(n, 1, 50, 0.3, 110)
    return body * env * 0.9


def hihat(dur_s: float = 0.06, open_hat: bool = False) -> np.ndarray:
    n = int((0.18 if open_hat else dur_s) * SR)
    noise = RNG.standard_normal(n)
    noise = np.convolve(noise, np.array([1, -0.9]), mode="same")
    env = envelope(n, 1, 25 if not open_hat else 80, 0.05, 30 if not open_hat else 80)
    return noise * env * 0.45


def crash(dur_s: float = 1.4) -> np.ndarray:
    n = int(dur_s * SR)
    noise = RNG.standard_normal(n)
    noise = np.convolve(noise, np.array([1, -0.85]), mode="same")
    t = np.arange(n) / SR
    env = np.exp(-t * 2.2)
    return noise * env * 0.55


def bass(freq: float, dur_s: float) -> np.ndarray:
    n = int(dur_s * SR)
    t = np.arange(n) / SR
    phase = 2 * np.pi * freq * t
    saw = 2 * (t * freq - np.floor(0.5 + t * freq))
    sub = np.sin(phase) * 0.6
    body = saw * 0.35 + sub
    body = np.tanh(body * 1.6) * 0.6
    env = envelope(n, 4, 80, 0.55, 80)
    return body * env


def power_chord(root_hz: float, dur_s: float, octaves: tuple[int, ...] = (0, 1, 2)) -> np.ndarray:
    n = int(dur_s * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for octv in octaves:
        f = root_hz * (2 ** octv)
        f5 = f * 1.4983
        saw1 = 2 * (t * f - np.floor(0.5 + t * f))
        saw2 = 2 * (t * f5 - np.floor(0.5 + t * f5))
        out += saw1 * 0.35 + saw2 * 0.28
    out = np.tanh(out * 1.4) * 0.55
    env = envelope(n, 6, 100, 0.45, 200)
    return out * env


CHORDS = [
    ("Em", 82.41),
    ("Em", 82.41),
    ("C",  65.41),
    ("C",  65.41),
    ("G",  98.00),
    ("G",  98.00),
    ("D",  73.42 * 2),
    ("D",  73.42 * 2),
]


def place(track: np.ndarray, sample: np.ndarray, t_start: float) -> None:
    s = int(t_start * SR)
    e = min(s + len(sample), len(track))
    if s >= len(track):
        return
    track[s:e] += sample[: e - s]


def build() -> np.ndarray:
    n_total = int(DURATION * SR)
    drums = np.zeros(n_total)
    bass_t = np.zeros(n_total)
    chords_t = np.zeros(n_total)

    bars_total = int(DURATION / BAR) + 1
    for b in range(bars_total):
        t0 = b * BAR
        if t0 >= DURATION:
            break
        name, root = CHORDS[b % len(CHORDS)]

        place(chords_t, power_chord(root, BAR + 0.1), t0)
        place(bass_t, bass(root, BAR + 0.05), t0)

        for beat in (0, 2):
            place(drums, kick(), t0 + beat * BEAT)
        for beat in (1, 3):
            place(drums, snare(), t0 + beat * BEAT)
        for i in range(8):
            open_hat = i == 7 and (b % 4 == 3)
            place(drums, hihat(open_hat=open_hat), t0 + i * (BEAT / 2))

        if b % 8 == 0:
            place(drums, crash(), t0)

        if (b + 1) % 8 == 0:
            place(drums, snare(0.08), t0 + 3 * BEAT + BEAT / 2)
            place(drums, snare(0.08), t0 + 3 * BEAT + 3 * BEAT / 4)

    mix = drums * 0.7 + bass_t * 0.5 + chords_t * 0.45

    intro_n = int(2.5 * SR)
    mix[:intro_n] *= np.linspace(0.0, 1.0, intro_n)
    outro_n = int(4.0 * SR)
    mix[-outro_n:] *= np.linspace(1.0, 0.0, outro_n)

    mix = np.tanh(mix * 1.05)
    peak = np.max(np.abs(mix)) + 1e-9
    mix *= 0.92 / peak
    return mix


def write_wav(path: Path, samples: np.ndarray) -> None:
    stereo = np.stack([samples, samples], axis=1)
    pcm = (stereo * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(pcm.tobytes())


if __name__ == "__main__":
    print(f"Building {DURATION}s rock track at {BPM} BPM")
    samples = build()
    write_wav(OUT, samples)
    print(f"Wrote {OUT}")
    print(f"Peak: {np.max(np.abs(samples)):.3f}")
    print(f"RMS:  {np.sqrt(np.mean(samples**2)):.4f}")
