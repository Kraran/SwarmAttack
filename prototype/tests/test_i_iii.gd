extends SceneTree
const Pilot = preload("res://pilot.gd")
const Run = preload("res://arcade_run.gd")
const Round = preload("res://combat_round.gd")
const Wave = preload("res://combat_wave.gd")
const Docking = preload("res://docking.gd")
var failures := 0

func _initialize() -> void:
	var pilot := Pilot.new(1,112,5)
	_expect(pilot.uses_fire_groups(), "I + III utilise ses deux canons")
	pilot.step(Pilot.FIRE)
	_expect(pilot.active_shots() == [Vector2i(99,212),Vector2i(123,212),Vector2i(111,183)],
		"I + III : tir central I et paire large III, aucun tir II")
	var saved := pilot.active_shots()
	var restored := Pilot.new(1,112,5)
	restored.restore_shots(saved)
	_expect(restored.active_shots() == saved, "Restauration des trois projectiles")
	for index in [2,1,0]:
		restored.deactivate_shot(index)
	_expect(restored.active_shots().is_empty(), "Les trois projectiles se désactivent individuellement")
	for frame in 49:
		pilot.step(0)
	pilot.step(Pilot.FIRE)
	_expect(pilot.shot_active and pilot._group_active[0] and pilot._group_active[1]
		and not pilot._group_active[2] and not pilot._group_active[3],
		"Le I tire à nouveau indépendamment, le III conserve sa paire, aucune alternance avec le II")
	for frame in 200:
		pilot.step(Pilot.RIGHT)
	_expect(pilot.ship_x == Pilot.MAX_X, "Butée droite I + III")
	for frame in 200:
		pilot.step(Pilot.LEFT)
	_expect(pilot.ship_x == Pilot.MIN_X, "Butée gauche I + III")
	var run := _next_dock()
	_expect(run.docking.target_module == 3 and run.docking.is_i_to_iii(), "Le prochain partenaire du I est le III")
	for frame in 2500:
		if run.docking.stage != Docking.Stage.INTRO and run.docking.stage != Docking.Stage.APPROACH:
			break
		run.step(_approach_input(run.docking))
	_expect(run.docking.stage == Docking.Stage.SUCCESS and run.docking.bonus > 0,
		"Amarrage I → III réussi par approche normale, sans forcer le contact")
	for frame in Docking.BONUS_HOLD:
		run.step(0)
	_expect(run.attached == 5 and run.combat.pilot.attached == 5 and run.ship_label() == "I + III"
		and run.available_modules() == 5 and run.lives == 2, "I + III formé uniquement après réussite, II toujours détruit")
	run.combat.outcome = Round.Outcome.CLEARED
	run.step(0)
	_expect(run.attached == 5 and run.combat.pilot.attached == 5 and run.docking_target() == 0,
		"I + III conservé à la vague suivante, aucun partenaire absent")
	for outcome in [Docking.Stage.TIMED_OUT, Docking.Stage.COLLISION]:
		var failed := _next_dock()
		failed.docking.stage = outcome
		for frame in Docking.COLLISION_HOLD + 1:
			if failed.phase != Run.Phase.DOCKING:
				break
			failed.step(0)
		_expect(failed.attached == (1 if outcome == Docking.Stage.TIMED_OUT else 4)
			and not (failed.available_modules() & 2), "Échec I → III : bonne coque de reprise, II toujours détruit")
	for contact in [[Vector2i(8,-6),Docking.Stage.SUCCESS], [Vector2i(8,-3),Docking.Stage.COLLISION],
			[Vector2i(35,12),Docking.Stage.APPROACH]]:
		var dock := Docking.new(1,112,false,1,3)
		dock.position = Docking.TARGET + contact[0]
		dock._resolve_contact()
		_expect(dock.stage == contact[1], "I → III : capture, collision et passage hors cible")
		if dock.stage == Docking.Stage.SUCCESS:
			_expect(dock.display_position() == Vector2(112,200), "I aligné sur sa position dans le duo I + III")
	for module in [1,3]:
		var hit_run := Run.new()
		hit_run.attached = 5
		hit_run._lost_modules = 2
		hit_run._begin_combat(112,255)
		hit_run.combat.outcome = Round.Outcome.MODULE_LOST
		hit_run.combat.lost_module = module
		hit_run.step(0)
		for frame in Run.COUNTER_DROP_FRAMES:
			hit_run.step(0)
		_expect(hit_run.attached == (4 if module == 1 else 1) and not (hit_run.available_modules() & 2),
			"Perte du %d : seul l'autre survivant, sans recréer le II" % module)
	var wave := Wave.new(3)
	var enemy := Wave.Enemy.new()
	wave.enemies.assign([enemy])
	for position in [Vector2i(116,193),Vector2i(116,218),Vector2i(135,200)]:
		enemy.position = position
		_expect(wave.hit_module(112,5) in [1,3], "Un contact I + III n'est jamais attribué au II")
	if failures == 0:
		print("I + III OK: séparation après perte II, I seul, prochain amarrage au III, issues, canons et collisions.")
	quit(1 if failures else 0)

func _next_dock() -> Run:
	var run := Run.new()
	run.attached = 7
	run.stage = 2
	run.wave_number = 3
	run._begin_combat(112,255)
	run.combat.outcome = Round.Outcome.MODULE_LOST
	run.combat.lost_module = 2
	run.step(0)
	for frame in Run.COUNTER_DROP_FRAMES:
		run.step(0)
	_expect(run.attached == 1 and run.available_modules() == 5 and run.entrance_modules() == 1,
		"Perte du II : seul le I remonte, III intact en réserve")
	for frame in Run.ENTRANCE_FRAMES:
		run.step(0)
	_expect(run.combat.pilot.attached == 1 and run.docking_target() == 3, "Combat avec le I seul, prochaine cible III")
	for wave in 2:
		run.combat.outcome = Round.Outcome.CLEARED
		run.step(0)
	for frame in Run.CYCLE_ENTRANCE_DONE:
		run.step(0)
	_expect(run.cycle == 2 and run.phase == Run.Phase.COMBAT and run.available_modules() == 5,
		"Cycle suivant sans recréer le II")
	for wave in 4:
		run.combat.outcome = Round.Outcome.CLEARED
		run.step(0)
	_expect(run.phase == Run.Phase.DOCKING and run.attached == 1, "Prochain amarrage atteint avec le I seul")
	return run

func _approach_input(dock: Docking) -> int:
	if dock.stage != Docking.Stage.APPROACH:
		return 0
	var input := 0
	var desired := 128 + clampi((dock.position.x - 120) * 5, -28, 28)
	if dock._horizontal.velocity > desired:
		input |= Pilot.RIGHT
	elif dock._horizontal.velocity < desired:
		input |= Pilot.LEFT
	if absi(dock.position.x - 120) > 11 and dock._vertical.velocity < 128:
		input |= Pilot.FIRE
	return input

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
