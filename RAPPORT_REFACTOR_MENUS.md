# Extraction des menus — intégrée à la 0.4.0

## Résultat

Au terme de l’extraction initiale, `prototype/prototype_view.gd` passe de 2 435 à 1 378 lignes, soit 1 057 lignes de moins (environ 43 %). Il ne possède plus les états ni les fonctions de navigation et de dessin des menus Options, Pause, Entraînement, Accueil, Classements et Résultats.

Les neuf sous-scripts de `prototype/ui` regroupent les cinq écrans, leur base de présentation, le routeur d’entrées, la navigation commune et le calque de dessin. La [documentation de l’interface](prototype/ui/README.md) décrit leurs responsabilités et les services fournis par la vue.

Le dessin reste fondé sur le calque `Node2D` mis en cache. Le choix de sous-scripts, plutôt qu’une conversion simultanée en widgets natifs `Control`, permet de séparer les responsabilités sans modifier les coordonnées, polices, zones cliquables ou règles de focus. À propos conserve son `Control` existant.

## Frontières conservées

- La vue coordonne la session, la simulation, les effets sonores, le focus, les dimensions de fenêtre et l’horloge. Le rendu du jeu et les trajectoires ne sont pas déplacés.
- Chaque menu possède son choix courant et ses états transitoires ; les anciens champs privés et fonctions de menu ne sont pas maintenus comme doublons dans la vue.
- Le profil conserve les règles de classement et la persistance. Les menus accèdent au profil et à la session courants, sans stocker une ancienne copie lors des redémarrages.
- Le routeur conserve la priorité des dialogues avant les commandes du vaisseau, notamment la capture des touches et l’absence de tir à la fermeture d’un menu.
- Le recalage des commandes et de l’horloge passe par `_sync_menu_input()`. L’hystérésis du stick est commune et réarmée à l’entrée d’un menu.
- Le calque `menu_overlay.gd` conserve l’invalidation du dessin et son ordre au-dessus du terrain. Les écrans de classement utilisent le canevas fourni par la vue ; les autres menus utilisent ce calque.

## Vérification avant/après

La référence est la source publiée 0.3.1 (`0b5b499`), copiée dans un projet de diagnostic isolé, avec le même moteur Godot 4.7.2 et le rendu Compatibility.

- Les 24 suites existantes passent avant l’extraction. Leurs événements et assertions sont conservés après adaptation des accès aux états privés vers leurs nouveaux propriétaires.
- Les 24 suites passent également sur la version finale refactorisée, notamment les 510 290 vérifications de collisions et les tests des menus, du son, des résultats et des sauvegardes.
- Les tests Options ajoutent la vérification du seuil du stick, du maintien, du relâchement, des changements de sens et de l’indépendance des axes. Le test Entraînement vérifie aussi le retour exact vers Options en conservant la partie en pause.
- Les tests Résultats conservent les cas solo/duo, égalités, rangs, difficultés, sauvegarde, abandon de saisie et navigation clavier/manette.
- L’audit graphique capture vingt états dans les six langues et les deux orientations : accueil, sept pages Options, saisie et rejet d’une affectation, erreur de sauvegarde, pause, options en pause, entraînement, bilan, deux classements, résultats, classement final et initiales avec ou sans erreur de sauvegarde.
- Résultat visuel : **240 comparaisons exactes des pixels, aucune différence**. Animation, pointeur et focus sont fixés dans le dispositif de capture pour comparer les mêmes états. Une première série a permis d’identifier puis d’éliminer les différences de survol et de focus dues au contexte de lancement des fenêtres de test.

`tools/audit_menu_render.gd` conserve le dispositif de capture et la comparaison des empreintes. Les projets de référence, images et profils de diagnostic restent dans `.reference`, hors dépôt et hors distribution.

L’extraction est intégrée à la 0.4.0. La [vérification de livraison](RAPPORT_VERIFICATION_0.4.0.md) complète ces mesures historiques avec les vibrations, la stéréo et le compteur FPS ajoutés ensuite. L’archive Windows 0.4.0 est reconstruite. L’exécutable extrait démarre sans erreur de script avec un profil isolé ; les empreintes des copies locales de l’exécutable et de l’archive correspondent aux fichiers construits.
