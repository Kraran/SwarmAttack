extends SceneTree

const ArcadeRun = preload("res://arcade_run.gd")
const Pilot = preload("res://pilot.gd")
const CombatRound = preload("res://combat_round.gd")
const CombatWave = preload("res://combat_wave.gd")
const Docking = preload("res://docking.gd")

var failures := 0


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _initialize() -> void:
	_check_points_by_stage()
	_check_points_after_second_docking()
	_check_cycle_end_timeline()
	_check_second_cycle_waves()
	_check_life_loss_keeps_cycle()
	_check_lost_module_of_assembled_ship()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("CYCLE OK")
		quit(0)


func _cleared_after_second_dock(score := 0) -> ArcadeRun:
	# pr11c : vague 0x0d terminée en I + II + III, dernier crédit à 17603.
	var run := ArcadeRun.new()
	run.attached = 7
	run.stage = 2
	run.wave_number = ArcadeRun.WAVES_BEFORE_DOCK
	run._previous_score = score
	run.combat = CombatRound.new(4, 1, 146, 255, 7, run.points_per_hit())
	run.combat.outcome = CombatRound.Outcome.CLEARED
	return run


func _check_points_by_stage() -> void:
	var run := ArcadeRun.new()
	_expect(run.points_per_hit(1, 0) == 50 and run.points_per_hit(2, 0) == 50, "Vagues 1-2 : 50 points (0x12, 0x13 sur pr11c)")
	_expect(run.points_per_hit(3, 0) == 30 and run.points_per_hit(4, 0) == 30, "Vagues 3-4 : 30 points (0x05 sur pr1, 0x14 et 0x15 sur pr11c)")
	_expect(run.points_per_hit(3, 1) == 60 and run.points_per_hit(4, 1) == 60, "Après le premier amarrage : 60 points (pr7, 0x07 et 0x08)")
	_expect(run.points_per_hit(3, 2) == 100 and run.points_per_hit(4, 2) == 100, "Après le second amarrage : 100 points (0x0c et 0x0d)")
	_expect(run.combat.wave.points_per_hit == 50, "Départ : vague 1 à 50 points")
	var wave := CombatWave.new(3)
	_expect(wave.points_per_hit == 30, "Sans valeur imposée, une entrée large vaut 30")
	print("OK valeur des ennemis par étape : 50, 30, 60, 100")


func _check_points_after_second_docking() -> void:
	# pr8c : réussite I + II → III (deuxième amarrage), reprise à 16662 en 0x0c.
	var run := ArcadeRun.new()
	run.attached = 3
	run.stage = 1
	run.wave_number = 4
	run.phase = ArcadeRun.Phase.DOCKING
	run.docking = Docking.new(1, Pilot.START_X, false, 3)
	run.docking.stage = Docking.Stage.SUCCESS
	run.docking.bonus = 1500
	for index in range(Docking.BONUS_HOLD):
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT and run.attached == 7, "Reprise en I + II + III")
	_expect(run.stage == 2, "Étape 2 après le second amarrage, obtenu %d" % run.stage)
	_expect(run.combat.wave.points_per_hit == 100, "pr9 : +100 par ennemi en 0x0c, obtenu %d" % run.combat.wave.points_per_hit)
	# Expiration au premier amarrage (II → III) : l'étape avance aussi.
	run = ArcadeRun.new()
	run.attached = 2
	run.wave_number = 4
	run.phase = ArcadeRun.Phase.DOCKING
	run.docking = Docking.new(2, Pilot.START_X, false, 2)
	run.docking.stage = Docking.Stage.TIMED_OUT
	for index in range(Docking.TIMEOUT_HOLD):
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT and run.stage == 1, "Après une expiration, l'étape 1 commence")
	_expect(run.combat.wave.points_per_hit == 60, "Étape 1 : 60 points, obtenu %d" % run.combat.wave.points_per_hit)
	print("OK reprise après amarrage : étape suivante, 100 points après le second")


func _check_cycle_end_timeline() -> void:
	var run := _cleared_after_second_dock(8040)
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.CYCLE_END, "pr11c : fin de cycle après la vague 0x0d, phase=%s" % ArcadeRun.Phase.keys()[run.phase])
	_expect(run.cycle_end_elapsed == 0, "Image du dernier crédit = image 0")
	var lives := run.lives
	var checks := {
		32: [0, true, false, 7], # 17635 : écran 0x00, vaisseau encore à 0x822c = 216
		33: [1, true, false, 7], # 17637 : 215
		46: [14, true, false, 7], # PNG 17640 : pas de texte
		47: [15, true, true, 7], # PNG 17650 : « PLUS LOIN »
		190: [158, true, true, 7], # PNG 17790 : texte, 0x822c = 58
		191: [159, false, false, 1], # 17799 : 0x822c = 57, modules en réserve
		310: [0, false, false, 1], # 17920 : écran vide
	}
	for elapsed in range(1, ArcadeRun.CYCLE_ENTRANCE_START):
		if elapsed > 1:
			run.step(Pilot.FIRE | Pilot.LEFT)
		if run.phase != ArcadeRun.Phase.CYCLE_END:
			_fail("Fin de cycle interrompue à %d" % elapsed)
			return
		_expect(run.cycle_end_elapsed == elapsed - 1 or elapsed == 1, "Compteur de fin de cycle")
		if checks.has(run.cycle_end_elapsed):
			var expected: Array = checks[run.cycle_end_elapsed]
			var at := run.cycle_end_elapsed
			if expected[1]:
				_expect(run.cycle_end_rise() == expected[0], "Image %d : montée %d, obtenu %d" % [at, expected[0], run.cycle_end_rise()])
			_expect(run.cycle_end_shows_ship() == expected[1], "Image %d : vaisseau visible = %s" % [at, expected[1]])
			_expect(run.cycle_end_shows_message() == expected[2], "Image %d : PLUS LOIN = %s" % [at, expected[2]])
			_expect(run.attached == expected[3], "Image %d : modules %d, obtenu %d" % [at, expected[3], run.attached])
		_expect(run.score() == 8040, "Score inchangé pendant la fin de cycle (8040), obtenu %d" % run.score())
		_expect(run.lives == lives, "Vies inchangées")
		_expect(run.combat.pilot.ship_x == 146, "Le vaisseau ne se déplace pas")
	run.step(0)
	_expect(run.cycle_end_elapsed == 310 or run.phase == ArcadeRun.Phase.REPLACEMENT, "Suite")
	while run.phase == ArcadeRun.Phase.CYCLE_END:
		run.step(0)
	var entrance_start := run.frame
	_expect(run.phase == ArcadeRun.Phase.REPLACEMENT and run.is_cycle_entrance(), "Entrée du module I du cycle 2")
	_expect(run.cycle == 2 and run.stage == 0 and run.wave_number == 1, "Cycle 2, étape 0, vague 1")
	_expect(run.lives == lives, "Pas de vie perdue ni gagnée")
	while run.phase == ArcadeRun.Phase.REPLACEMENT:
		run.step(0)
	# pr11c : combat 0x12 à 18304, soit 689 images de boucle après 17603.
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Combat du cycle 2")
	_expect(run.frame - entrance_start + ArcadeRun.CYCLE_ENTRANCE_START == 689, "Combat à +689, obtenu %d" % [run.frame - entrance_start + ArcadeRun.CYCLE_ENTRANCE_START])
	_expect(run.attached == 1 and run.front_module() == 1, "Module I seul, II et III en réserve")
	_expect(run.combat.pilot.ship_x == Pilot.START_X, "Module I à x = 112 (0x822b = 128)")
	_expect(run.combat.wave.remaining == 8 and not run.combat.wave.wide_entry, "Vague 1 : 8 ennemis, entrée étroite")
	_expect(run.combat.wave.points_per_hit == 50, "0x12 : 50 points")
	_expect(run.score() == 8040, "Score conservé")
	print("OK fin de cycle pr11c : montée 159 images, PLUS LOIN, modules remis, combat du cycle 2 à +689")


func _check_second_cycle_waves() -> void:
	# pr11c : 0x12 et 0x13 à 50 points, 0x14 et 0x15 à 30, puis amarrage si un partenaire reste.
	var run := ArcadeRun.new()
	run.cycle = 2
	for wave in range(1, 5):
		run.wave_number = wave
		run.combat = CombatRound.new(wave, 1, Pilot.START_X, 255, 1, run.points_per_hit())
		_expect(run.combat.wave.points_per_hit == (50 if wave < 3 else 30), "Cycle 2, vague %d" % wave)
		run.combat.outcome = CombatRound.Outcome.CLEARED
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.DOCKING and run.docking_target() == 2, "Après la vague 4 du cycle 2, le module I amarre le II (comme au cycle 1, non relevé)")
	print("OK cycle 2 : vagues 1-4 à 50, 50, 30, 30")
	_check_second_cycle_speed()


func _check_second_cycle_speed() -> void:
	# pr12a : 0x14 entre en courbes larges comme 0x04 (pas en rangée), et les
	# huit objets ont les mêmes positions RAM que 0x04 pendant les 90 premiers
	# pas de boucle (3749 et 20185, aucun impact). Le cycle 2 n'accélère pas le
	# mouvement : seul 0x823d passe de 1 à 2. Le rythme de boucle est le même
	# (1,01 image par pas en 0x04 comme en 0x14).
	var waves := []
	for cycle in [1, 2]:
		var run := ArcadeRun.new()
		run.cycle = cycle
		run.wave_number = 3
		run._begin_combat(Pilot.START_X, 255)
		_expect(run.combat.wave.wide_entry and not run.combat.wave.rows, "Cycle %d, vague 3 : entrée large" % cycle)
		_expect(run.combat.wave.max_divers == cycle, "Cycle %d : 0x823d = %d" % [cycle, cycle])
		waves.append(run.combat.wave)
	var frame := 1000
	for step in range(31 + 90):
		frame += 1
		for wave in waves:
			wave.advance(frame, Pilot.START_X)
		for k in range(waves[0].enemies.size()):
			if waves[0].enemies[k].position != waves[1].enemies[k].position:
				_fail("Cycle 2, vague 3 : objet %d diffère du cycle 1 au pas %d" % [k, step - 30])
				return
	print("OK cycle 2 : vague 3 en entrée large, même mouvement qu'au cycle 1 (90 pas)")


func _check_life_loss_keeps_cycle() -> void:
	# pr11c : le module I perdu en 0x12 (18771), vies 3 → 2 à 19060, le module II
	# reprend la même vague avec les 3 survivants à 19438.
	var run := ArcadeRun.new()
	run.cycle = 2
	run.combat = CombatRound.new(1, 1, Pilot.START_X, 0b00101010, 1, 50)
	run.combat.outcome = CombatRound.Outcome.MODULE_LOST
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.REPLACEMENT and not run.is_cycle_entrance(), "Perte de vie ordinaire")
	while run.phase == ArcadeRun.Phase.REPLACEMENT:
		run.step(0)
	_expect(run.lives == 2 and run.attached == 2, "Vies 2, module II")
	_expect(run.cycle == 2 and run.wave_number == 1, "Même cycle, même vague")
	_expect(run.combat.wave.remaining == 3, "3 survivants, obtenu %d" % run.combat.wave.remaining)
	# pr11c : le module II seul détruit en 0x14 (20461), vies 2 → 1, le III entre.
	run.wave_number = 3
	run.combat = CombatRound.new(3, 2, Pilot.START_X, 0b11100000, 2, 30)
	run.combat.outcome = CombatRound.Outcome.MODULE_LOST
	run.step(0)
	while run.phase == ArcadeRun.Phase.REPLACEMENT:
		run.step(0)
	_expect(run.lives == 1 and run.attached == 4, "pr11c : le module III succède au II, masque %d" % run.attached)
	print("OK pertes de vie au cycle 2 : survivants conservés, II puis III")


func _enemy_at(position: Vector2i) -> CombatWave:
	var wave := CombatWave.new(3)
	var enemy := CombatWave.Enemy.new()
	enemy.alive = true
	enemy.position = position
	wave.enemies.clear()
	wave.enemies.append(enemy)
	return wave


func _check_lost_module_of_assembled_ship() -> void:
	# Contacts relevés sur le I + II + III (x vaisseau, position de l'ennemi, module perdu).
	var contacts := [
		["pr8c 16754", 14, Vector2i(28, 196), 1],
		["pr9 16926", 110, Vector2i(116, 193), 1],
		["pr10b 16903", 112, Vector2i(116, 193), 1],
		["pr9b 17008", 200, Vector2i(192, 212), 3],
		["pr10a 16553", 122, Vector2i(116, 209), 3],
		["pr11a 16974", 150, Vector2i(142, 218), 3],
		["pr11b 17010", 166, Vector2i(192, 212), 3],
	]
	for contact in contacts:
		var wave := _enemy_at(contact[2])
		var module := wave.hit_module(contact[1], 7)
		_expect(module == contact[3], "%s : module %d attendu, obtenu %d" % [contact[0], contact[3], module])
	# Perte du III : le I entre seul (pr11a : vies 3 → 2 à 17283, reprise 17672 à y = 200).
	var run := ArcadeRun.new()
	run.attached = 7
	run.stage = 2
	run.wave_number = 3
	run.combat = CombatRound.new(3, 1, 150, 255, 7, 100)
	var enemy := CombatWave.Enemy.new()
	enemy.alive = true
	enemy.position = Vector2i(142, 218)
	run.combat.wave.enemies.clear()
	run.combat.wave.enemies.append(enemy)
	run.combat.wave._wave_clock = 100
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.REPLACEMENT and run.combat.lost_module == 3, "Contact bas : module III perdu, obtenu %d" % run.combat.lost_module)
	while run.phase == ArcadeRun.Phase.REPLACEMENT:
		run.step(0)
	_expect(run.lives == 2 and run.attached == 1, "pr11a : le module I seul reprend, masque %d" % run.attached)
	_expect(run.combat.wave.points_per_hit == 100, "Même étape (0x0c) : 100 points")
	print("OK perte d'un module du I + II + III : I touché → II seul, III touché → I seul")
