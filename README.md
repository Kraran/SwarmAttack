# SWARM ATTACK

SWARM ATTACK est un jeu de défense orbitale. Pilotez votre vaisseau à travers dix vagues et assemblez ses trois modules lors des manœuvres d’amarrage. Jouez en solo ou à deux en alternance sur le même PC.

**[Télécharger la 0.4.0 pour Windows x64](https://github.com/Kraran/SwarmAttack/releases/download/v0.4.0/SwarmAttack-Windows-x64.zip)** · [Notes de version](https://github.com/Kraran/SwarmAttack/releases/tag/v0.4.0)

Décompressez l’archive et ouvrez `SwarmAttack.exe`. Espace lance une partie et sert à tirer. Déplacez-vous avec les flèches ou la manette. Échap ouvre le menu de pause et F5 coupe ou réactive le son.

La version 0.4.0 comprend :

- Des modèles 3D chromés, un rendu Full HD ou portrait et des mouvements interpolés avec VSync.
- Un menu Options pour la difficulté, les six langues, le son, l’affichage et les commandes personnalisables au clavier et à la manette.
- Un entraînement aux **dix vagues et aux deux amarrages**, en Normal ou Vétérans, hors classement. F2 ouvre le sélecteur ; R, F2 ou Y relance l’exercice.
- Deux classements indépendants de dix scores, pour Normal et Vétérans, avec saisie des initiales au clavier ou à la manette et bilan de fin de partie.
- Deux banques sonores en stéréo positionnelle : **Original**, sélectionnée par défaut, et **Moderne**, avec vingt-deux effets SF. Les sons de vol suivent les ennemis ; les impacts et tirs viennent de leur position dans le terrain.
- Des vibrations de manette réglables : explosion du vaisseau et choc au contact d’un amarrage réussi, sans vibration au tir.
- Un compteur FPS facultatif mesurant les images réellement rendues, en haut à droite, y compris dans les menus et en pause.
- Un curseur masqué après trois secondes sans mouvement en jeu, qui réapparaît dès que la souris bouge et reste accessible dans les menus.
- Des collisions continues vérifiées sur les sept assemblages, des transitions sans tirs fantômes et des animations débarrassées des arrêts matériels de la borne.
- Des jets de réacteurs qui grandissent progressivement pendant les déplacements et un logo cliquable ouvrant À propos.
- Des sons de vol et d’impact propres aux cinq familles d’ennemis, une annonce d’amarrage corrigée, un son de vie supplémentaire et le thème spécifique de passage de cycle.

Les impacts détruisent uniquement le module touché. Après la perte du II, le I reprend seul et peut rejoindre le III resté en réserve au prochain amarrage. Le développement s’appuie sur plusieurs versions arcade. La 0.4.0 corrige la fermeture brutale liée au routage audio et sépare les menus dans des sous-scripts dédiés.

- [Commandes, compilation et tests](prototype/README.md)
- [Plan de développement](PLAN_DEVELOPPEMENT.md)
- [Audit des collisions](RAPPORT_COLLISIONS.md) · [Analyse des sons](RAPPORT_SONS_ENNEMIS.md)
- [Vérification de la 0.4.0](RAPPORT_VERIFICATION_0.4.0.md) · [Correction du plantage audio](RAPPORT_PLANTAGE_AUDIO.md)
