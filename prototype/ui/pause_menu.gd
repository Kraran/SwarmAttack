extends "res://ui/menu_screen.gd"

const LABELS := ["Reprendre", "Options", "Entraînement", "Accueil", "Quitter"]
const HOME := 3
const QUIT := 4
var active := false
var choice := 0
# Leaving the game in progress asks first: HOME or QUIT while the question is
# open (-1 otherwise). answer 0 = Yes, 1 = No; No is preselected.
var asking := -1
var answer := 1
# Set when the game paused itself because a controller went away.
var pad_lost := false


func render_state() -> Array:
	return [active, choice, asking, answer, pad_lost]


func toggle() -> void:
	active = not active
	pad_lost = false
	choice = 0
	asking = -1
	_navigation.reset()
	_audio.set_paused(active)
	_view._sync_menu_input()
	_view._redraw()


func info_rect() -> Rect2:
	var area := content_rect()
	return Rect2(area.position.x + 8, area.position.y, area.size.x - 16, 78)


func button_rect(index: int) -> Rect2:
	var area := content_rect()
	var width := minf(420.0, area.size.x - 40.0)
	var height := 52.0 if not portrait() else 48.0
	return Rect2(area.get_center().x - width / 2.0, area.position.y + 112 + index * (height + 14), width, height)


func ask(action: int) -> void:
	choice = action
	asking = action
	answer = 1
	_navigation.reset()
	_view._redraw()


func answer_rect(index: int) -> Rect2:
	var box := dialog_rect()
	var width := (box.size.x - 72.0) / 2.0
	return Rect2(box.position.x + 24 + index * (width + 24), box.end.y - 78, width, 52)


func dialog_rect() -> Rect2:
	var first := button_rect(1)
	var last := button_rect(4)
	return Rect2(first.position.x - 20, first.position.y - 6, first.size.x + 40, last.end.y - first.position.y + 12)


# The question takes every input until it is answered or cancelled.
func handle_question(event: InputEvent) -> void:
	if event.is_echo():
		return
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK]
			or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		cancel_question()
		return
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		answer_question()
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = _view._panel_point(event.position)
		for index in 2:
			if answer_rect(index).has_point(point):
				if index != answer:
					answer = index
					_view._redraw()
				if event is InputEventMouseButton:
					answer_question()
				return
		return
	var direction := _navigation.direction(event)
	if direction.x != 0 or direction.y != 0:
		answer = 1 - answer
		_view._redraw()


func cancel_question() -> void:
	asking = -1
	_navigation.reset()
	_view._redraw()


func answer_question() -> void:
	var action := asking
	if answer == 1:
		cancel_question()
		return
	asking = -1
	if action == HOME:
		_view._return_to_title()
	else:
		_view.get_tree().quit()


func handle_input(event: InputEvent) -> bool:
	if asking >= 0:
		handle_question(event)
		return true
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
	elif event is InputEventJoypadMotion:
		direction = _navigation.direction(event).y
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point: Vector2 = _view._panel_point(event.position)
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
		HOME, QUIT:
			ask(choice)


func draw(canvas: Node2D) -> void:
	sheet(canvas)
	var status := _translate("Entraînement") if _session.practice else _translate("Cycle %d · vague %d") % [_run.cycle, _view._cycle_wave()]
	header(canvas, _translate("PAUSE"), status)
	var info := info_rect()
	skin.panel(canvas, info)
	var columns := [
		[_translate("Score"), "%06d" % _run.score()],
		[_translate("Vies"), str(_run.lives)],
		[_translate("Joueur"), str(_session.player + 1)] if _session.runs.size() == 2 else [_translate("Cibles"), str(_run.combat.wave.remaining)],
	]
	for index in columns.size():
		var x := info.position.x + info.size.x * (index + 0.5) / columns.size()
		skin.text(canvas, Vector2(x, info.position.y + 24), skin.caps(columns[index][0]), skin.body_size(20), skin.c("accent"), 0, skin.detail_font)
		skin.text(canvas, Vector2(x, info.position.y + 54), columns[index][1], 16, skin.c("text"), 0, skin.score_font)
	if pad_lost:
		skin.text(canvas, Vector2(info.get_center().x, (info.end.y + button_rect(0).position.y) / 2.0),
			skin.caps(_translate("Manette déconnectée")), skin.body_size(24), skin.c("danger"), 0, skin.body_font, info.size.x)
	for index in range(LABELS.size()):
		skin.button(canvas, button_rect(index), _translate(LABELS[index]), row_state(index, choice), 34 if not portrait() else 30)
	if asking >= 0:
		draw_question(canvas)
		hints(canvas, [
			hint(["key:←", "key:→"], ["pad:◀▶"], "Choisir"),
			hint(["key:Entrée"], ["pad:A"], "Valider"),
			hint(["key:Échap"], ["pad:B"], "Annuler"),
		])
		return
	hints(canvas, [
		hint(["key:↑", "key:↓"], ["pad:✚"], "Choisir"),
		hint(["key:Entrée"], ["pad:A"], "Valider"),
		hint(["key:Échap"], ["pad:Start"], "Reprendre"),
	])


func draw_question(canvas: Node2D) -> void:
	var box := dialog_rect()
	# Shade the list behind, then the question in its own panel.
	canvas.draw_rect(box.grow(8), Color(skin.c("backdrop_edge"), 0.85))
	canvas.draw_rect(box, Color(skin.c("panel"), 1.0))
	skin.panel(canvas, box)
	var title := "Quitter la partie ?" if asking == QUIT else "Retour à l’accueil ?"
	skin.title(canvas, Vector2(box.get_center().x, box.position.y + 62), _translate(title), 46, 0, box.size.x - 40)
	skin.text(canvas, Vector2(box.get_center().x, box.position.y + 120), _translate("La partie en cours sera perdue."),
		skin.body_size(26), skin.c("muted"), 0, skin.detail_font, box.size.x - 40)
	for index in 2:
		skin.button(canvas, answer_rect(index), _translate(["Oui", "Non"][index]), row_state(index, answer), 32)
