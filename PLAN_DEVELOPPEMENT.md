# SWARM ATTACK — Plan de développement

Version **1.0.2** : menus « Arcade » à thèmes, treize langues avec choix automatique selon Windows, navigation complète clavier, manette (Xbox, PlayStation, Nintendo) et souris, banque Moderne réorchestrée, mode attraction revu, vitesse identique quelle que soit la fréquence de l’écran, collisions précises sur les modèles HD et fond étoilé en parallaxe. SWARM ATTACK est un jeu de défense orbitale pour Windows, développé avec Godot. Le joueur traverse dix vagues, manœuvre dans des champs de météorites et assemble jusqu’à trois modules pour faire évoluer son armement.

Les correctifs après la 0.3.0 retirent les tirs fantômes aux transitions et les trois arrêts matériels reproduits dans les vagues. Ils maintiennent le déplacement pendant le crédit final et remplacent les délais dépendant de la charge de la borne par un délai d’effet constant. Les tests vérifient désormais ces comportements corrigés ; les relevés arcade restent des références de trajectoires, pas une obligation de reproduire leurs défauts.

## Fonctionnalités réalisées

| Domaine | État en 1.0.2 |
| --- | --- |
| Boucle de jeu | Dix vagues, deux amarrages, cycles successifs, vies, réserve et scores ; solo et duo local en alternance |
| Modules | Seule la coque touchée est détruite ; les survivants se séparent. Après perte du II, le I reprend seul et peut s’amarrer au III resté en réserve |
| Difficulté | Normal : cycle 1, réserve à 30 000 points. Vétérans : cycle 2, réserve à 50 000 points |
| Entraînement | Choix des dix vagues ou des deux amarrages, dans les deux difficultés ; bilan hors classement et relance rapide par R, F2 ou Y |
| Menus et commandes | Menus « Arcade » à côté du terrain, trois thèmes et thèmes personnalisés, menu à droite ou à gauche, introduction animée ; navigation clavier, manette et souris partout, y compris en portrait ; confirmations avant de quitter, Xbox + Start, pause si la manette est débranchée ; affectations personnalisables |
| Langues | Treize langues avec drapeaux : anglais, français, espagnol, portugais, allemand, italien, danois, néerlandais, norvégien, polonais, russe, suédois et turc ; choix sauvegardé |
| Classements | Dix scores par difficulté, initiales au clavier ou à la manette, record du mode actif, écran regroupant les deux tables et bilan individuel en fin de partie |
| Affichage | Modèles 3D chromés, Full HD paysage et portrait, plein écran ou fenêtre, interpolation avec VSync, fond étoilé à trois plans aux couleurs réalistes avec parallaxe horizontale, et jets de réacteurs progressifs pendant les mouvements |
| Vibrations | Deux effets : explosion du joueur (environ une seconde) et double choc d’amarrage réussi ; activation, intensité 0 à 100 % et test ; réglages sauvegardés |
| FPS | Compteur facultatif des images réellement rendues, fenêtre de 0,5 seconde et actualisation à 10 Hz ; actif aussi dans les menus et en pause |
| Curseur | Masquage après trois secondes sans mouvement en jeu, retour au mouvement de la souris et visibilité dans les menus |
| À propos | Logo cliquable, photo de l’auteur à gauche ouvrant son profil GitHub, lien vers le dépôt, aux couleurs du thème, treize langues et reprise du contexte après fermeture |
| Son | Banques Original et Moderne sélectionnables, vingt-deux sons par banque, vols et impacts propres aux cinq familles, thèmes de montée et de cycle, annonce d’amarrage et signal de réserve ; volume, silence et aperçu du tir ; balance stéréo selon les sources et routage audio synchronisé |
| Sauvegardes | Réglages et classements versionnés, vérifiés par SHA-256 ; récupération de la version précédente si nécessaire et import de l’ancien profil |
| Collisions | Précises par défaut : silhouettes des modules HD et rayon apparent de chaque famille d’ennemis ; mode Borne avec les boîtes d’origine ; trajet suivi entre deux images |
| Livraison | [Version Windows x64 1.0.2](https://github.com/Kraran/SwarmAttack/releases/tag/v1.0.2), exécutable autonome avec icône, guide et licences dans l’archive |

## Architecture et validation

- Godot 4.7.2 standard, GDScript et moteur de rendu Compatibility.
- Simulation à pas fixe pour les collisions, les tirs, les points et les transitions. La présentation interpole les déplacements sans accélérer la simulation.
- Coques et propulsion construites dans le projet. La banque Original utilise les captures arcade ; la banque Moderne réorchestre en synthèse moderne la durée, le rythme et la mélodie de chacun des vingt-deux sons arcade, en PCM 48 kHz sans perte. Huit voix d’effets, une voix de vol et une voix de séquences sont reliées à un bus moderne avec limiteur. Le générateur déterministe est conservé dans `tools/modern_audio` et se lance par `tools/build_modern_audio.py`.
- Réglages, commandes et classements séparés de la simulation. Les profils utilisent des sauvegardes vérifiées avec récupération de secours.
- En 0.4.0, les menus possèdent leurs états, interactions et dessins dans des sous-scripts dédiés. Un routeur conserve la priorité des écrans modaux, une navigation commune gère le stick et un calque de menus assure le cache de dessin. La vue conserve la session, la persistance, le son et l’horloge de simulation.
- En 0.4.0, un contrôleur de vibrations indépendant du son gère les impulsions et leurs priorités sur la manette active. Options → Vibrations expose activation, intensité et test, avec persistance et six langues. Les tests simulent les moteurs ; le ressenti et la compatibilité matérielle restent à vérifier sur une manette connectée.
- En 0.4.0, les bruitages Original et Moderne sont spatialisés selon leur source dans le terrain. Le routage indépendant par voix conserve les priorités et le limiteur Moderne ; les sons de vol suivent leur ennemi. Les tests capturent le mixage gauche/droite et vérifient la normalisation du niveau sonore.
- En 1.0.0, les menus passent par des thèmes (`ui/skin.gd`), un fond animé en shader, des retours sonores et animations communs, et une question de sortie globale. Le rendu 3D n’est recalculé que lorsqu’un vaisseau ou un ennemi est visible.
- En 1.0.1, le fond étoilé défile selon le temps écoulé et non plus par image affichée, et un nouveau profil prend la langue de Windows.
- En 1.0.2, `hull_shapes.gd` décrit la silhouette de chaque module, relevée sur son rendu HD, et en tire un champ de distances au démarrage. Le mode précis teste le disque apparent de l’ennemi contre ces silhouettes sur le trajet de l’image ; le mode Borne garde les boîtes relevées sur la borne, toujours couvertes par les tests de référence.
- Trente-cinq suites Godot sans affichage couvrent notamment les trajectoires, la continuité des mouvements, l’absence de tirs fantômes, les tirs assemblés, les pertes de modules, l’amarrage I → III, l’entraînement, les classements, les options, À propos, le curseur, les sons et les sauvegardes. L’[audit des collisions](RAPPORT_COLLISIONS.md) ajoute plus de 510 000 assertions sur les contacts fixes et mobiles. Le test de livraison atteint le cycle suivant après deux amarrages réussis.
- Les audits complémentaires couvrent les dix vagues des cycles 2, 3 et 4, les transitions jusqu’au cycle 5 et le routage audio sous charge. La [vérification de la 1.0.0](RAPPORT_VERIFICATION_1.0.0.md) consigne les résultats.
- Les contrôles graphiques complètent ces suites pour les compositions paysage et portrait. Le guide détaille les [commandes, la compilation et les tests](prototype/README.md).

## Prochaines améliorations

1. Affiner la banque Moderne en situation de jeu, à partir des retours d’écoute sur les tirs, les impacts et les séquences simultanées.
2. Affiner la lisibilité des formations, des effets et des amarrages sur les deux orientations ; faire relire les libellés des treize langues par des locuteurs natifs.
3. Mesurer la difficulté sur des parties complètes en Normal et Vétérans, au clavier et à la manette, avant tout ajustement des règles.
4. Profiler le rendu sur les écrans et pilotes réels, en conservant la cadence de simulation, les trois plans d’étoiles et la fidélité visuelle.

## Procédure de livraison

Avant chaque version :

1. Vérifier la révision source et mettre à jour le numéro de version, les liens de téléchargement, le guide et ce plan.
2. Importer le projet et exécuter les trente-deux suites avec des profils de test isolés.
3. Contrôler les interactions clavier, manette et souris ainsi que le rendu paysage et portrait des fonctions modifiées.
4. Reconstruire l’archive Windows avec `tools/build_windows.ps1`, puis lancer l’exécutable extrait avec un profil de test isolé.
5. Publier un tag correspondant à la révision testée, joindre l’archive à la version GitHub et vérifier son empreinte SHA-256.
