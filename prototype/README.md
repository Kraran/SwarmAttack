# SwarmAttack — Prototype de la première vague

Sous Windows, ouvrir [Lancer le prototype.cmd](../Lancer%20le%20prototype.cmd). Le lanceur utilise l’installation portable de Godot dans `.tools`. Le projet Godot s’ouvre avec [project.godot](project.godot).

| Action | Commande |
| --- | --- |
| Déplacer le module | Flèches gauche et droite, Q et D, stick gauche ou croix de la manette |
| Tirer | Espace ou bouton A |
| Recommencer | R |
| Masquer ou afficher la grille et les mesures | F1 |

Le prototype démarre aux commandes du module I sur le terrain de 224 × 256 unités logiques. Quatre paires entrent en formation. Chaque moitié détruite rapporte 50 points, et les survivants peuvent se séparer et plonger. La manche se termine lorsque les huit cibles sont détruites ou lorsque le module I entre en collision. Appuyer sur R pour rejouer.

L’horloge applique un pas de 16,5 ms. La vue affiche le score et le nombre de cibles. La grille, les zones de collision du projectile et les coordonnées s’affichent avec F1. Les formes restent celles d’une vue de diagnostic. La suite du parcours arcade commence au prochain jalon, avec les vagues suivantes et l’amarrage.

## Comparaison avec Jeutel

Depuis la racine de SwarmAttack, produire les traces MAME puis lancer le comparateur Godot.

```powershell
python .\tools\arcade\capture.py --scenario idle --scenario movement --scenario opposed --scenario fire --scenario fire_tap --scenario fire_busy
python .\tools\arcade\capture.py --replay tools\arcade\replays\module-i-combined.csv --frames 596 --output .reference\module-i-combined
python .\tools\arcade\capture.py --replay tools\arcade\replays\module-i-expiry.csv --frames 610 --output .reference\module-i-expiry

$godot = '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$traces = (Resolve-Path .reference).Path
& $godot --headless --path prototype --script res://tests/compare_jeutel.gd -- `
    "$traces\mouncrst" `
    "$traces\module-i-combined\mouncrst\replay.csv" `
    "$traces\module-i-expiry\mouncrst\replay.csv"
```

Les cinq fenêtres de tir sans collision correspondent à Jeutel sur 699 images au total. Le comparateur vérifie aussi les déplacements enregistrés et rapporte les écarts de position liés aux pauses de déplacement dans MAME. Dans le test isolé de traversée, le déplacement à chaque pas produit un écart temporaire de 12 pixels logiques au maximum. Les deux limites mesurées sont atteintes. La cadence du module reste à affiner pour les parties complètes.

Les positions des huit cibles correspondent sur les 87 premières images de la formation. Deux séquences de tir touchent les mêmes cibles que Jeutel. Les impacts des frames 575 et 778 correspondent exactement. L’impact Jeutel de la frame 699 se produit à la frame 698 dans le prototype. Des cas de contact vérifient les limites de collision du module I. Un essai automatisé a terminé la manche avec 400 points. La cadence après l’ouverture reste approximative, car les interruptions Jeutel varient selon la situation. Les trajectoires longues et les plongeons tardifs demandent encore un relevé plus complet.
