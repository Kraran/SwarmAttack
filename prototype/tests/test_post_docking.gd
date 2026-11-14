extends SceneTree

const ArcadeRun = preload("res://arcade_run.gd")
const Pilot = preload("res://pilot.gd")
const CombatRound = preload("res://combat_round.gd")
const Docking = preload("res://docking.gd")

var failures := 0


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _initialize() -> void:
	_check_success_resumes_as_two_and_three()
	_check_collision_resumes_as_three()
	_check_timeout_resumes_as_two()
	_check_life_lost_after_assembled_ship()
	_check_cycle_continues_without_partner()
	_check_module_one_docks_with_two()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("POST-DOCKING OK")
		quit(0)


func _start_docking(attached: int) -> ArcadeRun:
	var run := ArcadeRun.new()
	run.attached = attached
	run.wave_number = 4
	run.phase = ArcadeRun.Phase.DOCKING
	run.docking = Docking.new(run.front_module(), Pilot.START_X, false)
	run._docking_life_taken = false
	return run


func _hold_until_resume(run: ArcadeRun, hold: int) -> void:
	for index in range(hold):
		if run.phase != ArcadeRun.Phase.DOCKING:
			_fail("Reprise anticipée à l'image %d / %d" % [index, hold])
			return
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Le combat devrait reprendre après %d images, phase=%s" % [
		hold, ArcadeRun.Phase.keys()[run.phase]
	])


func _check_success_resumes_as_two_and_three() -> void:
	var run := _start_docking(2)
	run.docking.stage = Docking.Stage.SUCCESS
	run.docking.bonus = 2600
	_expect(run.score() == 0, "Le bonus ne doit pas être crédité avant la fin de l'écran")
	for index in range(Docking.BONUS_HOLD - 1):
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.DOCKING, "Le bonus de 305 images n'est pas encore écoulé")
	_expect(run.score() == 0, "Le bonus est crédité seulement à la 305e image")
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "La réussite doit enchaîner sur le combat")
	_expect(run.attached == 6, "Le vaisseau repris doit être II + III, masque=%d" % run.attached)
	_expect(run.ship_label() == "II + III", "Libellé inattendu : %s" % run.ship_label())
	_expect(run.front_module() == 2, "Le module supérieur reste le II")
	_expect(run.combat.pilot.has_module(2) and run.combat.pilot.has_module(3), "Le pilote doit porter les modules II et III")
	_expect(run.score() == 2600, "Score attendu 2600 après le bonus, obtenu %d" % run.score())
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large (vague %d)" % ArcadeRun.WAVE_AFTER_DOCK)
	_expect(run.combat.wave.wide_entry, "La vague de reprise doit être une entrée large")
	_expect(run.combat.pilot.ship_x == Docking.TARGET.x, "Reprise alignée sur la cible")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "L'amarrage réussi ne consomme pas de vie")
	var frame := run.frame
	run.step(Pilot.FIRE)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Le combat doit continuer après la reprise")
	_expect(run.frame == frame + 1, "L'horloge avance pendant le combat repris")
	var shots := run.combat.pilot.active_shots()
	_expect(shots.size() == 2, "Le premier appui du II + III tire le groupe à écart 12, obtenu %d" % shots.size())
	_expect(shots[0] == Vector2i(99, 212) and shots[1] == Vector2i(123, 212), "Positions du premier groupe inattendues : %s" % str(shots))
	print("OK réussite : bonus 2600, reprise II + III, vague 3, combat continué")


func _check_collision_resumes_as_three() -> void:
	var run := _start_docking(2)
	run.docking.stage = Docking.Stage.COLLISION
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "Les vies ne baissent qu'au pas de collision")
	run.step(0)
	_expect(run.lives == ArcadeRun.STARTING_LIVES - 1, "La collision baisse le compteur dès l'explosion, obtenu %d" % run.lives)
	_expect(run.phase == ArcadeRun.Phase.DOCKING, "L'écran de collision doit durer 466 images")
	for index in range(Docking.COLLISION_HOLD - 1):
		if run.phase != ArcadeRun.Phase.DOCKING:
			_fail("Reprise anticipée pendant la collision à l'image %d" % (index + 1))
			return
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Le combat reprend après 466 images")
	_expect(run.attached == 4, "Après collision, le module III seul continue, masque=%d" % run.attached)
	_expect(run.front_module() == 3, "Le module repris est le III")
	_expect(run.score() == 0, "Pas de bonus en cas de collision")
	_expect(run.lives == ArcadeRun.STARTING_LIVES - 1, "Les vies restent baissées à la reprise")
	_expect(run.combat.pilot.ship_x == Docking.TARGET.x, "Reprise du module III à x = 112")
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large")
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Le combat continue avec le module III")
	print("OK collision : vies 3 → 2, reprise module III seul, sans bonus")


func _check_timeout_resumes_as_two() -> void:
	var run := _start_docking(2)
	run.docking.stage = Docking.Stage.TIMED_OUT
	_hold_until_resume(run, Docking.TIMEOUT_HOLD)
	if run.phase != ArcadeRun.Phase.COMBAT:
		return
	_expect(run.attached == 2, "Après expiration, le module II seul continue, masque=%d" % run.attached)
	_expect(run.front_module() == 2, "Le module repris est le II")
	_expect(run.score() == 0, "Pas de bonus si le chrono expire")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "L'expiration ne consomme pas de vie")
	_expect(run.combat.pilot.ship_x == Pilot.START_X, "Reprise recentrée à x = 112, obtenu %d" % run.combat.pilot.ship_x)
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large")
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Le combat continue avec le module II")
	print("OK chrono écoulé : reprise module II seul à x = 112, sans bonus")


func _check_life_lost_after_assembled_ship() -> void:
	var run := ArcadeRun.new()
	run.attached = 6
	run.lives = 2
	run.combat = CombatRound.new(1, 2, Pilot.START_X, 255, 6)
	run.combat.outcome = CombatRound.Outcome.MODULE_LOST
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.REPLACEMENT, "La perte du vaisseau ouvre le remplacement")
	_expect(run.lives == 2, "Le compteur 0x8097 ne baisse qu'après %d images" % ArcadeRun.COUNTER_DROP_FRAMES)
	_expect(run.attached == 6, "Le masque reste II + III tant que le compteur n'a pas baissé")
	for index in range(ArcadeRun.COUNTER_DROP_FRAMES - 1):
		run.step(0)
	_expect(run.lives == 2, "Vies encore inchangées à l'image %d" % (ArcadeRun.COUNTER_DROP_FRAMES - 1))
	run.step(0)
	_expect(run.lives == 1, "Vies 2 → 1 à la baisse du compteur, obtenu %d" % run.lives)
	_expect(run.attached == 2, "Le module II seul succède au vaisseau II + III, masque=%d" % run.attached)
	_expect(run.phase == ArcadeRun.Phase.REPLACEMENT, "L'entrée suit la baisse du compteur")
	_expect(run.entrance_ship_y() < 0, "Le module reste caché pendant les 25 premières images")
	for index in range(ArcadeRun.ENTRANCE_HIDDEN + ArcadeRun.ENTRANCE_RISE - 1):
		run.step(0)
	_expect(run.entrance_ship_y() == ArcadeRun.ENTRANCE_MID_Y, "Le module s'arrête à y = 120, obtenu %d" % run.entrance_ship_y())
	for index in range(ArcadeRun.ENTRANCE_PAUSE + ArcadeRun.ENTRANCE_DESCENT + 1):
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Le combat reprend après 378 images d'entrée")
	_expect(run.combat.pilot.attached == 2, "Le nouveau combat se joue avec le module II")
	_expect(run.combat.pilot.module == 2, "Le module supérieur est le II")
	_expect(run.combat.pilot.ship_x == Pilot.START_X, "Reprise d'entrée à x = 112")
	# Une dernière vie perdue termine la partie à la baisse du compteur.
	run.combat.outcome = CombatRound.Outcome.MODULE_LOST
	run.step(0)
	for index in range(ArcadeRun.COUNTER_DROP_FRAMES):
		if run.phase == ArcadeRun.Phase.GAME_OVER:
			break
		run.step(0)
	_expect(run.lives == 0, "Vies 1 → 0, obtenu %d" % run.lives)
	_expect(run.phase == ArcadeRun.Phase.GAME_OVER, "Plus aucune vie : partie terminée")
	_expect(not run.game_over_shows_message(), "Le message de fin n'apparaît qu'après 31 images")
	for index in range(ArcadeRun.GAME_OVER_CLEAR):
		run.step(0)
	_expect(run.game_over_shows_message(), "JEU 1 TERMINE s'affiche après 31 images")
	print("OK perte de vie : 2 → 1 puis module II, ensuite fin de partie")


func _check_cycle_continues_without_partner() -> void:
	var run := ArcadeRun.new()
	run.attached = 6
	run.wave_number = 4
	run.combat = CombatRound.new(4, 2, Pilot.START_X, 255, 6)
	run.combat.outcome = CombatRound.Outcome.CLEARED
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Sans partenaire, un nouveau cycle de combat commence")
	_expect(run.wave_number == 1, "Le cycle reprend à la vague 1, obtenu %d" % run.wave_number)
	_expect(run.attached == 6, "Le vaisseau II + III est conservé")
	print("OK cycle suivant : combat poursuivi sans nouvel amarrage")


func _check_module_one_docks_with_two() -> void:
	# Règle relevée : l'amarrage I + II n'a lieu que si le module I est encore
	# là après la vague 4. Les seuils, la reprise et le tir de l'assemblage
	# I + II restent à mesurer (replay solo-docking-i-ii.csv).
	var run := ArcadeRun.new()
	run.attached = 1
	run.wave_number = 4
	run.combat = CombatRound.new(4, 1, Pilot.START_X, 255, 1)
	run.combat.outcome = CombatRound.Outcome.CLEARED
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.DOCKING, "Après la vague 4, le module I doit amarrer le II")
	_expect(run.docking_target() == 2, "La cible est le module II, obtenu %d" % run.docking_target())
	_expect(run.docking.module == 1, "Le module en approche est le I, obtenu %d" % run.docking.module)
	_expect(run.front_module() == 1, "Le module supérieur reste le I tant que l'amarrage n'est pas conclu")
	print("OK vague 4 avec le module I : approche vers le module II")
