extends RefCounted

# Shared axis latch: release below 0.4, new navigation at 0.65.
var _stick := Vector2i.ZERO

func reset() -> void:
	_stick = Vector2i.ZERO

func direction(event: InputEvent) -> Vector2i:
	if event is InputEventKey and event.pressed:
		return Vector2i(int(event.keycode == KEY_RIGHT) - int(event.keycode == KEY_LEFT),
			int(event.keycode == KEY_DOWN) - int(event.keycode == KEY_UP))
	if event is InputEventJoypadButton and event.pressed:
		return Vector2i(int(event.button_index == JOY_BUTTON_DPAD_RIGHT) - int(event.button_index == JOY_BUTTON_DPAD_LEFT),
			int(event.button_index == JOY_BUTTON_DPAD_DOWN) - int(event.button_index == JOY_BUTTON_DPAD_UP))
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var axis := int(event.axis == JOY_AXIS_LEFT_Y)
		if absf(event.axis_value) < 0.4:
			_stick[axis] = 0
		elif absf(event.axis_value) >= 0.65:
			var tilt := int(signf(event.axis_value))
			if tilt != _stick[axis]:
				_stick[axis] = tilt
				return Vector2i(tilt, 0) if axis == 0 else Vector2i(0, tilt)
	return Vector2i.ZERO
