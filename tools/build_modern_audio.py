"""Build the "Moderne" sound bank (prototype/audio/modern).

The generator lives in tools/modern_audio/: it reads the timing and melodies of
the arcade cues and re-voices them with modern synthesis. NumPy and SciPy are
required at build time only.

    python tools/build_modern_audio.py [cue ...]
"""
import runpy
import sys
from pathlib import Path

if __name__ == "__main__":
    sys.argv[0] = str(Path(__file__).with_name("modern_audio") / "build.py")
    runpy.run_path(sys.argv[0], run_name="__main__")
