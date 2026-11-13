# Jalon 0 — Premiers relevés arcade

## Environnement

- MAME 0.286 est disponible dans `D:\mame`. Python exécute le collecteur avec sa bibliothèque standard.
- Godot 4.7.2 standard est installé en version portable dans `.tools/godot-4.7.2/`. La commande `--version` renvoie `4.7.2.stable.official.ed1daf0bf`. Le SHA-256 de l’archive correspond à celui de la release officielle. [Release Godot](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
- **Moune Creste de Jeutel (`mouncrst`) est l’unique étalon.** L’archive `mouncrst.zip` a été vérifiée avec `-verifyroms`. [Pilote MAME](https://github.com/mamedev/mame/blob/mame0286/src/mame/galaxian/galaxian.cpp)

## Reproduire les mesures

Depuis la racine de SwarmAttack, dans PowerShell.

```powershell
python .\tools\arcade\capture.py
python .\tools\arcade\capture.py --output .reference\repeat
```

Le script lance MAME dans un dossier temporaire, avec les réglages de borne par défaut. Chaque scénario démarre à froid et possède son CSV et son manifeste JSON dans `.reference/mouncrst/`. Le manifeste consigne la version de MAME, le SHA-256 de la ROM, les réglages DIP, les paramètres d’affichage et la liste des PNG produits. Les scénarios de partie insèrent un crédit et démarrent en solo. Le scénario `attract` laisse jouer la démonstration sans entrée.

Les numéros ci-dessous sont des indices locaux au collecteur, à partir de sa première notification de frame. Les champs d’entrée décrivent les commandes programmées entre deux notifications. Les registres sont lus après l’intervalle correspondant. Comparer les traces avec le même script et le même réglage de borne.

## Déplacement et tir

| Scénario | Entrées après le démarrage | Résultat observé sur Jeutel |
| --- | --- | --- |
| `idle` | Aucune | Premier groupe d’ennemis enregistré dans les registres de sprites à la frame 571 après l’animation de départ. |
| `movement` | Gauche 535–604, droite 615–784 | Premier mouvement à la frame 540. Incréments de ±2 lorsqu’il y a déplacement. Quelques frames intermédiaires gardent la position. Les valeurs brutes atteignent `0x16` à gauche (frame 595) et `0xd0` à droite (frame 712). |
| `opposed` | Gauche et droite 570–589 | Le vaisseau part à gauche et termine le déplacement à x = 74 dans ce scénario. |
| `fire` | Tir maintenu 535–814 | Un seul tir. Il apparaît à la frame 540 et le registre se désactive à la frame 586. |
| `fire_tap` | Plusieurs appuis entre 535 et 804 | Cinq tirs aux frames 540, 601, 676, 752 et 801. L’appui 554–557, alors que le premier projectile est actif, ne déclenche pas de nouveau tir. |
| `fire_busy` | Appuis 535–547, 554–630 et 640–647 | Le deuxième appui, commencé pendant le premier tir et maintenu au-delà de sa disparition, ne déclenche pas de tir différé. Le troisième déclenche un tir à la frame 641. |

Les PNG MAME sont en 224 × 768 après rotation. Un pixel horizontal et trois pixels verticaux correspondent à une unité logique. Le nez du module I en jeu se trouve à y = 200. Son x vaut le registre de défilement `0x9832` moins 8 sur les frames contrôlées. Les captures montrent le module au centre (x = 112) et aux deux limites (x = 14 et x = 200). Au centre, le premier tir est visible à x = 111 et son bord supérieur part de y = 183. Il remonte de quatre unités logiques par frame. Les pauses observées dans le déplacement restent à expliquer avant une comparaison à la frame sur une partie entière.

## Amarrage de démonstration

La démonstration Jeutel présente les modules I et II et réussit l’amarrage. Le chrono affiche `30:0` à la frame 1710. Le dernier affichage avant le bonus est `10:7` à la frame 2685. L’écran passe au bonus à la frame 2686 et affiche le calcul complet `10 × 100 = 1000` à la frame 2687. La démo montre ensuite les deux modules assemblés, puis reprend le combat.

Capturer la démonstration avec un PNG toutes les 120 frames, puis le contact image par image dans un dossier séparé.

```powershell
python .\tools\arcade\capture.py --scenario attract --snap-every 120
python .\tools\arcade\capture.py --scenario attract --frames 2721 --snap-from 2660 --snap-every 1 --output .reference\docking
```

## Amarrage en partie solo

Le [replay solo](replays/solo-docking.csv) part d’une mise sous tension, franchit les vagues et atteint un amarrage des modules II et III après la perte du module I. Le CSV contient l’état des cinq commandes à chaque changement, à partir de la frame 0. Chaque état reste appliqué jusqu’à la ligne suivante.

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking.csv --frames 7481 --snap-from 7408 --snap-every 1 --output .reference\solo-success
```

Sur le parcours enregistré, le module II devient contrôlable pendant l’approche. Une impulsion vers la droite aux frames 6750–6757 inverse la dérive. Elle persiste après le relâchement. Pour le bouton, les essais divergent à la frame 6750 après des entrées identiques. À la frame 7100, le registre vertical du même module vaut 196 en laissant les commandes au repos et 70 en maintenant le bouton. Le bouton freine puis inverse la descente, avec une remontée jusqu’à la butée dans cet essai. Le replay réussi utilise un appui de 150 frames à partir de 6790.

À la frame 7413, le module en approche est à x = 116 dans le registre de la moitié gauche de son sprite. Le module cible est à x = 112 dans le registre homologue. À la frame 7417, le jeu aligne l’ensemble à x = 112 et passe au bonus. Le dernier chrono affiché est `13:5`. La frame 7418 affiche `13 × 200 = 2600`. À la reprise, le score passe de 1 280 à 3 880. Les deux exécutions comparées produisent la même trace sur les 7 481 premières frames. Les valeurs de position de cette section utilisent les coordonnées des registres de sprites.

Les variantes suivantes se reproduisent en copiant le replay et en remplaçant l’index de sa dernière ligne, qui marque le relâchement du bouton. Enregistrer au moins 7 531 frames.

| Frame de relâchement | Position dans la zone de contact | Issue |
| --- | --- | --- |
| 6910 | x = 105 à y = 202, soit 7 unités à gauche | Collision. Le module atteint x = 106 à y = 204, trop tard pour s’amarrer. |
| 6912 | x = 106 à y = 202, soit 6 unités à gauche | Amarrage. |
| 6946 | x = 118 à y = 201, soit 6 unités à droite | Amarrage. |
| 6948 | x = 119 à y = 201, soit 7 unités à droite | Collision. |

La tolérance de 6 unités est vérifiée pour ce contact entre les modules II et III. Les seuils de l’assemblage I et II en partie et les effets d’autres vitesses d’approche restent à mesurer.

## Sonde de RAM

`--probe` ajoute un fichier `<scénario>-probe.csv` à côté de la trace. Chaque option donne une adresse ou une plage hexadécimale du programme, lue à la fin de chaque frame à partir de `--probe-from`. Le manifeste consigne les plages et la frame de départ.

```powershell
python .\tools\arcade\capture.py --scenario movement --probe 8005 --output .reference\cadence
```

| Adresse | Contenu observé |
| --- | --- |
| `0x8005` | Compteur de boucle, incrémenté à chaque passage du gestionnaire d’interruption. `0x8006` reçoit la retenue. |
| `0x8222`, `0x8223` | Vitesses horizontale et verticale du module en approche, de `0x40` à `0xc0`. |
| `0x8224`, `0x8225` | Attentes avant le prochain pas horizontal et vertical. |
| `0x822b`, `0x822c` | Position horizontale et verticale du module en approche, décalées de 16 par rapport aux registres de sprites. |
| `0x8230`, `0x8231` | Chrono d’amarrage en BCD, secondes puis dixièmes de 10 à 1. |
| `0x8232` | Non nul une fois l’amarrage conclu. |

## Cadence de la boucle

Le compteur `0x8005` ne progresse pas à toutes les frames. Sur les deux approches d’amarrage relevées, il reste figé 17 et 9 fois en 750 frames. Ces frames figées sont les pauses observées dans le déplacement.

Le désassemblage montre un ordonnanceur de tâches piloté par l’interruption de trame. Le gestionnaire en `0x0066` coupe l’interruption par `0xB000`, puis poursuit en `0x00DE`. Il incrémente le compteur, appelle `0x039F` à chaque passage et `0x047A` un passage sur quatre, ce qui correspond au tick de contrôle de l’amarrage. L’ordonnanceur en `0x0229` réarme ensuite l’interruption et reprend une tâche. Une trame qui survient pendant que l’interruption est coupée est perdue, ce qui explique un compteur figé quand le traitement déborde. Le rythme dépend donc de la charge de la carte à chaque instant.

Pour comparer une séquence à la frame près, relever `0x8005` avec la trace et avancer la simulation à chaque incrément du compteur.

## Après l’amarrage

Trois replays partent du même parcours solo et divergent pendant l’approche du module II vers le module III. Les captures relèvent toute la RAM (`--probe 8000-83ff`) et une image toutes les 20 frames.

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-suite.csv --frames 9600 --probe 8000-83ff --snap-from 7400 --snap-every 20 --output .reference\suite
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-collision.csv --frames 9600 --probe 8000-83ff --probe-from 6100 --snap-from 7440 --snap-every 20 --output .reference\collision
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-held.csv --frames 9600 --probe 8000-83ff --probe-from 6100 --snap-from 7900 --snap-every 20 --output .reference\timeout
```

| Cas | Déroulement observé |
| --- | --- |
| Amarrage réussi | Contact à la frame 7417. Écran `BONUS 13 × 200 = 2600` et `BRAVO !!` pendant 305 frames. Le combat reprend à la frame 7723 avec le module II posé sur le module III, et le score passe à 3 880. |
| Collision | Le module II explose à la frame 7452. `SORRY NO BONUS` s’affiche, puis le combat reprend à la frame 7918 avec le module III seul. |
| Chrono écoulé | Le chrono atteint `00:0` à la frame 7942. Le combat reprend à la frame 8125 avec le module II seul. |

`0x8097` compte les modules restants. Il vaut 3 au départ et baisse d’une unité par vaisseau détruit, quel que soit le nombre de modules assemblés.

| Événement du replay de suite | Frame | `0x8097` |
| --- | --- | --- |
| Module I détruit | 5215 | 3 → 2 à la frame 5504 |
| Vaisseau II + III détruit | 8090 | 2 → 1 à la frame 8379 |
| Module II seul détruit | 9021 | 1 → 0 à la frame 9313 |

Après une destruction, `0x8004` reste à 1 pendant 161 frames, puis 127 frames s’écoulent avant la baisse du compteur. Le module suivant monte alors du bas de l’écran, s’immobilise à mi-hauteur et redescend à sa place avant la reprise. Après la destruction du vaisseau II + III, c’est le module II seul qui repart. À zéro, la carte affiche `JEU 1 TERMINE`, `ESSAYEZ A NOUVEAU` et `JEU TERMINE`, puis revient à la démonstration.

### Vaisseau II + III

Les lignes de défilement 26 à 28 portent la position et les lignes 29 et 30 la même valeur plus 8. La ligne 26 va de `0x0e` à `0xc0` entre les deux butées.

Le tir alterne entre deux groupes, et les deux peuvent être en vol ensemble. Un appui tire un projectile central à l’abscisse de la ligne 26 plus 4, depuis l’ordonnée de registre `0x27`. L’appui suivant tire une paire aux abscisses de la ligne 29 et de la ligne 29 plus 16, depuis `0x38`. Tous montent de 4 par frame.

À la reprise de la première capture, deux projectiles sont apparus aux abscisses `0x40` et `0x50` sans appui sur le bouton. Leur origine reste à expliquer.
