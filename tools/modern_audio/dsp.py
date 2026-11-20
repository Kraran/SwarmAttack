"""Small offline synthesis toolkit for the Swarm Attack "Moderne" sound bank."""
import numpy as np
from scipy import signal

RATE = 48000


def seconds(duration):
    return np.arange(int(round(duration * RATE))) / RATE


def midi_hz(midi):
    return 440.0 * 2.0 ** ((np.asarray(midi, dtype=float) - 69.0) / 12.0)


def rng(seed):
    return np.random.default_rng(seed)


# --- Oscillators -------------------------------------------------------------

def phase_of(freq, length, start=0.0):
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (length,))
    return (start + np.cumsum(freq) / RATE) % 1.0, freq / RATE


def _blep(t, dt):
    out = np.zeros_like(t)
    a = t < dt
    x = t[a] / np.maximum(dt[a], 1e-9)
    out[a] = x + x - x * x - 1.0
    b = t > 1.0 - dt
    x = (t[b] - 1.0) / np.maximum(dt[b], 1e-9)
    out[b] = x * x + x + x + 1.0
    return out


def saw(freq, length, start=0.0):
    t, dt = phase_of(freq, length, start)
    return 2.0 * t - 1.0 - _blep(t, dt)


def square(freq, length, width=0.5, start=0.0):
    t, dt = phase_of(freq, length, start)
    t2 = (t + 1.0 - width) % 1.0
    return (2.0 * t - 1.0 - _blep(t, dt)) - (2.0 * t2 - 1.0 - _blep(t2, dt))


def sine(freq, length, start=0.0):
    t, _ = phase_of(freq, length, start)
    return np.sin(2 * np.pi * t)


def triangle(freq, length, start=0.0):
    t, _ = phase_of(freq, length, start)
    return 1.0 - 4.0 * np.abs(t - 0.5)


def supersaw(freq, length, cents=(-14, -6, 0, 7, 15), seed=1):
    r = rng(seed)
    freq = np.asarray(freq, dtype=float)
    out = np.zeros(length)
    for c in cents:
        out += saw(freq * 2 ** (c / 1200.0), length, r.random())
    return out / np.sqrt(len(cents))


def fm(freq, length, ratio, index, start=0.0):
    """Two-operator FM; index may be an envelope array."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (length,))
    mod = sine(freq * ratio, length)
    t, _ = phase_of(freq, length, start)
    return np.sin(2 * np.pi * t + np.asarray(index) * mod)


def noise(length, seed):
    return rng(seed).standard_normal(length)


# --- Envelopes ---------------------------------------------------------------

def adsr(length, attack, decay, sustain, release, hold=None):
    """hold: seconds before the release starts (defaults to the full length)."""
    t = np.arange(length) / RATE
    hold = length / RATE - release if hold is None else hold
    env = np.where(t < attack, t / max(attack, 1e-6),
                   sustain + (1 - sustain) * np.exp(-(t - attack) / max(decay, 1e-6)))
    rel = t > hold
    level_at_release = np.interp(hold, t, env) if length else 0
    env = np.where(rel, level_at_release * np.exp(-(t - hold) / max(release / 5, 1e-6)), env)
    return env


def attack_ramp(length, seconds_):
    return np.clip(np.arange(length) / RATE / max(seconds_, 1e-6), 0, 1)


def expdecay(length, tau, delay=0.0):
    t = np.arange(length) / RATE - delay
    return np.where(t < 0, 0.0, np.exp(-np.maximum(t, 0) / tau))


def exp_sweep(length, start, end, tau):
    t = np.arange(length) / RATE
    return end + (start - end) * np.exp(-t / tau)


def fade_edges(x, attack=0.002, release=0.02):
    a = min(len(x), int(attack * RATE))
    r = min(len(x), int(release * RATE))
    if a:
        x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if r:
        x[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return x


# --- Filters -----------------------------------------------------------------

def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, min(cutoff, RATE * 0.45), "low", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, "high", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, low, high, order=2):
    sos = signal.butter(order, [low, min(high, RATE * 0.45)], "band", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def sweep_filter(x, cutoff, kind="low", q=0.9, block=64):
    """Time-varying resonant biquad (RBJ), cutoff per sample, updated per block."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), (len(x),))
    out = np.zeros_like(x)
    z = np.zeros(2)
    for i in range(0, len(x), block):
        fc = float(np.clip(cutoff[i], 30, RATE * 0.45))
        w = 2 * np.pi * fc / RATE
        alpha = np.sin(w) / (2 * q)
        cw = np.cos(w)
        if kind == "low":
            b = np.array([(1 - cw) / 2, 1 - cw, (1 - cw) / 2])
        elif kind == "high":
            b = np.array([(1 + cw) / 2, -(1 + cw), (1 + cw) / 2])
        else:  # band (constant peak gain)
            b = np.array([alpha, 0.0, -alpha])
        a = np.array([1 + alpha, -2 * cw, 1 - alpha])
        seg, z = signal.lfilter(b / a[0], a / a[0], x[i:i + block], zi=z)
        out[i:i + block] = seg
    return out


# --- Effects -----------------------------------------------------------------

def saturate(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def reverb(x, decay=1.4, mix=0.25, predelay=0.012, damp=5500, seed=7, tail=True):
    """Convolution with a synthetic room: early taps plus a damped noise tail."""
    length = int((decay + predelay) * RATE)
    r = rng(seed)
    ir = np.zeros(length)
    t = np.arange(length) / RATE
    body = r.standard_normal(length) * np.exp(-6.9 * t / decay)
    body = lowpass(body, damp, 1)
    start = int(predelay * RATE)
    ir[start:] += body[:length - start]
    for tap, gain in [(0.007, 0.5), (0.013, 0.35), (0.019, 0.3), (0.027, 0.22), (0.041, 0.15)]:
        ir[int((predelay + tap) * RATE)] += gain * (1 if r.random() > 0.5 else -1)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)[: len(x) + (length if tail else 0)]
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry * (1 - mix * 0.5) + wet * mix


def delay(x, time, feedback=0.35, mix=0.25, damp=4000, repeats=6):
    step = int(time * RATE)
    out = np.concatenate([x, np.zeros(step * repeats)])
    echo = np.concatenate([x, np.zeros(step * repeats)])
    for n in range(1, repeats + 1):
        echo = lowpass(echo, damp, 1)
        out[step * n:] += mix * (feedback ** (n - 1)) * echo[: len(out) - step * n]
    return out


def place(target, sound, at):
    i = int(round(at * RATE))
    if i >= len(target):
        return target
    n = min(len(sound), len(target) - i)
    target[i:i + n] += sound[:n]
    return target


def mix(*layers):
    """Sum arrays of different lengths."""
    out = np.zeros(max(len(l) for l in layers))
    for l in layers:
        out[:len(l)] += l
    return out


def fit(x, length):
    if len(x) >= length:
        return x[:length].copy()
    return np.concatenate([x, np.zeros(length - len(x))])


# --- Drums -------------------------------------------------------------------

def kick(length=0.45, punch=1.0, seed=11):
    n = int(length * RATE)
    f = exp_sweep(n, 160 * punch, 42, 0.035)
    body = sine(f, n) * expdecay(n, 0.22)
    click = lowpass(highpass(noise(n, seed), 2500), 9000) * expdecay(n, 0.003) * attack_ramp(n, 0.0005)
    return saturate(body + 0.15 * click, 1.4)


def snare(length=0.35, seed=12):
    n = int(length * RATE)
    tone = sine(exp_sweep(n, 260, 185, 0.03), n) * expdecay(n, 0.06)
    rattle = bandpass(noise(n, seed), 1400, 9000) * expdecay(n, 0.11) * attack_ramp(n, 0.001)
    return 0.6 * tone + 0.7 * rattle


def hat(length=0.12, seed=13, tau=0.03):
    n = int(length * RATE)
    return lowpass(highpass(noise(n, seed), 7000, 4), 14000) * expdecay(n, tau) * attack_ramp(n, 0.001)


def crash_cymbal(length=2.0, seed=14):
    n = int(length * RATE)
    x = lowpass(highpass(noise(n, seed), 3500, 2), 12000)
    shimmer = 1 + 0.2 * np.sin(2 * np.pi * 7 * np.arange(n) / RATE)
    return x * expdecay(n, 0.55) * shimmer * attack_ramp(n, 0.004) * 0.45


def tom(freq, length=0.5, seed=15):
    n = int(length * RATE)
    body = sine(exp_sweep(n, freq * 1.6, freq, 0.04), n) * expdecay(n, 0.2)
    skin = lowpass(noise(n, seed), 1800) * expdecay(n, 0.03)
    return body + 0.3 * skin


# --- Instruments ---------------------------------------------------------------

def lead(midi, duration, bright=1.0, vibrato=0.25, seed=21, glide_from=None, glide=0.06):
    n = int((duration + 0.25) * RATE)
    t = np.arange(n) / RATE
    f = np.full(n, midi_hz(midi))
    if glide_from is not None:
        f = midi_hz(midi + (glide_from - midi) * np.exp(-t / glide))
    vib = 1 + 0.006 * vibrato * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.18) / 0.25, 0, 1)
    tone = 0.7 * supersaw(f * vib, n, seed=seed) + 0.35 * square(f * vib * 0.5, n, 0.38)
    env = adsr(n, 0.008, 0.18, 0.72, 0.18, hold=duration)
    cutoff = midi_hz(midi) * (3.0 + 9 * bright * (0.4 + 0.6 * np.exp(-t / 0.14)))
    return sweep_filter(tone, cutoff, q=0.8) * env


def bell(midi, duration, seed=31, ratio=3.5, index=2.4):
    n = int((duration + 0.6) * RATE)
    t = np.arange(n) / RATE
    f = midi_hz(midi)
    env = expdecay(n, 0.12 + 0.35 * min(duration, 1.0))
    index = index * min(1.0, 1800.0 / f)  # keep the FM sidebands below Nyquist
    tone = fm(f, n, ratio, index * np.exp(-t / 0.18)) * env
    tone += 0.3 * sine(f * 2.01, n) * expdecay(n, 0.09)
    return tone * np.clip(t / 0.002, 0, 1)


def pluck(midi, duration, seed=41, cutoff_mul=8.0):
    n = int((duration + 0.3) * RATE)
    t = np.arange(n) / RATE
    f = midi_hz(midi)
    tone = saw(f, n) + 0.5 * square(f * 1.003, n, 0.3)
    env = expdecay(n, 0.18 + duration * 0.3) * attack_ramp(n, 0.002)
    return sweep_filter(tone, f * (1.5 + cutoff_mul * np.exp(-t / 0.07)), q=1.1) * env


def pad(midis, duration, seed=51, attack=0.25, release=0.5, cutoff=2400):
    n = int((duration + release) * RATE)
    out = np.zeros(n)
    for k, m in enumerate(midis):
        out += supersaw(midi_hz(m), n, cents=(-11, -4, 3, 10), seed=seed + k)
    out = lowpass(out / len(midis), cutoff, 2)
    return out * adsr(n, attack, 0.6, 0.85, release, hold=duration)


def bass(midi, duration, seed=61):
    n = int((duration + 0.15) * RATE)
    t = np.arange(n) / RATE
    f = midi_hz(midi)
    tone = 0.8 * sine(f, n) + 0.45 * sweep_filter(saw(f, n), f * (2 + 5 * np.exp(-t / 0.08)), q=0.9)
    return saturate(tone, 1.3) * adsr(n, 0.004, 0.25, 0.7, 0.1, hold=duration)


def k_weight(x):
    """ITU-R BS.1770 K-weighting at 48 kHz: loudness as heard, not raw energy."""
    x = signal.lfilter([1.53512485958697, -2.69169618940638, 1.19839281085285],
                       [1.0, -1.69065929318241, 0.73248077421585], x)
    return signal.lfilter([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621], x)


def active_rms(x, gate=0.01):
    """K-weighted RMS over the 10 ms frames that are not near silence."""
    x = k_weight(x)
    frames = x[: len(x) // 480 * 480].reshape(-1, 480)
    rms = np.sqrt(np.mean(frames ** 2, axis=1))
    loud = rms > gate * max(rms.max(), 1e-9) / 0.3
    return float(np.sqrt(np.mean(frames[loud] ** 2))) if loud.any() else 1e-9


def master(x, length, target_rms, ceiling=0.89, release=0.03):
    """Fit, trim DC, normalise to a loudness target, soft-limit the peaks."""
    x = fit(x, length)
    x = highpass(x, 25, 2)
    x = fade_edges(x, 0.0015, release)
    for _ in range(3):
        x *= target_rms / max(active_rms(x), 1e-9)
        x = _limit(x, ceiling)
    x = fade_edges(x, 0.0015, release)
    return x


def _limit(x, ceiling):
    peak = np.abs(x)
    env = signal.lfilter([0.02], [1, -0.98], peak)
    env = np.maximum(env, peak)
    gain = np.where(env > ceiling * 0.8, (ceiling * 0.8 + (env - ceiling * 0.8) * 0.25) / np.maximum(env, 1e-9), 1.0)
    gain = signal.filtfilt([0.05], [1, -0.95], gain)
    x = x * np.minimum(gain, 1.0)
    return np.clip(x, -ceiling, ceiling)
