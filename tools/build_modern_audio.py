"""Build the original synthesized SF sound bank. Requires NumPy at build time."""
from pathlib import Path
import wave

import numpy as np

RATE = 48000
OUTPUT = Path(__file__).resolve().parents[1] / "prototype/audio/modern"


def noise(time, seed, low=40, high=6000):
    rng = np.random.default_rng(seed)
    spectrum = np.fft.rfft(rng.standard_normal(len(time)))
    frequencies = np.fft.rfftfreq(len(time), 1 / RATE)
    spectrum *= (1 - np.exp(-(frequencies / low) ** 2)) * np.exp(-(frequencies / high) ** 4)
    values = np.fft.irfft(spectrum, n=len(time))
    return values / max(np.std(values), 1e-9)


def sweep(time, start, end, decay):
    frequency = end + (start - end) * np.exp(-time / decay)
    phase = np.cumsum(frequency) * 2 * np.pi / RATE
    return np.sin(phase)


def metal(time, frequencies, decay):
    values = np.zeros(len(time))
    for index, frequency in enumerate(frequencies):
        values += np.sin(2 * np.pi * frequency * time) * np.exp(-time / (decay / (1 + index * 0.4))) / (index + 1)
    return values


def chord(time, frequencies, spacing, decay):
    values = np.zeros(len(time))
    for index, frequency in enumerate(frequencies):
        age = np.maximum(time - spacing * index, 0)
        envelope = (1 - np.exp(-age / 0.012)) * np.exp(-age / decay)
        values += envelope * (np.sin(2 * np.pi * frequency * age) + 0.12 * np.sin(4 * np.pi * frequency * age))
    return values / len(frequencies)


def build(name, duration):
    time = np.arange(round(duration * RATE)) / RATE
    seed = sum((index + 1) * ord(char) for index, char in enumerate(name)) + 1980
    air = noise(time, seed)
    body = noise(time, seed + 1, high=1500)
    if name == "shot":
        sound = 0.52 * sweep(time, 1200, 230, 0.022) * np.exp(-time / 0.037)
        sound += 0.22 * air * np.exp(-time / 0.013)
        sound += 0.18 * metal(time, [470, 790, 1370], 0.055)
    elif name == "impact":
        sound = 0.30 * air * np.exp(-time / 0.032) + 0.38 * body * np.exp(-time / 0.055)
        sound += 0.32 * sweep(time, 360, 75, 0.025) * np.exp(-time / 0.08)
        sound += 0.14 * metal(time, [690, 1110, 1870], 0.11)
    elif name in {"loss", "crash"}:
        sound = 0.5 * body * np.exp(-time / 0.19) + 0.18 * air * np.exp(-time / 0.085)
        sound += 0.45 * sweep(time, 160, 34, 0.055) * np.exp(-time / 0.23)
        sound += 0.16 * metal(time, [310, 557, 919, 1427], 0.22)
        if name == "crash":
            age = np.maximum(time - 0.055, 0)
            sound += 0.17 * np.sin(2 * np.pi * 62 * age) * np.exp(-age / 0.19)
    elif name == "wave":
        sound = 0.17 * air * np.exp(-((time - 0.075) / 0.045) ** 2)
        sound += 0.30 * metal(time, [390, 585, 780], 0.10)
    elif name == "launch":
        rise = np.sin(np.pi * np.minimum(time / 0.8, 1)) ** 2
        sound = 0.32 * body * rise + 0.12 * air * rise
        sound += 0.12 * sweep(time, 95, 520, 0.23) * rise
        sound += 0.16 * chord(time, [110, 165, 220, 330], 0.08, 0.24)
    elif name == "dock":
        envelope = np.sin(np.pi * time / duration) ** 2
        sound = 0.16 * air * envelope + 0.23 * sweep(time, 160, 620, 0.16) * envelope
        sound += 0.24 * metal(time, [330, 495, 930], 0.16)
    elif name == "start":
        sound = 0.9 * chord(time, [110, 165, 220, 330], 0.13, 0.20)
        sound += 0.13 * body * np.exp(-time / 0.12)
    elif name == "success":
        sound = 0.9 * chord(time, [220, 277.18, 329.63, 440], 0.12, 0.24)
        sound += 0.06 * metal(time, [880, 1320, 1760], 0.20)
    elif name == "timeout":
        sound = 0.35 * sweep(time, 280, 85, 0.09) * np.exp(-time / 0.14)
        sound += 0.11 * metal(time, [210, 303, 445], 0.17)
    elif name == "cycle":
        sound = chord(time, [146.83, 220, 293.66, 440], 0.17, 0.28)
        sound += 0.12 * body * np.sin(np.pi * np.minimum(time / 0.6, 1)) ** 2
    else:
        raise ValueError(name)
    # Smooth both endpoints after the layers are combined.
    attack = min(round(0.002 * RATE), len(time))
    release = min(round(0.025 * RATE), len(time))
    sound[:attack] *= np.sin(np.linspace(0, np.pi / 2, attack)) ** 2
    sound[-release:] *= np.cos(np.linspace(0, np.pi / 2, release)) ** 2
    sound *= 0.58 / max(np.max(np.abs(sound)), 1e-9)
    pcm = np.rint(sound * 32767).astype("<i2")
    assert pcm[0] == 0 and pcm[-1] == 0
    assert np.max(np.abs(pcm.astype(np.int32))) < 20000
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as target:
        target.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        target.writeframes(pcm.tobytes())
    print(f"{name:8} {duration:.2f}s  peak {np.max(np.abs(sound)):.2f}  RMS {20*np.log10(np.sqrt(np.mean(sound**2))):.1f} dBFS")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for cue, length in {
        "shot": 0.22, "impact": 0.32, "loss": 0.95, "crash": 1.10,
        "wave": 0.40, "launch": 1.10, "dock": 0.75, "start": 1.0,
        "success": 1.05, "timeout": 0.65, "cycle": 1.30,
    }.items():
        build(cue, length)
