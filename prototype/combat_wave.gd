extends RefCounted

const SPAWN_FRAME := 32
const OPENING_LENGTH := 16
# The startup trace includes three board frames without a wave-clock increment.
const OPENING_CLOCK_HOLDS := [34, 118, 212]
const INITIAL_POSITIONS := [
	Vector2i(112, 96), Vector2i(120, 96), Vector2i(128, 96), Vector2i(120, 88)
]
const OPENING_STEPS := [Vector2i(-2, -2), Vector2i(0, -1), Vector2i(2, -2), Vector2i(0, -2)]

# Displacements for the 28 headings, in the board's 8-bit coordinate system.
const HEADINGS := [
	Vector2i(0, 3), Vector2i(-1, 4), Vector2i(-3, 5), Vector2i(-4, 4),
	Vector2i(-5, 3), Vector2i(-4, 1), Vector2i(-3, 0), Vector2i(-3, 0),
	Vector2i(-4, -1), Vector2i(-5, -3), Vector2i(-4, -4), Vector2i(-3, -5),
	Vector2i(-1, -4), Vector2i(0, -3), Vector2i(0, -3), Vector2i(1, -4),
	Vector2i(3, -5), Vector2i(4, -4), Vector2i(5, -3), Vector2i(4, -1),
	Vector2i(3, 0), Vector2i(3, 0), Vector2i(4, 1), Vector2i(5, 3),
	Vector2i(4, 4), Vector2i(3, 5), Vector2i(1, 4), Vector2i(0, 3)
]

enum Flight { OPENING, ENTRY_CURVE, FORMATION, DIVE, STRAIGHT_DIVE, RETURNING, CIRCLING }

class Enemy:
	var position: Vector2i
	var velocity: Vector2i
	var alive := true
	var phase := Flight.OPENING
	var opening_left := OPENING_LENGTH
	var heading := 1
	var turn := 1
	var turns_left := 0
	var steps_left := 0
	var straight_steps := 1
	var diagonal_steps := 1
	var acceleration := 0
	var reverse_turn := false
	var separate_at := 0
	var cadence := 1
	var cadence_left := 1

	func display_position() -> Vector2:
		return Vector2(position.x - 8, position.y + 8)

var enemies: Array[Enemy] = []
var remaining: int
var points_per_hit: int
var wide_entry: bool
var _alive_mask: int
var _wave_clock := 0
var _dive_patterns := [0, 0, 0, 0]
var _return_pattern := 0
var _formation_pattern := 0


func _init(wave_number := 1, alive_mask := 255) -> void:
	wide_entry = wave_number >= 3
	points_per_hit = 30 if wide_entry else 50
	_alive_mask = alive_mask
	remaining = 0
	for slot in range(8):
		if alive_mask & (1 << slot):
			remaining += 1


func survivors() -> int:
	return _alive_mask


func advance(frame: int, ship_x: int) -> void:
	if frame in OPENING_CLOCK_HOLDS:
		return
	_wave_clock += 1
	if _wave_clock == SPAWN_FRAME:
		for index in range(8):
			var enemy := Enemy.new()
			enemy.alive = bool(_alive_mask & (1 << index))
			if wide_entry:
				enemy.position = Vector2i(120, 128)
				enemy.phase = Flight.ENTRY_CURVE
				_start_entry(enemy, index)
			else:
				enemy.position = INITIAL_POSITIONS[index >> 1]
				enemy.velocity = OPENING_STEPS[index >> 1]
			enemies.append(enemy)
		return
	if enemies.is_empty() or remaining == 0:
		return
	if _wave_clock & 1:
		return
	for enemy in enemies:
		if enemy.alive:
			_advance_enemy(enemy, ship_x + 8)


func hit_by(shot: Vector2i) -> Enemy:
	var bullet := shot + Vector2i(17, 4)
	if bullet.y < 12:
		return null
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not enemy.alive:
			continue
		var distance := bullet - enemy.position
		if distance.x >= 0 and distance.x < 16 and distance.y >= 0 and distance.y < 12:
			enemy.alive = false
			remaining -= 1
			_alive_mask &= ~(1 << index)
			if not wide_entry and not (index & 1):
				enemies[index + 1].separate_at = _wave_clock + 2
			return enemy
	return null


func hits_ship(ship_x: int, module := 1) -> bool:
	var raw_position := Vector2i(ship_x + 8, 192) if module == 1 else Vector2i(ship_x, 192 + (module - 1) * 8)
	const LEFT_LIMITS := [-9, -5, -10]
	const RIGHT_LIMITS := [11, 23, 28]
	var top := -11 if module == 3 else -3
	for enemy in enemies:
		if enemy.alive:
			var delta := enemy.position - raw_position
			if delta.x >= LEFT_LIMITS[module - 1] and delta.x <= RIGHT_LIMITS[module - 1] and delta.y >= top and delta.y <= 12:
				return true
	return false


func _advance_enemy(enemy: Enemy, ship: int) -> void:
	if enemy.separate_at > 0 and _wave_clock >= enemy.separate_at:
		enemy.separate_at = 0
		enemy.phase = Flight.FORMATION
		enemy.turns_left = 0
	if enemy.phase == Flight.OPENING:
		_move(enemy)
		enemy.opening_left -= 1
		if enemy.opening_left == 0:
			enemy.phase = Flight.FORMATION
		return

	var phase := enemy.phase
	if phase == Flight.STRAIGHT_DIVE:
		_move(enemy)
		_check_exit(enemy)
		return
	if enemy.turns_left == 0:
		match phase:
			Flight.FORMATION:
				if wide_entry:
					_start_wide_formation(enemy)
				else:
					_start_curve(enemy, 1, -1 if _wave_clock & 2 else 1, 30, 1, 2)
			Flight.DIVE:
				_start_dive(enemy, ship)
			Flight.RETURNING:
				enemy.position = Vector2i(120, 80)
				_return_pattern ^= 2
				if _return_pattern:
					_start_curve(enemy, 1, -enemy.turn, 47, 1, 1)
				else:
					_start_curve(enemy, 15, -enemy.turn, 31, 1, 1)
			Flight.CIRCLING:
				_start_curve(enemy, 15, -enemy.turn, 9, 3, 3)
	else:
		_step_curve(enemy)

	if (phase == Flight.ENTRY_CURVE or phase == Flight.RETURNING) and enemy.turns_left == 0:
		enemy.phase = Flight.CIRCLING
	if phase == Flight.CIRCLING and enemy.turns_left == 0:
		enemy.phase = Flight.FORMATION
	if phase != Flight.RETURNING and _check_exit(enemy):
		return
	if not wide_entry and phase == Flight.FORMATION and remaining < 5:
		enemy.phase = Flight.DIVE
		enemy.turns_left = 0


func _start_entry(enemy: Enemy, index: int) -> void:
	var turn := -1 if index & 1 else 1
	var pair := index >> 1
	const LENGTHS := [Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 4)]
	var length: Vector2i = LENGTHS[pair]
	_start_curve(enemy, 8 if turn > 0 else 22, turn, 9, length.x, length.y, 0, false, 4 if pair == 0 else 2)


func _start_wide_formation(enemy: Enemy) -> void:
	var occupied := false
	for other in enemies:
		if other.alive and other.phase == Flight.STRAIGHT_DIVE:
			occupied = true
			break
	if not occupied:
		enemy.phase = Flight.STRAIGHT_DIVE
		return
	_formation_pattern = (_formation_pattern + 6) & 6
	const STEPS := [Vector2i(2, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 2)]
	var length: Vector2i = STEPS[_formation_pattern >> 1]
	var turn := enemy.turn
	var heading := 8 if turn < 0 or _formation_pattern == 0 else 22
	_start_curve(enemy, heading, turn, 29, length.x, length.y)


func _check_exit(enemy: Enemy) -> bool:
	if enemy.position.y >= 8 and (enemy.position.x < 244 or enemy.position.x >= 252):
		return false
	enemy.phase = Flight.RETURNING
	enemy.turns_left = 0
	return true


func _start_dive(enemy: Enemy, ship: int) -> void:
	var x := enemy.position.x
	var y := enemy.position.y
	var turn := -enemy.turn
	var heading := 22 if turn > 0 else 8
	if x < ship - 32 or x >= ship + 32:
		var pattern := _next_dive_pattern(0, 14)
		const DURATIONS := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(4, 2),
			Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 4), Vector2i(2, 6)]
		var pace: Vector2i = DURATIONS[pattern >> 1]
		var acceleration := 1 if (pattern & 4) == 0 else -1
		_start_curve(enemy, heading, turn, 15, pace.x, pace.y, acceleration)
		return
	var region := 1
	var mask := 14
	if y >= 96 and y < 160:
		region = 2 if y < 128 else 3
		mask = 2
	var pattern := _next_dive_pattern(region, mask)
	if pattern < 4:
		_start_curve(enemy, heading, turn, 31, 4, 4, -1)
	else:
		_start_curve(enemy, heading, turn, 127, pattern >> 2, 1, 0, true)


func _next_dive_pattern(region: int, mask: int) -> int:
	var value: int = (_dive_patterns[region] + 6) & mask
	_dive_patterns[region] = value
	return value


func _start_curve(
		enemy: Enemy, heading: int, turn: int, turns: int, straight: int, diagonal: int,
		acceleration := 0, reverse_turn := false, cadence := 1
) -> void:
	enemy.heading = heading
	enemy.turn = turn
	enemy.turns_left = turns
	enemy.straight_steps = straight
	enemy.diagonal_steps = diagonal
	enemy.acceleration = acceleration
	enemy.reverse_turn = reverse_turn
	enemy.cadence = cadence
	enemy.cadence_left = cadence
	_change_heading(enemy)
	_move(enemy)


func _step_curve(enemy: Enemy) -> void:
	enemy.cadence_left -= 1
	if enemy.cadence_left > 0:
		return
	enemy.cadence_left = enemy.cadence
	enemy.steps_left -= 1
	if enemy.steps_left == 0:
		enemy.turns_left -= 1
		if enemy.turns_left == 0:
			return
		if enemy.reverse_turn and (enemy.turns_left & 7) == 2:
			enemy.turns_left -= 1
		enemy.heading = posmod(enemy.heading + enemy.turn - 1, HEADINGS.size()) + 1
		if enemy.reverse_turn and (enemy.turns_left & 15) == 0:
			enemy.turn = -enemy.turn
		if (enemy.turns_left & 7) == 0:
			enemy.straight_steps = maxi(1, enemy.straight_steps + enemy.acceleration)
			enemy.diagonal_steps = maxi(1, enemy.diagonal_steps + enemy.acceleration)
		_change_heading(enemy)
	_move(enemy)


func _change_heading(enemy: Enemy) -> void:
	enemy.velocity = HEADINGS[enemy.heading - 1]
	var straight := enemy.heading < 4 or (enemy.heading >= 11 and enemy.heading < 18) or enemy.heading >= 25
	enemy.steps_left = enemy.straight_steps if straight else enemy.diagonal_steps


func _move(enemy: Enemy) -> void:
	var next := enemy.position + enemy.velocity
	enemy.position = Vector2i(next.x & 255, next.y & 255)
