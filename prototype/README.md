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
| Perte d’un module | Le compteur de vies (`0x8097`, départ à 3) baisse d’une unité après 289 images de boucle (161 + 127 + 1). Le module suivant monte en 378 images (25 caché, 136 de montée de y = 255 à 120, 137 d’arrêt à mi-hauteur, 80 de descente jusqu’à y = 200). Après la perte du module I, le II prend le relais. Après celle du vaisseau II + III, le II seul repart. La perte du II seul, dans le relevé, ramène le compteur à 0. | Recoupé sur les traces `pr1-suite` au rythme de `0x8005`. Les 292 images murales de la dernière perte viennent de 3 frames figées. |
| Modules II et III seuls | Tir double, écarté de 8 puis 12 unités de part et d’autre de l’axe. | Inchangé. |
| Vaisseau II + III | Tir alterné de deux paires, les deux pouvant voler ensemble. Premier appui : écart 12, y = 212. Appui suivant : écart 8, y = 195. Après une reprise, le premier groupe part. Un appui est refusé tant que son groupe est en vol. Un maintien commencé pendant le vol et poursuivi après la disparition ne déclenche pas de volée différée : un nouvel front d’appui est nécessaire. | `pr1-suite` (motif) et `pr2-held-fire` (maintien), au rythme de `0x8005`. Les projectiles `0x40` / `0x50` ne sont pas reproduits. |
| Amarrage | Après la vague 4, le module monte, le suivant arrive, puis l’approche se pilote avec inertie sous un chrono de 30 secondes. Réussite, collision ou temps écoulé, puis le combat reprend. | Approche du module II, voir ci-dessous. Reprise après amarrage recoupée sur `pr1-bonus`, `pr1-collision` et `pr1-timeout`. |

| Issue de l’amarrage II → III | Comportement du prototype | Source |
| --- | --- | --- |
| Réussite | Écran bonus 305 images, crédit du bonus, reprise en vaisseau II + III aligné à x = 112, puis vague à entrée large (vague 3). | `pr1-bonus` : `0x8004` bascule à 7417 et 7722, bonus 13 × 200 = 2600, première vague à 7753. |
| Collision | Dès l’explosion, `0x8097` baisse d’une unité. Attente 466 images, pas de bonus, reprise avec le module III seul à x = 112, vague à entrée large. | `pr1-collision` : explosion et baisse des vies à 7452, reprise à 7918, vague à 7950. |
| Chrono écoulé | Attente 183 images, pas de bonus, vies inchangées, reprise avec le module II seul recentré à x = 112, vague à entrée large. | `pr1-timeout` : chrono 00:0 à 7942, `0x822b` passe de 31 à 128 à 8125, vague à 8157. |
| Cycle suivant | Sans partenaire restant, après la vague 4, un nouveau cycle reprend à la vague 1. | Non relevé jusqu’à une vague terminée après amarrage : provisoire. |
| Hitbox II + III | Union du module II et du module III, ce dernier avec le plafond dy ≥ −3 (comme le II), pas le plafond solo −11. | `pr3-hitbox`, vaisseau immobile à x = 114 : raté du sprite 7 à (141, 204) aux frames 8233–8234 (`0x8004` = 0), contact à (140, 208) à 8235 (`0x8004` = 1). La zone du module III seul est inchangée. |
| Limites de déplacement II + III | Butée gauche à x = 14 (`0x822b` = 30). Butée droite à x = 200 (`0x822b` = 216). | `pr3-hitbox` : palier droit tenu 70 images (7810–7879) avec la droite enfoncée et `0x8004` = 0 ; palier gauche tenu 46 images (7974–8019). |
| Amarrage I + II, puis I + II vers III | Le modèle d’approche du module supérieur est réutilisé. Après une perte d’assemblage autre que II + III, seul le module supérieur repart. | Non relevé : provisoire. |
| Écran de fin | 31 images après la baisse à 0, puis 30 images de « JEU 1 TERMINE / ESSAYEZ A NOUVEAU / JEU TERMINE ». La démo n’est pas reproduite. | `pr1-suite` : 9313 → 9344 (31), 9344 → 9374 (30), puis 869 images de texte d’attract jusqu’à la démo à 10246 (932 images de boucle au total). |
| Projectiles 0x40 / 0x50 | Non reproduits. | Ils naissent à la reprise, ils ne sont pas des tirs résiduels : présents à 7723 (y = 96) et 8125 (y = 92), absents pendant l’écran de résultat et après une collision. Leur mécanisme exact reste à expliquer. |

La vue affiche le score, la vague, le nombre de cibles, les vies et la configuration du vaisseau. La grille, les zones de collision et les coordonnées s’affichent avec F1. Les formes restent celles d’une vue de diagnostic.

Les tests sans traces MAME se lancent ainsi, depuis la racine, avec Godot 4.7.2 :

```powershell
& $godot --headless --path prototype --script res://tests/smoke.gd
& $godot --headless --path prototype --script res://tests/test_post_docking.gd
& $godot --headless --path prototype --script res://tests/test_assembled_fire.gd
& $godot --headless --path prototype --script res://tests/test_assembled_limits.gd
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

La reprise après amarrage a été recoupée sur les captures `pr1-bonus`, `pr1-collision`, `pr1-timeout` et `pr1-suite`. Les comparateurs Jeutel existants n’ont pas été relancés : ces traces portent sur l’après-amarrage, pas sur l’approche. Les constantes encore provisoires sont listées dans le tableau ci-dessus.
