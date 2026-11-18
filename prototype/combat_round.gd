extends RefCounted

const Pilot = preload("res://pilot.gd")
const CombatWave = preload("res://combat_wave.gd")
const IMPACT_FRAMES := 12
# Bref délai d'effet, constant indépendamment de la charge de la borne.
const SCORE_DELAY := 10

enum Outcome { PLAYING, MODULE_LOST, CLEARED }

var pilot: Pilot
var wave: CombatWave
var score := 0
var outcome := Outcome.PLAYING
var impact_position := Vector2.ZERO
var impact_age := IMPACT_FRAMES
var impacted_enemy: CombatWave.Enemy
var lost_module := 0
var _elapsed_frames := 0
var _pending_points: Array[int] = []


func _init(
		wave_number := 1, module := 1, start_x := Pilot.START_X, alive_mask := 255, attached := 0,
		points := -1, stage := 0, max_divers := 1, patterns: Array = []
) -> void:
	pilot = Pilot.new(module, start_x, attached)
	wave = CombatWave.new(wave_number, alive_mask, points, stage)
	wave.max_divers = max_divers
	wave.load_patterns(patterns)


func step(input_mask: int) -> void:
	_elapsed_frames += 1
	impact_age = mini(impact_age + 1, IMPACT_FRAMES)
	var credits := 0
	for index in range(_pending_points.size() - 1, -1, -1):
		if _pending_points[index] <= _elapsed_frames:
			_pending_points.remove_at(index)
			score += wave.points_per_hit
			credits += 1
	if outcome != Outcome.PLAYING:
		for i in range(credits):
			wave.credit_kill()
		return
	# Pendant le crédit final, garder le déplacement actif, sans nouveaux tirs.
	if wave.remaining == 0:
		for i in range(credits):
			wave.credit_kill()
		pilot.step(input_mask & ~Pilot.FIRE)
		if input_mask & Pilot.FIRE:
			pilot.absorb_held_fire()
		pilot.clear_shots()
		if _pending_points.is_empty():
			outcome = Outcome.CLEARED
		return
	var previous_ship_x := pilot.ship_x
	var previous_shots := pilot.active_shots()
	var previous_enemies := {}
	for enemy in wave.enemies:
		if enemy.has_visible_pose():
			previous_enemies[enemy] = enemy.position
	pilot.step(input_mask)
	wave.advance(pilot.frame, pilot.ship_x)
	# 0x823c baisse à l'image du crédit, après le déplacement des ennemis :
	# la règle des moins de 5 survivants joue au pas suivant (pr11c 18679-18681).
	for i in range(credits):
		wave.credit_kill()
	var shots := pilot.active_shots()
	var hits: Array[int] = []
	for index in range(shots.size() - 1, -1, -1):
		var origin := shots[index] + Vector2i(0, Pilot.SHOT_STEP)
		var previous := Vector2(origin) if origin in previous_shots else Vector2(shots[index])
		if _try_hit(shots[index], previous, previous_enemies):
			hits.append(index)
	for index in hits:
		pilot.deactivate_shot(index)
	if wave.remaining == 0:
		pilot.clear_shots()
		if _pending_points.is_empty():
			outcome = Outcome.CLEARED
	else:
		lost_module = wave.hit_module(pilot.ship_x, pilot.attached, pilot.assembly_y_offset, previous_ship_x, previous_enemies)
		if lost_module == 0:
			return
		outcome = Outcome.MODULE_LOST
		pilot.clear_shots()
		impact_position = Vector2(pilot.ship_x, pilot.module_y(lost_module) + pilot.assembly_y_offset + 6)
		impacted_enemy = null
		impact_age = 0


func score_delay() -> int:
	return SCORE_DELAY


func _try_hit(position: Vector2i, previous := Vector2.INF, previous_enemies: Dictionary = {}) -> bool:
	var hit := wave.hit_by(position, previous, previous_enemies)
	if hit == null:
		return false
	_pending_points.append(_elapsed_frames + score_delay())
	impacted_enemy = hit
	impact_position = hit.display_position()
	impact_age = 0
	return true
