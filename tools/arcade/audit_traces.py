#!/usr/bin/env python3
"""Recherche, dans les relevés existants, des tirs ennemis, des fragments
d'objets en chute et des changements de rythme entre cycles.

Usage : python tools/arcade/audit_traces.py DOSSIER_SONDES

Pour chaque capture (replay.csv + replay-probe.csv) et chaque valeur de
0x809b en jeu (0x02 à 0x1f) :
- projectiles matériels (0x9860-0x987f, 8 x 4 octets, octet 3 = position de
  défilement) : créneaux utilisés et nombre de pas vers le bas (octet 3 qui
  diminue de moins de 16, hors valeur de repos 0xfc). Un tir ennemi descend ;
- rythme : images par pas de boucle (0x8005) ;
- objets en chute (0x09, 0x0a) : objets qui s'activent hors des huit positions
  d'apparition relevées (un fragment après un impact en serait un).
"""
import csv, glob, os, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_waves as A

FALL_SPAWNS = {(144, 80), (80, 128), (64, 32), (192, 112), (176, 32), (80, 64), (32, 48), (160, 96)}


def audit(trace, probe):
    P = A.load(probe)
    used = collections.defaultdict(set)
    down = collections.Counter()
    frames = collections.Counter()
    steps = collections.Counter()
    fragments = collections.Counter()
    prev = None
    with open(trace) as f:
        for row in csv.DictReader(f):
            fr = int(row['frame'])
            b = bytes.fromhex(row['bullet_ram'])
            if fr in P and fr - 1 in P and 2 <= P[fr][0x9b] <= 0x1f:
                lvl = P[fr][0x9b]
                frames[lvl] += 1
                if P[fr][5] != P[fr - 1][5]:
                    steps[lvl] += 1
                for i in range(8):
                    if b[4 * i:4 * i + 4] != b'\0\0\0\0' and b[4 * i + 3] != 0xfc:
                        used[lvl].add(i)
                    if prev is not None:
                        a, c = prev[4 * i + 3], b[4 * i + 3]
                        if a and c and 0xfc not in (a, c) and 0 < a - c < 16:
                            down[lvl] += 1
                if lvl in (9, 10):
                    for k in range(8):
                        o = 0x170 + 20 * (k + 1)
                        if P[fr][o + 5] and not P[fr - 1][o + 5] and not P[fr - 1][o + 3] \
                                and A.pos(P[fr], k) not in FALL_SPAWNS and A.pos(P[fr - 1], k) == (0, 0):
                            fragments[lvl] += 1
            prev = b
    return used, down, frames, steps, fragments


def main():
    root = sys.argv[1]
    for trace in sorted(glob.glob(os.path.join(root, '**', 'mouncrst', 'replay.csv'), recursive=True)):
        probe = trace.replace('replay.csv', 'replay-probe.csv')
        if not os.path.exists(probe):
            continue
        used, down, frames, steps, fragments = audit(trace, probe)
        name = A.name(trace)
        for lvl in sorted(frames):
            print('%-34s 0x%02x  projectiles %-12s descentes %3d  images/pas %.3f  fragments %d' % (
                name, lvl, ''.join(str(i) for i in sorted(used[lvl])) or '-', down[lvl],
                frames[lvl] / max(1, steps[lvl]), fragments[lvl]))


if __name__ == '__main__':
    main()
