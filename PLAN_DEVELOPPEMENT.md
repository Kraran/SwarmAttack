# SwarmAttack — Plan de développement

La livraison Windows x64 et ses commandes sont décrites dans le [guide du jeu](prototype/README.md). Cette version comprend le mode solo, le duo en alternance, les records locaux, le mode portrait, les graphismes 3D et les sons originaux. Le rendu de livraison utilise Godot en mode Compatibility. La borne Jeutel reste la référence pour comparer la simulation.

## Plateforme recommandée

**Godot 4.7.2 standard avec GDScript, Blender pour la 3D et Windows x64 pour la première livraison.** Godot permet de faire tourner une simulation arcade 2D indépendante et d’afficher les mêmes positions avec une caméra 3D orthographique. Le moteur standard suffit pour cette architecture. Blender fournit les modèles et animations au format GLB. La version Windows utilise le moteur de rendu Compatibility. Unity avec URP reste une option si le projet dispose déjà d’une chaîne de production Unity ou d’assets qui en dépendent. [Godot pour Windows](https://godotengine.org/download/windows/) · [Caméra orthographique](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) · [Import 3D](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)

Le premier livrable est un jeu arcade autonome, en portrait, jouable au clavier, à la manette et au stick arcade. **Moune Creste de Jeutel (`mouncrst`) est l’unique référence de gameplay.** Les réglages MAME par défaut servent de point de départ et figurent dans le manifeste de chaque relevé. Le développement couvre la partie solo en premier, puis le mode deux joueurs et les réglages de borne tels qu’ils se comportent dans cette version. Une sortie Windows 1080p est la cible initiale. Le projet est nommé SwarmAttack et la production visuelle et sonore utilise des assets propres.

## Niveau de fidélité

**SwarmAttack est une version améliorée de Moune Creste, pas une copie exacte.** Jeutel sert de référence pour les règles, les trajectoires, les seuils et les barèmes. Les défauts de la carte ne sont pas reproduits.

Première application : la boucle Jeutel perd des trames quand son traitement déborde, ce qui fige le jeu une frame de temps en temps. SwarmAttack avance à pas régulier. Les comparaisons avec Jeutel se font au rythme du compteur de boucle `0x8005`, pour vérifier les règles sans hériter de ces pauses.

## Références vérifiées

| Référence | Constat | Usage |
| --- | --- | --- |
| `mouncrst.zip` | MAME 0.286 valide le set *Moune Creste* de Jeutel. | Mesurer et valider les règles, les vagues, les timings et l’amarrage. |
| Longplay fourni | 7 min 37 s, 1280 × 720, 29,97 images/s. Il montre la version Nichibutsu. | Document d’origine pour le cadrage général du projet. |

[Déclarations des machines MAME](https://github.com/mamedev/mame/blob/master/src/mame/galaxian/galaxian.cpp) · [Vérification des ROM dans MAME](https://docs.mamedev.org/commandline/commandline-all.html#verifyroms)

Le XML local de MAME indique **60,606061 Hz** et une rotation de **90°** pour Jeutel. Un pas de simulation de **16,5 ms** permet de représenter cette cadence. Les mises à jour de gameplay sont relevées séparément, car elles peuvent occuper plusieurs frames. MAME annonce un raster de 768 × 224 avant rotation avec un facteur horizontal de 3 dans le pilote. Utiliser une grille logique initiale de 224 × 256 en portrait, puis calibrer séparément le rapport d’affichage et les bords visibles sur les captures de référence. [Constantes vidéo du pilote MAME](https://github.com/mamedev/mame/blob/master/src/mame/galaxian/galaxian.h)

Les mesures et la procédure de capture sont dans le [carnet de relevés Jeutel](tools/arcade/README.md).
Le [replay solo](tools/arcade/replays/solo-docking.csv) fixe un parcours du démarrage à l’amarrage réussi des modules II et III, après la perte du module I. La démo fournit la séquence d’assemblage des modules I et II.

Le [prototype Godot](prototype/README.md) enchaîne les dix vagues du cycle, le remplacement des modules perdus et les deux amarrages (réussite, collision ou temps écoulé). Le module I en première vague et l’approche d’amarrage du module II sont comparés à Jeutel. La boucle d’après amarrage a été recoupée sur les traces `pr1-*` (durées d’écran, vies, entrée du module, vague à entrée large). Le tir alterné du vaisseau II + III suit les deux paires relevées sur `pr1-suite`. Les butées du vaisseau II + III sont confirmées à x = 14 et x = 200 sur `pr3-hitbox`. La hitbox assemblée est l’union du module II et du module III avec le plafond dy ≥ −3, calée sur le contact immobile à la frame 8235. Les projectiles `0x40` / `0x50` de la reprise sont les créneaux logiciels de la dernière volée du module II, figés à l’entrée en amarrage et recopiés après une réussite ou une expiration (une collision efface le drapeau). L’amarrage I + II en partie est relevé sur `pr5-amarrage-i-ii`, `pr5b-amarrage-i-ii` et `pr5c-amarrage-i-ii-succes` : le module I survit à 5215, l’intro (9584) reprend le calendrier du II → III depuis y = 200, l’approche à l’inertie touche la butée basse et expire à 11343 (écran 183 images, reprise du I seul à x = 112). Le contact réussi a lieu à 10599 : l’affichage reste à l’offset (14, −7), mais le cran porte le module à (14, −6), et c’est sur cette position calculée que le contact se teste ; (13, −7) au cran précédent n’accroche pas. L’écran « BRAVO !! » affiche `17 × 100 = 1700` pendant 305 images, puis le vaisseau I + II reprend à x = 112 (`0x822b` = 128, `0x822c` = 232), vies inchangées, sans tir figé. La butée droite est x = 200, comme le II + III. Un maintien du tir commencé pendant l’approche ne déclenche pas de volée à la reprise. Le tir du I + II et sa butée gauche sont calés sur `pr6-tir-i-ii` : alternance d’une paire (écart 8, y = 211, 53 images) et d’un projectile central (y = 199, 50 images), pas de tir différé si l’appui est maintenu, butée gauche à x = 14. La hitbox du I + II est calée sur `pr6b-hitbox-i-ii` : vaisseau immobile à x = 114 (`0x822c` = 232), raté à (123, 231) aux frames 11492–11493, contact à (120, 226) à 11494 par un ennemi identifié sur le bas du module II ; les boîtes I et II sont abaissées de 16 (y = 208 et 216). L’amarrage I + II vers le III est relevé sur `pr7-amarrage-i-ii-iii` : le I + II survit aux vagues 3 et 4, l’intro part de `0x822c` = 232 à la butée droite, monte de 76 pixels (chrono `30:10` à 15173), l’approche en boucle ouverte touche la butée basse (`0x822c` = 240) et expire à 16592 (écran 183 images, pas de bonus, reprise du I + II à x = 112, `0x822c` = 216, vies 3). Sur `pr8-amarrage-i-ii-iii-approche`, l’approche dirigée heurte le III à 15673 : offset (31, −3) après un cran sans contact à (32, −4), écran 466 images, vies 3 → 1 dès l’explosion, pas de bonus, reprise du module III seul à x = 112 (`0x822b` = 128, `0x822c` = 232). Sur `pr8b-amarrage-i-ii-iii-approche`, l’approche recentrée dérive encore à droite et heurte le III à 16369 : offset (29, −3) après un cran sans contact à (28, −4) ; (25, −7), (26, −6) et (27, −5) restent sans contact. Mêmes suites (écran 466 images, vies 3 → 1, pas de bonus, reprise du III seul à x = 112, `0x822c` = 232), puis destruction en vague à 17422. Sur `pr8c-amarrage-i-ii-iii-approche`, le contact réussit à 16357 : offset (8, −6) après un cran sans contact à (7, −7). L’écran « BRAVO !! » affiche `05 × 300 = 1500` pendant 305 images (`0x822c` reste à 218), puis le vaisseau I + II + III reprend à 16662, x = 112 (`0x822b` = 128, `0x822c` = 216, modules à y = 192, 200 et 216), vies inchangées, score 4940 + 1500 = 6440. La butée gauche est x = 14 (`0x822b` = 30). Destruction à 16754, vies 3 → 2 à 17073, puis entrée du II + III. Sur `pr9-tir-i-ii-iii`, la gauche est relâchée à 16662 ; à 16664, `0x822b` passe de 128 à 126 sans commande (x = 110). Le tir du I + II + III reprend les deux paires du II + III : premier appui (16778) à y = 195, écart 8 ; second (16793) à y = 212, écart 12, les deux volées en vol. Contact à 16926 à (116, 193) sur le nez du module I, après un raté à (116, 189) à 16925 ; le plafond du I est resserré à dy ≥ −2. Sur `pr9b-tir-i-ii-iii`, la droite part à 16664 ; `0x822b` atteint 216 (x = 200) à 16711 et y reste. Le premier appui (16840, projectiles à 16841) forme encore le groupe 1 : l’index est celui laissé par le I + II (dernier groupe 0 à 14721). Le second (16855) ajoute le groupe 0, les deux volées en vol. Un maintien à 16990 lance le groupe 0. Contact à 17008 à (192, 212) sur le flanc du module III, après (192, 208) à 17007 (`0x8004` = 0) ; `0x8004` reste à 1 pendant 161 images, vies 3 → 2 à 17319. Les captures `pr10*` closent les relevés. Sur `pr10a` et `pr10b`, deux balayages des rangées −5 et −6 accrochent le III à (14, −6) et (3, −6), avec des bonus `14 × 300 = 4200` et `05 × 300 = 1500`, après des ratés à (15, −5), (15, −6), (2, −5) et (1, −6). La zone de capture I + II → III va donc de x = 3 à x = 14 sur la rangée −6. Sur `pr10c` et `pr10d`, le même ennemi touche le I + II décalé à x = 106 et x = 122 à l’image même du contact de `pr6b`, ce qui confirme la boîte basse du module II sans la modifier. `pr10e-attract` donne le cycle d’attraction complet : 745 images de texte, 123 de tableau des scores, puis une démo de 8526 images de boucle, identique d’un cycle à l’autre. Le prototype l’affiche en rejouant les états relevés.

## Architecture

- **Simulation.** Une méthode `step(input)` en GDScript applique une frame arcade à partir d’un masque d’entrées. Positions et compteurs entiers ou à virgule fixe. Déterminer l’ordre de mise à jour par observation, notamment pour les collisions, les destructions et la fin de vague. Les états explicites couvrent la démo, le départ, les vagues, l’amarrage, la perte de module, la fin de partie et les scores.
- **Horloge et entrées.** Un accumulateur indépendant du rafraîchissement de l’écran avance par pas de 16 500 µs. Il conserve les changements d’entrée jusqu’au pas qui doit les consommer. Tester les ralentissements, les reprises, les écrans à 60/120 Hz et les appuis très courts. Calibrer gauche/droite simultanés, tir maintenu et réaction au bouton pendant l’amarrage.
- **Données.** Décrire les vagues et points d’apparition, les trajectoires, les configurations de vaisseau, les hitboxes et le barème avec des données versionnées. Relier chaque valeur à une mesure ou à un cas de test. Reproduire la source de variation des trajectoires uniquement après l’avoir caractérisée. Fixer et enregistrer l’état initial pour les replays.
- **Présentation.** Une scène de diagnostic affiche coordonnées, hitboxes et événements. La scène HD projette le même état en 3D avec caméra orthographique fixe et profondeur décorative. Les modèles, particules, sons et animations consomment les événements de simulation. La simulation conserve la maîtrise des collisions et des transitions.
- **Outils.** Captures image par image, journal CSV ou JSON par frame, comparateur de traces et tests en mode headless. Les scénarios enregistrent la version MAME, le set et ses empreintes, les DIP switches, l’état initial et les entrées. Le dépôt suit les mesures, les outils et les tests. La ROM et le longplay restent des références locales.

## Feuille de route

Estimations pour une personne expérimentée, à temps plein, avec un volume d’assets HD maîtrisé.

| Jalon | Durée | Travail | Critère de sortie |
| --- | --- | --- | --- |
| 0 · Étalon | 3–5 jours | Vérifier le set Jeutel. Figer réglages et captures. Relever les déplacements, le tir, les bornes, les premiers ennemis et un amarrage. | Au moins trois traces reproductibles sur Jeutel, dont un amarrage réussi. |
| 1 · Prototype jouable | 1–2 semaines | Créer l’horloge, les entrées et le replay. Programmer déplacement, tir, collisions, premières vagues et premier amarrage. Ajouter la vue de diagnostic. | À entrées équivalentes, le prototype reproduit les événements et positions relevés du démarrage au premier amarrage. |
| 2 · Boucle arcade complète | 2–4 semaines | Relever et intégrer tous les types d’ennemis et trajectoires, l’enchaînement des vagues, les trois modules et leurs tirs, les amarrages suivants, les pertes et le cycle suivant. Reproduire le score, les bonus, le meilleur score, la démo et les modes de jeu de la borne. | Une partie complète et une partie qui dépasse le premier cycle passent le comparateur. Les cas d’échec d’amarrage sont couverts. |
| 3 · Tranche HD | 1–2 semaines | Créer les deux premiers modules, un ennemi, les tirs, une explosion, le fond et le HUD. Réaliser le premier amarrage en HD. Ajuster silhouettes, éclairage et sons sur plusieurs séquences rapides. | Le même replay passe en diagnostic et en HD. On distingue le joueur, les projectiles, les ennemis et le point d’amarrage au premier coup d’œil. |
| 4 · Production visuelle et sonore | 3–5 semaines | Finaliser le troisième module et tous les ennemis. Décliner animations et effets pour chaque assemblage. Terminer le HUD, le titre, les transitions, la démo et les sons de tir, collision, amarrage et bonus. | Tous les états jouables et écrans de la boucle ont leurs assets finaux. La scène la plus chargée respecte le budget mesuré sur le PC cible. |
| 5 · Validation et export | 1–2 semaines | Tester en portrait et en paysage avec aire de jeu préservée, en fenêtre et plein écran. Vérifier clavier, manette et stick, sauvegarde des réglages et des scores, retour de focus, parties longues, replays et export Windows x64. | ZIP autonome testé sur un second PC Windows, avec les commandes, la fiche de référence et les résultats des tests. |

**Ordre de grandeur de 9 à 16 semaines de travail.** Une première scène HD exploitable peut être préparée dès que le premier amarrage fonctionne, en parallèle du relevé des vagues avancées. La durée dépend surtout du nombre de comportements à mesurer et du temps de production des modèles, animations et effets.

## Protocole de fidélité

1. Lancer la référence avec un profil MAME dédié. Noter la version, les empreintes de ROM et les DIP switches. Enregistrer les entrées avec `-record` et les rejouer avec `-playback`. Utiliser l’avance image par image ou Lua pour observer les états et produire des captures. [Options MAME](https://docs.mamedev.org/commandline/commandline-all.html) · [API Lua MAME](https://docs.mamedev.org/luascript/index.html)
2. Établir des points de départ reproductibles. Capturer des scénarios courts pour isoler chaque règle, puis des parties complètes. Aligner les traces sur un événement défini, par exemple la première frame jouable, et comparer les états dans le même repère.
3. Exiger l’égalité des scores, bonus, états de vaisseau, résultats de collision et frames de transition pour les scénarios de référence. Comparer les positions à l’unité logique quand elles sont observables précisément. Pour une mesure issue seulement d’une image, consigner l’incertitude de lecture et remesurer les écarts qui dépassent un pixel logique.
4. Exécuter le même replay avec et sans rendu HD et à plusieurs fréquences d’affichage. Exiger la même trace de simulation. Mesurer séparément la latence d’entrée et la régularité du rendu. Viser 1080p à 60 Hz sur le PC cible, avec 16,67 ms par image comme budget de départ et un contrôle des pics sur les séquences chargées.

| Cas à couvrir | Mesures et variantes |
| --- | --- |
| Déplacement et tir | Limites, vitesse selon l’état du vaisseau, appui bref, maintien, inversion, tirs simultanés autorisés, temps avant le tir suivant. |
| Vagues | Ordre et composition, positions initiales, trajectoires et sorties, réaction au dernier ennemi, comportement avec plusieurs parcours Jeutel. |
| Collisions et pertes | Contacts au bord, destruction simultanée, perte de chaque configuration, reprise, dernier module et conditions de partie terminée. |
| Amarrage | Fenêtre latérale, vitesse d’approche, effet du bouton, seuil de contact, réussite centrée et limite, échec et expiration. Vérifier le bonus au passage d’une seconde et l’état d’armement à la reprise. |
| Score et boucle | Barèmes, seuil bonus configuré, meilleur score, retour à la démo, deux joueurs et transitions entre tours, cycle suivant. |
| Robustesse | Partie prolongée, relance d’un replay, entrée pendant une baisse de FPS, changement de focus et correspondance entre rendu et hitboxes. |

## Direction artistique HD

- Vaisseaux et modules identifiables par leur silhouette, avec panneaux métalliques, matériaux PBR, propulseurs et points d’accroche cohérents. Vérifier le profil de chaque assemblage à sa taille réelle à l’écran.
- Fond spatial sombre et peu contrasté. Réserver les couleurs les plus lisibles aux projectiles, aux ennemis et au repère d’amarrage. Calibrer le halo et les particules sur des captures fixes et en mouvement.
- Conserver la composition arcade et la zone de jeu portrait. Sur écran 16:9, ajouter des marges latérales autour du terrain. Le HUD reprend l’information utile du jeu, dont le score, les modules, le temps d’amarrage et le bonus.
- Intégrer les sons de la borne Jeutel et les synchroniser avec les événements. Vérifier à l’oreille que chaque signal reste identifiable pendant une vague et pendant l’amarrage.

## Première séance

Vérifier la ROM Jeutel et lancer le relevé dans PowerShell.

```powershell
& 'D:\mame\mame.exe' -noreadconfig -rompath 'D:\SwarmAttack' -verifyroms mouncrst
python .\tools\arcade\capture.py
```

La première livraison interne doit pouvoir rejouer une séquence courte de déplacement et de tir, afficher les positions à chaque frame et comparer le résultat à une capture MAME de Jeutel.

