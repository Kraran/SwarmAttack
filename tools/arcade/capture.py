"""Enregistre un scénario de mesure sur un profil MAME temporaire."""

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).with_name("trace.lua")
ROM_SET = "mouncrst"
SCENARIOS = {
    "idle": 850,
    "movement": 850,
    "opposed": 650,
    "fire": 850,
    "fire_tap": 850,
    "fire_busy": 700,
    "attract": 3200,
}
FIELDS = ("frame", "coin", "start", "left", "right", "fire", "tile_scroll", "sprite_ram", "bullet_ram")
INPUT_FIELDS = FIELDS[:6]
REGISTER_SIZES = {"tile_scroll": 64, "sprite_ram": 32, "bullet_ram": 32}


def read_replay(path, frames):
    data = path.read_bytes().replace(b"\r\n", b"\n")
    lines = iter(data.decode("ascii").removesuffix("\n").split("\n"))
    if next(lines, "") != ",".join(INPUT_FIELDS):
        raise ValueError(f"En-tête de replay invalide dans {path}")
    previous = -1
    for line_number, row in enumerate(lines, 2):
        if not re.fullmatch(r"[0-9]+(?:,[01]){5}", row):
            raise ValueError(f"Commande de replay invalide à la ligne {line_number}")
        frame = int(row.partition(",")[0])
        if (previous == -1 and frame != 0) or frame <= previous or frame >= frames:
            raise ValueError(f"Index de frame invalide à la ligne {line_number}")
        previous = frame
    if previous == -1:
        raise ValueError("Le replay doit contenir l'état des commandes à la frame 0")
    return data


def probe_range(text):
    match = re.fullmatch(r"([0-9a-f]{4})(?:-([0-9a-f]{4}))?", text.lower())
    if not match or int(match[1], 16) > int(match[2] or match[1], 16):
        raise argparse.ArgumentTypeError(f"Plage d'adresses invalide : {text}")
    return f"{match[1]}-{match[2] or match[1]}"


def capture(args):
    replay = read_replay(args.replay, args.frames) if args.replay else None
    roms = args.rom_dir.resolve()
    rom = roms / f"{ROM_SET}.zip"
    rom_hash = hashlib.sha256(rom.read_bytes()).hexdigest()
    command = [str(args.mame.resolve()), "-noreadconfig", "-rompath", str(roms)]
    subprocess.run([*command, "-verifyroms", ROM_SET], check=True)
    xml = ET.fromstring(subprocess.check_output([*command, "-listxml", ROM_SET]))
    machine = xml.find(f"./machine[@name='{ROM_SET}']")
    metadata = {
        "mame": xml.attrib["build"],
        "set": ROM_SET,
        "rom_sha256": rom_hash,
        "display": machine.find("display").attrib,
        "dip_defaults": {
            dip.attrib["name"]: dip.find("./dipvalue[@default='yes']").attrib["name"]
            for dip in machine.findall("dipswitch")
        },
        "script_sha256": hashlib.sha256(SCRIPT.read_bytes()).hexdigest(),
    }
    if replay is not None:
        metadata["replay_sha256"] = hashlib.sha256(replay).hexdigest()
    probes = list(dict.fromkeys(args.probe or ()))
    if probes:
        metadata["probe"] = {"ranges": probes, "from": args.probe_from}
    output = args.output.resolve() / ROM_SET
    output.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(dir=output) as directory:
        work = Path(directory)
        captures = []
        scenarios = ("replay",) if replay is not None else args.scenario or SCENARIOS
        for scenario in dict.fromkeys(scenarios):
            frames = args.frames if args.frames is not None else SCENARIOS[scenario]
            scratch = work / scenario
            scratch.mkdir()
            if replay is not None:
                (scratch / "inputs.csv").write_bytes(replay)
            env = dict(
                os.environ, SWARM_SCENARIO=scenario, SWARM_FRAMES=str(frames),
                SWARM_SNAPSHOT_INTERVAL=str(args.snap_every),
                SWARM_SNAPSHOT_START=str(args.snap_from),
                SWARM_PROBE=",".join(probes), SWARM_PROBE_START=str(args.probe_from),
            )
            result = subprocess.run(
                [
                    *command, ROM_SET, "-nowriteconfig", "-noplugins", "-noautosave",
                    "-video", "none", "-sound", "none", "-nothrottle", "-frameskip", "0",
                    "-cfg_directory", "cfg", "-nvram_directory", "nvram",
                    "-snapshot_directory", ".", "-seconds_to_run", str(frames // 60 + 3),
                    "-autoboot_delay", "0", "-autoboot_script", str(SCRIPT),
                ],
                cwd=scratch, env=env, capture_output=True, text=True,
                timeout=max(30, frames // 30),
            )
            if result.stderr:
                print(result.stderr.rstrip())
            result.check_returncode()
            trace = scratch / "trace.csv"
            with trace.open(newline="", encoding="ascii") as stream:
                reader = csv.DictReader(stream)
                rows = list(reader)
            if tuple(reader.fieldnames or ()) != FIELDS or len(rows) != frames:
                raise ValueError(f"Trace incomplète pour {scenario}")
            for frame, row in enumerate(rows):
                if int(row["frame"]) != frame or any(
                    len(bytes.fromhex(row[key])) != size for key, size in REGISTER_SIZES.items()
                ):
                    raise ValueError(f"Trace invalide à la frame {frame} ({scenario})")
            probe = None
            if probes:
                probe = scratch / "probe.csv"
                with probe.open(newline="", encoding="ascii") as stream:
                    probe_rows = list(csv.reader(stream))
                sizes = [
                    2 * (int(last, 16) - int(first, 16) + 1)
                    for first, last in (item.split("-") for item in probes)
                ]
                if (
                    probe_rows[:1] != [["frame", *probes]]
                    or [row[0] for row in probe_rows[1:]] != [str(i) for i in range(args.probe_from, frames)]
                    or any([len(value) for value in row[1:]] != sizes for row in probe_rows[1:])
                ):
                    raise ValueError(f"Sonde incomplète pour {scenario}")
            snapshots = []
            if args.snap_every:
                snapshots = [
                    scratch / f"frame-{frame:05d}.png"
                    for frame in range(args.snap_from, frames, args.snap_every)
                ]
                if any(not snapshot.is_file() for snapshot in snapshots):
                    raise ValueError(f"Captures d'écran incomplètes pour {scenario}")
            captures.append((scenario, frames, trace, snapshots, probe))
        for scenario, frames, trace, snapshots, probe in captures:
            target = output / f"{scenario}.csv"
            trace.replace(target)
            if probe:
                probe.replace(output / f"{scenario}-probe.csv")
            if snapshots:
                pictures = output / f"{scenario}-snapshots"
                pictures.mkdir(exist_ok=True)
                for snapshot in snapshots:
                    snapshot.replace(pictures / snapshot.name)
            manifest = work / f"{scenario}.json"
            manifest.write_text(json.dumps(
                dict(
                    metadata, scenario=scenario, frames=frames,
                    snapshots=[snapshot.name for snapshot in snapshots],
                ),
                indent=2, ensure_ascii=False,
            ) + "\n", encoding="utf-8")
            manifest.replace(output / manifest.name)
            print(f"{frames} frames | {target}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=Path(r"D:\mame\mame.exe"))
    parser.add_argument("--rom-dir", type=Path, default=ROOT)
    parser.add_argument("--scenario", choices=SCENARIOS, action="append")
    parser.add_argument("--replay", type=Path, help="CSV des changements de commandes.")
    parser.add_argument("--frames", type=int)
    parser.add_argument("--snap-every", type=int, default=0, help="Intervalle des captures PNG, 0 pour désactiver.")
    parser.add_argument("--snap-from", type=int, default=0, help="Index de la première capture PNG.")
    parser.add_argument(
        "--probe", type=probe_range, action="append",
        help="Adresse ou plage hexadécimale à relever à chaque frame, par exemple 8005 ou 8222-8232.",
    )
    parser.add_argument("--probe-from", type=int, default=0, help="Index de la première frame de la sonde.")
    parser.add_argument("--output", type=Path, default=ROOT / ".reference")
    options = parser.parse_args()
    if options.frames is not None and options.frames < 1:
        parser.error("--frames doit être positif")
    if options.replay and (options.scenario or options.frames is None):
        parser.error("--replay exige --frames et s'utilise seul, sans --scenario")
    if options.snap_every < 0:
        parser.error("--snap-every doit être positif ou nul")
    if options.snap_from < 0:
        parser.error("--snap-from doit être positif ou nul")
    if options.probe_from < 0:
        parser.error("--probe-from doit être positif ou nul")
    capture(options)
