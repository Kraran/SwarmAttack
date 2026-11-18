# Sons des ennemis — analyse et correction

Analyse locale du 18 novembre 2026 avec MAME 0.286 et la ROM fournie, puis capture séparée des sons par le pilote sonore de la machine.

## Ce qui manquait

Le jeu ne déclenchait aucun son de vol ou de réapparition. Il jouait le même extrait `wave.wav` à toutes les transitions de combat et le même `impact.wav` pour toutes les victimes. Ces extraits ne remplacent pas les sons propres aux cinq familles.

Les registres de MAME confirment cinq commandes de vol (0 à 4) et cinq commandes d’impact (5 à 9). Les commandes de vol se produisent à l’apparition et à la réapparition après une sortie du terrain, même sans tir. Elles ne correspondent pas à un bruit permanent répété à chaque image ni à un son à ajouter à chaque changement de direction.

## Captures isolées intégrées

Les durées comprennent une marge finale de 80 ms et des rampes anti-clic de 2 ms à l’entrée et 10 ms à la sortie. Les fichiers restent en PCM mono 16 bits à 48 kHz, sans normalisation ni compression avec perte.

| Vagues du cycle | Famille | Commande de vol | Durée | Commande d’impact | Durée |
| --- | --- | --- | --- | --- | --- |
| 1–2 | Anneaux divisibles | 0 | 5,542 s | 5 | 0,806 s |
| 3–4 | Pinces | 2 | 2,638 s | 7 | 0,938 s |
| 5–6 | Intercepteurs | 1 | 1,862 s | 6 | 0,674 s |
| 7–8 | Météorites | 3 | 1,647 s | 8 | 1,070 s |
| 9–10 | Ennemis en rangée | 4 | 2,736 s | 9 | 0,674 s |

Les numéros de commande suivent l’ordre du programme arcade, différent de l’ordre des vagues. La capture distingue donc bien les pinces des intercepteurs.

L’extraction suspend les tâches graphiques de l’attraction après le test mémoire initial, tout en conservant le pilote sonore et ses interruptions. Le rendu audio évite ainsi les ralentissements induits par ces tâches. Les marges finales et la synchronisation de début expliquent que la durée du WAV dépasse celle du seul motif audible.

## Preuves observées dans MAME

Le replay local de 20 800 images couvre un cycle complet et le début du suivant. Exemples de commandes acceptées :

- Image 571 : commande 0 pour l’apparition des huit moitiés d’anneaux ; image 1085 : même commande au retour d’un ennemi sorti du terrain.
- Image 4426 : commande 2 au retour d’un ennemi de la première famille à entrée large.
- Image 10935 : commande 1 après le premier amarrage ; image 11017 : même commande lors d’un retour.
- Images 14164, 14230 et 14313 : commande 3 pour les paires successives de météorites.
- Image 16693 : commande 4 pour les ennemis en rangée ; image 16742 : commande 4 lors d’un retour.
- Les impacts utilisent respectivement les commandes 5, 7, 6, 8 et 9 selon la famille.

Les départs simultanés sont regroupés en un déclenchement audible par pas logique. Sur la borne, plusieurs commandes identiques écrites dans la même image relancent le même circuit avant son rendu sonore.

Le [pilote sonore de MAME](https://github.com/mamedev/mame/blob/master/src/mame/galaxian/galaxian_a.cpp) confirme la séparation du circuit de tir et de la voie tonale. Les captures locales déterminent les commandes, leur correspondance et leurs déclenchements.

## Comportement corrigé

- Son de vol spécifique à l’apparition et aux retours ; nouvelle paire de météorites audible sans tirer.
- Son d’impact propre à chaque famille.
- Suppression de l’extrait de début de vague générique au profit des véritables événements.
- Banque Original : le tir reste indépendant ; les vols peuvent remplacer d’autres vols, mais ne coupent pas les impacts ou les musiques en cours. Aucun empilement artificiel de huit vols identiques.
- Banque Moderne : dix équivalents SF distincts, lecteur de vol indépendant des effets, arrêté aux transitions.
- Pause, volume, silence, changement de banque et arrêt de partie appliqués aux nouvelles voix.
- Trajectoires, collisions, vitesse et score inchangés.

Deux autres anomalies ont été corrigées : l’ancien `dock.wav` avait été découpé dans un retour d’ennemi (commande 2, image 6432), et ne contenait pas l’annonce d’amarrage. Il est remplacé par la commande 15, relevée aux images 9600 et 14869. La commande 16 de vie supplémentaire, absente du lecteur, est ajoutée et déclenchée une seule fois au franchissement du seuil. Les WAV isolés mesurent respectivement 13,115 s et 3,529 s ; la musique de montée demandée conserve son déclenchement au début du mouvement et peut donc remplacer l’annonce d’amarrage en cours.

## Reproduction et vérifications

`tools/arcade/capture_enemy_audio.py` enregistre le WAV, les écritures sonores, les commandes acceptées et les états RAM avec un replay local. `tools/arcade/extract_enemy_audio.py` déclenche séparément les douze commandes dans MAME et extrait les WAV. Les ROMs et les captures de diagnostic restent dans les emplacements locaux ignorés par Git.

`prototype/tests/test_enemy_audio.gd` vérifie les dix vagues, les retours, les paires de météorites, les impacts, l’absence de répétition par image, la pause et le format PCM. En rendu graphique, ce même test vérifie aussi les lecteurs réels, les priorités et la séparation des voix. Les suites existantes restent applicables, notamment les remontées musicales, le cycle complet et l’audit des collisions.

Résultats : 24 suites réussies avec profils isolés, dont les 510 290 vérifications de collisions ; test sonore également réussi avec rendu OpenGL et lecteurs audio réels. Les deux banques et les remontées musicales restent couvertes.

### Enchaînement de fin de cycle

La vérification suivante a reproduit six échecs de régression, trois par banque : `cycle` était lancé à l’entrée en fin de cycle, puis interrompu 33 images (0,5445 s) plus tard par `launch`. Ce dernier dure 6,237 s en Original, alors que la remontée suivante commence seulement 303 images (4,9995 s) après le départ : il était donc encore interrompu.

Une nouvelle capture MAME de 18 400 images confirme la commande 13 à l’image 17635 (passage de cycle, état `0x0e`), puis la commande 10 à l’image 17921 (arrivée, état `0x11`). Ce sont deux thèmes distincts. Le précédent remplacement par un motif court de l’arrivée était donc incorrect.

Le thème `cycle` est rétabli au début de la montée, à +33 images, au lieu d’être lancé trop tôt puis coupé par `launch`. La musique d’arrivée complète ne démarre qu’à la montée suivante, à +336 images. Le délai de 303 images (4,9995 s) laisse finir le thème Original (4,6695 s) et son équivalent Moderne (1,30 s). Les tests vérifient cet intervalle entre les deux thèmes, et non la seule durée pendant laquelle le vaisseau reste visible.
