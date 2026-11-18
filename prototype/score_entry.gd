extends RefCounted

const Profile = preload("res://arcade_profile.gd")
const REPEAT_DELAY := 0.35
const REPEAT_INTERVAL := 0.08
const DIRECTIONS := {
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
	JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
}

enum Result { NONE, CHANGED, SAVE, SKIP }

var initials := "AAA"
var cursor := 0
var save_failed := false
var _stick := Vector2i.ZERO
var _dpad := Vector2i.ZERO
var _held := Vector2i.ZERO
var _repeat_in := 0.0
var _device := -1


func handle(event: InputEvent) -> Result:
	if event is InputEventKey and event.pressed:
		return _key(event)
	if event is InputEventJoypadButton:
		if DIRECTIONS.has(event.button_index):
			_use_pad(event.device)
			var direction: Vector2i = DIRECTIONS[event.button_index]
			var axis := int(direction.x == 0)
			if event.pressed or _dpad[axis] == direction[axis]:
				_dpad[axis] = direction[axis] if event.pressed else 0
			return _pad_move()
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_START:
					return Result.SAVE
				JOY_BUTTON_A:
					if cursor == 2:
						return Result.SAVE
					cursor += 1
					return Result.CHANGED
				JOY_BUTTON_B:
					if cursor == 0:
						return Result.SKIP
					cursor -= 1
					return Result.CHANGED
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		_use_pad(event.device)
		var axis := int(event.axis == JOY_AXIS_LEFT_Y)
		if absf(event.axis_value) < 0.4:
			_stick[axis] = 0
		elif absf(event.axis_value) >= 0.65:
			_stick[axis] = int(signf(event.axis_value))
		return _pad_move()
	return Result.NONE


func repeat(delta: float) -> bool:
	if _held == Vector2i.ZERO:
		return false
	_repeat_in -= delta
	if _repeat_in > 0.0:
		return false
	_repeat_in = REPEAT_INTERVAL
	_move(_held)
	return true


func release_pad(device := -1) -> void:
	if device == -1 or device == _device:
		_device = -1
		_dpad = Vector2i.ZERO
		_stick = Vector2i.ZERO
		_held = Vector2i.ZERO


func _key(event: InputEventKey) -> Result:
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			return Result.NONE if event.echo else Result.SAVE
		KEY_ESCAPE:
			return Result.NONE if event.echo else Result.SKIP
		KEY_BACKSPACE:
			cursor = maxi(0, cursor - 1)
		KEY_LEFT:
			_move(Vector2i.LEFT)
		KEY_RIGHT:
			_move(Vector2i.RIGHT)
		KEY_UP:
			_move(Vector2i.UP)
		KEY_DOWN:
			_move(Vector2i.DOWN)
		_:
			if event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.unicode == 0:
				return Result.NONE
			var letter := String.chr(event.unicode).to_upper()
			if letter.length() != 1 or not Profile.INITIALS_ALPHABET.contains(letter):
				return Result.NONE
			_set_letter(letter)
			cursor = mini(2, cursor + 1)
	return Result.CHANGED


func _use_pad(device: int) -> void:
	if device != _device:
		release_pad()
		_device = device


func _pad_move() -> Result:
	var direction := _dpad if _dpad != Vector2i.ZERO else _stick
	if direction == _held:
		return Result.NONE
	_held = direction
	if _held == Vector2i.ZERO:
		return Result.NONE
	_repeat_in = REPEAT_DELAY
	_move(_held)
	return Result.CHANGED


func _move(direction: Vector2i) -> void:
	cursor = posmod(cursor + direction.x, 3)
	if direction.y != 0:
		var alphabet := Profile.INITIALS_ALPHABET
		var index := alphabet.find(initials[cursor])
		_set_letter(alphabet[posmod(index - direction.y, alphabet.length())])


func _set_letter(letter: String) -> void:
	initials = initials.left(cursor) + letter + initials.substr(cursor + 1)
