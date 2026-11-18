extends RefCounted

const ACTIONS := [&"move_left", &"move_right", &"fire", &"pause"]
const LABELS := ["Déplacer à gauche", "Déplacer à droite", "Tirer / Freiner", "Pause"]
const DEFAULT_KEYS := {
	"move_left": [KEY_LEFT, KEY_Q, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"fire": [KEY_SPACE],
	"pause": [KEY_ESCAPE],
}
const DEFAULT_BUTTONS := {
	"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
	"fire": JOY_BUTTON_A, "pause": JOY_BUTTON_START,
}
const RESERVED_KEYS := [KEY_R, KEY_T, KEY_2, KEY_KP_2, KEY_F1, KEY_F2, KEY_F3,
	KEY_F4, KEY_F5, KEY_F10, KEY_F11]
const RESERVED_BUTTONS := [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_BACK]


static func valid_key(code: int, action: StringName) -> bool:
	return (code > 0 and not code in RESERVED_KEYS and (code != KEY_ESCAPE or action == &"pause")
		and not OS.get_keycode_string(code).is_empty())


static func valid_button(code: int) -> bool:
	return code >= 0 and code < JOY_BUTTON_MAX and not code in RESERVED_BUTTONS


static func read_keys(stored: Variant) -> Dictionary:
	var fallback := DEFAULT_KEYS.duplicate(true)
	if not stored is Dictionary:
		return fallback
	var result := {}
	var used: Array[int] = []
	for action in ACTIONS:
		var keys: Variant = stored.get(String(action), [])
		if not keys is Array or keys.is_empty() or keys.size() > 3:
			return fallback
		for key in keys:
			if not key is int or not valid_key(key, action) or used.has(key):
				return fallback
			used.append(key)
		result[String(action)] = keys.duplicate()
	return result


static func read_buttons(stored: Variant) -> Dictionary:
	var fallback := DEFAULT_BUTTONS.duplicate()
	if not stored is Dictionary:
		return fallback
	var result := {}
	var used: Array[int] = []
	for action in ACTIONS:
		var button: Variant = stored.get(String(action), -1)
		if not button is int or not valid_button(button) or used.has(button):
			return fallback
		used.append(button)
		result[String(action)] = button
	return result


static func assign_key(bindings: Dictionary, action: StringName, key: int) -> bool:
	if not valid_key(key, action):
		return false
	var previous: Array = bindings[String(action)].duplicate()
	for other in ACTIONS:
		if other != action and bindings[String(other)].has(key):
			for old_key in previous:
				if not valid_key(old_key, other):
					return false
	for other in ACTIONS:
		if other != action and bindings[String(other)].has(key):
			bindings[String(other)] = previous
	bindings[String(action)] = [key]
	return true


static func assign_button(bindings: Dictionary, action: StringName, button: int) -> void:
	var previous: int = bindings[String(action)]
	for other in ACTIONS:
		if other != action and bindings[String(other)] == button:
			bindings[String(other)] = previous
	bindings[String(action)] = button


static func apply(keys: Dictionary, buttons: Dictionary) -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		InputMap.action_erase_events(action)
		for code in keys[String(action)]:
			var key := InputEventKey.new()
			key.keycode = code
			InputMap.action_add_event(action, key)
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = buttons[String(action)]
		InputMap.action_add_event(action, button)
		if action in [&"move_left", &"move_right"]:
			var stick := InputEventJoypadMotion.new()
			stick.device = -1
			stick.axis = JOY_AXIS_LEFT_X
			stick.axis_value = -1.0 if action == &"move_left" else 1.0
			InputMap.action_add_event(action, stick)


static func key_name(code: int) -> String:
	match code:
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_SPACE: return "Espace"
		KEY_ESCAPE: return "Échap"
		KEY_ENTER, KEY_KP_ENTER: return "Entrée"
	return OS.get_keycode_string(code)


static func button_label(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_DPAD_LEFT: return "←"
		JOY_BUTTON_DPAD_RIGHT: return "→"
		JOY_BUTTON_DPAD_UP: return "↑"
		JOY_BUTTON_DPAD_DOWN: return "↓"
	return "#%d" % (button + 1)
