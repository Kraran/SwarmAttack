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


func _init(wave_number := 1, module := 1, start_x := Pilot.START_X, alive_mask := 255) -> void:
	pilot = Pilot.new(module, start_x)
	wave = CombatWave.new(wave_number, alive_mask)


func step(input_mask: int) -> void:
	_elapsed_frames += 1
	impact_age = mini(impact_age + 1, IMPACT_FRAMES)
	while not _pending_points.is_empty() and _pending_points[0] == _elapsed_frames:
		_pending_points.pop_front()
		score += wave.points_per_hit
	if outcome != Outcome.PLAYING:
		return
	var next_frame := pilot.frame + 1
	pilot.step(input_mask, next_frame not in CombatWave.OPENING_CLOCK_HOLDS)
	wave.advance(pilot.frame, pilot.ship_x)
	if pilot.shot_active and _try_hit(pilot.shot_position):
		pilot.shot_active = false
	if pilot.second_shot_active and _try_hit(pilot.second_shot_position):
		pilot.second_shot_active = false
	if wave.remaining == 0 and _pending_points.is_empty():
		outcome = Outcome.CLEARED
		pilot.clear_shots()
	elif wave.hits_ship(pilot.ship_x, pilot.module):
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
