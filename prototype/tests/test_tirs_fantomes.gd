extends SceneTree

const ArcadeRun = preload("res://arcade_run.gd")
const Pilot = preload("res://pilot.gd")
const CombatRound = preload("res://combat_round.gd")
const Docking = preload("res://docking.gd")

# Dernière volée du module II avant l'amarrage, figée à la frame 6185 sur pr1 :
# registres (0x40, 88) et (0x50, 88). y logique = 251 − registre.
const LEFTOVER_LEFT := Vector2i(47, 163)
const LEFTOVER_RIGHT := Vector2i(63, 163)
# Reprise réussie à 7723 : y registre 96, soit deux pas depuis le gel.
const SUCCESS_Y := 155
# Reprise après expiration à 8125 : y registre 92, soit un pas depuis le gel.
const TIMEOUT_Y := 159

var failures := 0


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _initialize() -> void:
	_check_hidden_during_hold()
	_check_success_resumes_leftovers()
	_check_timeout_resumes_leftovers()
	_check_collision_clears_leftovers()
	_check_wave_clear_keeps_shots()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("TIRS FANTÔMES OK")
		quit(0)


func _start_docking_with_leftovers() -> ArcadeRun:
	var run := ArcadeRun.new()
	run.attached = 2
	run.wave_number = 4
	run.phase = ArcadeRun.Phase.DOCKING
	run.docking = Docking.new(run.front_module(), Pilot.START_X, false)
	run._docking_life_taken = false
	run.combat = CombatRound.new(4, 2, 56, 255, 2)
	run.combat.pilot.shot_position = LEFTOVER_LEFT
	run.combat.pilot.shot_active = true
	run.combat.pilot.second_shot_position = LEFTOVER_RIGHT
	run.combat.pilot.second_shot_active = true
	return run


func _expect_pair(shots: Array, left: Vector2i, right: Vector2i, label: String) -> void:
	_expect(shots.size() == 2, "%s : deux projectiles attendus, obtenu %d (%s)" % [label, shots.size(), shots])
	if shots.size() < 2:
		return
	_expect(left in shots and right in shots, "%s : attendu %s et %s, obtenu %s" % [label, left, right, shots])


func _check_hidden_during_hold() -> void:
	var run := _start_docking_with_leftovers()
	run.docking.stage = Docking.Stage.SUCCESS
	run.docking.bonus = 2600
	for index in range(Docking.BONUS_HOLD - 1):
		run.step(0)
		_expect(run.phase == ArcadeRun.Phase.DOCKING, "L'écran bonus doit durer 305 images")
		_expect_pair(
			run.combat.pilot.active_shots(),
			LEFTOVER_LEFT,
			LEFTOVER_RIGHT,
			"Gel pendant l'écran à l'image %d" % index
		)
		if failures:
			return
	print("OK écran de résultat : créneaux figés, sans avancement")


func _check_success_resumes_leftovers() -> void:
	var run := _start_docking_with_leftovers()
	run.docking.stage = Docking.Stage.SUCCESS
	run.docking.bonus = 2600
	for index in range(Docking.BONUS_HOLD):
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "La réussite doit reprendre le combat")
	_expect(run.attached == 6, "Reprise en vaisseau II + III")
	var shots := run.combat.pilot.active_shots()
	_expect_pair(shots, Vector2i(47, SUCCESS_Y), Vector2i(63, SUCCESS_Y), "Reprise réussie")
	_expect(run.combat.pilot._group_is_busy(1), "Les fantômes occupent le groupe 1")
	_expect(not run.combat.pilot._group_is_busy(0), "Le groupe 0 reste libre")
	run.step(Pilot.FIRE)
	var after := run.combat.pilot.active_shots()
	_expect(after.size() == 4, "Le premier appui lance le groupe 0 en plus des fantômes, obtenu %d" % after.size())
	_expect(Vector2i(99, 212) in after and Vector2i(123, 212) in after, "Le groupe 0 part du centre : %s" % str(after))
	_expect(Vector2i(47, SUCCESS_Y - Pilot.SHOT_STEP) in after and Vector2i(63, SUCCESS_Y - Pilot.SHOT_STEP) in after, "Les fantômes continuent de monter : %s" % str(after))
	print("OK réussite : reprise à y = 155, groupe 0 toujours premier")


func _check_timeout_resumes_leftovers() -> void:
	var run := _start_docking_with_leftovers()
	run.docking.stage = Docking.Stage.TIMED_OUT
	for index in range(Docking.TIMEOUT_HOLD):
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "L'expiration doit reprendre le combat")
	_expect(run.attached == 2, "Reprise avec le module II seul")
	_expect_pair(
		run.combat.pilot.active_shots(),
		Vector2i(47, TIMEOUT_Y),
		Vector2i(63, TIMEOUT_Y),
		"Reprise après expiration"
	)
	print("OK expiration : reprise à y = 159, module II seul")


func _check_collision_clears_leftovers() -> void:
	var run := _start_docking_with_leftovers()
	run.docking.stage = Docking.Stage.COLLISION
	run.step(0)
	_expect(run.combat.pilot.active_shots().is_empty(), "L'explosion efface le drapeau des créneaux")
	for index in range(Docking.COLLISION_HOLD - 1):
		if run.phase != ArcadeRun.Phase.DOCKING:
			_fail("Reprise anticipée pendant la collision")
			return
		run.step(0)
	_expect(run.phase == ArcadeRun.Phase.COMBAT, "Le combat reprend après la collision")
	_expect(run.attached == 4, "Reprise avec le module III seul")
	_expect(run.combat.pilot.active_shots().is_empty(), "Aucun projectile à la reprise après collision")
	print("OK collision : créneaux vidés dès l'explosion, rien à la reprise")


func _check_wave_clear_keeps_shots() -> void:
	var combat := CombatRound.new(1, 2, 56, 255, 2)
	combat.wave.remaining = 0
	combat.wave.enemies.clear()
	combat.pilot.shot_position = LEFTOVER_LEFT
	combat.pilot.shot_active = true
	combat.pilot.second_shot_position = LEFTOVER_RIGHT
	combat.pilot.second_shot_active = true
	combat.step(0)
	_expect(combat.outcome == CombatRound.Outcome.CLEARED, "Sans ennemi restant ni points en attente, la vague est terminée")
	_expect_pair(
		combat.pilot.active_shots(),
		LEFTOVER_LEFT,
		LEFTOVER_RIGHT,
		"Fin de vague sans vidage des créneaux"
	)
	combat.step(0)
	_expect_pair(combat.pilot.active_shots(), LEFTOVER_LEFT, LEFTOVER_RIGHT, "Plus d'avancement une fois la vague terminée")
	print("OK fin de vague : les projectiles restent figés dans les créneaux")
