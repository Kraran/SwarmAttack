# SwarmAttack — Plan de développement

SwarmAttack est un jeu de défense orbitale pour Windows. Le joueur traverse des vagues de formations ennemies, manœuvre dans des champs de météorites et assemble jusqu’à trois modules pour faire évoluer son armement.

## Socle jouable

| Domaine | État |
| --- | --- |
| Boucle de jeu | Dix vagues, deux amarrages, passage au cycle suivant, vies et scores |
| Modes | Solo, duo local en alternance et entraînement à l’amarrage |
| Affichage | Rendu 3D chromé, VSync, interpolation entre pas logiques, paysage et portrait |
| Son | Bruitages et jingles arcade, pause et réglage du son |
| Livraison | [Archive Windows x64 et guide utilisateur](prototype/README.md) |

## Architecture

- Godot 4.7.2 standard, GDScript, moteur de rendu Compatibility.
- La simulation règle collisions, points, formes de tir et transitions à pas fixe. La présentation applique l’interpolation sur les mouvements du vaisseau, des ennemis et des modules d’amarrage.
- Les coques et effets de propulsion sont construits dans le projet. Les bruitages et jingles actuels proviennent de captures arcade.
- Les tests sans affichage couvrent le combat, les amarrages, le duo, les records, le rendu interpolé et une partie jusqu’au cycle suivant.

## Suite du développement

1. Étoffer les formations et les comportements propres à chaque famille ennemie, puis mesurer la difficulté sur des parties complètes.
2. Affiner la lisibilité du combat, des effets et des amarrages sur les compositions paysage et portrait.
3. Enrichir l’identité sonore et équilibrer les niveaux des tirs, impacts et jingles en partie.

Avant chaque livraison, exécuter les suites Godot, tester le clavier et la manette et vérifier le lancement de l’exécutable extrait de l’archive.
