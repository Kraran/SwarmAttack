# Guide de SwarmAttack

Décompressez la [version 0.3.1 pour Windows x64](https://github.com/Kraran/SwarmAttack/releases/tag/v0.3.1) et ouvrez `SwarmAttack.exe`.

| Action | Clavier | Manette |
| --- | --- | --- |
| Jouer en solo, tirer, freiner pendant l’amarrage | Espace | A |
| Jouer à deux en alternance | 2 | Y |
| Déplacer le module | ←/→ ou Q/D | Stick gauche ou croix |
| Mettre en pause ou reprendre | Échap | Start |
| Choisir et valider dans la pause | ↑/↓ et Entrée | Croix et A |
| Revenir à l’accueil depuis la pause | T | B |
| Recommencer | R | |
| Choisir un entraînement ; relancer l’exercice en entraînement | F2 | Y pour relancer |
| Ouvrir les options depuis l’accueil ou la pause | F3 | X |
| Choisir et valider dans les options | ↑/↓ et Entrée | Croix et A |
| Activer ou couper le son | F5 | |
| Alterner entre paysage et portrait | F10 | |
| Alterner entre plein écran et fenêtré | F11 | |
| Activer le diagnostic visuel | F1 | |

Le menu de pause propose « Reprendre », « Options », « Entraînement », « Accueil » et « Quitter ». La souris permet également de choisir ces options. En jeu, le curseur disparaît après trois secondes sans mouvement de la souris et réapparaît dès qu’elle bouge.

Le logo **SWARM ATTACK** est cliquable et ouvre **À propos**, avec la photo de Franck Fornasari (Kraran) à gauche. La photo et Profil GitHub ouvrent son profil ; Projet GitHub ouvre le dépôt du jeu. Fermer, Échap, B ou Start revient à l’écran précédent. L’ouverture pendant une partie fige le jeu et le son, puis restitue leur état à la fermeture. L’écran est adapté au paysage et au portrait, dans les six langues.

**Entraînement**, depuis l’accueil, les options, la pause ou F2, propose les dix vagues et les deux amarrages en Normal ou Vétérans. L’exercice s’arrête après réussite ou échec, hors classement. R, F2 ou Y relance le même exercice ; le bilan permet de changer d’exercice. Annuler le sélecteur conserve la partie en pause.

**Options > Son > Sons** choisit Original (par défaut) ou Moderne, avec un aperçu du tir et sauvegarde du choix. La banque moderne comprend vingt-deux effets SF en PCM 48 kHz sans perte, huit voix d’effets, une voix de vol indépendante des séquences et un limiteur sur son bus. `tools/build_modern_audio.py` régénère cette banque de façon déterministe.

La musique de décollage accompagne l’arrivée initiale, le remplacement après destruction, la montée avant amarrage et l’arrivée au cycle suivant. Elle démarre une seule fois par montée, dans la banque sonore choisie.

Le départ de fin de cycle utilise son thème spécifique, confirmé dans MAME. Il commence avec la montée et se termine avant la musique d’arrivée du cycle suivant, sans interruption prématurée.

Les cinq familles possèdent leurs propres sons de vol/réapparition et d’impact, avec de nouvelles captures MAME pour Original et des équivalents SF pour Moderne. Les vols se déclenchent aux apparitions et aux retours, sans tir nécessaire, et s’arrêtent aux transitions. L’annonce d’amarrage et le son de vie supplémentaire sont également corrigés. Voir le [rapport d’analyse sonore](../RAPPORT_SONS_ENNEMIS.md).

Les sous-menus Options regroupent le volume (0 à 100 %), la coupure du son, l’affichage plein écran ou fenêtré, l’orientation portrait ou paysage et la langue. Commandes permet de réaffecter le déplacement, le tir/freinage et la pause au clavier et aux boutons de manette. Sélectionnez une action puis appuyez sur la touche ou le bouton voulu. Échap ou Back annule la saisie. Une affectation déjà utilisée échange les deux commandes. Le stick gauche déplace le vaisseau et permet de naviguer dans les options. Les commandes par défaut peuvent être rétablies pour le clavier, la manette ou les deux. Les indications du jeu affichent les affectations choisies.

Le menu Options de l’accueil enregistre la difficulté des prochaines parties, en solo comme en duo. En **Normal**, la partie débute au cycle 1 et la réserve est acquise à 30 000 points. En **Vétérans**, elle débute à la première vague du cycle 2 et la réserve est acquise à 50 000 points.

## En jeu

Le score, le record et l’état des modules s’affichent dans le terrain. Le record est mis à jour à la fin de la partie. Avant l’approche d’amarrage, les instructions rappellent comment diriger et freiner. Le chrono affiche 30:0 pendant la montée du module cible.

Au départ, le vaisseau monte avec ses trois modules. Les deux modules inférieurs se détachent, puis le module I rejoint sa position de combat avant l’ouverture de la première vague. Après la perte du module I, les modules II et III remontent ensemble. Le III redescend hors champ pendant que le II prend le relais.

Après une collision d’amarrage, « AUCUN BONUS » s’affiche avant que le module cible reprenne seul. Les modules intacts forment le porteur au cycle suivant. Si la réserve est acquise, « UNE PARTIE DE PLUS » annonce le retour des trois modules à la perte de la dernière vie, avec le score conservé.

En combat, un impact sur un assemblage détruit uniquement le module touché et retire une seule vie. Les survivants se séparent. Après la perte du II dans le trio, **seul le I se redéploie**, le III intact restant en réserve. Au prochain amarrage, le I peut rejoindre le III ; **I + III** n’est formé qu’après réussite. Cet assemblage tire au centre avec le I et en paire large avec le III. Le II détruit ne revient pas et ne tire pas. Une expiration laisse le I seul ; une collision d’approche laisse le III seul.

Le cycle compte dix vagues et deux amarrages. Les premières formations comportent des rotors en deux demi-coques, puis viennent les chasseurs à pinces et les intercepteurs. Les météorites des vagues 7 et 8 descendent en diagonale. Les capsules des deux dernières vagues zigzaguent avant de plonger.

Les modules assemblés élargissent les possibilités de tir. Une fois les trois modules réunis, le petit module tire au centre et les deux paires latérales alternent. En duo, chacun joue à son tour avec ses propres vies et son score. Les réglages et les classements sont conservés dans `%APPDATA%\Godot\app_userdata\SwarmAttack\arcade.cfg.saves`. Le fichier historique `arcade.cfg` est importé automatiquement. Chaque sauvegarde est vérifiée par SHA-256 puis publiée sous un nom unique. Les deux dernières versions valides servent de sauvegarde principale et de secours. Une version illisible provoque la récupération automatique de la précédente, signalée à l’accueil.

Après chaque partie, le bilan affiche le score, le rang enregistré, le cycle atteint et les amarrages réussis de chaque joueur. Les nouvelles entrées sont surlignées dans le classement. Haut/bas choisit Voir le classement ou Accueil, puis Entrée/A valide. Échap/B revient au bilan depuis le classement, puis à l’accueil depuis le bilan. Le tableau de l’accueil reste visible environ huit secondes.

Le pas logique est de 16,5 ms. Le rendu interpole les positions et suit le rafraîchissement de l’écran via la VSync. Les trois plans d’étoiles descendent de 1, 2 et 3 pixels physiques par image. Le fond se fige en pause et sa cadence suit la fréquence de l’écran. La composition paysage est prévue pour 1920 × 1080. F1 affiche les positions et les zones de collision du diagnostic.

Les jets des réacteurs s’allongent jusqu’à environ deux fois leur taille et s’élargissent légèrement lorsque les vaisseaux se déplacent. La montée et le retour au repos sont progressifs ; l’effet se fige avec l’animation en pause et ne change ni les déplacements ni les collisions.

Les correctifs 0.3.1 excluent les défauts matériels de la borne : aucun arrêt artificiel aux frames 34, 118 et 212, aucun tir conservé à la fin d’une vague ou restauré après un amarrage. Un nouvel appui est nécessaire pour tirer à la reprise. Le vaisseau reste mobile pendant le crédit des derniers points ; le délai d’effet est constant et ne dépend plus du nombre d’ennemis. Les cadences des trajectoires et l’interpolation conservent la vitesse du jeu.

L’[audit des collisions](../RAPPORT_COLLISIONS.md) couvre les sept combinaisons de modules et les quatre types d’amarrage. Les trajets entre deux pas logiques sont pris en compte, les sorties masquées ne sont pas touchables et le tir rencontre la première cible sur son passage. F1 affiche les zones de contact des modules et les fenêtres d’amarrage ; la collision rouge est prioritaire sur la capture verte.

## Développement

Ouvrez [project.godot](project.godot) dans Godot 4.7.2 standard. Le [lanceur Windows](../Lancer%20le%20prototype.cmd) utilise l’exécutable Godot placé dans `.tools/godot-4.7.2`.

Pour produire l’archive Windows, placez le modèle d’export `windows_release_x86_64.exe` dans `.tools/godot-4.7.2/templates` et lancez depuis la racine.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

L’archive produite se trouve dans `dist/SwarmAttack-Windows-x64.zip`.

## Tests

Importez le projet avant la première exécution des tests. Depuis la racine, en remplaçant `$godot` par le chemin de l’exécutable console, lancez les vingt-quatre suites.

```powershell
& $godot --headless --editor --import --path prototype
foreach ($test in Get-ChildItem prototype/tests/test_*.gd, prototype/tests/smoke.gd) {
    & $godot --headless --path prototype --script "res://tests/$($test.Name)"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

La suite de livraison joue deux amarrages et atteint le deuxième cycle. Les tests de combat couvrent 18 trajectoires et 1 405 points de contrôle. Les [outils de trace](../tools/arcade/README.md) servent au diagnostic des mouvements et des collisions.
