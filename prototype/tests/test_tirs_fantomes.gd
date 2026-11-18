extends SceneTree
const Run = preload("res://arcade_run.gd")
const Round = preload("res://combat_round.gd")
const Pilot = preload("res://pilot.gd")
const Docking = preload("res://docking.gd")
var failures := 0

func _initialize() -> void:
	for configuration in [[1,2],[2,3],[3,3],[1,3]]:
		for outcome in [Docking.Stage.SUCCESS,Docking.Stage.TIMED_OUT,Docking.Stage.COLLISION]:
			for held in [0,Pilot.FIRE]:
				_check_resume(configuration[0],configuration[1],outcome,held)
	_check_wave_boundary()
	if failures == 0:
		print("TIRS FANTÔMES OK: 4 amarrages, 3 issues, maintien et nouvel appui, fin de vague nettoyée.")
	quit(1 if failures else 0)

func _dirty(pilot: Pilot) -> void:
	pilot.shot_active = true
	pilot.shot_position = Vector2i(47,163)
	pilot.second_shot_active = true
	pilot.second_shot_position = Vector2i(63,163)
	for slot in 4:
		pilot._group_active[slot] = true
		pilot._group_position[slot] = Vector2i(47+8*slot,163)

func _check_resume(mask: int, target: int, outcome: int, held: int) -> void:
	var run := Run.new()
	run.attached = mask
	if mask == 1 and target == 3:
		run._lost_modules = 2
	run.wave_number = run.last_wave()
	run._begin_combat(112,255)
	var completed := run.combat
	completed.outcome = Round.Outcome.CLEARED
	_dirty(completed.pilot)
	run.step(0)
	_expect(run.phase == Run.Phase.DOCKING and completed.pilot.active_shots().is_empty(), "Entrée d'amarrage : aucun tir conservé")
	# Vérifier aussi la défense à la reprise contre des créneaux anciens.
	_dirty(completed.pilot)
	run.docking.stage = outcome
	run.docking.bonus = 1500 if outcome == Docking.Stage.SUCCESS else 0
	var hold := run.docking.result_hold()
	for tick in hold:
		run.step(held)
	_expect(run.phase == Run.Phase.COMBAT and run.combat.pilot.active_shots().is_empty(),
		"Reprise sans tir fantôme : masque %d cible %d issue %d maintien %d" % [mask,target,outcome,held])
	_expect(completed.pilot.active_shots().is_empty(), "Les anciens créneaux sont aussi vidés à la reprise")
	for tick in 5:
		run.step(held)
		_expect(run.combat.pilot.active_shots().is_empty(), "Sans nouvel appui, aucun projectile après reprise")
	run.step(0)
	run.step(Pilot.FIRE)
	_expect(not run.combat.pilot.active_shots().is_empty(), "Un véritable nouvel appui tire normalement")

func _check_wave_boundary() -> void:
	var run := Run.new()
	run.combat.outcome = Round.Outcome.CLEARED
	var previous := run.combat
	_dirty(previous.pilot)
	run.step(Pilot.FIRE)
	_expect(previous.pilot.active_shots().is_empty() and run.combat.pilot.active_shots().is_empty(), "Les deux vagues ont leurs tirs vidés à la transition")
	run.step(Pilot.FIRE)
	_expect(run.combat.pilot.active_shots().is_empty(), "Le maintien ne déclenche pas de tir à la nouvelle vague")
	run.step(0)
	run.step(Pilot.FIRE)
	_expect(not run.combat.pilot.active_shots().is_empty(), "Le tir reste disponible après relâchement")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 10:
			printerr("FAIL: " + message)
