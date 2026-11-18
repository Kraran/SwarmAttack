extends SceneTree
const Run = preload("res://arcade_run.gd")
const Combat = preload("res://combat_round.gd")
const Wave = preload("res://combat_wave.gd")
const Effects = preload("res://arcade_effects.gd")
var view: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	var combat := _fixture(1,0)
	for index in range(8):
		var enemy := Wave.Enemy.new()
		enemy.position = Vector2i(45 + index * 22,80)
		enemy.velocity = Vector2i.ZERO
		enemy.phase = Wave.Flight.OPENING
		combat.wave.enemies.append(enemy)
	combat.pilot.shot_active = true
	combat.pilot.second_shot_active = true
	combat.pilot.shot_position = combat.wave.enemies[0].position - Vector2i(17,0)
	combat.pilot.second_shot_position = combat.wave.enemies[1].position - Vector2i(17,0)
	_step()
	_expect(view._combat_impacts.size() == 2 and combat.wave.remaining == 6 and combat.score == 0, "Deux impacts simultanés, crédit des points toujours différé")
	_expect(view._combat_impacts[0].slot == 0 and view._combat_impacts[1].slot == 1, "Chaque moitié reçoit son propre effet")
	var first: Vector2 = view._combat_impacts[0].point
	_step()
	_expect(view._combat_impacts.size() == 2, "Un impact ne se répète pas au pas suivant")
	combat.pilot.shot_active = true
	combat.pilot.shot_position = combat.wave.enemies[2].position - Vector2i(17,0)
	_step()
	_expect(view._combat_impacts.size() == 3 and view._combat_impacts[0].point == first, "Un impact ultérieur conserve les effets précédents")
	for i in Effects.IMPACT_LIFETIME + 1:
		_step()
	_expect(view._combat_impacts.is_empty() and combat.score == 3 * combat.wave.points_per_hit, "Effets expirés et scores crédités une seule fois")
	for fixture in [[5,1,Wave.Flight.FALL_EXIT], [3,2,Wave.Flight.ROW_EXIT]]:
		combat = _fixture(fixture[0], fixture[1])
		var enemy := Wave.Enemy.new()
		enemy.position = Vector2i(80,0)
		enemy.phase = fixture[2]
		combat.wave.enemies.append(enemy)
		_step()
		_expect(view._combat_impacts.is_empty() and combat.score == 0, "Une sortie hors champ ne crée pas d’explosion")
	combat = _fixture(1,0)
	var enemy := Wave.Enemy.new()
	enemy.position = Vector2i(80,70)
	enemy.phase = Wave.Flight.OPENING
	combat.wave.enemies.append(enemy)
	combat.wave.enemies.append(Wave.Enemy.new())
	var mask := combat.wave.survivors()
	combat.wave.kill(0)
	view._capture_combat_impacts(combat,mask,1)
	_expect(view._combat_impacts.size() == 1, "Effet avant changement de partie")
	view._return_to_title()
	_expect(view._combat_impacts.is_empty(), "L’accueil vide les effets")
	view._restart(false)
	_expect(view._combat_impacts.is_empty(), "Une nouvelle partie commence sans effets résiduels")
	if failures == 0:
		print("IMPACTS OK: volée simultanée, impacts consécutifs, expiration, crédit des points, sorties et relance.")
	quit(1 if failures else 0)

func _fixture(number: int, stage: int) -> Combat:
	view._restart(false)
	view._run.phase = Run.Phase.COMBAT
	view._run.stage = stage
	view._run.wave_number = number
	var combat := Combat.new(number,1,112,255,1,-1,stage)
	view._run.combat = combat
	return combat

func _step() -> void:
	view._simulation_tick += 1
	view._step_session(0)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

