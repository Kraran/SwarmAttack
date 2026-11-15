"""Extrait la démo d'attraction d'une sonde MAME vers prototype/attract_demo_data.gd.

Usage : python tools/arcade/extract_attract.py .reference/pr10e-attract/mouncrst/attract-probe.csv

La sonde doit couvrir 8000-83ff depuis la frame 0 (scénario attract). La démo
commence à la première frame où 0x8097 passe à 3 et finit quand il revient à 0.
Les frames figées (0x8005 inchangé) sont sautées : les indices de la table sont
des images de boucle, comme les constantes du prototype.
"""

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "prototype" / "attract_demo_data.gd"
FIELDS = ("loop", "x", "y", "lives", "flag", "screen", "step", "clock", "module_i", "module_ii", "module_iii", "volley")


def main(path):
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
    print(f"{len(table)} lignes, {loop} images de boucle | {TARGET}")


if __name__ == "__main__":
    main(sys.argv[1])
