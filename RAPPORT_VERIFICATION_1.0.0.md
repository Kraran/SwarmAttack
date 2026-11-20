# Vérification de SWARM ATTACK 1.0.0

Vérification du 20 novembre 2026, avant publication. Moteur Godot 4.7.2 (Linux, sans affichage et sous X virtuel avec rendu logiciel OpenGL), export Windows x64 avec le modèle officiel `windows_release_x86_64.exe`. Les profils de test sont isolés ; les sauvegardes réelles du joueur ne sont pas utilisées.

## Résultats

| Domaine | Contrôle | Résultat |
| --- | --- | --- |
| Import | Import complet du projet, nouvelles polices, musique et sons | Terminé, sans erreur de script ni d’import |
| Régressions | 31 suites Godot, dont les nouvelles suites confirmation de sortie, manette débranchée, musique de démarrage et menu portrait | 31 réussites |
| Collisions | Sept assemblages, contacts fixes et mobiles, quatre amarrages | 510 290 vérifications, aucun échec |
| Progression | Livraison : cycle complet, duo, réserve, profil et démo | Réussi |
| Traductions | Recherche statique des textes traduits et journal des textes absents pendant les captures et les tests, en anglais et en russe | Aucun texte manquant ; seules les touches (↑, ↓, F3…) restent volontairement identiques |
| Interface | Captures des menus en paysage et portrait, trois thèmes, menu à gauche et à droite, treize langues échantillonnées (dont russe, turc, polonais) | Textes complets, pas de glyphe manquant, pas de débordement constaté |
| Mode attraction | Présentation, classement et démo complète, dont le second amarrage retouché et les explosions | Conforme ; un seul logo, polices du thème |
| Banque Moderne | 22 sons : durée identique à l’original, niveau perçu aligné (pondération K), pics, continuité, crêtes de limiteur | Conforme ; écoute de validation faite par l’auteur |
| Performances | Temps d’image sur l’écran titre, la démo, les menus et en partie | Rendu 3D sauté lorsqu’aucun objet n’est visible : environ 45 % de temps d’image en moins sur l’écran titre en rendu logiciel |
| Export | Construction Windows release depuis Linux | Exécutable produit, ressources de version identiques à la 0.4.0 (modification des ressources désactivée) |
| Archive exportée | Chargement du pack embarqué | Version 1.0.0, treize langues, musique, polices et sons présents ; tests et README exclus |
| Démarrage du pack | Jeu lancé depuis le pack exporté, 400 images, profil neuf | Sortie normale, aucune erreur de script |
| Archive | `SwarmAttack.exe`, `LISEZ-MOI.txt`, `LICENCES-GODOT.txt`, `LICENCES-POLICES.txt` | Contenu conforme ; empreinte SHA-256 publiée avec la version |

## Portée des vérifications

L’exécutable Windows a été exporté et son pack contrôlé depuis Linux ; le premier lancement natif sous Windows reste à faire sur le poste de l’auteur. Les vibrations et la déconnexion de manette sont vérifiées avec des manettes simulées ; le ressenti physique dépend du matériel. Les traductions ajoutées (danois, néerlandais, norvégien, polonais, russe, suédois, turc) gagneraient à être relues par des locuteurs natifs.

Les outils reproductibles sont conservés dans `prototype/tests`, `tools/capture_ui.gd`, `tools/audit_menu_render.gd` et `tools/modern_audio`.
