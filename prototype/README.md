# Guide de SwarmAttack

Décompressez la [version 1.0.2 pour Windows x64](https://github.com/Kraran/SwarmAttack/releases/tag/v1.0.2) (`SwarmAttack-1.0.2-Win64.zip`) et ouvrez `SwarmAttack.exe`.

| Action | Clavier | Manette |
| --- | --- | --- |
| Jouer en solo, tirer, freiner pendant l’amarrage | Espace | A |
| Jouer à deux en alternance | 2 | Y |
| Déplacer le module | ←/→ ou Q/D | Stick gauche ou croix |
| Mettre en pause ou reprendre | Échap | Start |
| Choisir et valider dans la pause | ↑/↓ et Entrée | Croix et A |
| Revenir à l’accueil depuis la pause (avec confirmation) | T | B |
| Quitter le jeu de partout (avec confirmation) | | Xbox + Start (PS + Options) |
| Ouvrir le menu de l’accueil en portrait | ↑/↓ | Croix ou stick |
| Recommencer | R | |
| Choisir un entraînement ; relancer l’exercice en entraînement | F2 | Y pour relancer |
| Ouvrir les options depuis l’accueil ou la pause | F3 | X |
| Choisir et valider dans les options | ↑/↓ et Entrée | Croix et A |
| Activer ou couper le son | F5 | |
| Alterner entre paysage et portrait | F10 | |
| Alterner entre plein écran et fenêtré | F11 | |
| Activer le diagnostic visuel | F1 | |

Le menu de pause propose « Reprendre », « Options », « Entraînement », « Accueil » et « Quitter ». « Accueil » et « Quitter » demandent une confirmation, « Non » étant présélectionné. La souris permet également de choisir ces options. Si la manette utilisée pour jouer est débranchée ou perdue, la partie se met en pause et l’affiche. En jeu, le curseur disparaît après trois secondes sans mouvement de la souris et réapparaît dès qu’elle bouge.

Le logo **SWARM ATTACK** est cliquable et ouvre **À propos**, avec la photo de Franck Fornasari (Kraran) à gauche. La photo et Profil GitHub ouvrent son profil ; Projet GitHub ouvre le dépôt du jeu. Fermer, Échap, B ou Start revient à l’écran précédent. L’ouverture pendant une partie fige le jeu et le son, puis restitue leur état à la fermeture. L’écran reprend le thème choisi et s’adapte au paysage et au portrait, dans les treize langues.

**Entraînement**, depuis l’accueil, les options, la pause ou F2, propose les dix vagues et les deux amarrages en Normal ou Vétérans. L’exercice s’arrête après réussite ou échec, hors classement. R, F2 ou Y relance le même exercice ; le bilan permet de changer d’exercice. Annuler le sélecteur conserve la partie en pause.

**Options > Son > Sons** choisit Original (par défaut) ou Moderne, avec un aperçu du tir et sauvegarde du choix. La banque moderne comprend vingt-deux sons en PCM 48 kHz sans perte, huit voix d’effets, une voix de vol indépendante des séquences et un limiteur sur son bus. Chaque son reprend la durée, le rythme et la mélodie de son équivalent arcade, réorchestrés en synthèse moderne : thèmes joués par des synthés avec basse, accords et percussions, explosions en couches (souffle, grave, débris, réverbération), vols et impacts qui suivent le contour mélodique d’origine. Le niveau est aligné sur la banque Original en sonie perçue (pondération K). `tools/build_modern_audio.py` régénère cette banque de façon déterministe à partir des sons arcade (NumPy et SciPy nécessaires à la génération uniquement).

La musique de décollage accompagne l’arrivée initiale, le remplacement après destruction, la montée avant amarrage et l’arrivée au cycle suivant. Elle démarre une seule fois par montée, dans la banque sonore choisie.

Les bruitages sont spatialisés en stéréo dans les deux banques : plus leur source se trouve à gauche ou à droite du terrain, plus ils s’entendent de ce côté. Les tirs partent du vaisseau, les explosions du point d’impact et les sons de vol suivent leur ennemi. Les contacts d’amarrage sont également positionnés. Le niveau global reste régulier pendant les déplacements ; chaque voix garde sa propre balance lorsque plusieurs effets se superposent. Musiques, annonces, signal de réserve et aperçu du menu Son restent centrés. Le comportement est identique en paysage et en portrait.

Le routage des bus reste stable pendant les mouvements. Les rares changements de destination sont synchronisés avec le mixeur audio pour éviter une fermeture native de Godot. Les journaux locaux sont conservés dans `%APPDATA%\Godot\app_userdata\SwarmAttack\logs` (quatre fichiers au maximum) et indiquent cycle, vague et phase aux transitions. Voir le [rapport de correction](../RAPPORT_PLANTAGE_AUDIO.md).

Le départ de fin de cycle utilise son thème spécifique, confirmé dans MAME. Il commence avec la montée et se termine avant la musique d’arrivée du cycle suivant, sans interruption prématurée.

Les cinq familles possèdent leurs propres sons de vol/réapparition et d’impact, avec de nouvelles captures MAME pour Original et des équivalents SF pour Moderne. Les vols se déclenchent aux apparitions et aux retours, sans tir nécessaire, et s’arrêtent aux transitions. L’annonce d’amarrage et le son de vie supplémentaire sont également corrigés. Voir le [rapport d’analyse sonore](../RAPPORT_SONS_ENNEMIS.md).

Les sous-menus Options regroupent le volume (0 à 100 %), la coupure du son, l’affichage plein écran ou fenêtré, l’orientation portrait ou paysage, le thème, la disposition du menu et la langue. Treize langues sont proposées, chacune avec son drapeau. Commandes permet de réaffecter le déplacement, le tir/freinage et la pause au clavier et aux boutons de manette. Sélectionnez une action puis appuyez sur la touche ou le bouton voulu. Échap ou Back annule la saisie. Une affectation déjà utilisée échange les deux commandes. Le stick gauche déplace le vaisseau et permet de naviguer dans les options. Les commandes par défaut peuvent être rétablies pour le clavier, la manette ou les deux. Les indications du jeu affichent les affectations choisies.

Le menu Options de l’accueil enregistre la difficulté des prochaines parties, en solo comme en duo. En **Normal**, la partie débute au cycle 1 et la réserve est acquise à 30 000 points. En **Vétérans**, elle débute à la première vague du cycle 2 et la réserve est acquise à 50 000 points.

**Options → Affichage → Compteur FPS** affiche la cadence réelle de rendu en haut à droite. Le choix est sauvegardé et désactivé par défaut. La mesure utilise le compteur d’images rendues de Godot et l’horloge monotone, indépendamment du pas de simulation, du temps de jeu ou de la fréquence nominale du moniteur. Elle s’actualise dix fois par seconde sur une fenêtre de 0,5 seconde et continue dans les menus et pendant la pause. Un arrêt du rendu produit zéro FPS ; le compteur ne reste pas artificiellement à 60.

## En jeu

Options → Vibrations permet d’activer ou désactiver le retour de la manette, de régler son intensité de 0 à 100 % et de le tester. Le réglage est sauvegardé ; l’intensité initiale reste de 70 %. Deux effets sont conservés : une forte secousse explosive lors de la destruction d’un vaisseau du joueur, y compris une collision d’amarrage, et un double choc puissant au contact d’un amarrage réussi. Les tirs, les explosions ennemies et les vies supplémentaires ne déclenchent aucune vibration. Les effets restent indépendants du son et s’arrêtent à la pause, à la perte de focus et au retour à l’accueil ; l’ouverture automatique d’un écran de résultats ne coupe pas une explosion en cours. La dernière manette utilisée reçoit les effets ; lorsqu’une seule est branchée, elle est sélectionnée automatiquement. Le bouton de test nécessite une manette compatible connectée, des vibrations activées et une intensité supérieure à zéro.

Le score, le record et l’état des modules s’affichent dans le terrain. Le record est mis à jour à la fin de la partie. Avant l’approche d’amarrage, les instructions rappellent comment diriger et freiner. Le chrono affiche 30:0 pendant la montée du module cible.

Au départ, le vaisseau monte avec ses trois modules. Les deux modules inférieurs se détachent, puis le module I rejoint sa position de combat avant l’ouverture de la première vague. Après la perte du module I, les modules II et III remontent ensemble. Le III redescend hors champ pendant que le II prend le relais.

Après une collision d’amarrage, « AUCUN BONUS » s’affiche avant que le module cible reprenne seul. Les modules intacts forment le porteur au cycle suivant. Si la réserve est acquise, « UNE PARTIE DE PLUS » annonce le retour des trois modules à la perte de la dernière vie, avec le score conservé.

En combat, un impact sur un assemblage détruit uniquement le module touché et retire une seule vie. Les survivants se séparent. Après la perte du II dans le trio, **seul le I se redéploie**, le III intact restant en réserve. Au prochain amarrage, le I peut rejoindre le III ; **I + III** n’est formé qu’après réussite. Cet assemblage tire au centre avec le I et en paire large avec le III. Le II détruit ne revient pas et ne tire pas. Une expiration laisse le I seul ; une collision d’approche laisse le III seul.

Le cycle compte dix vagues et deux amarrages. Les premières formations comportent des rotors en deux demi-coques, puis viennent les chasseurs à pinces et les intercepteurs. Les météorites des vagues 7 et 8 descendent en diagonale. Les capsules des deux dernières vagues zigzaguent avant de plonger.

Les modules assemblés élargissent les possibilités de tir. Une fois les trois modules réunis, le petit module tire au centre et les deux paires latérales alternent. En duo, chacun joue à son tour avec ses propres vies et son score. Les réglages et les classements sont conservés dans `%APPDATA%\Godot\app_userdata\SwarmAttack\arcade.cfg.saves`. Le fichier historique `arcade.cfg` est importé automatiquement. Chaque sauvegarde est vérifiée par SHA-256 puis publiée sous un nom unique. Les deux dernières versions valides servent de sauvegarde principale et de secours. Une version illisible provoque la récupération automatique de la précédente, signalée à l’accueil.

Après chaque partie, le bilan affiche le score, le rang enregistré, le cycle atteint et les amarrages réussis de chaque joueur. Les nouvelles entrées sont surlignées dans le classement. Haut/bas choisit Voir le classement ou Accueil, puis Entrée/A valide. Échap/B revient au bilan depuis le classement, puis à l’accueil depuis le bilan. Le tableau de l’accueil reste visible environ huit secondes.

Le pas logique est de 16,5 ms. Le rendu interpole les positions et suit le rafraîchissement de l’écran via la VSync. Les trois plans d’étoiles descendent de 60, 120 et 180 pixels physiques par seconde, au pixel près, quelle que soit la fréquence de l’écran (60, 120 ou 144 Hz). Le fond se fige en pause. La composition paysage est prévue pour 1920 × 1080. F1 affiche les positions et les zones de collision du diagnostic.

Les jets des réacteurs s’allongent jusqu’à environ deux fois leur taille et s’élargissent légèrement lorsque les vaisseaux se déplacent. La montée et le retour au repos sont progressifs ; l’effet se fige avec l’animation en pause et ne change ni les déplacements ni les collisions.

Les correctifs 0.3.1 excluent les défauts matériels de la borne : aucun arrêt artificiel aux frames 34, 118 et 212, aucun tir conservé à la fin d’une vague ou restauré après un amarrage. Un nouvel appui est nécessaire pour tirer à la reprise. Le vaisseau reste mobile pendant le crédit des derniers points ; le délai d’effet est constant et ne dépend plus du nombre d’ennemis. Les cadences des trajectoires et l’interpolation conservent la vitesse du jeu.

L’[audit des collisions](../RAPPORT_COLLISIONS.md) couvre les sept combinaisons de modules et les quatre types d’amarrage. Les trajets entre deux pas logiques sont pris en compte, les sorties masquées ne sont pas touchables et le tir rencontre la première cible sur son passage. F1 affiche les zones de contact des modules et les fenêtres d’amarrage ; la collision rouge est prioritaire sur la capture verte.

## Développement

Le choc d’amarrage dure 580 ms : contact plein pendant 160 ms, courte coupure, puis verrouillage fort qui s’estompe ; il est déclenché au contact réussi et sans répétition pendant le bonus. La destruction du joueur dure 950 ms, avec une attaque pleine suivie d’une décroissance en quatre étapes ; une collision d’amarrage prolonge le premier choc (1,1 s au total). Le bouton « Tester les vibrations » joue un contact d’amarrage, une pause puis une explosion du joueur.

Ouvrez [project.godot](project.godot) dans Godot 4.7.2 standard. Le [lanceur Windows](../Lancer%20le%20prototype.cmd) utilise l’exécutable Godot placé dans `.tools/godot-4.7.2`.

Pour produire l’archive Windows, placez le modèle d’export `windows_release_x86_64.exe` dans `.tools/godot-4.7.2/templates` et lancez depuis la racine.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

L’archive produite se trouve dans `dist/SwarmAttack-Windows-x64.zip`.

### Interface en 1.0.0

Les menus utilisent des thèmes définis dans [`ui/skin.gd`](ui/skin.gd) : Orbital (par défaut), Arcade et Phosphore, ainsi que des thèmes personnalisés placés dans `user://skins`. Le fond animé est un shader unique, les retours sonores et le glissement des écrans sont gérés par `ui/menu_feedback.gd`, et la question « Quitter le jeu ? » par `ui/quit_prompt.gd`. Les détails sont dans le [README de l’interface](ui/README.md).

### Interface en 0.4.0

Les menus Options, Pause, Entraînement, Accueil, Classements et Résultats sont extraits dans [`ui`](ui/README.md), avec leurs états et leur dessin. Un routeur traite les écrans modaux avant les commandes du vaisseau ; le calque des menus conserve le cache de rendu. La vue garde la session, le son et l’horloge du jeu ; le profil reste responsable des règles de classement et de la persistance.

Le [rapport de refactorisation](../RAPPORT_REFACTOR_MENUS.md) détaille les frontières et la comparaison visuelle avant/après.

L’audit visuel se lance avec un moteur graphique et un profil de test isolé. Le dernier argument est facultatif et désigne un dossier de captures de référence contenant `hashes.json`.

```powershell
& $godot --path prototype --script ../tools/audit_menu_render.gd -- .reference/menu-captures .reference/menu-baseline
```

## Tests

Importez le projet avant la première exécution des tests. Depuis la racine, en remplaçant `$godot` par le chemin de l’exécutable console, lancez les trente-cinq suites.

```powershell
& $godot --headless --editor --import --path prototype
foreach ($test in Get-ChildItem prototype/tests/test_*.gd, prototype/tests/smoke.gd) {
    & $godot --headless --path prototype --script "res://tests/$($test.Name)"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

La suite de livraison joue deux amarrages et atteint le deuxième cycle. Les tests de combat couvrent 18 trajectoires et 1 405 points de contrôle. Les [outils de trace](../tools/arcade/README.md) servent au diagnostic des mouvements et des collisions.

Les audits de stabilité audio et des cycles utilisent aussi un profil `APPDATA` isolé. Le premier sollicite le mixeur pendant un temps réel donné ; `switch` ajoute des changements de destination. Le second rend les dix vagues aux cycles 2, 3 et 4 et vérifie les transitions vers les cycles 3, 4 et 5.

```powershell
& $godot --headless --path prototype --script ../tools/audit_audio_stability.gd -- 30 switch
& $godot --path prototype --script ../tools/audit_cycle_stability.gd
```
