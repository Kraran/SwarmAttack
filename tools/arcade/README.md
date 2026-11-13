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
