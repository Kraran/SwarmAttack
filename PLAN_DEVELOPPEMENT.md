# SwarmAttack — Plan de développement

## Plateforme recommandée

**Godot 4.7.2 standard avec GDScript, Blender pour la 3D et Windows x64 pour la première livraison.** Godot permet de faire tourner une simulation arcade 2D indépendante et d’afficher les mêmes positions avec une caméra 3D orthographique. Le moteur standard suffit pour cette architecture. Blender fournit les modèles et animations au format GLB. Forward+ servira au prototype visuel. Le choix du moteur de rendu définitif dépendra des mesures sur le PC cible. Unity avec URP reste une option si le projet dispose déjà d’une chaîne de production Unity ou d’assets qui en dépendent. [Godot pour Windows](https://godotengine.org/download/windows/) · [Caméra orthographique](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) · [Import 3D](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)

Le premier livrable est un jeu arcade autonome, en portrait, jouable au clavier, à la manette et au stick arcade. **Moune Creste de Jeutel (`mouncrst`) est l’unique référence de gameplay.** Les réglages MAME par défaut servent de point de départ et figurent dans le manifeste de chaque relevé. Le développement couvre la partie solo en premier, puis le mode deux joueurs et les réglages de borne tels qu’ils se comportent dans cette version. Une sortie Windows 1080p est la cible initiale. Le projet est nommé SwarmAttack et la production visuelle et sonore utilise des assets propres.

## Références vérifiées

| Référence | Constat | Usage |
| --- | --- | --- |
| `mouncrst.zip` | MAME 0.286 valide le set *Moune Creste* de Jeutel. | Mesurer et valider les règles, les vagues, les timings et l’amarrage. |
| Longplay fourni | 7 min 37 s, 1280 × 720, 29,97 images/s. Il montre la version Nichibutsu. | Document d’origine pour le cadrage général du projet. |

[Déclarations des machines MAME](https://github.com/mamedev/mame/blob/master/src/mame/galaxian/galaxian.cpp) · [Vérification des ROM dans MAME](https://docs.mamedev.org/commandline/commandline-all.html#verifyroms)

Le XML local de MAME indique **60,606061 Hz** et une rotation de **90°** pour Jeutel. Un pas de simulation de **16,5 ms** permet de représenter cette cadence. Les mises à jour de gameplay sont relevées séparément, car elles peuvent occuper plusieurs frames. MAME annonce un raster de 768 × 224 avant rotation avec un facteur horizontal de 3 dans le pilote. Utiliser une grille logique initiale de 224 × 256 en portrait, puis calibrer séparément le rapport d’affichage et les bords visibles sur les captures de référence. [Constantes vidéo du pilote MAME](https://github.com/mamedev/mame/blob/master/src/mame/galaxian/galaxian.h)

Les mesures et la procédure de capture sont dans le [carnet de relevés Jeutel](tools/arcade/README.md).
Le [replay solo](tools/arcade/replays/solo-docking.csv) fixe un parcours du démarrage à l’amarrage réussi des modules II et III, après la perte du module I. La démo fournit la séquence d’assemblage des modules I et II.

Le [prototype Godot de la première vague](prototype/README.md) permet de jouer au module I jusqu’à la perte du vaisseau ou la destruction des huit cibles. Le jalon 1 se poursuit avec le parcours jusqu’au premier amarrage.

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
- Créer des sons originaux avec des attaques brèves et synchronisées aux événements. Vérifier à l’oreille que chaque signal reste identifiable pendant une vague et pendant l’amarrage.

## Première séance

Vérifier la ROM Jeutel et lancer le relevé dans PowerShell.

```powershell
& 'D:\mame\mame.exe' -noreadconfig -rompath 'D:\SwarmAttack' -verifyroms mouncrst
python .\tools\arcade\capture.py
```

La première livraison interne doit pouvoir rejouer une séquence courte de déplacement et de tir, afficher les positions à chaque frame et comparer le résultat à une capture MAME de Jeutel.

