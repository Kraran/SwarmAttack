# Vérification de SWARM ATTACK 0.4.0

Vérification du 19 novembre 2026, avant publication. Moteur Godot 4.7.2, Windows x64, rendu Compatibility sur Intel UHD Graphics 630. Les profils de test sont isolés dans `.reference` ; les sauvegardes réelles du joueur ne sont pas utilisées.

## Résultats

| Domaine | Contrôle | Résultat |
| --- | --- | --- |
| Import | Import complet du projet en contexte Windows normal | Terminé, sans erreur de script ni erreur d’import |
| Régressions | 27 suites Godot | 27 réussites |
| Collisions | Sept assemblages, contacts fixes et mobiles, quatre amarrages | 510 290 vérifications, aucun échec |
| Progression | Replay d’un cycle complet, duo, réserve et difficultés | Réussi, deux amarrages et passage au cycle suivant |
| Stabilité graphique | Dix vagues aux cycles 2, 3 et 4 ; transitions vers 3, 4 et 5 | 30 870 pas et 3 861 images rendues, sortie normale |
| Stabilité audio | 60 secondes de charge avec changements de destination | 16 040 000 mises à jour, sans plantage ni fuite signalée à la fermeture |
| Stéréo | Captures du mixage Original et Moderne à cinq positions, voix simultanées | Gauche/droite et niveau global conformes ; musique centrée |
| Sons ennemis | Lecteurs réels, dix vagues, retours et météorites | Réussi, priorités et transitions conservées |
| FPS | Limites à 30 et 60, arrêt du rendu, pause, deux orientations | Environ 30,01 / 60,01 FPS ; zéro lorsque le rendu est arrêté ; préférence sauvegardée |
| Interface | Matrice de 252 captures : 21 états, six langues, deux orientations | Captures produites sans erreur ; contrôles visuels de dispositions et traductions représentatives |
| Compteur FPS | Douze captures complémentaires, six langues et deux orientations | En haut à droite, hors des commandes |
| Profils | Sauvegardes, récupération, profils anciens et nouvelles préférences | Réussi |
| Vibrations | Destruction du joueur, contact d’amarrage, exclusions, arrêt, intensité et sauvegarde | Commandes de moteurs simulées conformes |
| Export | Construction Windows release et extraction du ZIP | Exécutable, guide 0.4.0 et licences présents |
| Archive exportée | Chargement du pack depuis le dossier extrait | Version 0.4.0, À propos 0.4.0, tests et fichiers privés absents |
| Code exporté | Tests Livraison, Options et Vibrations contre le pack compilé | Réussis |
| Démarrage natif | Exécutable extrait, profil neuf, arrêt automatique après 180 images | Sortie 0, aucune erreur dans le journal |

## Points vérifiés et ajustements

- Le routage stéréo sécurisé reste actif. Les destinations inchangées ne sont pas réassignées ; un changement réel prend le verrou du serveur audio.
- Le test de charge utilise volontairement des sons bouclés. Son nettoyage attend désormais leur arrêt effectif avant de détruire les bus : le premier passage sous charge signalait encore des lectures en attente à la fermeture du dispositif. Le passage final de 60 secondes ne signale plus de fuite. Le comportement sonore du jeu n’a pas été modifié pour ce nettoyage de test.
- L’import initial en bac à sable signalait une écriture de cache de l’éditeur refusée. Le même import, avec profil isolé et permissions Windows normales, est propre ; la sauvegarde sécurisée n’a pas été désactivée.
- Les versions dans le projet, le guide, les notes, le README et le plan sont harmonisées sur 0.4.0. Les anciennes versions du changelog restent historiques.
- L’archive contient uniquement `SwarmAttack.exe`, `LISEZ-MOI.txt` et `LICENCES-GODOT.txt`. Les ROM, vidéos, captures, journaux et profils de diagnostic restent hors de la livraison.

## Portée des vérifications

Le parcours des cycles est un dispositif borné utilisant les vrais ennemis, collisions, sons et rendu ; ce n’est pas une série de parties intégralement jouées par un humain. Le ressenti physique des vibrations reste dépendant de la manette : aucune manette n’est connectée sur le poste de validation.

L’outil de contrôle interactif de la fenêtre native a expiré côté autorisation. Le démarrage natif, le contenu du pack et les tests d’interaction exécutés sur le code exporté ont été vérifiés séparément. Les tests graphiques utilisent le même moteur et les ressources de la version livrée.

Le profilage GPU approfondi reste au plan de développement. Les FPS et les tests de stabilité ne constituent pas une mesure complète de la marge GPU sur tous les matériels.

Les traces détaillées sont locales sous `.reference/release-040-*`. Les outils reproductibles sont conservés dans `prototype/tests`, `tools/audit_menu_render.gd`, `tools/audit_cycle_stability.gd` et `tools/audit_audio_stability.gd`.
