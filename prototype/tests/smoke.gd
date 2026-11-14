extends SceneTree

const ArcadeRun = preload("res://arcade_run.gd")
const Pilot = preload("res://pilot.gd")
const CombatRound = preload("res://combat_round.gd")
const Docking = preload("res://docking.gd")

var failures := 0


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)


func _initialize() -> void:
	_check_ship_contact()
	_check_spawn()
	_check_docking_start()
	_check_module_two_fire()
	_check_idle_run()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("SMOKE OK")
		quit(0)


func _check_ship_contact() -> void:
	for offset in [-10, -9, 11, 12]:
		var round := CombatRound.new()
		for index in range(32):
			round.step(0)
		round.wave.enemies[0].position = Vector2i(120 + offset, 192)
		round.step(0)
		var expected: bool = offset in [-9, 11]
		if (round.outcome == CombatRound.Outcome.MODULE_LOST) != expected:
			_fail("Collision vaisseau incorrecte pour un décalage de %d" % offset)
		else:
			print("OK collision offset %d -> %s" % [offset, "perdu" if expected else "intact"])


func _check_spawn() -> void:
	var combat := CombatRound.new()
	for index in range(31):
		combat.step(0)
	if not combat.wave.enemies.is_empty():
		_fail("Apparition anticipée avant le spawn")
	combat.step(0)
	if combat.wave.enemies.size() != 8:
		_fail("8 ennemis attendus au spawn, obtenu %d" % combat.wave.enemies.size())
	else:
		print("OK spawn vague 1: 8 cibles, remaining=%d, points=%d" % [
			combat.wave.remaining, combat.wave.points_per_hit
		])


func _check_docking_start() -> void:
	var dock := Docking.new(2, Pilot.START_X, false)
	if dock.stage != Docking.Stage.APPROACH:
		_fail("L'essai d'amarrage devrait commencer en APPROACH, stage=%s" % Docking.Stage.keys()[dock.stage])
	else:
		print("OK Docking module 2 départ position %s chrono %s" % [dock.position, dock.display_clock()])
	for index in range(40):
		dock.step(0)
	print("Après 40 pas repos: stage=%s pos=%s chrono=%s" % [
		Docking.Stage.keys()[dock.stage], dock.position, dock.display_clock()
	])


func _check_module_two_fire() -> void:
	var pilot := Pilot.new(2, Pilot.START_X)
	pilot.step(Pilot.FIRE)
	if not (pilot.shot_active and pilot.second_shot_active):
		_fail("Le module II devrait tirer deux projectiles")
	else:
		print("OK module II tir double: %s et %s" % [pilot.shot_position, pilot.second_shot_position])


func _check_idle_run() -> void:
	var run := ArcadeRun.new()
	if run.phase != ArcadeRun.Phase.COMBAT or run.front_module() != 1 or run.wave_number != 1 or run.lives != 3:
		_fail("État initial ArcadeRun inattendu")
	else:
		print("OK ArcadeRun départ: vague %d module %d vies %d score %d" % [
			run.wave_number, run.front_module(), run.lives, run.score()
		])
	run.practice_docking()
	if run.phase != ArcadeRun.Phase.DOCKING or run.docking == null:
		_fail("practice_docking n'a pas basculé en DOCKING")
	else:
		print("OK practice_docking: module %d stage %s" % [
			run.docking.module, Docking.Stage.keys()[run.docking.stage]
		])
	var long_run := ArcadeRun.new()
	for index in range(2000):
		long_run.step(0)
	print("OK 2000 pas idle: phase=%s vague=%d frame=%d cibles=%d score=%d" % [
		ArcadeRun.Phase.keys()[long_run.phase], long_run.wave_number, long_run.frame,
		long_run.combat.wave.remaining, long_run.score()
	])
