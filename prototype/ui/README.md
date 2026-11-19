# Menus et présentation

Les menus sont des sous-scripts possédant leur état, leurs interactions et leur dessin. Ils conservent le rendu `Node2D` mis en cache pour préserver la disposition et les textes existants ; cette extraction n’introduit pas une nouvelle navigation native `Control` en parallèle.

| Script | Responsabilité |
| --- | --- |
| `options_menu.gd` | Pages, choix, réglages, remappage, annulation de capture et erreurs de sauvegarde |
| `pause_menu.gd` | État de pause, sélection, reprise, options, entraînement, accueil et sortie |
| `training_menu.gd` | Sélecteur, bilan et retour au contexte précédent |
| `title_menu.gd` | Boutons d’accueil, options et indications de commandes |
| `scores_menu.gd` | Classements, saisie des initiales, bilans solo/duo et navigation associée |
| `menu_input.gd` | Priorité des dialogues et raccourcis avant les commandes de jeu |
| `menu_navigation.gd` | Navigation clavier/manette et hystérésis du stick, partagée entre les menus |
| `menu_overlay.gd` | Calque supérieur et invalidation du dessin à partir de l’état des menus |
| `menu_screen.gd` | Palette, texte, coordonnées et accès aux services de la vue |
| `fps_counter.gd` | Mesure indépendante de la cadence réelle de rendu et affichage en haut à droite, sans invalider les autres calques |

`prototype_view.gd` instancie les menus et conserve la session, le son, l’horloge et le rendu du jeu. Le profil reste responsable des règles de classement et de la persistance. Les menus utilisent ces services sans conserver une ancienne copie du profil ou de la session. `_sync_menu_input()` recale l’horloge et les commandes à l’ouverture ou à la fermeture pour éviter un rattrapage ou un tir involontaire.

Le routeur respecte l’ordre existant : À propos et logo, saisie des initiales, événements répétés, entraînement et bilan, résultats/classements, options, pause puis raccourcis. Seuls les événements qui traversent ce filtre mettent à jour les commandes du vaisseau. À propos conserve sa scène `Control` existante ; les classements restent confiés au modèle de profil pour les règles et la sauvegarde.

Les fonctions et les états privés des menus ne restent pas dupliqués dans la vue. Les tests qui configuraient ces états accèdent maintenant au menu concerné (`view._options`, `view._pause`, `view._training`), tout en conservant leurs événements et assertions de comportement.

L’audit `tools/audit_menu_render.gd` capture 252 écrans : vingt et un états, six langues et deux orientations, dont la page Vibrations. Il fige l’animation et injecte une position de pointeur constante, puis compare les empreintes des pixels avec une référence. Les profils de test doivent être isolés via `APPDATA` comme pour les suites du projet.
