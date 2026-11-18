# Outils de trace

Ces outils de diagnostic utilisent des traces CSV locales. Les suites Godot se lancent avec les données de test du dépôt. Les modes de capture et d’audit avancé attendent des fichiers fournis par le développeur.

| Outil | Usage |
| --- | --- |
| `capture.py` | Enregistre les entrées, les sprites et des sondes RAM avec un scénario ou un replay |
| `audit_waves.py` | Rejoue les trajectoires à partir des CSV `replay-probe.csv` qui contiennent la plage `8000-83ff` |
| `audit_traces.py` | Inspecte les projectiles, la cadence et les objets des traces existantes |
| `extract_attract.py` | Régénère les données du mode démo à partir d’une sonde d’attraction |
| `capture_enemy_audio.py` | Enregistre les sons, les écritures des registres et les commandes acceptées pendant un replay MAME |
| `extract_enemy_audio.py` | Capture séparément les cinq vols, cinq impacts, l’annonce d’amarrage et le bonus avec le pilote sonore analysé |

## Exemples

```powershell
python tools/arcade/capture.py --machine $machine --rom-dir $roms --scenario fire_tap --output .reference
python tools/arcade/capture_enemy_audio.py --machine $machine --rom-dir $roms --replay $replay --output .reference/enemy-audio-mame
python tools/arcade/extract_enemy_audio.py --machine $machine --rom-dir $roms --capture .reference/enemy-audio-isolated --output prototype/audio/arcade
python tools/arcade/audit_waves.py .reference --godot $godot
```

Les entrées échantillonnées et les trames RAM reposent sur les adresses du format de trace. Le paramètre `--machine` identifie le programme exécuté dans MAME, dont le fichier ZIP doit être disponible dans `--rom-dir`.

Les outils sonores utilisent les adresses du programme localement analysé ; ils ne constituent pas un extracteur universel pour tous les bootlegs. Le [rapport sonore](../../RAPPORT_SONS_ENNEMIS.md) indique les correspondances vérifiées. L’extraction régénère les WAV indiqués dans `--output` ; les captures complètes et la ROM restent hors distribution.

Les comparateurs Godot `compare_arcade.gd` et `compare_docking.gd` acceptent les chemins des traces après `--`. Les exécuter seuls affiche les arguments attendus. L’audit des trajectoires accepte `--checkpoints` pour régénérer ses points de contrôle.
