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
	_check_timeout_resumes_as_one()
	_check_idle_i_from_the_right_times_out()
	_check_life_lost_after_assembled_ship()
	_check_life_lost_after_i_and_ii()
	_check_cycle_continues_without_partner()
	_check_module_one_docks_with_two()
	_check_module_one_capture_from_pr5c()
	_check_success_resumes_as_one_and_two()
	_check_i_ii_to_iii_intro()
	_check_timeout_resumes_as_i_and_ii()
	_check_idle_i_ii_from_the_right_times_out()
	_check_i_ii_to_iii_collision_from_pr8()
	_check_collision_resumes_as_three_from_i_ii()
	_check_i_ii_to_iii_capture_from_pr8c()
	_check_success_resumes_as_one_two_and_three()
	_check_life_lost_after_i_ii_and_iii()
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
	run.docking = Docking.new(run.front_module(), Pilot.START_X, false, attached)
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


func _check_timeout_resumes_as_one() -> void:
	# pr5b-amarrage-i-ii : expiration I + II à 11343, reprise à 11526.
	var run := _start_docking(1)
	run.docking.stage = Docking.Stage.TIMED_OUT
	_hold_until_resume(run, Docking.TIMEOUT_HOLD)
	if run.phase != ArcadeRun.Phase.COMBAT:
		return
	_expect(run.attached == 1, "Après expiration, le module I seul continue, masque=%d" % run.attached)
	_expect(run.front_module() == 1, "Le module repris est le I")
	_expect(run.score() == 0, "Pas de bonus si le chrono expire")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "L'expiration ne consomme pas de vie")
	_expect(run.combat.pilot.ship_x == Pilot.START_X, "Reprise recentrée à x = 112, obtenu %d" % run.combat.pilot.ship_x)
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large")
	_expect(run.combat.wave.wide_entry, "La vague de reprise doit être une entrée large")
	_expect(run.combat.pilot.active_shots().is_empty(), "pr5b : aucun projectile figé à la reprise")
	print("OK chrono écoulé I + II : reprise module I seul à x = 112, sans bonus")


func _check_idle_i_from_the_right_times_out() -> void:
	# pr5b : après l'intro, le module I part de x = 180 (0x822b = 196, y = 124)
	# sans commande, touche la butée basse (0x822c = 240) et expire. Écran de
	# 183 images, puis reprise du I seul à x = 112, vies inchangées.
	var run := ArcadeRun.new()
	run.attached = 1
	run.wave_number = 4
	run.phase = ArcadeRun.Phase.DOCKING
	run.docking = Docking.new(1, 180, false)
	run._docking_life_taken = false
	_expect(run.docking.position == Vector2i(188, 116), "Départ après la montée : %s" % str(run.docking.position))
	var hit_floor := false
	var steps := 0
	while run.docking.stage == Docking.Stage.APPROACH and steps < 5000:
		run.step(0)
		steps += 1
		if run.docking.position.y >= 232:
			hit_floor = true
	_expect(run.docking.stage == Docking.Stage.TIMED_OUT, "L'approche sans commande doit expirer, stage=%s" % Docking.Stage.keys()[run.docking.stage])
	_expect(hit_floor, "pr5b : le module I atteint la butée basse avant l'expiration")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "Les vies restent à 3 pendant l'approche et l'écran")
	_hold_until_resume(run, Docking.TIMEOUT_HOLD)
	if run.phase != ArcadeRun.Phase.COMBAT:
		return
	_expect(run.attached == 1, "Reprise du module I seul, masque=%d" % run.attached)
	_expect(run.combat.pilot.ship_x == Pilot.START_X, "Reprise recentrée à x = 112")
	_expect(run.score() == 0, "Pas de bonus")
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Vague à entrée large")
	print("OK approche I à l'inertie depuis la droite : butée basse, expiration, reprise du I")


func _check_module_one_docks_with_two() -> void:
	# Règle relevée : l'amarrage I + II n'a lieu que si le module I est encore
	# là après la vague 4. L'expiration est calée sur pr5b, la réussite sur pr5c.
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

func _approach_tick(dock: Docking, offset: Vector2i, velocity: Vector2i, wait: Vector2i, input_mask: int) -> void:
	dock.stage = Docking.Stage.APPROACH
	dock.position = Docking.TARGET + offset
	dock._horizontal.velocity = velocity.x
	dock._horizontal.wait = wait.x
	dock._vertical.velocity = velocity.y
	dock._vertical.wait = wait.y
	dock._advance_approach(input_mask)


func _check_module_one_capture_from_pr5c() -> void:
	# pr5c : au cran 10595, l'offset (13, -7) n'accroche pas. Au cran 10599,
	# l'affichage reste à (14, -7) mais le cran porte le module à (14, -6)
	# (vitesses 111/125, attentes 1/0, droite + tir) : contact. Le chrono
	# affiché est 17:0, le bonus 17 × 100 = 1700.
	var miss := Docking.new(1, Pilot.START_X, false)
	miss.remaining_tenths = 172
	miss.position = Docking.TARGET + Vector2i(13, -7)
	miss._resolve_contact()
	_expect(miss.stage == Docking.Stage.APPROACH, "pr5c frame 10595 : (13, -7) ne doit pas accrocher, stage=%s" % Docking.Stage.keys()[miss.stage])
	var shown := Docking.new(1, Pilot.START_X, false)
	shown.position = Docking.TARGET + Vector2i(14, -7)
	shown._resolve_contact()
	_expect(shown.stage == Docking.Stage.APPROACH, "La position affichée (14, -7) n'est pas celle du contact")
	var dock := Docking.new(1, Pilot.START_X, false)
	dock.remaining_tenths = 171
	_approach_tick(dock, Vector2i(14, -7), Vector2i(111, 125), Vector2i(1, 0), Pilot.RIGHT | Pilot.FIRE)
	_expect(dock.stage == Docking.Stage.SUCCESS, "pr5c frame 10599 : le cran vers (14, -6) doit accrocher, stage=%s" % Docking.Stage.keys()[dock.stage])
	_expect(dock.bonus == 1700, "Bonus 17 × 100 = 1700, obtenu %d" % dock.bonus)
	_expect(dock.position == Docking.TARGET + Vector2i(8, -8), "Accrochage à (120, 208), obtenu %s" % str(dock.position))
	# pr10e (démo), frame 2686 : affiché (6, -7), vitesses 171/64, attentes 0 :
	# le cran donne (5, -6), contact, chrono 10:7, bonus 10 × 100 = 1000.
	var demo := Docking.new(1, Pilot.START_X, false)
	demo.remaining_tenths = 107
	_approach_tick(demo, Vector2i(6, -7), Vector2i(171, 64), Vector2i(0, 0), Pilot.RIGHT)
	_expect(demo.stage == Docking.Stage.SUCCESS, "Démo frame 2686 : le cran vers (5, -6) doit accrocher, stage=%s" % Docking.Stage.keys()[demo.stage])
	_expect(demo.bonus == 1000, "Bonus de la démo 10 × 100 = 1000, obtenu %d" % demo.bonus)
	print("OK contact I + II : (13, -7) raté, cran vers (14, -6) réussi (bonus 1700), démo (5, -6) (bonus 1000)")


func _check_success_resumes_as_one_and_two() -> void:
	# pr5c-amarrage-i-ii-succes : contact 10599, écran BRAVO 305 images,
	# reprise 10904 en I + II à x = 112, vies 3, score +1700, pas de tir figé.
	# Le maintien du tir commencé pendant l'approche ne déclenche pas de volée.
	var run := _start_docking(1)
	run.docking.stage = Docking.Stage.SUCCESS
	run.docking.bonus = 1700
	_expect(run.score() == 0, "Le bonus ne doit pas être crédité avant la fin de l'écran")
	for index in range(Docking.BONUS_HOLD - 1):
		run.step(Pilot.RIGHT | Pilot.FIRE)
	_expect(run.phase == ArcadeRun.Phase.DOCKING, "Le bonus de 305 images n'est pas encore écoulé")
	_expect(run.score() == 0, "Le bonus est crédité seulement à la 305e image")
	run.step(Pilot.RIGHT | Pilot.FIRE)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "La réussite doit enchaîner sur le combat")
	_expect(run.attached == 3, "Le vaisseau repris doit être I + II, masque=%d" % run.attached)
	_expect(run.ship_label() == "I + II", "Libellé inattendu : %s" % run.ship_label())
	_expect(run.front_module() == 1, "Le module supérieur reste le I")
	_expect(run.combat.pilot.has_module(1) and run.combat.pilot.has_module(2), "Le pilote doit porter les modules I et II")
	_expect(run.score() == 1700, "Score attendu 1700 après le bonus, obtenu %d" % run.score())
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large (vague %d)" % ArcadeRun.WAVE_AFTER_DOCK)
	_expect(run.combat.wave.wide_entry, "La vague de reprise doit être une entrée large")
	_expect(run.combat.pilot.ship_x == Docking.TARGET.x, "Reprise alignée sur la cible")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "L'amarrage réussi ne consomme pas de vie")
	_expect(run.combat.pilot.active_shots().is_empty(), "pr5c : aucun projectile figé à la reprise")
	var start_x := run.combat.pilot.ship_x
	run.step(Pilot.RIGHT | Pilot.FIRE)
	_expect(run.combat.pilot.ship_x == start_x + Pilot.MOVE_STEP, "La droite déplace le I + II dès la reprise")
	_expect(run.combat.pilot.active_shots().is_empty(), "Un maintien du tir poursuivi à la reprise ne déclenche pas de volée")
	# Butée droite confirmée sur pr5c : 0x822b = 216 de 10948 à la destruction 12290.
	for index in range(80):
		run.step(Pilot.RIGHT)
	_expect(run.combat.pilot.ship_x == Pilot.MAX_X, "La butée droite du I + II est x = 200, obtenu %d" % run.combat.pilot.ship_x)
	run.step(Pilot.RIGHT)
	_expect(run.combat.pilot.ship_x == Pilot.MAX_X, "La butée droite tient tant que la droite reste enfoncée")
	print("OK réussite I + II : bonus 1700, 305 images, reprise à x = 112, vies 3, butée 200, pas de tir maintenu")


func _check_life_lost_after_i_and_ii() -> void:
	# pr5c : destruction du I + II à 12290, vies 3 → 2 à 12579, puis entrée du
	# module I (0x822c vers 200, visible à 12968). La capture s'arrête pendant
	# cette entrée, déjà identifiable comme le module I.
	var run := ArcadeRun.new()
	run.attached = 3
	run.lives = 3
	run.combat = CombatRound.new(3, 1, Pilot.MAX_X, 255, 3)
	run.combat.outcome = CombatRound.Outcome.MODULE_LOST
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.REPLACEMENT, "La perte du I + II ouvre le remplacement")
	for index in range(ArcadeRun.COUNTER_DROP_FRAMES - 1):
		run.step(0)
	_expect(run.lives == 3, "Vies encore inchangées à l'image %d" % (ArcadeRun.COUNTER_DROP_FRAMES - 1))
	_expect(run.attached == 3, "Le masque reste I + II tant que le compteur n'a pas baissé")
	run.step(0)
	_expect(run.lives == 2, "Vies 3 → 2 à la baisse du compteur, obtenu %d" % run.lives)
	_expect(run.attached == 1, "Le module I seul succède au vaisseau I + II, masque=%d" % run.attached)
	print("OK perte du I + II : vies 3 → 2, puis module I")


func _check_i_ii_to_iii_intro() -> void:
	# pr7 : vague 4 terminée avec le I + II, intro depuis 0x822c = 232
	# (position logique y = 224), à l'abscisse courante.
	var run := ArcadeRun.new()
	run.attached = 3
	run.wave_number = 4
	run.combat = CombatRound.new(4, 1, Pilot.MAX_X, 255, 3)
	run.combat.outcome = CombatRound.Outcome.CLEARED
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.DOCKING, "Après la vague 4, le I + II doit amarrer le III")
	_expect(run.docking_target() == 3, "La cible est le module III, obtenu %d" % run.docking_target())
	_expect(run.docking.is_i_and_ii(), "L'approche est celle de l'assemblage I + II")
	_expect(run.docking.position == Vector2i(Pilot.MAX_X + 8, Docking.I_II_START_Y), "Départ d'intro à (208, 224), obtenu %s" % str(run.docking.position))
	# pr8c accroche à (8, -6) seulement : (14, -7), réussi pour le module I, ne suffit pas ici.
	run.docking.stage = Docking.Stage.APPROACH
	run.docking.position = Docking.TARGET + Vector2i(14, -7)
	run.docking._resolve_contact()
	_expect(run.docking.stage == Docking.Stage.APPROACH, "(14, -7) ne doit pas accrocher le I + II → III")
	print("OK vague 4 avec le I + II : intro depuis y = 224, (14, -7) sans contact")


func _check_timeout_resumes_as_i_and_ii() -> void:
	# pr7 : expiration à 16592, écran 183 images, reprise à 16775 en I + II
	# à x = 112, 0x822c = 216 (offset 0), vies 3, score inchangé.
	var run := _start_docking(3)
	run.docking.stage = Docking.Stage.TIMED_OUT
	_hold_until_resume(run, Docking.TIMEOUT_HOLD)
	if run.phase != ArcadeRun.Phase.COMBAT:
		return
	_expect(run.attached == 3, "Après expiration, le I + II continue, masque=%d" % run.attached)
	_expect(run.ship_label() == "I + II", "Libellé inattendu : %s" % run.ship_label())
	_expect(run.score() == 0, "Pas de bonus si le chrono expire")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "L'expiration ne consomme pas de vie")
	_expect(run.combat.pilot.ship_x == Pilot.START_X, "Reprise recentrée à x = 112, obtenu %d" % run.combat.pilot.ship_x)
	_expect(run.combat.pilot.assembly_y_offset == 0, "pr7 : 0x822c = 216, offset 0 après expiration")
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large")
	print("OK chrono écoulé I + II → III : reprise I + II à x = 112, offset 0, sans bonus")


func _check_idle_i_ii_from_the_right_times_out() -> void:
	# pr7 : après l'intro, le I + II part de la butée droite (0x822b = 216,
	# 0x822c = 156) et, avec le pilotage en boucle ouverte, touche la butée
	# basse (0x822c = 240) puis expire. Écran de 183 images, reprise du
	# I + II à x = 112, vies inchangées, 0x822c = 216.
	var run := ArcadeRun.new()
	run.attached = 3
	run.wave_number = 4
	run.phase = ArcadeRun.Phase.DOCKING
	run.docking = Docking.new(1, Pilot.MAX_X, false, 3)
	run._docking_life_taken = false
	_expect(run.docking.position == Vector2i(Pilot.MAX_X + 8, Docking.I_II_START_Y - Docking.LIFT_HEIGHT), "Départ après la montée : %s" % str(run.docking.position))
	var hit_floor := false
	var steps := 0
	while run.docking.stage == Docking.Stage.APPROACH and steps < 5000:
		run.step(0)
		steps += 1
		if run.docking.position.y >= 232:
			hit_floor = true
	_expect(run.docking.stage == Docking.Stage.TIMED_OUT, "L'approche sans commande doit expirer, stage=%s" % Docking.Stage.keys()[run.docking.stage])
	_expect(hit_floor, "pr7 : le I + II atteint la butée basse avant l'expiration")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "Les vies restent à 3 pendant l'approche et l'écran")
	_hold_until_resume(run, Docking.TIMEOUT_HOLD)
	if run.phase != ArcadeRun.Phase.COMBAT:
		return
	_expect(run.attached == 3, "Reprise du I + II, masque=%d" % run.attached)
	_expect(run.combat.pilot.ship_x == Pilot.START_X, "Reprise recentrée à x = 112")
	_expect(run.combat.pilot.assembly_y_offset == 0, "Altitude de combat 0x822c = 216")
	_expect(run.score() == 0, "Pas de bonus")
	print("OK approche I + II à l'inertie depuis la droite : butée basse, expiration, reprise du I + II")

func _check_i_ii_to_iii_collision_from_pr8() -> void:
	# pr8 : au cran 15669, l'offset (32, -4) n'accroche pas ; au cran 15673,
	# (31, -3) est une collision. pr8b : (28, -4) à 16361 sans contact,
	# (29, -3) à 16369 en collision. (25, -7), (26, -6) et (27, -5) restent
	# sans contact. La capture n'est pas relevée.
	var dock := Docking.new(1, Pilot.MAX_X, false, 3)
	for miss in [Vector2i(32, -4), Vector2i(28, -4), Vector2i(25, -7), Vector2i(26, -6), Vector2i(27, -5)]:
		dock.stage = Docking.Stage.APPROACH
		dock.position = Docking.TARGET + miss
		dock._resolve_contact()
		_expect(dock.stage == Docking.Stage.APPROACH, "pr8/pr8b : %s ne doit pas accrocher, stage=%s" % [miss, Docking.Stage.keys()[dock.stage]])
	for hit in [Vector2i(31, -3), Vector2i(29, -3)]:
		dock.stage = Docking.Stage.APPROACH
		dock.position = Docking.TARGET + hit
		dock._resolve_contact()
		_expect(dock.stage == Docking.Stage.COLLISION, "pr8/pr8b : %s doit entrer en collision, stage=%s" % [hit, Docking.Stage.keys()[dock.stage]])
		_expect(dock.bonus == 0, "Pas de bonus en cas de collision")
	print("OK collision I + II → III : (32, -4) et (28, -4) ratés, (31, -3) et (29, -3) collisions")


func _check_collision_resumes_as_three_from_i_ii() -> void:
	# pr8 : explosion 15673, vies 3 → 1, écran 466 images, reprise 16139
	# du module III seul à x = 112, score inchangé.
	var run := _start_docking(3)
	run.docking.stage = Docking.Stage.COLLISION
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "Les vies ne baissent qu'au pas de collision")
	run.step(0)
	_expect(run.lives == 1, "pr8 : vies 3 → 1 dès l'explosion, obtenu %d" % run.lives)
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
	_expect(run.lives == 1, "Les vies restent à 1 à la reprise")
	_expect(run.combat.pilot.ship_x == Docking.TARGET.x, "Reprise du module III à x = 112")
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large")
	print("OK collision I + II → III : vies 3 → 1, reprise module III seul, sans bonus")

func _check_i_ii_to_iii_capture_from_pr8c() -> void:
	# pr8c : au cran 16353, l'offset (7, -7) n'accroche pas ; au cran 16357,
	# (8, -6) réussit. Le chrono affiché est 05:01, le bonus 05 × 300 = 1500.
	# Pendant l'écran, 0x822c reste à 218 : on ne replace pas le vaisseau.
	var dock := Docking.new(1, Pilot.START_X, false, 3)
	dock.remaining_tenths = 51
	dock.position = Docking.TARGET + Vector2i(7, -7)
	dock._resolve_contact()
	_expect(dock.stage == Docking.Stage.APPROACH, "pr8c frame 16353 : (7, -7) ne doit pas accrocher, stage=%s" % Docking.Stage.keys()[dock.stage])
	dock.position = Docking.TARGET + Vector2i(8, -6)
	dock._resolve_contact()
	_expect(dock.stage == Docking.Stage.SUCCESS, "pr8c frame 16357 : (8, -6) doit accrocher, stage=%s" % Docking.Stage.keys()[dock.stage])
	_expect(dock.bonus == 1500, "Bonus 05 × 300 = 1500, obtenu %d" % dock.bonus)
	_expect(dock.position == Docking.TARGET + Vector2i(8, -6), "Le contact reste à (120, 210), obtenu %s" % str(dock.position))
	# pr10a : balayage vers la gauche sur les rangées -5 / -6, (15, -5) et
	# (15, -6) ratés, (14, -6) contact à 15977, chrono 14:06, bonus 14 × 300.
	# pr10b : balayage vers la droite, (1, -6) et (2, -5) ratés, (3, -6)
	# contact à 16333, chrono 05:07, bonus 05 × 300.
	for miss in [Vector2i(15, -5), Vector2i(15, -6), Vector2i(1, -6), Vector2i(2, -5), Vector2i(6, -8)]:
		var outside := Docking.new(1, Pilot.START_X, false, 3)
		outside.position = Docking.TARGET + miss
		outside._resolve_contact()
		_expect(outside.stage == Docking.Stage.APPROACH, "%s ne doit pas accrocher le I + II → III" % str(miss))
	var right := Docking.new(1, Pilot.START_X, false, 3)
	right.remaining_tenths = 146
	right.position = Docking.TARGET + Vector2i(14, -6)
	right._resolve_contact()
	_expect(right.stage == Docking.Stage.SUCCESS, "pr10a frame 15977 : (14, -6) doit accrocher")
	_expect(right.display_clock() == "14:6", "Chrono 14:6, obtenu %s" % right.display_clock())
	_expect(right.bonus == 4200, "Bonus 14 × 300 = 4200, obtenu %d" % right.bonus)
	var left := Docking.new(1, Pilot.START_X, false, 3)
	left.remaining_tenths = 57
	left.position = Docking.TARGET + Vector2i(3, -6)
	left._resolve_contact()
	_expect(left.stage == Docking.Stage.SUCCESS, "pr10b frame 16333 : (3, -6) doit accrocher")
	_expect(left.bonus == 1500, "Bonus 05 × 300 = 1500, obtenu %d" % left.bonus)
	print("OK contact I + II → III : rangée y = -6 de x = 3 à x = 14, (1, -6), (15, -6), (2, -5), (15, -5) ratés")


func _check_success_resumes_as_one_two_and_three() -> void:
	# pr8c : contact 16357, écran BRAVO 305 images, crédit et reprise à 16662
	# en I + II + III à x = 112 (0x822b = 128, 0x822c = 216), vies 3,
	# score +1500, butée gauche x = 14 (0x822b = 30).
	var run := _start_docking(3)
	run.docking.stage = Docking.Stage.SUCCESS
	run.docking.bonus = 1500
	_expect(run.score() == 0, "Le bonus ne doit pas être crédité avant la fin de l'écran")
	for index in range(Docking.BONUS_HOLD - 1):
		run.step(Pilot.LEFT)
	_expect(run.phase == ArcadeRun.Phase.DOCKING, "Le bonus de 305 images n'est pas encore écoulé")
	_expect(run.score() == 0, "Le bonus est crédité seulement à la 305e image")
	run.step(Pilot.LEFT)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "La réussite doit enchaîner sur le combat")
	_expect(run.attached == 7, "Le vaisseau repris doit être I + II + III, masque=%d" % run.attached)
	_expect(run.ship_label() == "I + II + III", "Libellé inattendu : %s" % run.ship_label())
	_expect(run.front_module() == 1, "Le module supérieur reste le I")
	_expect(run.combat.pilot.has_module(1) and run.combat.pilot.has_module(2) and run.combat.pilot.has_module(3), "Le pilote doit porter les trois modules")
	_expect(run.combat.pilot.assembly_y_offset == 0, "pr8c : 0x822c = 216, offset 0 après la réussite")
	_expect(run.score() == 1500, "Score attendu 1500 après le bonus, obtenu %d" % run.score())
	_expect(run.wave_number == ArcadeRun.WAVE_AFTER_DOCK, "Reprise sur une entrée large (vague %d)" % ArcadeRun.WAVE_AFTER_DOCK)
	_expect(run.combat.pilot.ship_x == Docking.TARGET.x, "Reprise alignée sur la cible")
	_expect(run.lives == ArcadeRun.STARTING_LIVES, "L'amarrage réussi ne consomme pas de vie")
	var start_x := run.combat.pilot.ship_x
	run.step(Pilot.LEFT)
	_expect(run.combat.pilot.ship_x == start_x - Pilot.MOVE_STEP, "La gauche déplace le I + II + III dès la reprise")
	for index in range(80):
		run.step(Pilot.LEFT)
	_expect(run.combat.pilot.ship_x == Pilot.MIN_X, "La butée gauche du I + II + III est x = 14, obtenu %d" % run.combat.pilot.ship_x)
	run.step(Pilot.LEFT)
	_expect(run.combat.pilot.ship_x == Pilot.MIN_X, "La butée gauche tient tant que la gauche reste enfoncée")
	# pr7 + pr9b : le dernier groupe du I + II est le 0 (14721) ; à la reprise,
	# le premier appui (16840) forme le groupe 1 assemblé (y = 195, écart 8).
	run = _start_docking(3)
	run.combat = CombatRound.new(4, 1, Pilot.START_X, 255, 3)
	run.combat.pilot.step(Pilot.FIRE)
	_expect(run.combat.pilot._next_group == 1, "Après le groupe 0 du I + II, l'index doit passer à 1")
	run.combat.pilot.clear_shots()
	run.docking.stage = Docking.Stage.SUCCESS
	run.docking.bonus = 1500
	for index in range(Docking.BONUS_HOLD):
		run.step(0)
	_expect(run.attached == 7 and run.combat.pilot._next_group == 1, "L'index 1 survit à l'amarrage réussi")
	run.combat.pilot.ship_x = 200
	run.combat.pilot.step(Pilot.FIRE)
	var shots := run.combat.pilot.active_shots()
	var left := Vector2i(191, 195)
	var right := Vector2i(207, 195)
	_expect(shots.size() == 2 and left in shots and right in shots, "Premier tir après reprise : groupe 1 à x = 200, obtenu %s" % str(shots))
	print("OK réussite I + II → III : bonus 1500, 305 images, reprise à x = 112, vies 3, butée 14, premier tir groupe 1")


func _check_life_lost_after_i_ii_and_iii() -> void:
	# pr8c : destruction du I + II + III à la butée gauche (16754), vies 3 → 2
	# à 17073, puis entrée du II + III (modules à y = 200 et 216, à 17451).
	var run := ArcadeRun.new()
	run.attached = 7
	run.lives = 3
	run.combat = CombatRound.new(3, 1, Pilot.MIN_X, 255, 7)
	run.combat.outcome = CombatRound.Outcome.MODULE_LOST
	run.step(0)
	_expect(run.phase == ArcadeRun.Phase.REPLACEMENT, "La perte du I + II + III ouvre le remplacement")
	for index in range(ArcadeRun.COUNTER_DROP_FRAMES - 1):
		run.step(0)
	_expect(run.lives == 3, "Vies encore inchangées à l'image %d" % (ArcadeRun.COUNTER_DROP_FRAMES - 1))
	_expect(run.attached == 7, "Le masque reste I + II + III tant que le compteur n'a pas baissé")
	run.step(0)
	_expect(run.lives == 2, "Vies 3 → 2 à la baisse du compteur, obtenu %d" % run.lives)
	_expect(run.attached == 6, "Le vaisseau II + III succède au I + II + III, masque=%d" % run.attached)
	print("OK perte du I + II + III : vies 3 → 2, puis II + III")
