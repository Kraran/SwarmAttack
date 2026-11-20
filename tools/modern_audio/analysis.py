import numpy as np, wave
RATE = 48000
HOP = 240

def load(path):
    w = wave.open(str(path))
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768
    return x

def track(x, n=4096, lo=90.0):
    frames = (len(x) - 1) // HOP + 1
    pad = np.concatenate([np.zeros(n // 2), x, np.zeros(n)])
    win = np.hanning(n)
    fr = np.fft.rfftfreq(n, 1 / RATE)
    f0 = np.zeros(frames); amp = np.zeros(frames)
    for i in range(frames):
        seg = pad[i * HOP:i * HOP + n] * win
        amp[i] = np.sqrt(np.mean(x[i * HOP:i * HOP + HOP] ** 2)) if i * HOP < len(x) else 0
        sp = np.abs(np.fft.rfft(seg)); sp[fr < lo] = 0
        k = int(np.argmax(sp))
        if 0 < k < len(sp) - 1:
            a, b, c = np.log(sp[k - 1] + 1e-12), np.log(sp[k] + 1e-12), np.log(sp[k + 1] + 1e-12)
            k = k + 0.5 * (a - c) / (a - 2 * b + c + 1e-12)
        f0[i] = k * RATE / n
    return f0, amp

def notes(x, min_frames=3, gate=0.012, lo=150.0):
    f0, amp = track(x)
    midi = np.where((amp > gate) & (f0 > lo), np.round(12 * np.log2(np.maximum(f0, 1) / 440) + 69), -1)
    out = []; start = 0
    for i in range(1, len(midi) + 1):
        if i == len(midi) or midi[i] != midi[start]:
            if midi[start] >= 0 and i - start >= min_frames:
                out.append([start * HOP / RATE, (i - start) * HOP / RATE, int(midi[start]), float(amp[start:i].mean())])
            start = i
    return out
