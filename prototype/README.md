# Guide de SwarmAttack

Décompressez la [version Windows x64](https://github.com/Kraran/SwarmAttack/releases/tag/v0.2.1) et ouvrez `SwarmAttack.exe`.

| Action | Clavier | Manette |
| --- | --- | --- |
| Jouer en solo, tirer, freiner pendant l’amarrage | Espace | A |
| Jouer à deux en alternance | 2 | Y |
| Déplacer le module | ←/→ ou Q/D | Stick gauche ou croix |
| Mettre en pause ou reprendre | Échap | Start |
| Choisir et valider dans la pause | ↑/↓ et Entrée | Croix et A |
| Revenir à l’accueil depuis la pause | T | B |
| Recommencer | R | |
| S’entraîner à l’amarrage | F2 | |
| Régler le seuil de la réserve depuis l’accueil | F3 | |
| Activer ou couper le son | F5 | |
| Alterner entre paysage et portrait | F10 | |
| Alterner entre plein écran et fenêtré | F11 | |
| Activer le diagnostic visuel | F1 | |

Le menu de pause propose « Reprendre », « Accueil » et « Quitter ». La souris permet également de choisir ces options.

## En jeu

Le cycle compte dix vagues et deux amarrages. Les premières formations comportent des rotors en deux demi-coques, puis viennent les chasseurs à pinces et les intercepteurs. Les météorites des vagues 7 et 8 descendent en diagonale. Les capsules des deux dernières vagues zigzaguent avant de plonger.

Les modules assemblés élargissent les possibilités de tir. En duo, chacun joue à son tour avec ses propres vies et son score. Les réglages et les cinq meilleurs scores sont conservés dans `%APPDATA%\Godot\app_userdata\SwarmAttack\arcade.cfg`.

Le pas logique est de 16,5 ms. Le rendu interpole les positions et suit le rafraîchissement de l’écran via la VSync. La composition paysage est prévue pour 1920 × 1080. F1 affiche les positions et les zones de collision du diagnostic.

## Développement

Ouvrez [project.godot](project.godot) dans Godot 4.7.2 standard. Le [lanceur Windows](../Lancer%20le%20prototype.cmd) utilise l’exécutable Godot placé dans `.tools/godot-4.7.2`.

Pour produire l’archive Windows, placez le modèle d’export `windows_release_x86_64.exe` dans `.tools/godot-4.7.2/templates` et lancez depuis la racine.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

L’archive produite se trouve dans `dist/SwarmAttack-Windows-x64.zip`.

## Tests

Importez le projet avant la première exécution des tests. Depuis la racine, en remplaçant `$godot` par le chemin de l’exécutable console, lancez les onze suites.

```powershell
& $godot --headless --editor --import --path prototype
foreach ($test in Get-ChildItem prototype/tests/test_*.gd, prototype/tests/smoke.gd) {
    & $godot --headless --path prototype --script "res://tests/$($test.Name)"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

La suite de livraison joue deux amarrages et atteint le deuxième cycle. Les tests de combat couvrent 18 trajectoires et 1 405 points de contrôle. Les [outils de trace](../tools/arcade/README.md) servent au diagnostic des mouvements et des collisions.
