extends SceneTree

# Rejoue les segments de wave_checkpoints.gd (relevés RAM) dans CombatWave et
# compare la position des huit objets toutes les 8 images de boucle.
const CombatWave = preload("res://combat_wave.gd")
const Checkpoints = preload("res://tests/wave_checkpoints.gd")

var _failures := 0


func _initialize() -> void:
	for segment in Checkpoints.SEGMENTS:
		_replay(segment)
	_check_falling_points()
	_check_stage_one_sequence()
	_check_rows_and_pattern_reset()
	_check_score_delays()
	if _failures == 0:
		print("WAVES OK")
	quit(1 if _failures else 0)


func _replay(segment: Dictionary) -> void:
	var wave := CombatWave.new(int(segment["wave"]), int(segment["mask"]), -1, int(segment["stage"]))
	wave.load_patterns(segment["patterns"])
	wave.max_divers = int(segment["max_divers"])
	var ship: Array[int] = []
	for run in segment["ship"]:
		for i in range(int(run[0])):
			ship.append(int(run[1]))
	var kills := {}
	for entry in segment["kills"]:
		kills.get_or_add(int(entry[0]), []).append(int(entry[1]))
	var credits: Array = segment["credits"]
	var checkpoints := {}
	for entry in segment["checkpoints"]:
		checkpoints[int(entry[0])] = entry[1]
	# Horloge de vague : 31 pas avant l'apparition (hors images figées de l'ouverture).
	var frame := 1000
	for i in range(31):
		frame += 1
		wave.advance(frame, ship[0])
	for step in range(1, ship.size() + 1):
		for index in kills.get(step, []):
			wave.kill(index)
		frame += 1
		wave.advance(frame, ship[step - 1])
		for c in credits:
			if int(c) == step:
				wave.credit_kill()
		if checkpoints.has(step):
			var expected: Array = checkpoints[step]
			for k in range(8):
				if int(expected[2 * k]) < 0:
					continue
				var want := Vector2i(int(expected[2 * k]), int(expected[2 * k + 1]))
				var got := wave.enemies[k].position if wave.enemies.size() > k else Vector2i(-1, -1)
				if got != want:
					_fail("%s : pas %d, objet %d en %s au lieu de %s" % [segment["label"], step, k, got, want])
					return
	print("OK %s : %d pas, %d points de contrôle" % [segment["label"], ship.size(), checkpoints.size()])


func _check_falling_points() -> void:
	const ArcadeRun = preload("res://arcade_run.gd")
	var run := ArcadeRun.new()
	run.stage = 1
	if run.points_per_hit(5) != 200 or run.points_per_hit(6) != 200 or run.points_per_hit(3) != 60:
		_fail("points 0x07-0x0a : %d, %d, %d" % [run.points_per_hit(3), run.points_per_hit(5), run.points_per_hit(6)])
		return
	if run.last_wave() != 6:
		_fail("étape 1 : dernière vague %d au lieu de 6" % run.last_wave())
		return
	print("OK étape 1 : vagues 3, 4 à 60 points, 5 et 6 (objets en chute) à 200")


func _check_stage_one_sequence() -> void:
	# pr7 : après le premier amarrage, 0x07, 0x08, 0x09, 0x0a puis le second
	# amarrage (0x0b) ; le vaisseau I + II approche le III.
	const ArcadeRun = preload("res://arcade_run.gd")
	const CombatRound = preload("res://combat_round.gd")
	var run := ArcadeRun.new()
	run.stage = 1
	run.attached = 3
	run.wave_number = 3
	run._begin_combat(112, 255)
	var seen: Array[int] = []
	for i in range(4):
		seen.append(run.wave_number)
		if run.combat.wave.falling != (run.wave_number >= 5):
			_fail("étape 1 : vague %d, objets en chute %s" % [run.wave_number, run.combat.wave.falling])
			return
		run.combat.outcome = CombatRound.Outcome.CLEARED
		run.step(0)
	if seen != [3, 4, 5, 6] or run.phase != ArcadeRun.Phase.DOCKING or run.docking_target() != 3:
		_fail("étape 1 : vagues %s, phase %d" % [seen, run.phase])
		return
	print("OK étape 1 : 0x07, 0x08, 0x09, 0x0a, puis second amarrage")


func _check_rows_and_pattern_reset() -> void:
	# Après le second amarrage, 0x0c et 0x0d entrent en rangée (pr7, pr11*).
	const ArcadeRun = preload("res://arcade_run.gd")
	const CombatRound = preload("res://combat_round.gd")
	var run := ArcadeRun.new()
	run.stage = 2
	run.attached = 3
	run.wave_number = 3
	run._patterns = [6, 2, 12, 2, 0, 0]
	run._begin_combat(112, 255)
	if not run.combat.wave.rows or run.combat.wave.wide_entry or run.points_per_hit() != 100:
		_fail("étape 2 : la vague 3 doit entrer en rangée à 100 points")
		return
	# Perte d'un module : les motifs 0x8242-0x8247 repartent de zéro à
	# l'entrée suivante (0x809b = 0x01), la même vague reprend en rangée.
	run.combat.outcome = CombatRound.Outcome.MODULE_LOST
	var guard := 0
	while guard < 2000:
		guard += 1
		run.step(0)
		if run.phase == ArcadeRun.Phase.COMBAT:
			break
	if run.phase != ArcadeRun.Phase.COMBAT or not run.combat.wave.rows or run.combat.wave.patterns() != [0, 0, 0, 0, 0, 0]:
		_fail("perte de module : phase %d, motifs %s" % [run.phase, run.combat.wave.patterns()])
		return
	print("OK étape 2 : rangées à 100 points, motifs remis à zéro après une perte")


func _check_score_delays() -> void:
	# Le crédit garde un bref délai d'effet, sans variation de charge matérielle.
	const CombatRound = preload("res://combat_round.gd")
	for configuration in [[1,0],[3,0],[3,1],[5,1],[3,2]]:
		var round := CombatRound.new(configuration[0],1,112,255,0,-1,configuration[1])
		for remaining in range(1,9):
			round.wave.credited_remaining = remaining
			if round.score_delay() != CombatRound.SCORE_DELAY:
				_fail("Le crédit dépend encore du type de vague ou du nombre d'ennemis")
				return
	print("OK délai de crédit constant : 10 pas, toutes familles et tous effectifs")


func _fail(message: String) -> void:
	_failures += 1
	printerr("ÉCHEC " + message)
