# Fermeture brutale pendant une vague au cycle 3

## Diagnostic

Le rapport Windows de l’exécutable local confirme une violation d’accès `0xC0000005`, à l’offset `0x0241BB5D` dans `SwarmAttack.exe` (moteur Godot 4.7.2).

L’analyse de cet exécutable, conservé localement avant correction, situe l’adresse dans `AudioServer::_mix_step`. Les références aux chaînes `_mix_step`, `bus_details_ptr` et `servers/audio/audio_server.cpp` identifient la fonction. L’instruction fautive lit `send->index_cache`, après la recherche de la destination d’un bus. Il ne s’agit pas d’un dépassement de numéro de cycle dans les règles du jeu.

Le nouveau routage stéréo réassignait `AudioServer.set_bus_send()` lors de chaque mise à jour de panoramique, même quand la destination était identique. Or le mixeur lit le nom de destination puis l’utilise dans deux recherches successives. La modification concurrente de ce nom peut invalider cette recherche. Dans [les sources officielles de Godot 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/audio/audio_server.cpp), `set_bus_send()` ne prend pas le verrou audio lui-même.

## Correction

- La mise à jour d’un panoramique modifie la balance et le gain, sans réécrire une destination inchangée.
- Les rares changements de destination, notamment l’aperçu Original/Moderne, sont protégés par `AudioServer.lock()` et `unlock()`.
- Les banques, les priorités, le niveau sonore, la stéréo et le limiteur Moderne sont conservés.
- Les journaux locaux rotatifs sont activés, avec cycle, vague et phase aux transitions. Ils restent dans le profil local et ne sont pas livrés dans l’archive.

## Vérification

| Contrôle | Résultat |
| --- | --- |
| Stress avant correction, mixeur réel avec pilote Dummy | Fermeture native `0xC0000005` après le jalon de 400 000 mises à jour |
| Même charge après correction, 20 secondes | 5 716 000 mises à jour, sortie normale |
| Charge avec changements de destination, 30 secondes | 7 020 000 mises à jour, sortie normale et nettoyage sans fuite signalée |
| Simulation, rendu Compatibility et audio actifs | Dix vagues des cycles 2, 3 et 4 ; transitions vers les cycles 3, 4 et 5 ; 30 870 pas et 3 861 images rendues, sortie normale |
| Régressions | 26 suites réussies, dont mixage stéréo capturé, cycles, collisions, sons et vibrations |

Le contrôle graphique utilise des séquences bornées avec les véritables ennemis, collisions et transitions. Il complète les tests de règles ; il ne constitue pas trois parties jouées intégralement par un joueur.

Les outils `tools/audit_audio_stability.gd` et `tools/audit_cycle_stability.gd` permettent de refaire ces vérifications. Les résultats locaux sont conservés sous `.reference` et utilisent des profils de test isolés. Les rapports Windows et données de profil de l’utilisateur ne sont pas inclus dans les livrables.
