# SWARM ATTACK — Audit des collisions

Audit du code local 0.3.1-dev, incluant les correctifs de fluidité et de tirs fantômes. Les modifications déjà présentes ont été conservées.

## Résultat

Les 21 suites existantes passaient avant l’audit, mais ne couvraient pas quatre anomalies reproduites. Après correction, les **22 suites passent**. La nouvelle suite `prototype/tests/test_collision_audit.gd` exécute **510 290 assertions**, sans échec.

Les volumes fixes des contacts avec les modules ont été conservés : **275 562 positions avant/après donnent exactement la même attribution de module**. Cet audit fiabilise la détection temporelle et le choix des cibles ; il ne redimensionne pas les coques pour modifier la difficulté.

## Anomalies reproduites et corrigées

| Cas | Avant | Après |
| --- | --- | --- |
| Ennemis superposés | L’ordre dans le tableau pouvait sélectionner l’ennemi du fond | Le premier contact sur le trajet du tir est retenu ; à égalité, la cible rencontrée depuis le bas passe en premier |
| Objets masqués en sortie | Un objet encore actif mais non dessiné pouvait être touché | Les phases de sortie masquées sont exclues des collisions de tir et de vaisseau |
| Croisement tir/ennemi | Un trajet diagonal pouvait passer entre deux positions testées | Le mouvement relatif des deux objets est testé sur tout le segment du pas logique |
| Frôlement du vaisseau entre deux pas | Un ennemi pouvait traverser un coin de la zone sans être détecté | Le déplacement relatif de l’ennemi et du joueur est également balayé |
| Bord supérieur | Une garde globale sur l’ordonnée du tir empêchait certains contacts autorisés par la hitbox | La géométrie du contact décide, sans cette exception liée au bord supérieur |

Exemples reproductibles en coordonnées logiques :

- Deux ennemis en `(112, 100)` et `(112, 108)`, tir en `(95, 104)` : la cible du bas doit être touchée, indépendamment de l’ordre des objets.
- Objet `ROW_EXIT` en `(112, 7)`, tir en `(95, 8)` : aucun impact, car l’objet est masqué.
- Ennemi passant de `(110, 192)` à `(114, 188)`, vaisseau I en `x = 112` : les deux extrémités sont hors contact, mais le segment traverse la zone.
- Ennemi passant de `(113, 100)` à `(109, 104)`, tir passant de `(95, 103)` à `(95, 99)` : le croisement intermédiaire doit toucher l’ennemi.

Les retours par les bords et les réapparitions ne sont pas traités comme une traversée de l’écran. Les objets nouveaux n’ont pas de trajectoire de collision avant leur apparition. Un impact détruit toujours un seul module et chaque ennemi est crédité une seule fois.

## Couverture

| Vérification | Étendue |
| --- | --- |
| Contacts fixes des modules | 275 562 positions ; I, II, III, I + II, I + III, II + III, I + II + III ; centre et butées `14/112/200` ; offsets `0/16` |
| Bords des tirs | Limites exactes de la zone de tir, contacts au bord supérieur, frôlements, cibles mortes et masquées |
| Ordre des impacts | Ennemis superposés dans les deux ordres, demi-coques indépendantes, tirs simultanés et crédit unique |
| Contacts mobiles | Croisements réels dans `CombatRound`, retours horizontaux/verticaux, réapparitions et absence de trajectoire antérieure |
| Balayage géométrique | 10 000 segments déterministes ; symétrie du sens de parcours, translation et recherche de contacts manqués par échantillonnage |
| Amarrage | 16 524 positions pour I → II, II → III, I + II → III et I → III ; priorité de la collision, frontières et stabilité du résultat |
| Réussite d’amarrage | 36 positions de réussite par combinaison dans la grille ; volumes de collision inchangés |
| Parcours de livraison | 9 250 pas, deux amarrages réussis, cycle 2 atteint, 14 340 points sur le nouvel enregistrement d’entrées |
| Cadence | Tests existants d’interpolation et de simulation identique à 30, 60, 120 et 144 Hz |
| Affichage | Sept combinaisons en HD et diagnostic, quatre approches d’amarrage, paysage et portrait |

## Diagnostic F1

Le diagnostic utilise maintenant les mêmes définitions de rectangles que la simulation :

- En combat, les zones de tir sur les ennemis restent affichées ; les rectangles rouges autour des modules indiquent les positions de centre ennemi qui provoquent un contact.
- À l’amarrage, le rouge montre la zone de collision et le vert la fenêtre candidate de capture. **Le rouge est prioritaire** dans leur partie commune.

Ces rectangles sont des volumes de jeu, pas des masques pixel par pixel de chaque coque 3D. Ils conservent les marges existantes et ne suivent pas les flammes, les traînées, l’éclairage ou chaque variation de silhouette. Le diagnostic montre les positions logiques ; le rendu HD interpole entre ces positions. Aucune nouvelle adaptation de la taille des hitboxes à la rotation ou au grossissement visuel n’a été ajoutée pendant cet audit.

## Reproduire les tests

Après import du projet, depuis la racine, avec un dossier de profil de test isolé :

```powershell
$godot = '.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = "$PWD/.reference/collision-audit-manual-appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
& $godot --headless --path prototype --script res://tests/test_collision_audit.gd
foreach ($suite in Get-ChildItem prototype/tests/test_*.gd, prototype/tests/smoke.gd) {
    & $godot --headless --path prototype --script "res://tests/$($suite.Name)"
    if ($LASTEXITCODE -ne 0) { throw "Échec : $($suite.Name)" }
}
```

Les journaux de cet audit sont dans `.reference/collision-audit-before`, `.reference/collision-audit-final` et `.reference/collision-audit-gui.log`. Les captures graphiques locales portent le préfixe `.reference/collision-audit-`.
