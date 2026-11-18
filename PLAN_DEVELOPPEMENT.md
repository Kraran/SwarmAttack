# SWARM ATTACK — Plan de développement

Version publiée : **0.3.1**. SWARM ATTACK est un jeu de défense orbitale pour Windows, développé avec Godot. Le joueur traverse dix vagues, manœuvre dans des champs de météorites et assemble jusqu’à trois modules pour faire évoluer son armement.

Les correctifs après la 0.3.0 retirent les tirs fantômes aux transitions et les trois arrêts matériels reproduits dans les vagues. Ils maintiennent le déplacement pendant le crédit final et remplacent les délais dépendant de la charge de la borne par un délai d’effet constant. Les tests vérifient désormais ces comportements corrigés ; les relevés arcade restent des références de trajectoires, pas une obligation de reproduire leurs défauts.

## Fonctionnalités réalisées

| Domaine | État en 0.3.1 |
| --- | --- |
| Boucle de jeu | Dix vagues, deux amarrages, cycles successifs, vies, réserve et scores ; solo et duo local en alternance |
| Modules | Seule la coque touchée est détruite ; les survivants se séparent. Après perte du II, le I reprend seul et peut s’amarrer au III resté en réserve |
| Difficulté | Normal : cycle 1, réserve à 30 000 points. Vétérans : cycle 2, réserve à 50 000 points |
| Entraînement | Choix des dix vagues ou des deux amarrages, dans les deux difficultés ; bilan hors classement et relance rapide par R, F2 ou Y |
| Menus et commandes | Options accessibles depuis l’accueil et la pause ; affectations clavier et boutons manette personnalisables, indications adaptées et navigation à la souris |
| Langues | Anglais, français, espagnol, portugais, allemand et italien ; choix sauvegardé |
| Classements | Dix scores par difficulté, initiales au clavier ou à la manette, record du mode actif, écran regroupant les deux tables et bilan individuel en fin de partie |
| Affichage | Modèles 3D chromés, Full HD paysage et portrait, plein écran ou fenêtre, interpolation avec VSync, fond étoilé à trois plans et jets de réacteurs progressifs pendant les mouvements |
| Curseur | Masquage après trois secondes sans mouvement en jeu, retour au mouvement de la souris et visibilité dans les menus |
| À propos | Logo cliquable, photo de l’auteur à gauche ouvrant son profil GitHub, lien vers le dépôt, six langues et reprise du contexte après fermeture |
| Son | Banques Original et Moderne sélectionnables, vingt-deux sons par banque, vols et impacts propres aux cinq familles, thèmes de montée et de cycle, annonce d’amarrage et signal de réserve ; volume, silence et aperçu du tir |
| Sauvegardes | Réglages et classements versionnés, vérifiés par SHA-256 ; récupération de la version précédente si nécessaire et import de l’ancien profil |
| Livraison | [Version Windows x64 0.3.1](https://github.com/Kraran/SwarmAttack/releases/tag/v0.3.1), exécutable autonome, guide et licences dans l’archive |

## Architecture et validation

- Godot 4.7.2 standard, GDScript et moteur de rendu Compatibility.
- Simulation à pas fixe pour les collisions, les tirs, les points et les transitions. La présentation interpole les déplacements sans accélérer la simulation.
- Coques et propulsion construites dans le projet. La banque Original utilise les captures arcade ; la banque Moderne contient vingt-deux effets SF synthétisés, en PCM 48 kHz sans perte. Huit voix d’effets, une voix de vol et une voix de séquences sont reliées à un bus moderne avec limiteur. Le générateur déterministe est conservé dans `tools/build_modern_audio.py`.
- Réglages, commandes et classements séparés de la simulation. Les profils utilisent des sauvegardes vérifiées avec récupération de secours.
- Vingt-quatre suites Godot sans affichage couvrent notamment les trajectoires, la continuité des mouvements, l’absence de tirs fantômes, les tirs assemblés, les pertes de modules, l’amarrage I → III, l’entraînement, les classements, les options, À propos, le curseur, les sons et les sauvegardes. L’[audit des collisions](RAPPORT_COLLISIONS.md) ajoute plus de 510 000 assertions sur les contacts fixes et mobiles. Le test de livraison atteint le cycle suivant après deux amarrages réussis.
- Les contrôles graphiques complètent ces suites pour les compositions paysage et portrait. Le guide détaille les [commandes, la compilation et les tests](prototype/README.md).

## Prochaines améliorations

1. Équilibrer la banque Moderne en situation de jeu, à partir des retours d’écoute sur les tirs, les impacts et les séquences simultanées.
2. Affiner la lisibilité des formations, des effets et des amarrages sur les deux orientations ; vérifier les libellés dans les six langues.
3. Mesurer la difficulté sur des parties complètes en Normal et Vétérans, au clavier et à la manette, avant tout ajustement des règles.
4. Profiler le rendu sur les écrans et pilotes réels, en conservant la cadence de simulation, les trois plans d’étoiles et la fidélité visuelle.

## Procédure de livraison

Avant chaque version :

1. Vérifier la révision source et mettre à jour le numéro de version, les liens de téléchargement, le guide et ce plan.
2. Importer le projet et exécuter les vingt-quatre suites avec des profils de test isolés.
3. Contrôler les interactions clavier, manette et souris ainsi que le rendu paysage et portrait des fonctions modifiées.
4. Reconstruire l’archive Windows avec `tools/build_windows.ps1`, puis lancer l’exécutable extrait avec un profil de test isolé.
5. Publier un tag correspondant à la révision testée, joindre l’archive à la version GitHub et vérifier son empreinte SHA-256.
