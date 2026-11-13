extends RefCounted

const LEFT := 1
const RIGHT := 2
const FIRE := 4
const FRAME_USEC := 16_500
const FIELD_SIZE := Vector2i(224, 256)
const START_X := 112
const MIN_X := 14
const MAX_X := 200
const SHIP_Y := 200
const MOVE_STEP := 2
const SHOT_START_Y := 183
const SHOT_STEP := 4
const SHOT_LENGTH := 4

var frame := 0
var ship_x := START_X
var module: int
var shot_active := false
var shot_position := Vector2i.ZERO
var second_shot_active := false
var second_shot_position := Vector2i.ZERO
var _fire_held := false


func _init(module_number := 1, start_x := START_X) -> void:
	module = module_number
	ship_x = start_x


func ship_y() -> int:
	return SHIP_Y + (module - 1) * 8


func clear_shots() -> void:
	shot_active = false
	second_shot_active = false


func step(input_mask: int, accept_input := true) -> void:
	frame += 1
	var slot_was_busy := shot_active or second_shot_active
	if shot_active:
		shot_position.y -= SHOT_STEP
		shot_active = shot_position.y >= 0
	if second_shot_active:
		second_shot_position.y -= SHOT_STEP
		second_shot_active = second_shot_position.y >= 0
	if not accept_input:
		return
	if input_mask & LEFT:
		ship_x = maxi(MIN_X, ship_x - MOVE_STEP)
	elif input_mask & RIGHT:
		ship_x = mini(MAX_X, ship_x + MOVE_STEP)

	var fire := bool(input_mask & FIRE)
	if fire and not _fire_held and not slot_was_busy:
		var spread := 4 * module if module > 1 else 0
		const START_HEIGHTS := [SHOT_START_Y, 195, 204]
		shot_position = Vector2i(ship_x - 1 - spread, START_HEIGHTS[module - 1])
		shot_active = true
		if spread:
			second_shot_position = Vector2i(ship_x - 1 + spread, shot_position.y)
			second_shot_active = true
	_fire_held = fire
