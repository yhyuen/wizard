#!/usr/bin/env python3
"""Synthesises the slice's sound effects into assets/sfx/*.wav (design/slice/systems.md §7).

Every sound is made here from sine waves and noise, so there is nothing to license. Run it again
after changing a recipe:  python3 tools/sfx/make_sfx.py
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(RATE * sec)) / RATE


def env(n, attack=0.005, decay=0.2):
    """A quick attack, then an exponential decay with time constant `decay` seconds."""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)


def lowpass(x, k):
    """A cheap one-pole low-pass; k near 0 is darker."""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def noise(sec):
    return rng.uniform(-1, 1, int(RATE * sec))


def fade_edges(x, sec=0.01):
    n = int(RATE * sec)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def bell(f0, sec, decay):
    """Inharmonic partials, as a cast bell has."""
    tt = t(sec)
    x = np.zeros_like(tt)
    for ratio, amp, d in [(0.5, 0.5, 1.2), (1.0, 1.0, 1.0), (1.19, 0.6, 0.8), (1.5, 0.4, 0.6), (2.0, 0.35, 0.5), (2.74, 0.25, 0.35), (3.76, 0.15, 0.25)]:
        x += amp * np.sin(2 * np.pi * f0 * ratio * tt) * np.exp(-tt / (decay * d))
    return fade_edges(x * np.clip(tt / 0.004, 0, 1))


os.makedirs(OUT, exist_ok=True)

# UI: a soft wooden tick, a page turn, a dawn chime.
tt = t(0.06)
save("tick", np.sin(2 * np.pi * 1800 * tt) * env(len(tt), 0.001, 0.012) + 0.3 * lowpass(noise(0.06), 0.3) * env(len(tt), 0.001, 0.008), 0.5)
save("page", fade_edges(lowpass(noise(0.22), 0.25) * env(int(RATE * 0.22), 0.04, 0.07)), 0.45)
save("chime", bell(880, 2.0, 0.9) * 0.6 + bell(1320, 2.0, 0.7) * 0.3, 0.45)

# The College bell at the end of day 7: low and long.
save("bell", bell(196, 6.0, 2.6), 0.85)

# Footsteps on stone: two dull thumps.
tt = t(0.5)
x = np.zeros_like(tt)
for at in (0.0, 0.26):
    i = int(at * RATE)
    n = int(0.12 * RATE)
    x[i:i + n] += lowpass(noise(0.12), 0.08) * env(n, 0.002, 0.03) + 0.5 * np.sin(2 * np.pi * 90 * t(0.12)) * env(n, 0.002, 0.04)
save("step", fade_edges(x), 0.5)

# The censer: a hiss that swells and settles.
tt = t(1.6)
save("hiss", fade_edges(lowpass(noise(1.6), 0.6) - lowpass(noise(1.6), 0.05)) * np.sin(np.pi * tt / 1.6) ** 2, 0.4)

# Death: a low falling drone with a dull hit.
tt = t(2.5)
f = 110 * np.exp(-tt * 0.4)
x = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-tt / 1.2) + 0.6 * lowpass(noise(2.5), 0.04) * np.exp(-tt / 0.25)
save("death", fade_edges(x), 0.8)

# Casts, one per sphere.
tt = t(0.35)
n = len(tt)
save("cast_fire", fade_edges(lowpass(noise(0.35), 0.35) * env(n, 0.01, 0.12) + 0.3 * np.sin(2 * np.pi * 160 * tt) * env(n, 0.005, 0.08)), 0.45)
save("cast_earth", fade_edges(lowpass(noise(0.35), 0.05) * env(n, 0.002, 0.07) + 0.8 * np.sin(2 * np.pi * 70 * tt) * env(n, 0.002, 0.09)), 0.55)
sweep = 2400 - 1600 * tt / 0.35
save("cast_storm", fade_edges((np.sign(np.sin(2 * np.pi * np.cumsum(sweep) / RATE)) * 0.3 + noise(0.35) * 0.4) * env(n, 0.001, 0.06)), 0.35)
save("cast_water", fade_edges(np.sin(2 * np.pi * (600 + 500 * np.exp(-tt / 0.05)) * tt) * env(n, 0.002, 0.07) + 0.3 * lowpass(noise(0.35), 0.2) * env(n, 0.01, 0.1)), 0.4)
save("cast_hours", fade_edges(bell(660, 0.8, 0.35)[::-1].copy()), 0.4)  # a chime played backwards
save("ward", fade_edges(bell(1046, 0.6, 0.25)), 0.4)

# Hits: dealt (a crack) and taken (a duller thud).
tt = t(0.15)
n = len(tt)
save("hit", fade_edges(noise(0.15) * env(n, 0.001, 0.025) + 0.5 * np.sin(2 * np.pi * 220 * tt) * env(n, 0.001, 0.04)), 0.45)
save("hurt", fade_edges(lowpass(noise(0.15), 0.1) * env(n, 0.001, 0.05) + np.sin(2 * np.pi * 80 * tt) * env(n, 0.001, 0.06)), 0.6)

# Night ambience: wind through stone, 8 s, made to loop (the ends match).
sec = 8.0
tt = t(sec)
w = lowpass(noise(sec), 0.02) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / sec) ** 2)
w = w * np.hanning(len(w)) ** 0.15
w = (w + w[::-1]) * 0.5  # symmetric, so the loop point is seamless
save("night", w, 0.3)
print("wrote", sorted(os.listdir(OUT)))
