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

La tolérance de 6 unités est vérifiée pour ce contact entre les modules II et III. Pour l’assemblage I et II en partie, le contact de `pr5c-amarrage-i-ii-succes` se fait à (14, −6) : c’est la position calculée au cran, l’affichage étant resté à (14, −7). Celui de la démo se fait à (5, −6), affiché (6, −7) ; voir « Relevés pr10 ». (13, −7) au cran précédent n’accroche pas. Les autres bords de la fenêtre et les effets d’autres vitesses d’approche restent à mesurer.

Le jeu n’amarre le module I avec le II que si le module I est encore là après la vague 4. Les captures `pr1-*`, `pr2-held-fire` et `pr3-hitbox` suivent toutes le parcours solo qui perd le module I à la frame 5215, puis amarrent le II sur le III. La démonstration, elle, réussit un I + II (chrono `10:7` à 2685, bonus `10 × 100 = 1000` à 2686–2687) mais ce n’est pas une approche jouée, et les traces de cette démo ne sont pas dans le dépôt.

Le replay [solo-docking-i-ii.csv](replays/solo-docking-i-ii.csv) reprend `solo-docking.csv` à l’identique jusqu’à la frame 5159, alors que le module I vient d’aller à droite (x ≈ 150). Au lieu de revenir au centre et d’y zigzager — ce qui le fait détruire à 5215 par un plongeon (sprite 3, x ≈ 121, y montant vers 188) — il poursuit vers la butée droite, tisse dans la moitié droite et tire toutes les 60 images, puis, à partir de 6400, enchaîne des maintiens de tir de 180 images avec de petites corrections latérales. La capture `pr5-amarrage-i-ii` (10 000 images, sonde `8000-83ff` depuis 5100, instantanés toutes les 2 images depuis 6000) est complète et en reproduit exactement les entrées.

Le module I survit : à 5215, `0x8004` reste à 0, `0x8097` reste à 3, et le vaisseau est sur la droite (`0x822b` = 208, abscisse de défilement = 190). Les vies restent à 3 jusqu’à la fin de la capture. Le combat se poursuit jusqu’à 9551, où `0x8226` passe à 0. Le dernier projectile matériel disparaît à 9541 ; les créneaux `0x8161–0x8168` sont déjà vides, donc cette fin de vague ne laisse pas de tir figé. 33 images plus tard (9584), `0x8224` passe à 8 : l’intro d’amarrage I + II commence, avec le même délai que le II → III (`6185` → `6218` sur `pr1-suite`).

La montée reprend le calendrier du II → III, depuis l’altitude de combat du module I : `0x822c` va de 200 à 124, la coordonnée logique `0x8143` de 192 à 116 (76 pixels, premier pas à +53 / 9604, dernier à +353 / 9904). Le chrono `0x8230–0x8231` apparaît à 9904 (`30:10`, affiché `30:0`). Pendant toute l’intro, `0x822b` reste à 196 (sprite 0 à x = `0xbc`). À 9998, le module II cible arrive par le bas (sprites 1 et 2 à y = 236, sprite 5 à y = 252) et le chrono est encore figé. L’approche jouable n’a pas commencé : par analogie avec `pr1-suite`, le chrono devrait commencer à décompter à 9551 + 516 = 10067, et le pilotage à 9551 + 524 = 10075, soit 76 images après la fin de `pr5`.

Le replay `solo-docking-i-ii.csv` n’a pas été modifié. La capture `pr5b-amarrage-i-ii` (13 000 images, sonde `8000-83ff` depuis 9500, instantanés toutes les 2 images depuis 9500) est complète, reprend exactement les entrées, et coïncide avec `pr5` sur le chevauchement 9500–9999.

L’approche jouable commence comme prévu : le chrono passe à `30:09` à 10072, le premier pas à 10112 (`0x822b` 196→195, `0x822c` 124→125). Sans commande, le modèle d’inertie du module II s’applique au I (butée basse `0x822c` = 240, soit y logique 232). Le module I touche cette butée à 10620 (chrono `17:2`, `0x822b` = 153), glisse vers la gauche le long du bas, et expire à 11343 (`0x8004` = 1, chrono `00:0`, écran « DOMMAGE !! », `0x822b` = 96, `0x822c` = 240, `0x8232` = 0). Les vies restent à 3. Les créneaux `0x8161–0x8168` restent vides.

L’écran d’expiration dure 183 images, sans aucune frame figée (`0x8005` avance de 37 à 220). À 11526, le module I seul reprend, recentré (`0x822b` = 128, `0x822c` = 216, score toujours 1280, pas de bonus). La vague à entrée large apparaît vers 11560. Un ennemi détruit ensuite le module I (explosion à 11759, baisse des vies 3→2 à 12051, 292 images murales), puis le module II entre en remplacement : même logique que les pertes déjà relevées.

Le replay [solo-docking-i-ii-success.csv](replays/solo-docking-i-ii-success.csv) reprend le trajet jusqu’à 9700, puis, à partir du premier pas (10112), tient gauche 53 ticks d’approche, freine à droite, et maintient le tir à partir du 60e tick. La capture `pr5c-amarrage-i-ii-succes` (13 000 images, sonde `8000-83ff` depuis 9500, instantanés toutes les 2 images depuis 9500) est complète, reprend exactement ces entrées, et coïncide avec `pr5b` jusqu’au début du pilotage (10112).

Le contact réussit à 10599 : `0x8004` passe à 1, chrono `17:10` (affiché `17:0`), `0x822b` = 134, `0x822c` = 217, soit l’offset (14, −7) par rapport à la cible (112, 216). Au cran de contrôle précédent (10595), l’offset (13, −7) n’a pas accroché. Relecture sur `pr10e` : à 10599, l’attente verticale `0x8225` était à 0 et repart à 1. Le cran a donc porté le module à (14, −6), position que le jeu teste sans l’afficher. L’objet `0x8140` se cale sur (120, 208). L’écran « BRAVO !! » affiche `BONUS 17 × 100 = 1700` pendant 305 images, sans frame figée (10599–10903). À 10904, le score passe de 1280 à 2980 et le vaisseau I + II reprend, recentré (`0x822b` = 128, `0x822c` = 232), vies toujours à 3, créneaux `0x8161–0x8168` vides. La vague à entrée large apparaît vers 10935.

La droite reste enfoncée : `0x822b` avance de 2 par image jusqu’à 216 à 10948 (x = 200) et y reste à cette butée jusqu’à la destruction. Le tir, maintenu depuis l’approche jusqu’à 10999, ne produit aucune volée à la reprise ; le motif de tir du I + II n’est donc pas observé. Un ennemi détruit le vaisseau à 12290 (`0x8004` = 1, toujours à la butée droite), les vies passent de 3 à 2 à 12579 (289 images de boucle). Le module I reprend ensuite l’entrée (`0x822c` vers 200, sprite `0x78`, visible à 12968). La capture s’arrête à 12999, pendant cette entrée. La hitbox du I + II et sa butée gauche ne sont pas calées sur ce seul contact. L’amarrage I + II vers le III n’est pas visé par ce passage.

Le replay [solo-docking-i-ii-fire.csv](replays/solo-docking-i-ii-fire.csv) reprend `solo-docking-i-ii-success.csv` à l’identique jusqu’à l’amarrage réussi (10352). À la reprise (10904), il relâche le tir et la droite pour laisser le vaisseau I + II à x = 112. Les essais de tir commencent à 11020, une fois l’entrée large remontée (sur `pr5c`, les ordonnées ennemies sont ≤ 86 à 11030). Deux taps de 5 images (11020 et 11035, écartés de 15 images) visent l’alternance et la superposition des volées. Un troisième tap à 11090, après une pause de 50 images, doit partir sur un créneau libre si une volée dure environ 54 images comme le II + III. Un nouvel appui à 11100, pendant que cette volée vole encore, puis un maintien de 120 images à partir de 11170, reprennent le protocole de `pr2-held-fire`. À 11300 le vaisseau pousse vers la butée gauche (arrivée attendue à 11349 si le pas est de 2, soit x = 14 / `0x822b` = 30), tient le palier jusqu’à 11419, revient au centre vers 11469, et reste immobile à partir de 11470 pour un contact contrôlé, comme `solo-docking-hitbox.csv`.

```powershell
git fetch origin
git checkout tir-i-ii
git pull
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-fire.csv --frames 13000 --probe 8000-83ff --probe-from 10900 --snap-from 10900 --snap-every 2 --output .reference\pr6-tir-i-ii
```

La capture `pr6-tir-i-ii` est complète (13 000 images, sonde `8000-83ff` depuis 10900, instantanés toutes les 2 images depuis 10900, même empreinte de replay). À la reprise (10904), le tir est relâché ; `0x822b` passe de 128 à 130 dès 10905 sans commande, puis reste à 130 jusqu’au déplacement. La vague apparaît à 10935.

Le premier appui (11020) fait apparaître à 11021 une paire, registres matériels x = 122 et 138 (logique 105 et 121, soit x vaisseau − 1 ± 8 pour `0x822b` = 130), y matériel = 40 (logique 211). Le deuxième appui (11035), alors que la paire vole encore, fait apparaître à 11036 un projectile central (x matériel 130, logique 113, y matériel 52, logique 199). Les deux volées coexistent (3 projectiles). Les premières volées rencontrent des ennemis et sont interrompues ; le tap 11090, les créneaux étant libres, relance la paire, et l’appui 11100, pendant que cette paire vole encore, relance le projectile central. Le maintien commencé à 11170 fait apparaître la paire à 11171 (y = 211) ; elle reste visible jusqu’à 11223 (y = 3) et disparaît à 11224, soit 53 images, sans aucune volée différée jusqu’au relâchement à 11290. Un nouvel front d’appui est nécessaire. Le projectile central, lancé à y = 199, dure 50 images s’il n’est pas interrompu.

À 11300 le vaisseau pousse à gauche (premier pas à 11302). La butée gauche est `0x822b` = 30 (x = 14), tenue de 11353 à 11421 avec la gauche enfoncée et `0x8004` = 0. Le retour au centre aboutit à `0x822b` = 130 à 11471, où le vaisseau reste immobile.

Un contact a lieu à 11889 (`0x8004` = 1, vaisseau toujours à `0x822b` = 130, `0x822c` = 232). Les vies passent de 3 à 2 à 12185 (289 images de boucle, y compris des frames figées). Les tuiles d’explosion apparaissent à y = 208 et 224. Les ennemis encore visibles à l’écran sont trop hauts ; le sprite toucheur n’est pas identifié de façon univoque, donc la hitbox du I + II n’est pas recalée sur ce contact.

Le replay [solo-docking-i-ii-hitbox.csv](replays/solo-docking-i-ii-hitbox.csv) reprend le trajet de réussite jusqu’à 10352, relâche tir et droite à la reprise (10904), et ne tire plus. Il calque le calendrier de `solo-docking-hitbox.csv` sur le départ de vague 10935 observé dans `pr6` : droite à 10947 (vague encore haute, ordonnées ennemies basses vers 11030), gauche à 11062 (butée droite attendue vers 10990), retour vers le centre à 11202 (butée gauche attendue vers 11157), puis attente immobile à partir de 11252, pour un contact dû à un seul ennemi identifiable.

```powershell
git fetch origin
git checkout tir-i-ii
git pull
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-hitbox.csv --frames 13000 --probe 8000-83ff --probe-from 10900 --snap-from 10900 --snap-every 2 --output .reference\pr6b-hitbox-i-ii
```

Relevé `pr6b-hitbox-i-ii` : la butée gauche `0x822b` = 30 (x = 14) est tenue de 11157 à 11203. Le vaisseau revient au centre (`0x822b` = 130) à 11253 et reste immobile. Contact à 11494 (`0x8004` = 1, `0x822c` = 232, vies encore à 3). Aux frames 11492–11493, l’ennemi de la table d’objets (`0x81e9` = 231, `0x81ea` = 123) est un raté ; à 11494 il est à (120, 226) et touche le bas du module II, ce que confirme l’image. Les boîtes I et II du I + II, pour ce combat à `0x822c` = 232, sont donc celles des modules I et II abaissées de 16 (y = 208 et 216). Le drapeau tombe à 11655 (161 images) ; les vies passent de 3 à 2 à 11783 (289 images de boucle).

Le replay [solo-docking-i-ii-iii.csv](replays/solo-docking-i-ii-iii.csv) reprend le même préfixe, relâche à 10904, puis, à partir de 11020, enchaîne des cycles de 100 images pour traverser les vagues 3 et 4. Relevé `pr7-amarrage-i-ii-iii` : le I + II survit jusqu’à l’amarrage avec le III. `0x8224` passe à 8 à 14853 (`0x822c` = 232, butée droite `0x822b` = 216). Premier pas de montée à 14873, dernier à 15173 (`0x822c` = 156, soit 76 pixels, chrono `30:10`). Le premier cran `30:09` tombe à 15325 (152 images au rythme de `0x8005`). L’approche, encore pilotée par les cycles de combat (le tir devient une poussée), touche la butée basse (`0x822c` = 240) à 15757 et expire à 16592 (`00:00`, vies 3, score inchangé, `0x8232` reste à `0x17` héritée du bonus I + II). Écran « DOMMAGE !! » de 183 images, reprise à 16775 : le I + II continue (`0x814a` = 3) à x = 112 (`0x822b` = 128, `0x822c` = 216, modules à y = 192 et 200). La zone de capture I + II → III n’a pas été vue. Le module III cible est bien à (112, 216) dès 15332.

Le replay [solo-docking-i-ii-iii-approche.csv](replays/solo-docking-i-ii-iii-approche.csv) reprend le même préfixe jusqu’à 15325, puis dirige l’assemblage vers la cible (112, 216) : gauche en descendant, poussée pour ne pas retomber au plancher, freinage, puis maintien du tir vers (130, 207). C’est encore un pilotage en boucle ouverte, destiné à observer un contact. Instantanés toutes les 2 images sur la fenêtre d’intro et d’approche.

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-iii-approche.csv --frames 18000 --probe 8000-83ff --probe-from 14800 --snap-from 14800 --snap-every 2 --output .reference\pr8-amarrage-i-ii-iii-approche
```

Relevé `pr8-amarrage-i-ii-iii-approche` : l’intro est identique à `pr7`. L’approche dirigée heurte le module III à 15673 (`0x8004` = 1, chrono `22:02`, `0x822b` = 151, `0x822c` = 221). Au cran précédent (15669), l’offset de la position logique (32, −4) reste sans contact ; à 15673, (31, −3) est une collision. Vies `0x8097` 3 → 1 dès l’explosion, score inchangé (pas de bonus), `0x8232` reste à `0x17`. Écran d’explosion 466 images, reprise à 16139 : le module III seul continue à x = 112 (`0x822b` = 128, `0x822c` = 232). La butée gauche du III est x = 14 (`0x822b` = 30, tenue jusqu’au contact de vague à 16231). La zone de capture n’a pas été vue.

Le replay [solo-docking-i-ii-iii-approche-b.csv](replays/solo-docking-i-ii-iii-approche-b.csv) reprend le même préfixe jusqu’à 15325, puis monte vers la gauche (gauche + tir), freine et redescend (droite sans tir).

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-iii-approche-b.csv --frames 18000 --probe 8000-83ff --probe-from 14800 --snap-from 14800 --snap-every 2 --output .reference\pr8b-amarrage-i-ii-iii-approche
```

Relevé `pr8b-amarrage-i-ii-iii-approche` : l’intro est identique à `pr7` et `pr8`. L’approche recentrée dérive encore vers la droite : à 16361, l’offset (28, −4) reste sans contact (`0x8004` = 0) ; à 16369, (29, −3) est une collision (`0x8004` = 1, chrono `04:08`, `0x822b` = 149, `0x822c` = 221). Plus tôt, (25, −7), (26, −6) et (27, −5) n’accrochent pas. Vies `0x8097` 3 → 1 dès l’explosion, score inchangé (pas de bonus), `0x8232` reste à `0x17`. Écran d’explosion 466 images, reprise à 16835 : le module III seul continue à x = 112 (`0x822b` = 128, `0x822c` = 232, `0x814a` = 1). Destruction en vague à 17422 (vies 1 → 0). La zone de capture n’a pas été vue sur ce relevé.

Le replay [solo-docking-i-ii-iii-approche-c.csv](replays/solo-docking-i-ii-iii-approche-c.csv) reprend le même préfixe jusqu’à 15832, puis recentre l’assemblage vers `0x822b` = 128 et freine la descente pour passer au voisinage de l’offset (8, −6) vers 16357, sans descendre à y = −3.

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-iii-approche-c.csv --frames 18000 --probe 8000-83ff --probe-from 14800 --snap-from 14800 --snap-every 2 --output .reference\pr8c-amarrage-i-ii-iii-approche
```

Relevé `pr8c-amarrage-i-ii-iii-approche` : l’intro est identique à `pr7`. Au cran 16353, l’offset (7, −7) reste sans contact ; à 16357, (8, −6) est une capture (`0x8004` = 1, chrono `05:01`, `0x822b` = 128, `0x822c` = 218, `0x8232` = 15). L’écran « BRAVO !! » affiche `05 × 300 = 1500` pendant 305 images (score encore à 4940). Reprise à 16662 : le I + II + III continue à x = 112 (`0x822b` = 128, `0x822c` = 216, sprites à y = 192, 200 et 216), vies 3, score 6440. La butée gauche `0x822b` = 30 (x = 14) est tenue de 16753 au contact 16754. Destruction en vague, vies 3 → 2 à 17073, entrée du II + III (modules à y = 200 et 216 à 17451). Le tir, la hitbox et la butée droite du I + II + III n’ont pas été isolés (la gauche restait enfoncée dès la reprise).

Le replay [solo-docking-i-ii-iii-tir.csv](replays/solo-docking-i-ii-iii-tir.csv) reprend `solo-docking-i-ii-iii-approche-c.csv` à l’identique jusqu’à l’amarrage réussi (16357) et la reprise (16662). À 16662, il relâche la gauche pour laisser le I + II + III à x = 112 et éviter le contact de 16754 à la butée gauche. Les essais de tir commencent à 16778, une fois l’entrée large remontée (sur `pr8c`, la vague apparaît à 16693). Deux taps de 5 images (16778 et 16793, écartés de 15 images) visent l’alternance et la superposition des volées. Un troisième tap à 16848, après une pause de 50 images, puis un appui à 16858 pendant que cette volée vole encore, et un maintien de 120 images à partir de 16928, reprennent le protocole de `pr6-tir-i-ii`. À 17058 le vaisseau pousse vers la butée droite (arrivée attendue à 17102 si le pas est de 2, soit x = 200 / `0x822b` = 216), tient le palier jusqu’à 17177, revient au centre à 17222, et reste immobile pour un contact contrôlé.

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-iii-tir.csv --frames 20000 --probe 8000-83ff --probe-from 16600 --snap-from 16600 --snap-every 2 --output .reference\pr9-tir-i-ii-iii
```

Relevé `pr9-tir-i-ii-iii` : à 16664, `0x822b` passe de 128 à 126 sans commande (x = 110), analogue au 128→130 du I + II à la reprise. Le vaisseau reste à `0x822b` = 126, `0x822c` = 216. Le premier appui (16778, projectiles à 16779) lance la paire du groupe 1 : y = 195, écart 8, abscisses logiques 101 et 117 (registres `0x76` / `0x86`). Le second (16793, projectiles à 16794), pendant que la première vole encore, lance la paire du groupe 0 : y = 212, écart 12, abscisses 97 et 121 (registres `0x72` / `0x8a`). Les deux paires coexistent. La première volée est interrompue par des ennemis vers 16823–16828. La paire y = 212 est encore formée à y = 4 à 16846 et à y logiciel 0 à 16847 ; les créneaux sont vides à 16848. L’appui de 16848, à la disparition, ne déclenche pas de volée ; celui de 16858 relance la paire y = 195 à 16859. Le maintien prévu à 16928, la butée droite et le stationnement au centre n’ont pas été atteints : un ennemi identifié dans la table `0x81d5` / `0x81d6` (y, x) plonge à x = 116 constant, +4 par image ; (116, 189) à 16925 est un raté (`0x8004` = 0), (116, 193) à 16926 un contact sur le nez du module I (`0x8004` = 1, vies encore à 3, score 6740). Le plafond dy ≥ −3 du module I compterait déjà 16925 ; il est resserré à −2 pour le I + II + III. Pendant l’explosion, `0x822b` ne bouge plus malgré la droite ensuite enfoncée. `0x8004` reste à 1 jusqu’à 17087 (161 images), vies 3 → 2 à 17252 (326 images après le contact). La butée droite n’est pas mesurée.

Le replay [solo-docking-i-ii-iii-tir-b.csv](replays/solo-docking-i-ii-iii-tir-b.csv) reprend le même préfixe jusqu’à 16662, puis pousse à droite dès 16664 pour quitter le centre avant le plongeon de 16926. Depuis x = 110 (`0x822b` = 126), l’arrivée à x = 200 (`0x822b` = 216) est attendue vers 16712 si le pas est de 2. La droite reste enfoncée pendant les essais de tir à la butée (taps de 5 images à 16840 et 16855, troisième tap à 16910, appui à 16920 pendant qu’une volée vole encore, maintien de 120 images à partir de 16990). À 17150 le vaisseau relâche tout et reste immobile à la butée pour un contact contrôlé.

```powershell
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-iii-tir-b.csv --frames 20000 --probe 8000-83ff --probe-from 16600 --snap-from 16600 --snap-every 2 --output .reference\pr9b-tir-i-ii-iii
```

Relevé `pr9b-tir-i-ii-iii` : à 16664, `0x822b` passe encore de 128 à 126 sans commande, puis la droite le ramène et l’amène à `0x822b` = 216 (x = 200) à 16711. La butée tient tant que la droite reste enfoncée, et le vaisseau y reste après le relâchement de 17150. Le premier appui (16840, projectiles à 16841) lance la paire du groupe 1 : y = 195, écart 8, abscisses 191 et 207. C’est le même premier groupe qu’à x = 110 sur `pr9` : l’index est celui laissé par le I + II (dernier groupe 0 à 14721, même préfixe, sondé sur `pr7`). Le second appui (16855, projectiles à 16856) ajoute la paire du groupe 0 : y = 212, écart 12, abscisses 187 et 211, les deux volées en vol. L’appui de 16910, à l’image où le dernier créneau se vide, ne déclenche pas de volée ; celui de 16920 relance le groupe 1 à 16921. Le maintien de 16990 lance le groupe 0 à 16991, sans seconde volée tant que cette paire vole. Le maintien n’est pas suivi jusqu’à la disparition : contact à 17008. L’ennemi identifié en `0x8210`–`0x8212` (y, x) avance à x = 192 constant, +4 par image ; à 17007, (192, 208) reste à préfixe `0x60` (`0x8004` = 0) ; à 17008, (192, 212) passe à préfixe `0x00` (`0x8004` = 1, vies encore à 3). C’est un contact sur le flanc du module III (boîte ancrée à y = 208, dx = −8, dy = 4). `0x8004` reste à 1 jusqu’à 17169 (161 images) ; vies 3 → 2 à 17319, comme la baisse de compteur de `pr9` (17252), pas un second contact.

## Captures finales

Ces cinq captures visent les dernières constantes encore provisoires : les bords de la zone de capture I + II → III au-delà du point (8, −6), la hitbox du I + II au-delà du contact de `pr6b`, et la démonstration d’attraction. Les offsets sont ceux des relevés `pr8*` : (`0x822b` − 120, `0x822c` − 224), relevés au cran de contrôle.

Pendant l’approche I + II → III, `pr8`, `pr8b` et `pr8c` ne présentent aucune frame figée : un cran tous les 4 images, à partir de 15332. Le modèle d’inertie du prototype (`docking.gd`, classe `Axis`), appliqué aux vitesses `0x8222`–`0x8223` et aux attentes `0x8224`–`0x8225`, reproduit image par image `0x822b`, `0x822c`, vitesses et attentes sur les trois relevés jusqu’au contact, avec les entrées du replay lues 1 à 4 images avant le cran (même résultat pour ces quatre décalages ; les nouveaux replays ne changent d’entrée que sur une frame de cran). Les deux replays d’approche ci-dessous reprennent `solo-docking-i-ii-iii-approche-c.csv` jusqu’à 15325, puis suivent une trajectoire calculée avec ce modèle. Les positions indiquées sont des prévisions, pas des mesures ; seule la capture fera foi.

| Replay | Trajectoire prévue | Ce qu’elle mesure |
| --- | --- | --- |
| [solo-docking-i-ii-iii-capture-droite.csv](replays/solo-docking-i-ii-iii-capture-droite.csv) | Descente à droite (x ≥ 33 tant que y > −14), entrée dans la bande y ∈ [−6, −4] à x = 33–34 (points sans contact de `pr8`), puis balayage vers la gauche d’une unité tous les deux crans, y alternant entre −5 et −6 : x = 24 vers 15896, x = 8 vers 16024, x = 0 vers 16088. | Bord droit de la zone de capture (ou de la zone de collision) sur les rangées −5 et −6 : premier contact. |
| [solo-docking-i-ii-iii-capture-gauche.csv](replays/solo-docking-i-ii-iii-capture-gauche.csv) | Passage au-dessus de la cible à y ≤ −14, descente à gauche (x ≤ −30 tant que y > −14), puis balayage vers la droite d’une unité tous les deux crans sur les mêmes rangées : x = −30 vers 16050, x = −10 vers 16228, x = 0 vers 16308, x = 8 vers 16372. | Bord gauche de la zone de capture (ou de la zone de collision) : premier contact. |
| [solo-docking-i-ii-hitbox-gauche.csv](replays/solo-docking-i-ii-hitbox-gauche.csv) | `solo-docking-i-ii-hitbox.csv` à l’identique, puis gauche 11466–11469 : le vaisseau passe de `0x822b` = 130 à environ 122 avant l’arrivée de l’ennemi de `0x81e9`–`0x81ea`, qui balaie le bas de l’écran de droite à gauche. | Contact (ou raté) de cet ennemi sur un autre point du I + II que sur `pr6b`, si sa trajectoire ne dépend pas du déplacement tardif du vaisseau. |
| [solo-docking-i-ii-hitbox-droite.csv](replays/solo-docking-i-ii-hitbox-droite.csv) | Idem avec droite 11466–11469 : `0x822b` vers 138, au-devant de l’ennemi. | Même ennemi, rencontré plus tôt et plus bas sur sa courbe. |
| Scénario `attract` | Mise sous tension sans aucune entrée, 20 000 images. | Démonstration complète (enchaînement, durée, retour au titre) pour la reproduire. |

```powershell
git fetch origin
git checkout captures-finales
git pull
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-iii-capture-droite.csv --frames 17000 --probe 8000-83ff --probe-from 15300 --snap-from 15300 --snap-every 2 --output .reference\pr10a-capture-i-ii-iii-droite
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-iii-capture-gauche.csv --frames 17200 --probe 8000-83ff --probe-from 15300 --snap-from 15300 --snap-every 2 --output .reference\pr10b-capture-i-ii-iii-gauche
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-hitbox-gauche.csv --frames 13000 --probe 8000-83ff --probe-from 11400 --snap-from 11400 --snap-every 2 --output .reference\pr10c-hitbox-i-ii-gauche
python .\tools\arcade\capture.py --replay tools\arcade\replays\solo-docking-i-ii-hitbox-droite.csv --frames 13000 --probe 8000-83ff --probe-from 11400 --snap-from 11400 --snap-every 2 --output .reference\pr10d-hitbox-i-ii-droite
python .\tools\arcade\capture.py --scenario attract --frames 20000 --probe 8000-83ff --snap-every 10 --output .reference\pr10e-attract
```

Restaient hors de ce lot, et restent provisoires : le bord bas de la zone de capture I + II → III (il faudrait passer sous la cible), les bords de la zone de capture du module I vers le II (l’approche de `pr5c` présente des frames figées, 8 entre 10120 et 10215, absentes de `pr5b` : la cadence des crans dépend des entrées et ne se prévoit pas encore), et le cycle suivant après la vague 4 sans partenaire.

## Relevés pr10

Les cinq captures sont complètes, avec les empreintes de replay attendues : 17 000, 17 200, 13 000, 13 000 et 20 000 images. Sur `pr10a` et `pr10b`, le modèle d’inertie reproduit image par image `0x822b`, `0x822c`, `0x8222`–`0x8225` jusqu’au contact. Les deux approches ont donc suivi la trajectoire prévue.

**`pr10a-capture-i-ii-iii-droite`.** Balayage vers la gauche, y alternant entre −5 et −6. (15, −5) et (15, −6) restent sans contact. Au cran 15976, (14, −6) accroche : `0x8004` = 1 à 15977, chrono `14:06`, `0x822b` = 134, `0x822c` = 218. L’écran bonus dure 305 images, puis le score passe de 4940 à 9140 (+ `14 × 300` = 4200). Reprise à 16282 en I + II + III (`0x822b` = 128, `0x822c` = 216). Destruction à 16553, vies 3 → 2 à 16866.

**`pr10b-capture-i-ii-iii-gauche`.** Balayage vers la droite. (1, −6), puis (2, −5) à deux crans, restent sans contact. Au cran 16332, (3, −6) accroche : `0x8004` = 1 à 16333, chrono `05:07`, `0x822b` = 123, `0x822c` = 218. Bonus `05 × 300`, score 4940 → 6440, reprise à 16638.

Ces deux captures donnent la zone I + II → III sur la rangée y = −6 : de x = 3 à x = 14, avec le contact (8, −6) de `pr8c`. (2, −6) n’a pas été visité. Les rangées y = −5 à 1 dans x = 3–14 ne sont jamais atteintes et restent provisoires. Les bords sont les mêmes que ceux du rectangle provisoire du module I, x = 3–14.

**`pr10c-hitbox-i-ii-gauche` et `pr10d-hitbox-i-ii-droite`.** La gauche, ou la droite, de 11466 à 11469 porte le vaisseau de `0x822b` = 130 à 122, ou à 138, dès 11471. L’ennemi `0x81e9`/`0x81ea` suit exactement la trajectoire de `pr6b` : sa course ne dépend pas de ce déplacement tardif. Dans les deux cas, (123, 231) à 11491–11492 est un raté et (120, 226) à 11493 un contact. C’est la même image de boucle que 11494 sur `pr6b`, à une frame figée près. Le contact sur le bas du module II (boîte à y = 216) couvre donc dx = −2, 6 et 14 à dy = 10 ; dy = 15 reste un raté. La boîte actuelle (dx de −5 à 23, dy ≤ 12) n’est pas modifiée. Les bords latéraux et le bas exact, entre 10 et 15, restent provisoires. Suites identiques sur les deux captures : drapeau levé 161 images, vies 3 → 2 à 11782, perte suivante à 12400, vies 2 → 1 à 12690.

**`pr10e-attract`.** Après la mise sous tension et l’effacement de la RAM (106–107), le cycle est le suivant :

| Écran | Frames (1er cycle / 2e cycle) | Durée | Repères |
| --- | --- | --- | --- |
| Texte de présentation | 107–855 / 9619–10367 | 748 images murales (4 / 3 figées), 745 de boucle au 2e cycle | `0x801d` = `0x60`. Lignes entamées puis complètes, lues sur les PNG à 10 images près : « BATAILLE DANS L’UNIVERS » 21–151, « MOUNE CRESTE » 181–251, « ESSAYEZ VOUS AUSSI » 501–601, « SENSATIONS FORTES » 641, « GARANTIES » 661. |
| Tableau des scores | 855–978 / 10367–10490 | 123 images, aucune figée | « SCORE NOM », NO1 à NO5 à 005000 (`0x8051` passe à 0). |
| Démo | 978–9619 / 10490–19134 | 8641 / 8644 images murales, 8526 de boucle | Démarre à `0x8097` = 3, finit au retour à 0. Retour direct au texte, sans écran « JEU TERMINE ». |

Au rythme de `0x8005`, les deux démos sont identiques : positions, vies et `0x8004` coïncident sur les 8526 images de boucle. La démo est donc scriptée. Elle se déroule ainsi (images de boucle depuis le début de la démo, frames du 1er cycle) :

- 0–377 (978–1355) : entrée du module I, à y = 120 vers 281 puis posé à y = 200 à 377. Il n’y a aucune vague de combat avant l’amarrage.
- 377 (1355) : intro de l’amarrage I → II (`0x809b` = 2, « RAVITAILLEMENT »), chrono `30:10` à 730 (1708).
- 1693 (2686) : contact. L’affichage reste à (6, −7), le cran porte le module à (5, −6). Chrono `10:07`, écran « BRAVO !! » `10 × 100 = 1000` pendant 305 images.
- 1998 (2991) : reprise en I + II à x = 112 (`0x822b` = 128, `0x822c` = 232), vagues 3 et 4 (`0x809b` = 3 puis 4 à 2611). Une volée toutes les 64 images de boucle, de 2045 à 3187 : 19 volées, dont un écart de 54 images au changement de vague. La démo ne marque aucun point (`0x8099`–`0x809a` inchangés).
- 3207 (4215) : intro I + II → III (`0x809b` = 5), chrono `30:10` à 3560 (4570), puis expiration à 4944 (5967) : « DOMMAGE !! », `00:0`, écran de 183 images.
- 5127 (6150) : reprise du I + II à x = 112, `0x822c` = 216. Volées de 5174 à 5494, toutes les 64 images.
- 5503 (6529) : destruction du I + II, drapeau 161 images, vies 3 → 2 à 5792 (289 images). Le module II est perdu (`0x8145` = 0) et le module I refait son entrée.
- 7247 (8334) : destruction du module I, vies 2 → 1 à 7536 (289 images). Le module III entre (`0x822c` = 224).
- 8209 (9302) : destruction du module III, drapeau 161 images, vies 1 → 0 et retour au texte à 8526, soit 317 images après le contact au lieu de 289.

Les états des modules `0x8140`, `0x8145` et `0x814a` valent 3 en réserve, 2 en entrée ou en approche, 1 en jeu et 0 une fois détruits.

Les commandes simulées par la démo ne sont pas observables : la trace ne contient que les commandes du collecteur, toutes au repos. On les déduit des positions. En fin d’approche (dès 2503), le module I descend en diagonale à la vitesse verticale maximale (`0x8223` = `0x40`, une unité par cran), et sa vitesse horizontale se resserre de 173 à 170. Le tir est régulier, toutes les 64 images, et seulement en I + II. La table `prototype/attract_demo_data.gd` conserve, image de boucle par image de boucle, chaque changement de `0x822b`, `0x822c`, `0x8097`, `0x8004`, `0x801d`, `0x809b`, `0x8230`–`0x8231` et des trois états de module, ainsi que les volées. Pour la régénérer :

```powershell
python .\tools\arcade\extract_attract.py .reference\pr10e-attract\mouncrst\attract-probe.csv
```

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

Le module suivant apparaît 25 images après la baisse, monte de y = 255 à y = 120 en 136 images, s’arrête 137 images de boucle à mi-hauteur, puis redescend à y = 200 en 80 images. La reprise du combat a lieu 378 images de boucle après la baisse (380 ou 382 images murales selon les frames figées). Après la destruction du vaisseau II + III, c’est le module II seul qui repart. Après celle du vaisseau I + II, c’est le module I seul qui reprend l’entrée (`pr5c`, à partir de 12579).

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
