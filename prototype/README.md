# SwarmAttack — Prototype jusqu’à la reprise après amarrage

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
| Perte d’un module | Le compteur de vies (`0x8097`, départ à 3) baisse d’une unité après 288 images (161 + 127). L’animation d’entrée qui suit n’est pas encore relevée : la reprise est immédiate (`ENTRANCE_FRAMES = 0`, provisoire). Après la perte du module I, le II prend le relais. Après celle du vaisseau II + III, le II seul repart. À zéro, la partie se termine. | Délai avant la baisse du compteur et succession I → II, II + III → II : voir le [carnet](../tools/arcade/README.md). Les autres successions et l’entrée du module restent à valider. |
| Modules II et III | Tir double, écarté de 8 puis 12 unités de part et d’autre de l’axe. Le vaisseau assemblé II + III conserve ce tir pour l’instant. | Aucune pour l’instant. Le tir alterné relevé sur II + III sera aligné plus tard. |
| Amarrage | Après la vague 4, le module monte, le suivant arrive, puis l’approche se pilote avec inertie sous un chrono de 30 secondes. Réussite, collision ou temps écoulé, puis le combat reprend. | Approche du module II, voir ci-dessous. Reprise après amarrage : durées d’écran relevées, à recouper avec une trace complète. |

| Issue de l’amarrage II → III | Comportement du prototype | Source |
| --- | --- | --- |
| Réussite | Écran bonus 305 images, crédit du bonus, reprise en vaisseau II + III aligné à x = 112. | Relevés : contact 7417, reprise 7723, bonus 2 600. |
| Collision | Attente 466 images, pas de bonus, reprise avec le module III seul. Les vies sont inchangées. | Relevés : explosion 7452, reprise 7918. À confirmer si l’explosion coïncide avec le début de l’étape collision. |
| Chrono écoulé | Attente 183 images, pas de bonus, reprise avec le module II seul à son abscisse d’affichage (position provisoire). Les vies sont inchangées. | Relevés : chrono 00:0 à 7942, reprise 8125. |
| Cycle suivant | Sans partenaire restant, un nouveau cycle des quatre vagues reprend. Après un amarrage, le prototype reprend aussi à la vague 1. | Composition des vagues après amarrage non relevée : provisoire. |
| Hitbox II + III | Union des zones des modules II et III. | Non relevée : provisoire. |
| Limites de déplacement II + III | Conservées à x = 14 et x = 200. | La ligne 26 va de `0x0e` à `0xc0` : le report en unités logiques reste à caler. |
| Amarrage I + II, puis I + II vers III | Le modèle d’approche du module supérieur est réutilisé. Après une perte d’assemblage autre que II + III, seul le module supérieur repart. | Non relevé : provisoire. |
| Écran de fin | Passage immédiat à « partie terminée » quand le compteur tombe à 0. | La durée de `JEU 1 TERMINE` / `ESSAYEZ A NOUVEAU` n’est pas relevée. |

La vue affiche le score, la vague, le nombre de cibles, les vies et la configuration du vaisseau. La grille, les zones de collision et les coordonnées s’affichent avec F1. Les formes restent celles d’une vue de diagnostic.

Les tests sans traces MAME se lancent ainsi, depuis la racine, avec Godot 4.7.2 :

```powershell
& $godot --headless --path prototype --script res://tests/smoke.gd
& $godot --headless --path prototype --script res://tests/test_post_docking.gd
```

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

Deux replays suivent le même parcours solo jusqu’à l’approche du module II. [solo-docking.csv](../tools/arcade/replays/solo-docking.csv) réussit l’amarrage. [solo-docking-held.csv](../tools/arcade/replays/solo-docking-held.csv) maintient le bouton à partir de la frame 6750. La sonde relève, à partir de la frame 6700, l’état d’amarrage `0x8222–0x8232`, l’objet `0x8140–0x814e` et le compteur de boucle `0x8005`.

```powershell
$sonde = '--probe', '8222-8232', '--probe', '8140-814e', '--probe', '8005', '--probe-from', '6700'
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking.csv --frames 7450 @sonde --output .reference\dock-success
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-held.csv --frames 7450 @sonde --output .reference\dock-held

& $godot --headless --path prototype --script res://tests/compare_docking.gd -- `
    "$traces\dock-success\mouncrst" "$traces\dock-held\mouncrst"
```

Le comparateur avance le prototype d’un pas à chaque incrément du compteur de boucle Jeutel. Dans ces conditions, la position, les deux vitesses et le chrono du module II sont identiques à Jeutel sur 660 images pour l’amarrage réussi et 701 images avec le bouton maintenu. L’amarrage se produit à la frame 7417 avec un bonus de 2 600 points, comme sur la carte.

La boucle Jeutel saute certaines frames, 17 sur 750 dans le relevé réussi et 9 sur 750 avec le bouton maintenu, à des intervalles qui dépendent de la situation. Le [carnet de relevés](../tools/arcade/README.md) en décrit le mécanisme. Le prototype en temps réel ne reproduit pas ces sauts, par choix, et avance donc un peu plus vite que la carte. Restent à comparer la montée du module et l’arrivée du module cible avant la frame 6700, ainsi que l’amarrage des modules I et II.

La reprise après amarrage (écrans de résultat, vaisseau II + III, collision, expiration, baisse des vies) est codée d’après le [carnet de relevés](../tools/arcade/README.md). Elle n’est pas encore rejouée par un comparateur sur une trace `.reference`. Les constantes provisoires et les points à recouper sont listés dans le tableau ci-dessus.
