extends RefCounted

const Pilot = preload("res://pilot.gd")
const TARGET := Vector2i(112, 216)
const LIFT_WAIT := 48
const LIFT_HEIGHT := 76
const TARGET_ARRIVAL := 200
const BOARD_FRAMES_PER_CONTROL := 4
const BONUS_HOLD := 305

enum Stage { INTRO, APPROACH, SUCCESS, COLLISION, TIMED_OUT }

class Axis:
	var velocity: int
	var wait := 0

	func _init(initial_velocity: int) -> void:
		velocity = initial_velocity

	func step(acceleration: int) -> int:
		velocity = clampi(velocity + acceleration, 64, 192)
		if wait > 0:
			wait -= 1
			return 0
		var speed := velocity if velocity < 128 else 256 - velocity
		wait = (speed - 64) >> 5
		return 1 if velocity < 128 else -1

var module: int
var position: Vector2i
var target_y := 256
var stage := Stage.INTRO
var bonus := 0
var remaining_tenths := 300
var _elapsed := 0
var _result_frames := 0
var _horizontal := Axis.new(128)
var _vertical := Axis.new(120)


func _init(approaching_module: int, ship_x: int, show_intro := true) -> void:
	module = approaching_module
	position = Vector2i(ship_x + (8 if module == 1 else 0), 192 if module == 1 else 200)
	if not show_intro:
		position.y -= LIFT_HEIGHT
		_release()


func display_position() -> Vector2:
	return Vector2(position.x - (8 if module == 1 else 0), position.y + 8)


func display_clock() -> String:
	if stage == Stage.INTRO:
		return "30:0"
	var seconds := maxi(0, (remaining_tenths - 1) / 10)
	return "%02d:%d" % [seconds, remaining_tenths % 10]


func credited_bonus() -> int:
	return bonus if _result_frames >= BONUS_HOLD else 0


func step(input_mask: int) -> void:
	if stage == Stage.INTRO:
		_advance_intro()
	elif stage == Stage.APPROACH:
		var phase := _elapsed % BOARD_FRAMES_PER_CONTROL
		if phase == 0:
			_advance_approach(input_mask)
		elif phase == 1:
			# The board counts the clock down on the frame after each control tick.
			remaining_tenths -= 1
		_elapsed += 1
	else:
		_result_frames += 1


func _advance_intro() -> void:
	_elapsed += 1
	var lift_end := LIFT_WAIT + LIFT_HEIGHT * BOARD_FRAMES_PER_CONTROL
	if _elapsed <= lift_end:
		if _elapsed > LIFT_WAIT and _elapsed % BOARD_FRAMES_PER_CONTROL == 0:
			position.y -= 1
	else:
		target_y = maxi(TARGET.y, 256 - ((_elapsed - lift_end) >> 2))
		if _elapsed >= lift_end + TARGET_ARRIVAL:
			_release()


func _release() -> void:
	stage = Stage.APPROACH
	target_y = TARGET.y
	_elapsed = 0


func _advance_approach(input_mask: int) -> void:
	if remaining_tenths <= 1:
		remaining_tenths = 0
		stage = Stage.TIMED_OUT
		return
	var steer := 0
	if input_mask & Pilot.LEFT:
		steer = 1
	elif input_mask & Pilot.RIGHT:
		steer = -1
	var bounds_offset := 8 if module == 1 else 16
	position.x = clampi(position.x + _horizontal.step(steer), 31 - bounds_offset, 216 - bounds_offset)
	var thrust := 1 if input_mask & Pilot.FIRE else -1
	position.y = clampi(position.y + _vertical.step(thrust), 47 - bounds_offset, 240 - bounds_offset)
	_resolve_contact()


func _resolve_contact() -> void:
	var offset := position - TARGET
	var crash_area := Rect2i(-8, -3, 34, 8) if module == 1 else Rect2i(-25, -11, 52, 16)
	var capture_area := Rect2i(3, -6, 12, 8) if module == 1 else Rect2i(-5, -14, 12, 16)
	if crash_area.has_point(offset):
		stage = Stage.COLLISION
	elif capture_area.has_point(offset):
		position = TARGET + (Vector2i(8, -8) if module == 1 else Vector2i(0, -16))
		bonus = ((remaining_tenths - 1) / 10) * module * 100
		stage = Stage.SUCCESS
