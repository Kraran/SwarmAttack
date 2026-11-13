# SwarmAttack — Prototype du parcours jusqu’à l’amarrage

Sous Windows, ouvrir [Lancer le prototype.cmd](../Lancer%20le%20prototype.cmd). Le lanceur utilise l’installation portable de Godot dans `.tools`. Le projet Godot s’ouvre avec [project.godot](project.godot).

| Action | Commande |
| --- | --- |
| Déplacer le module | Flèches gauche et droite, Q et D, stick gauche ou croix de la manette |
| Tirer | Espace ou bouton A |
| Recommencer | R |
| Essai d’amarrage direct | F2 |
| Freiner puis remonter pendant l’amarrage | Espace ou bouton A |
| Masquer ou afficher la grille et les mesures | F1 |

Le prototype démarre aux commandes du module I sur le terrain de 224 × 256 unités logiques. L’horloge applique un pas de 16,5 ms.

| Étape | Comportement du prototype | Validation contre Jeutel |
| --- | --- | --- |
| Vagues 1 et 2 | Quatre paires entrent en formation. Chaque moitié détruite rapporte 50 points. Les survivants se séparent et plongent. | Module I et première vague, voir ci-dessous. |
| Vagues 3 et 4 | Huit cibles entrent en courbe large et rapportent 30 points chacune. | Aucune pour l’instant. |
| Perte d’un module | Le module suivant prend le relais après 120 images, face aux cibles restantes. La perte du module III termine la partie. | Aucune pour l’instant. |
| Modules II et III | Tir double, écarté de 8 puis 12 unités de part et d’autre de l’axe. | Aucune pour l’instant. |
| Amarrage | Après la vague 4, le module monte, le suivant arrive, puis l’approche se pilote avec inertie sous un chrono de 30 secondes. Réussite, collision ou temps écoulé. | Approche du module II, voir ci-dessous. |

La vue affiche le score, la vague et le nombre de cibles. La grille, les zones de collision et les coordonnées s’affichent avec F1. Les formes restent celles d’une vue de diagnostic. Le prototype s’arrête après le premier amarrage.

## Comparaison avec Jeutel

Depuis la racine de SwarmAttack, produire les traces MAME puis lancer le comparateur Godot.

```powershell
python .\tools\arcade\capture.py --scenario idle --scenario movement --scenario opposed --scenario fire --scenario fire_tap --scenario fire_busy
python .\tools\arcade\capture.py --replay tools\arcade\replays\module-i-combined.csv --frames 596 --output .reference\module-i-combined
python .\tools\arcade\capture.py --replay tools\arcade\replays\module-i-expiry.csv --frames 610 --output .reference\module-i-expiry

$godot = '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$traces = (Resolve-Path .reference).Path
& $godot --headless --path prototype --script res://tests/compare_jeutel.gd -- `
    "$traces\mouncrst" `
    "$traces\module-i-combined\mouncrst\replay.csv" `
    "$traces\module-i-expiry\mouncrst\replay.csv"
```

Les cinq fenêtres de tir sans collision correspondent à Jeutel sur 699 images au total. Le comparateur vérifie aussi les déplacements enregistrés et rapporte les écarts de position liés aux pauses de déplacement dans MAME. Dans le test isolé de traversée, le déplacement à chaque pas produit un écart temporaire de 12 pixels logiques au maximum. Les deux limites mesurées sont atteintes. La cadence du module reste à affiner pour les parties complètes.

Les positions des huit cibles correspondent sur les 87 premières images de la formation. Deux séquences de tir touchent les mêmes cibles que Jeutel. Les impacts des frames 575 et 778 correspondent exactement. L’impact Jeutel de la frame 699 se produit à la frame 698 dans le prototype. Des cas de contact vérifient les limites de collision du module I. Un essai automatisé a terminé la manche avec 400 points. La cadence après l’ouverture reste approximative, car les interruptions Jeutel varient selon la situation. Les trajectoires longues et les plongeons tardifs demandent encore un relevé plus complet.

## Comparaison de l’amarrage

Les relevés `dock-probe-success` et `dock-probe-held` suivent le [replay solo](../tools/arcade/replays/solo-docking.csv) avec, à partir de la frame 6700, la RAM `0x8222–0x8232`, l’objet `0x8140–0x814e` et le compteur de boucle `0x8005`. Ils proviennent d’une variante locale de `trace.lua` conservée dans `.reference`. Cette sonde reste à intégrer au collecteur.

```powershell
& $godot --headless --path prototype --script res://tests/compare_docking.gd -- `
    "$traces\dock-probe-success" "$traces\dock-probe-held"
```

Le comparateur avance le prototype d’un pas à chaque incrément du compteur de boucle Jeutel. Dans ces conditions, la position, les deux vitesses et le chrono du module II sont identiques à Jeutel sur 660 images pour l’amarrage réussi et 701 images avec le bouton maintenu. L’amarrage se produit à la frame 7417 avec un bonus de 2 600 points, comme sur la carte.

Deux limites restent ouvertes. La boucle Jeutel saute certaines frames, 17 sur 750 dans le relevé réussi et 9 sur 750 avec le bouton maintenu, à des intervalles qui dépendent de la situation. Le prototype en temps réel ne reproduit pas ces sauts et avance donc un peu plus vite que la carte. La montée du module et l’arrivée du module cible avant la frame 6700 ne sont pas encore comparées, de même que l’amarrage des modules I et II.
