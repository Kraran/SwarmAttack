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
	_check_module_two_unchanged()
	_check_alternation_and_overlap()
	_check_refused_press_keeps_group()
	_check_lifetimes()
	_check_tap_does_not_repeat()
	_check_resume_starts_with_first_group()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("ASSEMBLED FIRE OK")
		quit(0)


func _assembled(start_x := Pilot.START_X) -> Pilot:
	return Pilot.new(2, start_x, 6)


func _expect_pair(shots: Array, spread: int, height: int, ship_x: int, label: String) -> void:
	var left := Vector2i(ship_x - 1 - spread, height)
	var right := Vector2i(ship_x - 1 + spread, height)
	_expect(shots.size() >= 2, "%s : deux projectiles attendus, obtenu %d" % [label, shots.size()])
	if shots.size() < 2:
		return
	_expect(left in shots and right in shots, "%s : attendu %s et %s, obtenu %s" % [label, left, right, shots])


func _check_module_two_unchanged() -> void:
	var pilot := Pilot.new(2, Pilot.START_X)
	pilot.step(Pilot.FIRE)
	_expect(pilot.shot_active and pilot.second_shot_active, "Le module II seul conserve son tir double")
	_expect(pilot.shot_position == Vector2i(103, 195), "Module II gauche inattendu : %s" % pilot.shot_position)
	_expect(pilot.second_shot_position == Vector2i(119, 195), "Module II droit inattendu : %s" % pilot.second_shot_position)
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	_expect(pilot.active_shots().size() == 2, "Le module II refuse un appui tant que la paire est en vol")
	print("OK module II seul inchangé")


func _check_alternation_and_overlap() -> void:
	var pilot := _assembled()
	pilot.step(Pilot.FIRE)
	var first := pilot.active_shots()
	_expect(first.size() == 2, "Premier appui : une paire, obtenu %d" % first.size())
	_expect_pair(first, 12, 212, Pilot.START_X, "Groupe 0 (registre 0x27)")
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	var both := pilot.active_shots()
	_expect(both.size() == 4, "Les deux groupes peuvent voler ensemble, obtenu %d" % both.size())
	_expect_pair(both, 12, 204, Pilot.START_X, "Groupe 0 encore en vol")
	_expect_pair(both, 8, 195, Pilot.START_X, "Groupe 1 (registre 0x38)")
	print("OK alternance : écart 12 à y = 212, puis écart 8 à y = 195, les deux en vol")


func _group_count(shots: Array, spread: int) -> int:
	var found := 0
	for point in shots:
		if point.x == Pilot.START_X - 1 - spread or point.x == Pilot.START_X - 1 + spread:
			found += 1
	return found


func _check_refused_press_keeps_group() -> void:
	var pilot := _assembled()
	pilot.step(Pilot.FIRE)
	# Le groupe 0 dure 54 images, le groupe 1 dure 49 : on décale le second
	# appui pour que le premier groupe disparaisse pendant que le second vole encore.
	for index in range(8):
		pilot.step(0)
	pilot.step(Pilot.FIRE)
	_expect(pilot.active_shots().size() == 4, "Les deux groupes doivent être en vol avant le refus")
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	var refused := pilot.active_shots()
	_expect(refused.size() == 4, "Appui refusé tant que le groupe suivant est occupé, obtenu %d" % refused.size())
	_expect(_group_count(refused, 12) == 2, "Le groupe 0 reste le suivant après un refus")
	for point in refused:
		_expect(point.y != 212, "Un appui refusé ne doit pas relancer le groupe 0")
	while _group_count(pilot.active_shots(), 12) > 0:
		pilot.step(0)
	_expect(_group_count(pilot.active_shots(), 8) == 2, "Après expiration du groupe 0, le groupe 1 reste en vol")
	pilot.step(Pilot.FIRE)
	var after := pilot.active_shots()
	_expect(after.size() == 4, "L'appui suivant relance le groupe 0, obtenu %d" % after.size())
	_expect_pair(after, 12, 212, Pilot.START_X, "Reprise du groupe 0")
	print("OK refus : l'alternance n'avance pas sur un appui refusé")


func _check_lifetimes() -> void:
	var pilot := _assembled()
	pilot.step(Pilot.FIRE)
	for index in range(53):
		pilot.step(0)
	var last := pilot.active_shots()
	_expect(last.size() == 2 and last[0].y == 0 and last[1].y == 0, "Le groupe 0 est encore visible à y = 0 après 54 images")
	pilot.step(0)
	_expect(pilot.active_shots().is_empty(), "Le groupe 0 disparaît à la 55e image")

	pilot = _assembled()
	pilot.step(Pilot.FIRE)
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	for index in range(48):
		pilot.step(0)
	var group_b: Array[Vector2i] = []
	for point in pilot.active_shots():
		if point.x == 103 or point.x == 119:
			group_b.append(point)
	_expect(group_b.size() == 2 and group_b[0].y == 3, "Le groupe 1 est encore visible à y = 3 après 49 images, obtenu %s" % str(group_b))
	pilot.step(0)
	group_b.clear()
	for point in pilot.active_shots():
		if point.x == 103 or point.x == 119:
			group_b.append(point)
	_expect(group_b.is_empty(), "Le groupe 1 disparaît à la 50e image")
	print("OK durées : 54 images pour le groupe 0, 49 pour le groupe 1")


func _check_tap_does_not_repeat() -> void:
	var pilot := _assembled()
	for index in range(5):
		pilot.step(Pilot.FIRE)
	_expect(pilot.active_shots().size() == 2, "Un appui maintenu 5 images ne déclenche qu'une volée")
	print("OK maintien de 5 images : une seule volée")


func _check_resume_starts_with_first_group() -> void:
	# Après un amarrage, ArcadeRun crée un nouveau Pilot : le prochain groupe est le 0.
	var pilot := _assembled()
	_expect(pilot.is_assembled() and pilot._next_group == 0, "À la reprise, le premier appui doit former le groupe 0")
	pilot.step(Pilot.FIRE)
	_expect_pair(pilot.active_shots(), 12, 212, Pilot.START_X, "Premier tir après reprise")
	# Même chose à la butée gauche, comme aux frames 7891 et 7866.
	pilot = _assembled(Pilot.MIN_X)
	pilot.step(Pilot.FIRE)
	_expect_pair(pilot.active_shots(), 12, 212, Pilot.MIN_X, "Groupe 0 à x = 14")
	pilot.step(0)
	pilot.step(Pilot.FIRE)
	_expect_pair(pilot.active_shots(), 8, 195, Pilot.MIN_X, "Groupe 1 à x = 14")
	print("OK reprise : le premier groupe part à y = 212, aussi à x = 14")
