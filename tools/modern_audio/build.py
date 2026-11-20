"""Build the "Moderne" sound bank from the arcade cues' timing and melodies.

python tools/modern_audio/build.py   (NumPy and SciPy required at build time)
"""
import sys, time, wave
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cues
from analysis import load
from dsp import RATE, master, active_rms

ROOT = HERE.parents[1]
cues.ARCADE = ROOT / "prototype/audio/arcade"
OUTPUT = ROOT / "prototype/audio/modern"
# Loudness relative to the arcade cue (dB): the frequent shot stays discreet.
# Flights sit behind the action, the first waves' rings most of all.
TRIM = {"shot": -3.0, "enemy_ring": -7.0, "enemy_claw": -4.0, "enemy_interceptor": -4.0,
        "enemy_meteor": -4.0, "enemy_row": -4.0}


def build(name):
    reference = load(cues.ARCADE / f"{name}.wav")
    raw = cues.CUES[name]()
    target = active_rms(reference) * 10 ** (TRIM.get(name, 0.0) / 20)
    sound = master(raw, len(reference), target)
    pcm = np.rint(np.clip(sound, -1, 1) * 32767).astype("<i2")
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(pcm.tobytes())
    return sound, reference


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(cues.CUES)
    for name in names:
        started = time.time()
        sound, reference = build(name)
        print(f"{name:18} {len(sound)/RATE:5.2f}s  peak {np.abs(sound).max():.2f}  "
              f"rms {active_rms(sound):.3f} (arcade {active_rms(reference):.3f})  {time.time()-started:.1f}s")
