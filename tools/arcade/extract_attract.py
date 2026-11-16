"""Extrait la démo d'attraction d'une sonde MAME vers prototype/attract_demo_data.gd.

Usage : python tools/arcade/extract_attract.py .reference/pr10e-attract/mouncrst/attract-probe.csv

La sonde doit couvrir 8000-83ff depuis la frame 0 (scénario attract). La démo
commence à la première frame où 0x8097 passe à 3 et finit quand il revient à 0.
Les frames figées (0x8005 inchangé) sont sautées : les indices de la table sont
des images de boucle, comme les constantes du prototype.
"""

import base64
import csv
import sys
import textwrap
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "prototype" / "attract_demo_data.gd"
VISUALS = ROOT / "prototype" / "attract_visual_data.gd"
FIELDS = ("loop", "x", "y", "lives", "flag", "screen", "step", "clock", "module_i", "module_ii", "module_iii", "volley")
MODULE_OFFSET = 26
STYLE_OFFSET = 32
DIVING_OFFSET = 33
THRUST_OFFSET = 34
VISUAL_STRIDE = 35


def main(path):
    trace_path = Path(path).with_name("attract.csv")
    with trace_path.open(newline="", encoding="ascii") as stream:
        video = {int(row["frame"]): row for row in csv.DictReader(stream)}
    rows = {}
    with open(path, newline="", encoding="ascii") as stream:
        reader = csv.reader(stream)
        if next(reader) != ["frame", "8000-83ff"]:
            raise SystemExit("Sonde 8000-83ff attendue")
        for frame, data in reader:
            rows[int(frame)] = bytes.fromhex(data)
    frames = sorted(rows)
    start = next(f for f in frames if f > 0 and rows[f][0x97] == 3 and rows[f - 1][0x97] == 0)
    end = next(f for f in frames if f > start and rows[f][0x97] == 0)
    table, previous, loop = [], None, 0
    visual_frames = bytearray()
    for frame in range(start, end + 1):
        ram, before = rows[frame], rows[frame - 1]
        if frame > start:
            if ram[0x05] == before[0x05]:
                continue
            loop += 1
        volley = int(ram[0x163] == 1 and before[0x163] == 0)
        state = (ram[0x22B], ram[0x22C], ram[0x97], ram[0x04], ram[0x1D], ram[0x9B],
                 ram[0x230] * 256 + ram[0x231], ram[0x140], ram[0x145], ram[0x14A])
        if state != previous or volley:
            table.append((loop, *state, volley))
        previous = state
        if frame < end:
            visual_frames.extend(visual_frame(ram, video[frame]))
    lines = [
        "# Généré par tools/arcade/extract_attract.py depuis la sonde pr10e-attract.",
        f"# Démo de la frame {start} à la frame {end} : {end - start} images murales, {loop} images de boucle.",
        "# Une ligne par changement : " + ", ".join(FIELDS) + ".",
        "# x, y : 0x822b, 0x822c. lives : 0x8097. flag : 0x8004. screen : 0x801d.",
        "# step : 0x809b. clock : 0x8230-0x8231 (BCD). module_* : 0x8140, 0x8145, 0x814a.",
        "# volley : nouvelle volée (0x8163 passe de 0 à 1).",
        "extends RefCounted",
        "",
        f"const LENGTH := {loop}",
        "const ROWS := [",
    ]
    lines += ["\t[%s]," % ", ".join(str(value) for value in row) for row in table]
    lines.append("]")
    TARGET.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    encoded = base64.b64encode(zlib.compress(visual_frames, 9)).decode("ascii")
    visual_lines = [
        "# Généré par tools/arcade/extract_attract.py. Positions relevées, sans données de ROM.",
        "extends RefCounted",
        "",
        f"const STRIDE := {VISUAL_STRIDE}",
        f"const MODULE_OFFSET := {MODULE_OFFSET}",
        f"const STYLE_OFFSET := {STYLE_OFFSET}",
        f"const DIVING_OFFSET := {DIVING_OFFSET}",
        f"const THRUST_OFFSET := {THRUST_OFFSET}",
        f"const SIZE := {len(visual_frames)}",
        "const DEFLATE := (",
        *[f'\t"{line}" +' for line in textwrap.wrap(encoded, 110)],
        ')',
    ]
    visual_lines[-2] = visual_lines[-2].removesuffix(" +")
    VISUALS.write_text("\n".join(visual_lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(table)} lignes, {loop} images de boucle | {TARGET}")


def visual_frame(ram, video):
    record = bytearray([255, 0] * 16 + [255, 0, 0])
    for index in range(3):
        start = 0x140 + index * 5
        state, _, _, y, x = ram[start:start + 5]
        top = y + (0 if index == 2 else 8)
        center = x - (8 if index == 0 else 0)
        if state in (1, 2) and y > 0 and 0 <= center < 224 and top < 255:
            record[MODULE_OFFSET + 2 * index:MODULE_OFFSET + 2 * index + 2] = bytes((center, top))
            if state == 1 and ram[0x14F] == 1:
                record[THRUST_OFFSET] = index + 1
    if ram[0x23B] < 4 or ram[0x1D] & 0xC0:
        return record
    bank = ram[0x23A]
    sprites = bytes.fromhex(video["sprite_ram"])
    for index in range(8):
        x, _, palette, y = sprites[4 * index:4 * index + 4]
        active = ram[0x182 + 20 * index] != 0
        if active and palette != 12 and 8 <= x < 232 and 1 <= y < 248:
            record[2 * index:2 * index + 2] = bytes((x - 8, y + 8))
            if bank <= 4:
                record[STYLE_OFFSET] = 2 * bank + int(palette in (2, 5))
            if bank == 4 and ram[0x187 + 20 * index] == 3:
                record[DIVING_OFFSET] |= 1 << index
    bullets = bytes.fromhex(video["bullet_ram"])
    for index in range(5):
        x, y = bullets[4 * index + 1], bullets[4 * index + 3]
        if x >= 17 and y <= 251:
            record[16 + 2 * index:18 + 2 * index] = bytes((x - 17, 251 - y))
    return record


if __name__ == "__main__":
    main(sys.argv[1])
