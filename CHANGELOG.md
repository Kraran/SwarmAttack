# Notes de version

## 0.4.0 — 19 novembre 2026

- Options → Affichage → Compteur FPS : activation sauvegardée et traduite, affichage discret en haut à droite en paysage et portrait. Cadence mesurée sur les images réellement rendues et l’horloge monotone, actualisée dix fois par seconde sur une fenêtre de 0,5 seconde, y compris dans les menus et en pause.
- Correction d’une fermeture brutale du mixeur audio pendant le jeu : les destinations de bus stéréo ne sont plus réécrites à chaque image ; un changement de destination utilise le verrou du serveur audio. Stéréo, priorités sonores et limiteur conservés. Journaux locaux rotatifs et état de partie aux transitions activés pour le diagnostic.
- Stéréo positionnelle dans les banques Original et Moderne : tirs à la position du vaisseau, explosions au point d’impact, contacts à la position d’amarrage et sons de vol suivant leur ennemi. Balance proportionnelle sur la largeur du terrain, niveau sonore normalisé ; musiques, annonces et aperçu des options centrés. Routage indépendant par voix, compatible avec les effets simultanés et le limiteur Moderne.
- Vibrations limitées à deux signatures : forte secousse explosive de 480 ms lors de la destruction du joueur (combat ou collision d’amarrage), et choc unique puissant de 85 ms au contact d’un amarrage réussi. Aucun retour au tir, sur les ennemis, à la vie supplémentaire ou à la fin d’une vague d’entraînement.
- Réglage initial conservé à 70 %, avec une courbe d’intensité renforcée. Le test des options joue un contact d’amarrage puis une explosion, séparés par un silence. Séquences annulées à la pause ou à la perte de focus.
- Options → Vibrations : activation, intensité de 0 à 100 % (70 % par défaut), aperçu et bouton de test, sauvegardés dans le profil et traduits dans les six langues. Arrêt à la pause, à la perte de focus, au changement de manette et à la sortie.
- État, navigation et dessin des menus Options, Pause, Entraînement, Accueil, Classements et Résultats extraits de `prototype_view.gd` vers des sous-scripts dédiés dans `prototype/ui`.
- Routage modal des événements et navigation au stick isolés ; calque de menus et cache de dessin dédiés. La simulation, les profils, le son et le rendu de jeu restent coordonnés par la vue.
- Interactions et apparence conservées, avec tests de navigation au stick et du retour Entraînement → Options renforcés.

## 0.3.1

- Fin de cycle : thème spécifique confirmé dans MAME et déclenché au début de la montée, puis musique d’arrivée au cycle suivant, sans interruption prématurée ni musique concurrente.
- Cinq sons de vol/réapparition et cinq impacts spécifiques aux familles d’ennemis, analysés et capturés séparément dans MAME ; équivalents SF dans la banque Moderne. Déclenchements liés aux apparitions et retours, impacts et musiques prioritaires, arrêt des vols aux transitions.
- Véritable annonce d’amarrage à la place d’un extrait de vol mal identifié, et son de vie supplémentaire au franchissement du seuil.
- Musique de décollage rejouée après destruction, avant l’amarrage et à l’arrivée du cycle suivant, dans les deux banques ; thème spécifique au départ de fin de cycle.
- Jets des réacteurs allongés et légèrement élargis pendant les déplacements, avec montée et retour progressifs, synchronisés sur l’animation et figés en pause.
- Logo cliquable ouvrant À propos, avec photo de l’auteur à gauche et liens GitHub, dans les six langues et les deux orientations. La partie et le son sont figés pendant la consultation.
- Collisions continues sur les trajets relatifs des tirs, ennemis et vaisseaux, sans collision fictive lors des retours par les bords ou des réapparitions.
- Première cible rencontrée prioritaire dans les superpositions, sorties masquées exclues et contacts cohérents au bord supérieur.
- Diagnostic F1 enrichi avec les zones de contact des modules et les fenêtres d’amarrage ; audit des sept assemblages et des quatre approches.
- Suppression des tirs fantômes après amarrage, quelle que soit son issue, et nettoyage des projectiles à la fin des vagues.
- Un maintien du bouton pendant la transition ne déclenche pas de tir à la reprise ; un nouvel appui tire normalement.
- Suppression des arrêts aux frames 34, 118 et 212, y compris les commandes ignorées pendant ces frames.
- Déplacement conservé pendant le crédit des derniers points, avec un délai d’effet constant indépendant de la charge de la borne.
- Tests mis à jour pour vérifier les corrections, les trajectoires et une partie complète avec les deux amarrages.

## 0.3.0

### Options et confort de jeu

- Difficultés Normal et Vétérans, avec départ aux cycles 1 et 2 et réserve à 30 000 ou 50 000 points.
- Menus en anglais, français, espagnol, portugais, allemand et italien.
- Réglages du son et de l’affichage, commandes clavier et boutons manette personnalisables.
- Curseur masqué après trois secondes sans mouvement pendant le jeu, réaffiché au mouvement de la souris et visible dans les menus.

### Entraînement et classements

- Sélection des dix vagues et des deux amarrages dans les deux difficultés, hors classement.
- Relance immédiate de l’exercice avec R, F2 ou Y ; choix d’un autre exercice depuis le bilan.
- Dix scores indépendants par difficulté, initiales au clavier ou à la manette et bilan de fin de partie.
- Sauvegardes versionnées et vérifiées, avec récupération automatique de la version précédente.

### Son et modules

- Choix entre les banques Original et Moderne, avec aperçu du tir et sauvegarde du choix. Original reste sélectionnée par défaut.
- Onze effets SF modernes, plusieurs voix simultanées et limiteur sur le bus moderne.
- Destruction du seul module touché, sans recréer les coques perdues.
- Après la perte du II, reprise avec le I seul, III en réserve ; amarrage I → III possible au prochain rendez-vous. I + III utilise le tir central du I et la paire large du III.

### Distribution

Archive Windows x64 autonome comprenant l’exécutable, le guide et les licences Godot. Décompresser puis lancer `SwarmAttack.exe`.
