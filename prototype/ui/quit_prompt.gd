extends "res://ui/menu_screen.gd"

# « Quitter le jeu ? » opened from anywhere outside play by Xbox (Guide) + Start.
# During play the same combination pauses the game and asks through the pause
# menu instead. No is preselected; Yes closes the game.
var opened := false
var answer := 1


func render_state() -> Array:
	return [opened, answer]


# True when this event completes the Guide + Start combination on its gamepad.
static func is_combo(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton and event.pressed):
		return false
	if event.button_index == JOY_BUTTON_START:
		return Input.is_joy_button_pressed(event.device, JOY_BUTTON_GUIDE)
	if event.button_index == JOY_BUTTON_GUIDE:
		return Input.is_joy_button_pressed(event.device, JOY_BUTTON_START)
	return false


func open() -> void:
	opened = true
	answer = 1
	_navigation.reset()
	_audio.set_paused(true)
	_view._sync_menu_input()
	_view._redraw()


func close() -> void:
	opened = false
	_navigation.reset()
	_audio.set_paused(_view._pause.active or _view._options.opened or _view._training.opened)
	_view._sync_menu_input()
	_view._redraw()


func dialog_rect() -> Rect2:
	var area := content_rect()
	var width := minf(520.0, area.size.x - 16.0)
	return Rect2(area.get_center().x - width / 2.0, area.position.y + 96, width, 270)


func answer_rect(index: int) -> Rect2:
	var box := dialog_rect()
	var width := (box.size.x - 72.0) / 2.0
	return Rect2(box.position.x + 24 + index * (width + 24), box.end.y - 78, width, 52)


func handle_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK]
			or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		close()
		return
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		confirm()
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = _view._panel_point(event.position)
		for index in 2:
			if answer_rect(index).has_point(point):
				if index != answer:
					answer = index
					_view._redraw()
				if event is InputEventMouseButton:
					confirm()
				return
		return
	var direction := _navigation.direction(event)
	if direction.x != 0 or direction.y != 0:
		answer = 1 - answer
		_view._redraw()


func confirm() -> void:
	if answer == 1:
		close()
	else:
		_view.get_tree().quit()


func draw(canvas: Node2D) -> void:
	# Dim whatever menu is underneath, then ask in an opaque panel.
	var area: Rect2 = _view.PORTRAIT_FIELD.grow(4)
	if not portrait():
		# The panel side, out to the screen edge (wide screens included).
		area = PANEL.grow_individual(2000.0 if _view._menu_left() else 0.0, 400.0, 0.0 if _view._menu_left() else 2000.0, 400.0)
	canvas.draw_rect(area, Color(skin.c("backdrop_edge"), 0.82))
	var box := dialog_rect()
	canvas.draw_rect(box, Color(skin.c("panel"), 1.0))
	skin.panel(canvas, box)
	skin.title(canvas, Vector2(box.get_center().x, box.position.y + 62), _translate("Quitter le jeu ?"), 46, 0, box.size.x - 40)
	skin.text(canvas, Vector2(box.get_center().x, box.position.y + 120), _translate("Le jeu va se fermer."),
		skin.body_size(26), skin.c("muted"), 0, skin.detail_font, box.size.x - 40)
	for index in 2:
		skin.button(canvas, answer_rect(index), _translate(["Oui", "Non"][index]), row_state(index, answer), 32)
	hints(canvas, [
		hint(["key:←", "key:→"], ["pad:◀▶"], "Choisir"),
		hint(["key:Entrée"], ["pad:A"], "Valider"),
		hint(["key:Échap"], ["pad:B"], "Annuler"),
	])
