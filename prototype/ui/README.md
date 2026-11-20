# Menus et présentation

## Style Arcade et skins

Depuis la 0.5, tous les menus sont dessinés avec un skin (`skin.gd`) : couleurs, polices, biseau des boutons, ombres, glyphes clavier/manette et fond. Trois thèmes sont fournis : **Orbital** (Orbitron, Rajdhani, cyan sur bleu nuit, boutons droits), thème par défaut ; **Arcade** (Bebas Neue, Teko, Press Start 2P, jaune/rouge sur violet, boutons biseautés) ; **Phosphore** (vert monochrome à fort contraste). Le choix se fait dans Options → Affichage → Thème ; il n'est enregistré dans le profil que lorsque le joueur change de thème, sinon le défaut s'applique.

Un joueur peut ajouter son propre thème dans `%APPDATA%\Godot\app_userdata\SwarmAttack\skins\<nom>.cfg`, section `[skin]`, avec les mêmes clés que les entrées de `SKINS` (couleurs `"#rrggbbaa"`, `skew`, `shadow_offset`, chemins de polices `res://fonts/...` ou `user://...`). Les clés absentes reprennent celles d'Orbital.

Le fond est un shader unique (`backdrop.gdshader`) qui couvre toute la surface visible, y compris sur les écrans ultra-larges ou en portrait sur un écran paysage : le jeu garde sa disposition 16:9 (ou portrait), centrée, et l'espace restant montre le fond au lieu de bandes noires. Il s'anime sur le GPU (rayons qui tournent, halo qui respire, trame qui défile, éclair coloré à l'amarrage, aux bonus, aux pertes et en fin de cycle) ; le processeur n'envoie que l'horloge à chaque image.

En paysage, Options → Affichage → Disposition place le menu à droite (défaut) ou à gauche ; le choix est sauvegardé dans le profil (`menu_left`). Le panneau garde ses coordonnées de mise en page et il est simplement décalé au dessin, et les positions du pointeur sont reconverties par `_panel_point()`. Le terrain reste toujours affiché à côté du menu : accueil, pause, options, entraînement et saisie des initiales occupent le panneau de droite ; la pause voile légèrement le terrain figé. En portrait, faute de panneau, les menus s'affichent sur un voile translucide au-dessus du terrain. La barre d'aide du bas suit le dernier périphérique utilisé (touches ou boutons de manette). Les polices sont sous licence SIL OFL 1.1 (`fonts/LICENCES-POLICES.txt`).

`tools/capture_ui.gd` produit des captures Full HD de tous les écrans : `godot --path prototype --script ../tools/capture_ui.gd -- DOSSIER fr,en landscape|portrait|both [arcade|phosphor]`.


Les menus sont des sous-scripts possédant leur état, leurs interactions et leur dessin. Ils conservent le rendu `Node2D` mis en cache pour préserver la disposition et les textes existants ; cette extraction n’introduit pas une nouvelle navigation native `Control` en parallèle.

| Script | Responsabilité |
| --- | --- |
| `options_menu.gd` | Pages, choix, réglages, remappage, annulation de capture et erreurs de sauvegarde |
| `pause_menu.gd` | État de pause, sélection, reprise, options, entraînement, accueil et sortie |
| `training_menu.gd` | Sélecteur, bilan et retour au contexte précédent |
| `title_menu.gd` | Liste d’accueil navigable (clavier, manette, souris), difficulté, meilleurs scores et aides en jeu |
| `scores_menu.gd` | Classements, saisie des initiales, bilans solo/duo et navigation associée |
| `menu_input.gd` | Priorité des dialogues et raccourcis avant les commandes de jeu |
| `menu_navigation.gd` | Navigation clavier/manette et hystérésis du stick, partagée entre les menus |
| `menu_overlay.gd` | Calque supérieur et invalidation du dessin à partir de l’état des menus |
| `skin.gd` | Skins intégrés et personnalisés, primitives de dessin (boutons biseautés, panneaux, jauges, glyphes, barre d'aide, fond) |
| `menu_screen.gd` | Zones du panneau, en-têtes, aides selon le périphérique et accès aux services de la vue |
| `fps_counter.gd` | Mesure indépendante de la cadence réelle de rendu et affichage en haut à droite, sans invalider les autres calques |

`prototype_view.gd` instancie les menus et conserve la session, le son, l’horloge et le rendu du jeu. Le profil reste responsable des règles de classement et de la persistance. Les menus utilisent ces services sans conserver une ancienne copie du profil ou de la session. `_sync_menu_input()` recale l’horloge et les commandes à l’ouverture ou à la fermeture pour éviter un rattrapage ou un tir involontaire.

Le routeur respecte l’ordre existant : À propos et logo, saisie des initiales, événements répétés, entraînement et bilan, résultats/classements, options, pause puis raccourcis. Seuls les événements qui traversent ce filtre mettent à jour les commandes du vaisseau. À propos conserve sa scène `Control` existante ; les classements restent confiés au modèle de profil pour les règles et la sauvegarde.

Les fonctions et les états privés des menus ne restent pas dupliqués dans la vue. Les tests qui configuraient ces états accèdent maintenant au menu concerné (`view._options`, `view._pause`, `view._training`), tout en conservant leurs événements et assertions de comportement.

L’audit `tools/audit_menu_render.gd` capture 252 écrans : vingt et un états, six langues et deux orientations, dont la page Vibrations. Il fige l’animation et injecte une position de pointeur constante, puis compare les empreintes des pixels avec une référence. Les profils de test doivent être isolés via `APPDATA` comme pour les suites du projet.
