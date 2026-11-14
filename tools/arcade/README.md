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
| Amarrage réussi | Contact à la frame 7417 (`0x8004` et `0x8232` basculent). Écran `BONUS 13 × 200 = 2600` et `BRAVO !!` pendant 305 images, sans frame figée. `0x8004` retombe à 7722. Le combat reprend à 7723 avec le module II posé sur le module III, recentré à x = 112, et le score passe de 1 280 à 3 880. Une vague à entrée large apparaît à 7753. |
| Collision | Le module II explose à la frame 7452. Au même instant, `0x8097` passe de 2 à 1. `SORRY NO BONUS` s’affiche, puis le combat reprend à 7918 avec le module III seul à x = 112 (466 images, sans frame figée). Une vague à entrée large apparaît à 7950. |
| Chrono écoulé | Le chrono atteint `00:0` à la frame 7942 (`0x8004` passe à 1, `0x822b,0x822c` = 31,47). Les vies restent à 2. À 8125, le combat reprend avec le module II seul recentré (`0x822b,0x822c` = 128,216, soit x = 112). Délai de 183 images, sans frame figée dans l’intervalle. Une vague à entrée large apparaît à 8157. |

`0x8097` compte les vaisseaux restants. Il vaut 3 au départ et baisse d’une unité par vaisseau détruit en combat, et aussi dès l’explosion d’une collision d’amarrage. L’expiration du chrono ne le fait pas baisser.

| Événement du replay de suite | Frame | `0x8097` |
| --- | --- | --- |
| Module I détruit | 5215 | 3 → 2 à la frame 5504 |
| Vaisseau II + III détruit | 8090 | 2 → 1 à la frame 8379 |
| Module II seul détruit | 9021 | 1 → 0 à la frame 9313 |

Après une destruction en combat, `0x8004` reste à 1 pendant 161 images, puis 127 images s’écoulent, puis une impulsion d’une image précède la baisse du compteur, soit 289 images de boucle. Sur la perte du module II, l’écart mural vaut 292 images à cause de 3 frames figées (`0x8005` immobile). Le prototype, qui avance à pas régulier, retient 289.

Le module suivant apparaît 25 images après la baisse, monte de y = 255 à y = 120 en 136 images, s’arrête 137 images de boucle à mi-hauteur, puis redescend à y = 200 en 80 images. La reprise du combat a lieu 378 images de boucle après la baisse (380 ou 382 images murales selon les frames figées). Après la destruction du vaisseau II + III, c’est le module II seul qui repart.

À zéro, 31 images s’écoulent, puis la carte affiche `JEU 1 TERMINE`, `ESSAYEZ A NOUVEAU` et `JEU TERMINE` pendant 30 images. Suivent 869 images de boucle de texte d’attract, puis la démonstration reprend à la frame 10246, où `0x8097` remonte à 3 (932 images de boucle depuis la baisse à 0).

### Vaisseau II + III

Les lignes de défilement 26 à 28 portent la position et les lignes 29 et 30 la même valeur plus 8. La ligne 26 va de `0x0e` à `0xc0` entre les deux butées. Dans les traces de combat du vaisseau assemblé, ces lignes restent inertes ; la position se lit dans `0x822b` (128 au centre, soit x = 112). La butée gauche est confirmée : `0x822b` atteint 30 (x = 14) et y reste pendant que la gauche est maintenue (`pr1-suite` 7850–7859, `pr2-held-fire`, `pr3-hitbox` 7974–8019). La butée droite l’est aussi sur `pr3-hitbox` : `0x822b` atteint 216 (x = 200) à 7810 et reste à cette valeur jusqu’à 7879, la droite enfoncée et `0x8004` à 0. Sur `pr1-suite`, le palier à 208 après la destruction 8090 n’était pas une butée : le vaisseau valait encore 208 (x = 192) en avançant.

Le tir alterne entre deux groupes, et les deux peuvent être en vol ensemble. Relevé sur `pr1-suite` aux frames 7776–8040, au rythme de `0x8005` :

| Groupe | Appui | Projectiles | y logique (registre) | Écart | Durée |
| --- | --- | --- | --- | --- | --- |
| 0 | Premier, puis un sur deux | Paire, x logique = `ship_x − 1 ± 12` (registre = logique + 17) | 212 (`0x27`) | 12 | 54 images, dernière à y = 0 |
| 1 | Deuxième, puis un sur deux | Paire, x logique = `ship_x − 1 ± 8` | 195 (`0x38`) | 8 | 49 images, dernière à y = 3 |

Tous montent de 4 par image. L’abscisse suit le même report que le module I (`x_registre − 17`, `y_logique = 251 − y_registre`). À la reprise après amarrage, le prochain appui forme le groupe 0 (frame 7776, vaisseau à x = 112, projectiles à 99 et 123). Après un déplacement à la butée gauche (`0x822b` = 30, soit x = 14), le groupe 0 part à 1 et 25, le groupe 1 à 5 et 21.

Un appui est refusé tant que le groupe qui devrait partir est encore en vol : l’appui 7940–7944 n’ajoute rien, l’alternance reste sur le groupe 0, et le nouvel appui 7965 le déclenche une fois le groupe libre. Les appuis observés durent 5 images et ne produisent qu’une volée. Un maintien commencé pendant le vol d’un groupe et poursuivi après sa disparition ne déclenche pas de volée différée, comme le `fire_busy` du module I : un nouvel front d’appui est nécessaire. Relevé sur `pr2-held-fire`.

Le replay [solo-docking-held-fire.csv](replays/solo-docking-held-fire.csv) reprend `solo-docking-suite.csv` à l’identique jusqu’après la reprise (7723), puis écarte les tirs de la suite. Un premier tap de 5 images à 7775 lance le groupe 0 (comme dans la suite, vaisseau au centre, projectiles fantômes déjà disparus). Le maintien de 120 images commence à 7790, pendant que ce groupe vole encore (disparition vers 7830). Le déplacement vers la gauche des frames 7800–7859 est conservé ; le vaisseau reste ensuite à la butée gauche, sans l’aller à droite de la suite qui se terminait par une destruction à 8090. Après le relâchement à 7910, un second cycle commence à 7940 pour le groupe suivant (tap de 5 images, puis maintien de 120 images à partir de 7955, disparition attendue vers 7990, relâchement à 8075).

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-held-fire.csv --frames 8200 --probe 8000-83ff --probe-from 7760 --snap-from 7770 --snap-every 2 --output .reference\pr2-held-fire
```

La capture `pr2-held-fire` est complète (8200 images, sonde 7760–8199, une image sur deux à partir de 7770). La reprise a lieu à 7723, `0x8097` reste à 2, sans destruction. Le tap de 7775 fait apparaître le groupe 0 à 7776. Le nouveau front d’appui à 7790, alors que le groupe 0 vole encore, déclenche le groupe 1 à 7791 (le groupe suivant était libre). Le groupe 0 disparaît à 7830 (dernière image à 7829), le groupe 1 à 7840 (dernière image à 7839) : aucune nouvelle volée pendant le maintien jusqu’à 7910. Après le relâchement, le tap de 7940 relance le groupe 0 à 7941 (à x = 14) : l’alternance n’a pas avancé pendant le maintien. Le second cycle se répète : front à 7955, groupe 1 à 7956, disparition du groupe 0 à 7995 et du groupe 1 à 8005, aucune volée différée jusqu’au relâchement à 8075. Une frame figée de `0x8005` apparaît à 8098, après l’essai.

Les lignes de défilement 26 à 30 de `0x9800`, dans ces captures, restent inertes pendant le combat du vaisseau assemblé. La position du vaisseau se lit dans `0x822b` (128 au centre, 30 à gauche). L’ancienne description d’un projectile central à « la ligne 26 plus 4 » puis d’une paire à « la ligne 29 et la ligne 29 plus 16 » ne correspond pas à ces traces : chaque groupe tire deux projectiles.


Le replay [solo-docking-hitbox.csv](replays/solo-docking-hitbox.csv) reprend `solo-docking-suite.csv` à l’identique jusqu’après la reprise (7723), sans tirer. Il pousse d’abord le vaisseau à droite dès 7765 (vague encore haute, ordonnées ennemies ≤ 122 jusqu’à 7873 sur `pr1-suite`), tient la trajectoire jusqu’à 7879, revient à gauche de 7880 à 8019, puis rejoint le centre vers 8070 et attend un contact.

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-hitbox.csv --frames 9000 --probe 8000-83ff --probe-from 7760 --snap-from 7764 --snap-every 2 --output .reference\pr3-hitbox
```

La capture `pr3-hitbox` est complète (9000 images, sonde 7760–8999, une image sur deux à partir de 7764, même empreinte ROM et même replay que `solo-docking-hitbox.csv`). La reprise est déjà en cours à 7760 (`0x822b` = 128, `0x8004` = 0, vies à 2).

La butée droite est confirmée : `0x822b` atteint 216 (x = 200) à 7810 et reste à cette valeur jusqu’à 7879, la droite toujours enfoncée et `0x8004` à 0 (70 images). La butée gauche se reconfirme à 30 (x = 14) de 7974 à 8019, la gauche enfoncée (46 images). Après le retour vers le centre, le vaisseau s’immobilise à `0x822b` = 130 (x = 114).

Le contact a lieu à la frame 8235 : `0x8004` passe à 1, le vaisseau est toujours à x = 114, et le sprite 7 vaut (140, 208) en coordonnées brutes. Aux deux images précédentes (8233–8234, `0x8005` = 62 puis 63), le même sprite vaut (141, 204) et `0x8004` reste à 0. L’union des zones solo II + III, avec le plafond du III à dy = −11, aurait déjà touché à 8228 (sprite 7 à (141, 198)). Pour le vaisseau assemblé, le module III contribue donc avec le même plafond que le II (dy ≥ −3). La zone du module III seul n’est pas modifiée. Les bords gauche et inférieur de l’assemblage, et le bord droit au-delà de dx = 26, ne sont pas contraints par ce seul contact.

Les projectiles `0x40` / `0x50` visibles à la reprise ne sont pas un nouveau tir : ce sont les créneaux logiciels de la dernière volée du module II, non vidés à l’entrée en amarrage. Sur `pr1-*` (chemin commun jusqu’à l’approche), cette paire part à la frame 6177 (registres x = 0x40 et 0x50, y = 0x38, soit le tir double du module II, écart 8). Le matériel (`bullet_ram`) s’arrête à 6185 (y = 88). Au même moment, `0x8226` passe à 0 et `0x8227` est remis à 0 : le moteur de tir ne met plus à jour les créneaux. Dans `0x8161–0x8168`, l’état reste gelé pendant toute l’approche et l’écran de résultat : y logiciel = 0xa7 (255 − 88), x = 0x40 / 0x50, drapeau `0x8163` = 1. Le matériel reste vide, d’où l’absence à l’écran.

À la reprise, si le drapeau est encore à 1, les créneaux sont recopiés vers le matériel et la montée reprend (+4 par image). Après un amarrage réussi, la première image visible (7723) applique deux pas (y registre 96, y logiciel 0x9f). Après une expiration, la première image (8125, où `0x8004` et `0x8000` basculent ensemble vers le combat) n’en applique qu’un (y registre 92, y logiciel 0xa3). Une collision d’amarrage efface seulement le drapeau (`0x8163` : 1 → 0 dès l’explosion, frame 7452) : les x et y restent en mémoire mais rien n’est recopié à 7918. Ces créneaux sont ceux du groupe 1 du vaisseau assemblé ; le prochain appui après la reprise lance toujours le groupe 0.
