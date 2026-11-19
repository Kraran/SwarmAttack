extends "res://ui/menu_screen.gd"

const LABELS := ["Reprendre", "Options", "Entraînement", "Accueil", "Quitter"]
const BUTTON := Rect2(52, 107, 120, 17)
const SPACING := 20.0
var active := false
var choice := 0


func render_state() -> Array:
	return [active, choice]


func toggle() -> void:
	active = not active
	choice = 0
	_audio.set_paused(active)
	_view._sync_menu_input()
	_view._redraw()


func button_rect(index: int) -> Rect2:
	return Rect2(BUTTON.position + Vector2(0, SPACING * index), BUTTON.size)


func handle_input(event: InputEvent) -> bool:
	var direction := 0
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			confirm()
			return true
		direction = int(event.keycode == KEY_DOWN) - int(event.keycode == KEY_UP)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			confirm()
			return true
		direction = int(event.button_index == JOY_BUTTON_DPAD_DOWN) - int(event.button_index == JOY_BUTTON_DPAD_UP)
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point := _field_input_position(event.position)
		for index in range(LABELS.size()):
			if button_rect(index).has_point(point):
				choice = index
				_view._redraw()
				if event is InputEventMouseButton:
					confirm()
				return true
	if direction != 0:
		choice = posmod(choice + direction, LABELS.size())
		_view._redraw()
		return true
	return false


func confirm() -> void:
	match choice:
		0:
			toggle()
		1:
			_view._options.set_open(true)
		2:
			_view._training.open_menu()
		3:
			_view._return_to_title()
		4:
			_view.get_tree().quit()


func draw(canvas: Node2D) -> void:
	var panel := Rect2(43, 83, 138, 128)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	_field_text(canvas, 112, 100, _translate("PAUSE"), PRIMARY, 11)
	for index in range(LABELS.size()):
		var button := button_rect(index)
		var selected := index == choice
		canvas.draw_rect(button, GRID if selected else BACKGROUND)
		canvas.draw_rect(button, SHOT if selected else BORDER, false, 0.5)
		_field_text(canvas, 112, button.position.y + 11.5, _translate(LABELS[index]), SHOT if selected else PRIMARY, 8)
