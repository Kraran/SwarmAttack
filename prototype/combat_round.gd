extends RefCounted

const Pilot = preload("res://pilot.gd")
const CombatWave = preload("res://combat_wave.gd")
const IMPACT_FRAMES := 12
const SCORE_DELAY := 10

enum Outcome { PLAYING, MODULE_LOST, CLEARED }

var pilot: Pilot
var wave: CombatWave
var score := 0
var outcome := Outcome.PLAYING
var impact_position := Vector2.ZERO
var impact_age := IMPACT_FRAMES
var _elapsed_frames := 0
var _pending_points: Array[int] = []


func _init(wave_number := 1, module := 1, start_x := Pilot.START_X, alive_mask := 255, attached := 0) -> void:
	pilot = Pilot.new(module, start_x, attached)
	wave = CombatWave.new(wave_number, alive_mask)


func step(input_mask: int) -> void:
	_elapsed_frames += 1
	impact_age = mini(impact_age + 1, IMPACT_FRAMES)
	while not _pending_points.is_empty() and _pending_points[0] == _elapsed_frames:
		_pending_points.pop_front()
		score += wave.points_per_hit
	if outcome != Outcome.PLAYING:
		return
	# Fin de vague : le moteur de tir Jeutel s'arrête (0x8226 à 0 vers 6185)
	# sans vider les créneaux logiciels. Les projectiles restent figés.
	if wave.remaining == 0:
		if _pending_points.is_empty():
			outcome = Outcome.CLEARED
		return
	var next_frame := pilot.frame + 1
	pilot.step(input_mask, next_frame not in CombatWave.OPENING_CLOCK_HOLDS)
	wave.advance(pilot.frame, pilot.ship_x)
	var shots := pilot.active_shots()
	var hits: Array[int] = []
	for index in range(shots.size() - 1, -1, -1):
		if _try_hit(shots[index]):
			hits.append(index)
	# La volée qui termine la vague n'est pas désactivée : pr1 fige
	# 0x8161–0x8168 (drapeau 0x8163 encore à 1, x = 0x40/0x50, y = 0xa7).
	if wave.remaining > 0:
		for index in hits:
			pilot.deactivate_shot(index)
	if wave.remaining == 0:
		if _pending_points.is_empty():
			outcome = Outcome.CLEARED
	elif wave.hits_attached(pilot.ship_x, pilot.attached):
		outcome = Outcome.MODULE_LOST
		pilot.clear_shots()
		impact_position = Vector2(pilot.ship_x, pilot.ship_y() + 6)
		impact_age = 0


func _try_hit(position: Vector2i) -> bool:
	var hit := wave.hit_by(position)
	if hit == null:
		return false
	_pending_points.append(_elapsed_frames + SCORE_DELAY)
	impact_position = hit.display_position()
	impact_age = 0
	return true
