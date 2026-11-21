extends SceneTree

# Collisions « précises » : le contact suit les silhouettes HD des modules et
# le rayon apparent des ennemis, et non les boîtes relevées sur la borne.
const Wave = preload("res://combat_wave.gd")
const Hulls = preload("res://hull_shapes.gd")
const Profile = preload("res://arcade_profile.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_geometry()
	_against_arcade()
	_sweep()
	_attribution()
	_radii()
	await _setting()
	Wave.precise_collisions = false
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("PRECISE COLLISIONS OK")
		quit(0)

# Ennemi seul de la vague 1 (anneaux), placé par son centre affiché.
func _wave(center: Vector2, wave_number := 1, stage := 0) -> Wave:
	var wave := Wave.new(wave_number, 255, -1, stage)
	var enemy := Wave.Enemy.new()
	enemy.alive = true
	enemy.position = Vector2i((center + Vector2(8, -8)).round())
	wave.enemies.assign([enemy])
	return wave

func _geometry() -> void:
	_expect(Hulls.clearance(1, Vector2(0, 5)) == 0.0, "Le cœur du module I est dans sa silhouette")
	_expect(is_equal_approx(Hulls.clearance(1, Vector2(0, -3)), 2.5), "Au-dessus du nez : 2,5 pixels, obtenu %s" % Hulls.clearance(1, Vector2(0, -3)))
	_expect(Hulls.clearance(3, Vector2(-15, 10)) == 0.0 and Hulls.clearance(3, Vector2(15, 10)) == 0.0, "Les ailes du III sont pleines")
	_expect(Hulls.clearance(3, Vector2(-8, 2)) > 2.0, "L'échancrure entre le nez et les ailes du III est vide")
	_expect(Hulls.clearance(2, Vector2(60, 0)) == Hulls.FAR, "Loin du module : distance maximale")

func _against_arcade() -> void:
	# Coin supérieur gauche de la boîte du module I : contact sur la borne, vide à l'écran.
	var corner := Wave.new(1)
	var enemy := Wave.Enemy.new()
	enemy.alive = true
	enemy.position = Vector2i(111, 189)
	corner.enemies.assign([enemy])
	Wave.precise_collisions = false
	_expect(corner.hit_module(112, 1) == 1, "Borne : le coin de la boîte touche le module I")
	Wave.precise_collisions = true
	_expect(corner.hit_module(112, 1) == 0, "Précises : le même coin ne touche pas le module I")
	# Ennemi sur la coque : contact dans les deux modes.
	var body := _wave(Vector2(112, 205))
	_expect(body.hit_module(112, 1) == 1, "Précises : un ennemi sur la coque touche")
	# Au-dessus du nez : contact seulement quand le disque atteint la pointe.
	var radius := body.enemy_radius
	_expect(_wave(Vector2(112, 200 - radius - 1.5)).hit_module(112, 1) == 0, "Précises : pas de contact avant la pointe")
	_expect(_wave(Vector2(112, 200 - radius + 0.5)).hit_module(112, 1) == 1, "Précises : contact quand le disque touche la pointe")
	# Module III seul : boîte haute de la borne, vide au-dessus des ailes.
	var above_wing := _wave(Vector2(98, 210))
	Wave.precise_collisions = false
	var arcade_hit := above_wing.hit_module(112, 4)
	Wave.precise_collisions = true
	_expect(arcade_hit == 3 and above_wing.hit_module(112, 4) == 0, "III seul : au-dessus de l'aile, la borne touche, les silhouettes non")

func _sweep() -> void:
	Wave.precise_collisions = true
	# Un ennemi qui franchit le module I entre deux images est détecté sur son trajet.
	var wave := _wave(Vector2(112, 214))
	var enemy := wave.enemies[0]
	var previous := {enemy: Vector2i(112 + 8, 190 - 8)}
	_expect(wave.hit_module(112, 1, 0) == 0, "Position finale sous le module I : aucun contact statique")
	_expect(wave.hit_module(112, 1, 0, 112, previous) == 1, "Traversée du module I entre deux images : contact")
	# Une réapparition (saut vertical) ne crée pas de traversée fictive.
	var wrap := {enemy: Vector2i(120, 2)}
	_expect(wave.hit_module(112, 1, 0, 112, wrap) == 0, "Réapparition : pas de contact fictif")
	# Le vaisseau qui glisse sous un ennemi immobile le touche aussi.
	var still := _wave(Vector2(112, 205))
	_expect(still.hit_module(112, 1, 0, 90, {still.enemies[0]: still.enemies[0].position}) == 1, "Déplacement du vaisseau sous l'ennemi : contact")


func _attribution() -> void:
	Wave.precise_collisions = true
	_expect(_wave(Vector2(112, 202)).hit_module(112, 7) == 1, "Trio : le nez appartient au module I")
	_expect(_wave(Vector2(127, 228)).hit_module(112, 7) == 3, "Trio : le bout d'aile appartient au module III")
	_expect(_wave(Vector2(112, 218), 1, 1).hit_module(112, 3, 16) == 1, "I + II abaissé de 16 : contact sur le module I")
	_expect(_wave(Vector2(112, 202), 1, 1).hit_module(112, 3, 16) == 0, "I + II abaissé : l'ancienne hauteur est vide")
	for mask in range(1, 8):
		_expect(_wave(Vector2(112, 212)).hit_module(112, mask) == 0 or mask & (1 << (_wave(Vector2(112, 212)).hit_module(112, mask) - 1)), "Masque %d : seule une coque présente est touchée" % mask)

func _radii() -> void:
	var expected := {1: 3.9, 3: 6.0, 5: 5.0, 7: 7.3, 9: 3.7}
	for cycle_wave in expected:
		var stage := 0 if cycle_wave <= 2 else (1 if cycle_wave <= 6 else 2)
		var wave_number: int = cycle_wave - [0, 2, 6][stage]
		_expect(is_equal_approx(Wave.new(wave_number, 255, -1, stage).enemy_radius, expected[cycle_wave]), "Rayon des ennemis de la vague %d" % cycle_wave)

func _setting() -> void:
	var profile := Profile.new()
	_expect(profile.precise_collisions, "Collisions précises par défaut")
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = Profile.new()
	view._profile.language = "fr"
	view._apply_collisions()
	_expect(Wave.precise_collisions, "Le profil active les collisions précises")
	view._options.set_open(true)
	view._options.open_page(view.OptionsMenu.Page.DISPLAY, 5)
	_expect(view._options.option_parts(5) == ["Collisions", "choice", "Précises"], "Options › Affichage : Collisions · Précises")
	view._options.adjust(1)
	_expect(not view._profile.precise_collisions and not Wave.precise_collisions, "Le réglage passe à Borne et s'applique aussitôt")
	_expect(view._options.option_parts(5)[2] == "Borne", "Libellé Borne")
	view._options.adjust(1)
	_expect(Wave.precise_collisions, "Retour aux collisions précises")
	view._options.set_open(false)
	view.free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
