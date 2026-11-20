"""Sound design of the "Moderne" bank.

Every cue keeps the length, rhythm and melodic contour of its arcade original
(read from prototype/audio/arcade at build time) and re-voices it with
modern synthesis: layered synths, sub-bass, filtered noise, room reverb.
"""
from pathlib import Path

import numpy as np
from scipy import signal

from analysis import load, track, HOP
from dsp import *

ARCADE = None  # set by the builder


def original(name):
    return load(ARCADE / f"{name}.wav")


def contour(name, transpose=-12, lo=110.0, hi=2600.0, gate=0.012, smooth=5):
    """Pitch and loudness of the arcade cue, per sample, transposed in semitones."""
    x = original(name)
    f0, amp = track(x)
    voiced = (amp > gate) & (f0 > 90)
    f = np.where(voiced, f0, np.nan)
    # Hold the last pitch through gaps so releases keep their note.
    last = np.nan
    for i in range(len(f)):
        if np.isnan(f[i]):
            f[i] = last
        else:
            last = f[i]
    first = np.nanmin(np.where(np.isnan(f), np.inf, np.arange(len(f))))
    f[np.isnan(f)] = f[int(first)] if np.isfinite(first) else 440
    f = f * 2 ** (transpose / 12)
    while np.any(f > hi):
        f = np.where(f > hi, f / 2, f)
    while np.any(f < lo):
        f = np.where(f < lo, f * 2, f)
    logf = signal.medfilt(np.log2(f), smooth)
    t_frames = np.arange(len(f)) * HOP / RATE
    n = len(x)
    t = np.arange(n) / RATE
    freq = 2 ** np.interp(t, t_frames, logf)
    a = np.where(voiced, amp, 0) / max(amp.max(), 1e-9)
    a = np.interp(t, t_frames, a)
    a = signal.lfilter([0.004], [1, -0.996], a)  # ~5 ms smoothing
    return freq, a / max(a.max(), 1e-9), n


# --- Weapons and impacts -------------------------------------------------------

def shot():
    n = int(0.42 * RATE)
    t = np.arange(n) / RATE
    f = exp_sweep(n, 2100, 330, 0.028)
    zap = fm(f, n, 1.5, 2.2 * np.exp(-t / 0.03)) * expdecay(n, 0.055)
    body = square(f * 0.5, n, 0.3) * expdecay(n, 0.045)
    body = sweep_filter(body, 600 + 5000 * np.exp(-t / 0.03), q=1.2)
    snap = bandpass(noise(n, 3), 2500, 11000) * expdecay(n, 0.006)
    x = 0.55 * zap + 0.45 * body + 0.35 * snap
    return reverb(x, 0.45, 0.18, damp=7000)


def explosion(n, seed, size=1.0, bright=1.0, sub=1.0):
    t = np.arange(n) / RATE
    crack = lowpass(highpass(noise(n, seed), 1800), 10000) * expdecay(n, 0.008) * attack_ramp(n, 0.001)
    body = noise(n, seed + 1)
    body = sweep_filter(body, 300 + 7000 * bright * np.exp(-t / (0.09 * size)), q=0.7) * expdecay(n, 0.18 * size)
    boom = sine(exp_sweep(n, 110, 34, 0.06 * size), n) * expdecay(n, 0.28 * size) * sub
    r = rng(seed + 2)
    debris = np.zeros(n)
    for _ in range(int(30 * size)):
        at = r.exponential(0.25 * size)
        g = int(r.uniform(0.004, 0.02) * RATE)
        grain = bandpass(r.standard_normal(g), r.uniform(800, 3000), 9000) * np.hanning(g)
        place(debris, grain * np.exp(-at / (0.5 * size)) * r.uniform(0.3, 1.0), 0.02 + at)
    return 0.3 * crack + 0.9 * body + 0.9 * boom + 0.35 * debris


def tonal_layer(name, voice, transpose=-12, **kw):
    freq, a, n = contour(name, transpose, **kw)
    return voice(freq, n) * a, n


def impact():
    tone, n = tonal_layer("impact", lambda f, n: 0.6 * square(f, n, 0.25) + 0.5 * saw(f * 1.004, n))
    tone = lowpass(tone, 5000)
    x = 0.55 * tone + explosion(n, 101, 0.6, 1.0, 0.6)
    return reverb(x, 0.6, 0.2)


HIT_DESIGN = {
    # voice of the melodic chirp, explosion size, brightness, extra layer
    "ring": dict(seed=201, size=0.7, bright=1.2),
    "claw": dict(seed=211, size=0.8, bright=0.9),
    "interceptor": dict(seed=221, size=0.6, bright=1.3),
    "meteor": dict(seed=231, size=1.1, bright=0.6),
    "row": dict(seed=241, size=1.0, bright=0.8),
}


def hit(family):
    d = HIT_DESIGN[family]
    name = "hit_" + family
    if family == "ring":
        voice = lambda f, n: fm(f, n, 3.51, 1.6) * 0.8 + 0.3 * sine(f * 2.76, n)
    elif family == "claw":
        voice = lambda f, n: saturate(saw(f, n) + 0.6 * saw(f * 1.5, n), 2.0)
    elif family == "interceptor":
        voice = lambda f, n: square(f, n, 0.5) * (0.6 + 0.4 * square(np.full(n, 31.0), n))
    elif family == "meteor":
        voice = lambda f, n: triangle(f, n) + 0.4 * saturate(sine(f * 0.5, n), 3)
    else:
        voice = lambda f, n: saw(f, n) + 0.7 * square(f * 0.5, n, 0.4)
    tone, n = tonal_layer(name, voice, -12 if family != "meteor" else -12)
    tone = lowpass(tone, 4200)
    x = 0.5 * tone + explosion(n, d["seed"], d["size"], d["bright"], 0.9)
    if family == "ring":
        r = rng(9)
        shards = sum(sine(np.full(n, r.uniform(1800, 5200)), n) * expdecay(n, r.uniform(0.05, 0.25)) for _ in range(7))
        x += 0.18 * shards
    if family == "row":
        clang = sum(sine(np.full(n, f), n) * expdecay(n, 0.3 / (k + 1)) for k, f in enumerate([311, 523, 877, 1291]))
        x += 0.3 * clang
    if family == "meteor":
        x += 0.5 * lowpass(noise(n, 77), 400) * expdecay(n, 0.35)
    return reverb(x, 0.8, 0.22)


def player_explosion(seconds_long, seed, metal=False):
    n = int(seconds_long * RATE)
    t = np.arange(n) / RATE
    x = 1.3 * explosion(n, seed, 2.2, 1.0, 1.4)
    # Second blast and a long rumble.
    place(x, 0.8 * explosion(int(1.6 * RATE), seed + 10, 1.2, 0.7, 1.0), 0.16)
    rumble = lowpass(noise(n, seed + 20), 180, 2) * expdecay(n, 0.9) * np.clip(t / 0.05, 0, 1)
    x += 1.1 * rumble
    # Power-down whine of the ship's reactor.
    f = exp_sweep(n, 780, 55, 0.55)
    whine = sweep_filter(saw(f, n) + 0.5 * saw(f * 1.01, n), 2400 * np.exp(-t / 0.6) + 200, q=1.0)
    x += 0.22 * whine * expdecay(n, 0.7) * np.clip(t / 0.03, 0, 1)
    if metal:
        clang = sum(sine(np.full(n, f), n) * expdecay(n, 0.6 / (k + 1)) for k, f in enumerate([233, 412, 655, 1033, 1517]))
        x += 0.45 * clang * np.clip(t / 0.002, 0, 1)
        scrape = bandpass(noise(n, seed + 30), 1800, 6000) * expdecay(n, 0.25)
        x += 0.25 * scrape
    return reverb(x, 2.2, 0.32, damp=4000)


def loss():
    return player_explosion(3.6, 301)


def crash():
    return player_explosion(2.35, 311, metal=True)


# --- Enemy flights (contour re-voiced) ---------------------------------------

def enemy(family):
    name = "enemy_" + family
    if family == "ring":
        freq, a, n = contour(name, -12, lo=140, hi=1400, smooth=7)
        t = np.arange(n) / RATE
        tone = supersaw(freq, n, seed=5) * 0.7 + 0.5 * sine(freq * 0.5, n)
        x = sweep_filter(tone, freq * (3 + 2 * np.sin(2 * np.pi * 0.7 * t)), q=1.5) * a
        x += 0.05 * bandpass(noise(n, 55), 800, 5000) * a
    elif family == "claw":
        freq, a, n = contour(name, -12, lo=150, hi=1800)
        t = np.arange(n) / RATE
        x = fm(freq, n, 2.0, 1.4 + 0.8 * np.sin(2 * np.pi * 9 * t)) * a
        x += 0.35 * saturate(saw(freq * 0.5, n), 2) * a
        x = lowpass(x, 5000)
    elif family == "interceptor":
        freq, a, n = contour(name, -12, lo=150, hi=2000)
        jet = sweep_filter(noise(n, 66), freq * 2.2, kind="band", q=2.5)
        x = (0.8 * jet + 0.45 * sine(freq, n) + 0.2 * square(freq * 0.5, n, 0.2)) * a
        x = lowpass(x, 7000)
    elif family == "meteor":
        freq, a, n = contour(name, -12, lo=90, hi=1200, smooth=7)
        whistle = sine(freq, n) + 0.3 * sine(freq * 2.01, n)
        rumble = lowpass(noise(n, 88), 220, 2)
        x = (1.0 * whistle + 0.7 * rumble + 0.35 * saturate(triangle(freq * 0.5, n), 2) + 0.25 * bandpass(noise(n, 89), 600, 4000)) * a
    else:
        freq, a, n = contour(name, -12, lo=120, hi=1600)
        t = np.arange(n) / RATE
        engine = square(freq, n, 0.35) + 0.6 * saw(freq * 1.005, n)
        x = sweep_filter(engine, freq * 4, q=1.0) * (0.75 + 0.25 * np.sin(2 * np.pi * 14 * t)) * a
        x += 0.5 * sine(freq * 0.5, n) * a
    # A short, dry room: flights must not leave a continuous bed behind them.
    return reverb(x, 0.45, 0.1)


# --- Music -------------------------------------------------------------------

def render(events, length, instrument, **kw):
    out = np.zeros(length + RATE)
    for start, duration, midi in events:
        place(out, instrument(midi, duration, **kw), start)
    return out


START_THEME = [  # time, duration, midi: the arcade melody one octave lower
    (0.03, 0.06, 66), (0.09, 0.05, 69), (0.14, 0.10, 73), (0.28, 0.06, 73), (0.34, 0.76, 78),
    (1.12, 0.05, 81), (1.18, 0.09, 78), (1.27, 0.05, 81), (1.32, 0.80, 85),
]


def fanfare(offset, length, out, big=1.0):
    events = [(offset + s, d, m) for s, d, m in START_THEME]
    place(out, 0.55 * render(events, length, lead, bright=1.0), 0)
    place(out, 0.12 * render([(s, d, m + 12) for s, d, m in events], length, bell), 0)
    # Harmony under the two long notes: F#m then C#sus4 → C#.
    place(out, 0.22 * pad([54, 57, 61, 66], 0.78), offset + 0.34)
    place(out, 0.22 * pad([49, 54, 56, 61], 0.25), offset + 1.32)
    place(out, 0.22 * pad([49, 53, 56, 61], 0.55, attack=0.05), offset + 1.57)
    place(out, 0.45 * bass(42, 0.75), offset + 0.34)
    place(out, 0.45 * bass(37, 0.8), offset + 1.32)
    for at in (0.03, 0.09, 0.14):
        place(out, 0.18 * snare(0.15), offset + at)
    place(out, 0.9 * kick(), offset + 0.34)
    place(out, 0.35 * crash_cymbal(1.6), offset + 0.34)
    place(out, 0.9 * kick(), offset + 1.32)
    place(out, 0.4 * snare(), offset + 1.32)
    place(out, 0.3 * crash_cymbal(1.2), offset + 1.32)
    return out


def start():
    n = int(2.26 * RATE)
    out = fanfare(0.0, n, np.zeros(n + RATE))
    return reverb(out, 1.6, 0.22)


def launch():
    n = int(6.24 * RATE)
    out = np.zeros(n + RATE)
    fanfare(0.0, n, out)
    fanfare(2.29, n, out)
    # Countdown pings speeding up, over a rising engine.
    for at in (4.63, 5.00, 5.34, 5.62, 5.86, 6.02, 6.12):
        place(out, mix(0.35 * bell(78, 0.08, index=1.6), 0.12 * hat(0.1)), at)
    m = int(1.7 * RATE)
    t = np.arange(m) / RATE
    riser = sweep_filter(noise(m, 404), 300 + 5000 * (t / t[-1]) ** 2, q=1.4) * (t / t[-1]) ** 1.5
    riser += 0.3 * saw(110 + 330 * (t / t[-1]) ** 2, m) * (t / t[-1]) ** 2
    place(out, 0.35 * lowpass(riser, 6000), 4.55)
    return reverb(out, 1.5, 0.2)


SUCCESS_THEME = [  # the arcade melody one octave lower
    (0.82, 0.15, 73), (1.08, 0.14, 73), (1.23, 0.13, 77), (1.35, 0.14, 80), (1.49, 0.13, 77), (1.62, 0.13, 80),
    (1.75, 0.14, 77), (1.89, 0.16, 75), (2.15, 0.14, 75), (2.28, 0.13, 78), (2.41, 0.40, 82), (2.81, 0.14, 84),
    (2.94, 0.13, 80), (3.07, 0.14, 77), (3.21, 0.13, 84), (3.33, 0.14, 80), (3.47, 0.13, 77), (3.60, 0.13, 84),
    (3.73, 0.14, 80), (3.87, 0.16, 85), (4.12, 0.14, 84), (4.26, 0.62, 85),
]


def success():
    n = int(5.02 * RATE)
    out = np.zeros(n + RATE)
    # Sparkling sweep up (the arcade glissando) then the melody.
    m = int(0.3 * RATE)
    t = np.arange(m) / RATE
    gliss = fm(400 * 2 ** (t / 0.3 * 3), m, 2.0, 1.0) * np.hanning(m)
    place(out, 0.35 * gliss, 0.0)
    for k, mm in enumerate([73, 77, 80, 85, 89, 92]):
        place(out, 0.18 * bell(mm, 0.1), 0.02 + k * 0.035)
    events = SUCCESS_THEME
    place(out, 0.42 * render(events, n, pluck), 0)
    place(out, 0.3 * render(events, n, lead, bright=0.7), 0)
    place(out, 0.14 * render([(s, d, m + 12) for s, d, m in events], n, bell), 0)
    chords = [(0.82, 1.07, [49, 56, 61, 65], 37), (1.89, 0.52, [51, 58, 63, 66], 39),
              (2.41, 0.66, [54, 58, 61, 66], 42), (3.07, 0.80, [53, 56, 60, 65], 44),
              (3.87, 0.25, [56, 60, 63, 68], 44), (4.12, 0.9, [49, 56, 61, 65], 37)]
    for at, dur, notes, root in chords:
        place(out, 0.18 * pad(notes, dur, attack=0.04, cutoff=2800), at)
        place(out, 0.4 * bass(root, dur), at)
    for k in range(int((4.12 - 0.82) / 0.26)):
        at = 0.82 + k * 0.265
        place(out, mix((0.6 if k % 2 == 0 else 0.0) * kick(0.3), (0.3 if k % 2 else 0.0) * snare(0.2), 0.12 * hat()), at)
    place(out, 0.8 * kick(), 4.26)
    place(out, 0.35 * crash_cymbal(1.5), 4.26)
    return reverb(out, 1.8, 0.24)


TIMEOUT_THEME = [  # the arcade melody one octave lower
    (0.00, 0.11, 92), (0.14, 0.07, 97), (0.22, 0.06, 92), (0.28, 0.12, 89), (0.41, 0.07, 92), (0.48, 0.07, 89),
    (0.55, 0.12, 85), (0.68, 0.06, 89), (0.74, 0.07, 85), (0.81, 0.22, 80), (1.07, 0.07, 80), (1.14, 0.07, 79),
    (1.21, 0.06, 80), (1.27, 0.07, 81), (1.34, 0.07, 82), (1.41, 0.06, 81), (1.47, 0.06, 82), (1.53, 0.07, 84),
    (1.60, 0.22, 85), (1.86, 0.12, 80), (2.00, 0.08, 80), (2.08, 0.20, 81), (2.28, 0.42, 80), (2.73, 0.2, 84),
]


def timeout():
    n = int(2.99 * RATE)
    out = np.zeros(n + RATE)
    events = [(s, d, m - 12) for s, d, m in TIMEOUT_THEME]
    place(out, 0.5 * render(events, n, lead, bright=0.5, vibrato=0.6), 0)
    place(out, 0.2 * render(TIMEOUT_THEME, n, bell, index=1.2), 0)
    for at, dur, notes, root in [(0.0, 0.8, [61, 64, 68], 37), (0.81, 0.79, [56, 61, 64], 32),
                                 (1.6, 0.68, [57, 61, 64], 33), (2.28, 0.7, [56, 60, 63], 32)]:
        place(out, 0.2 * pad(notes, dur, attack=0.06, cutoff=1800), at)
        place(out, 0.35 * bass(root, dur), at)
    return reverb(out, 1.7, 0.26)


CYCLE_THEME = [  # start, duration, target midi, glide from (arcade one octave lower)
    (0.04, 0.47, 73, 68), (0.51, 0.29, 73, 73), (0.81, 0.74, 77, 75), (1.55, 0.76, 80, 78),
    (2.31, 0.72, 85, 84), (3.02, 0.75, 73, 68), (3.77, 0.39, 77, 75), (4.16, 0.34, 77, 77), (4.50, 0.17, 80, 78),
]


def cycle():
    n = int(4.67 * RATE)
    out = np.zeros(n + RATE)
    for s, d, m, g in CYCLE_THEME:
        place(out, 0.5 * lead(m, d, bright=0.9, glide_from=g, glide=0.035), s)
        place(out, 0.12 * bell(m + 12, d * 0.5), s + 0.03)
    for at, dur in [(0.04, 0.77), (0.81, 0.74), (1.55, 0.76), (2.31, 0.72), (3.02, 0.75), (3.77, 0.9)]:
        place(out, 0.2 * pad([49, 56, 61, 65, 68], dur, attack=0.12, cutoff=2600), at)
    for at, root in [(0.04, 37), (0.81, 41), (1.55, 44), (2.31, 49), (3.02, 37), (3.77, 41)]:
        place(out, 0.4 * bass(root, 0.7), at)
        place(out, 0.55 * tom(midi_hz(root + 12)), at)
    place(out, 0.4 * crash_cymbal(2.0), 2.31)
    place(out, 0.8 * kick(), 2.31)
    return reverb(out, 2.0, 0.26)


def bonus():
    n = int(3.53 * RATE)
    out = np.zeros(n + RATE)
    arp = [73, 77, 80, 85]
    starts = [0.03, 0.24, 0.47, 0.70, 0.94, 1.16, 1.39, 1.61, 1.84, 2.06, 2.29, 2.52, 2.75, 2.97, 3.20]
    for k, at in enumerate(starts):
        m = arp[k % 4] + (12 if k >= 12 else 0) * (k % 4 < 2)
        place(out, mix(0.4 * bell(m, 0.13, index=2.0), 0.3 * pluck(m, 0.12, cutoff_mul=4.0)), at)
        place(out, 0.22 * bell(m + 12, 0.05, index=1.0), at + 0.14)
    place(out, 0.2 * pad([61, 65, 68, 73], 3.2, attack=0.6, cutoff=3500), 0.03)
    t = np.arange(n) / RATE
    sparkle = highpass(noise(n, 515), 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 4.4 * t)) * np.clip(t / 0.5, 0, 1) * np.exp(-t / 2.5)
    out[:n] += 0.05 * sparkle
    return delay(reverb(out, 1.4, 0.2), 0.22, 0.3, 0.18)


WAVE_THEME = [(0.03, 0.10, 90), (0.14, 0.08, 90)]


def wave():
    n = int(0.69 * RATE)
    out = np.zeros(n + RATE)
    for s, d, m in WAVE_THEME:
        place(out, 0.4 * bell(m, d, index=1.4), s)
    # Siren swoop F#8 → D#8 → E8, voiced two octaves lower.
    m = int(0.45 * RATE)
    t = np.arange(m) / RATE
    f = midi_hz(np.interp(t, [0, 0.1, 0.2, 0.31, 0.35, 0.41, 0.45], [90, 89, 88, 87, 88, 87, 87]))
    siren = supersaw(f, m) * adsr(m, 0.01, 0.1, 0.8, 0.08)
    place(out, 0.4 * sweep_filter(siren, f * 4, q=1.0), 0.24)
    return delay(reverb(out, 1.0, 0.2), 0.12, 0.25, 0.15)


def dock():
    freq, a, n = contour("dock", -24, lo=180, hi=1500, smooth=7)
    t = np.arange(n) / RATE
    # Sonar pings for the opening blips, a synth siren for the sweeps.
    is_siren = freq > midi_hz(73)
    siren = sweep_filter(supersaw(freq, n, seed=9), freq * 3.5, q=1.2)
    ping = fm(freq, n, 2.0, 0.6)
    voice = np.where(is_siren, 0.55 * siren, 0.6 * ping) * a
    out = np.zeros(n + RATE)
    out[:n] += voice
    # Tension bed: pulsing F# bass and a soft beat locked to the siren cycle.
    beat = 0.355
    start_bed = 2.6
    k = 0
    at = start_bed
    while at < 12.8:
        place(out, 0.5 * bass(30 if (k // 8) % 2 == 0 else 33, 0.16), at)
        if k % 4 == 0:
            place(out, 0.55 * kick(0.4), at)
        if k % 4 == 2:
            place(out, 0.18 * snare(0.25), at)
        place(out, 0.06 * hat(), at + beat / 2)
        at += beat
        k += 1
    m = int((12.8 - start_bed) * RATE)
    place(out, 0.15 * pad([42, 49, 54, 57], 12.8 - start_bed, attack=1.5, release=0.3, cutoff=1500), start_bed)
    return reverb(out, 1.6, 0.22)


CUES = {
    "shot": shot, "impact": impact, "loss": loss, "crash": crash,
    "wave": wave, "launch": launch, "dock": dock, "start": start,
    "success": success, "timeout": timeout, "cycle": cycle, "bonus": bonus,
    **{f"enemy_{f}": (lambda f=f: enemy(f)) for f in HIT_DESIGN},
    **{f"hit_{f}": (lambda f=f: hit(f)) for f in HIT_DESIGN},
}
