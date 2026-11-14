extends SceneTree

const Pilot = preload("res://pilot.gd")

var failures := 0


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _initialize() -> void:
	_check_first_pair_then_single()
	_check_alternation_after_clear()
	_check_lifetimes()
	_check_tap_does_not_repeat()
	_check_hold_does_not_queue()
	_check_left_limit()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("I + II FIRE OK")
		quit(0)


func _i_ii(start_x := Pilot.START_X) -> Pilot:
	return Pilot.new(1, start_x, 3)


func _expect_pair(shots: Array, height: int, ship_x: int, label: String) -> void:
	var left := Vector2i(ship_x - 1 - Pilot.I_II_PAIR_SPREAD, height)
	var right := Vector2i(ship_x - 1 + Pilot.I_II_PAIR_SPREAD, height)
	_expect(left in shots and right in shots, "%s : attendu %s et %s, obtenu %s" % [label, left, right, shots])


func _check_first_pair_then_single() -> void:
	# pr6-tir-i-ii : tap 11020, paire visible à 11021, x matériel 122/138
	# (logique 105/121 à x vaisseau = 114), y = 211. Tap 11035, projectile
	# central visible à 11036 (x matériel 130, y = 199), les deux volées ensemble.
	var pilot := _i_ii(114)
	pilot.step(Pilot.FIRE)
	var first := pilot.active_shots()
	_expect(first.size() == 2, "Premier appui : une paire, obtenu %d" % first.size())
	_expect_pair(first, Pilot.I_II_PAIR_START_Y, 114, "Groupe 0")
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	var both := pilot.active_shots()
	_expect(both.size() == 3, "Paire et projectile central peuvent voler ensemble, obtenu %d" % both.size())
	_expect_pair(both, Pilot.I_II_PAIR_START_Y - 2 * Pilot.SHOT_STEP, 114, "Groupe 0 encore en vol")
	_expect(Vector2i(113, Pilot.I_II_SINGLE_START_Y) in both, "Groupe 1 central à y = 199, obtenu %s" % str(both))
	print("OK I + II : paire écart 8 à y = 211, puis un tir central à y = 199")


func _check_alternation_after_clear() -> void:
	# pr6 : après la fin des volées, le tap 11090 relance la paire.
	var pilot := _i_ii()
	pilot.step(Pilot.FIRE)
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	while not pilot.active_shots().is_empty():
		pilot.step(0)
	pilot.step(Pilot.FIRE)
	_expect_pair(pilot.active_shots(), Pilot.I_II_PAIR_START_Y, Pilot.START_X, "Après dégagement, le groupe 0 repart")
	print("OK alternance : après dégagement, le prochain appui relance la paire")


func _check_lifetimes() -> void:
	# pr6 maintien 11170–11289 : paire visible 11171–11223 (y = 211 → 3),
	# disparue à 11224, soit 53 images.
	var pair := _i_ii()
	pair.step(Pilot.FIRE)
	var frames := 1
	while true:
		pair.step(0)
		if pair.active_shots().size() < 2:
			break
		frames += 1
		if frames > 80:
			_fail("La paire ne disparaît pas")
			break
	_expect(frames == 53, "La paire du I + II dure 53 images, obtenu %d" % frames)
	var single := _i_ii()
	single.step(Pilot.FIRE)
	single.step(0)
	single.step(Pilot.FIRE)
	_expect(Vector2i(Pilot.START_X - 1, Pilot.I_II_SINGLE_START_Y) in single.active_shots(), "Le second appui ajoute le projectile central")
	var single_frames := 1
	while true:
		single.step(0)
		var has_single := false
		for shot in single.active_shots():
			if shot.x == Pilot.START_X - 1:
				has_single = true
		if not has_single:
			break
		single_frames += 1
		if single_frames > 80:
			_fail("Le projectile central ne disparaît pas")
			break
	_expect(single_frames == 50, "Le projectile central dure 50 images, obtenu %d" % single_frames)
	print("OK durées I + II : 53 images pour la paire, 50 pour le tir central")


func _check_tap_does_not_repeat() -> void:
	var pilot := _i_ii()
	for index in range(5):
		pilot.step(Pilot.FIRE)
	_expect(pilot.active_shots().size() == 2, "Un tap de 5 images ne lance qu'une paire, obtenu %d" % pilot.active_shots().size())
	print("OK tap de 5 images : une seule volée")


func _check_hold_does_not_queue() -> void:
	# pr6 : maintien de 11170 à 11289, disparition à 11224, aucune volée
	# différée jusqu'au relâchement.
	var pilot := _i_ii()
	pilot.step(Pilot.FIRE)
	for index in range(80):
		pilot.step(Pilot.FIRE)
	_expect(pilot.active_shots().is_empty(), "Le maintien après disparition ne relance pas de volée")
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	# Le maintien a lancé le groupe 0 ; l'alternance est déjà passée au groupe 1
	# et n'avance pas pendant le maintien. pr6 n'a pas d'appui après ce maintien.
	_expect(pilot.active_shots() == [Vector2i(Pilot.START_X - 1, Pilot.I_II_SINGLE_START_Y)], "Nouvel appui après relâchement : groupe 1, obtenu %s" % str(pilot.active_shots()))
	print("OK maintien : pas de tir différé, nouvel appui nécessaire")


func _check_left_limit() -> void:
	# pr6 : palier 0x822b = 30 (x = 14) de 11353 à 11421, gauche enfoncée,
	# 0x8004 = 0.
	var pilot := _i_ii(18)
	for index in range(8):
		pilot.step(Pilot.LEFT)
	_expect(pilot.ship_x == Pilot.MIN_X, "La butée gauche du I + II est x = 14, obtenu %d" % pilot.ship_x)
	pilot.step(Pilot.LEFT)
	_expect(pilot.ship_x == Pilot.MIN_X, "La butée gauche tient tant que la gauche reste enfoncée")
	print("OK butée gauche I + II : x = 14")
