extends "res://ui/menu_screen.gd"

var opened := false
var result_open := false
var from_options := false
var return_result := false
var choice := 0
var kind := TrainingSession.Kind.WAVE
var target := 1
var difficulty := ArcadeProfile.Difficulty.NORMAL


func render_state() -> Array:
	return [opened, result_open, choice, kind, target, difficulty]


func open_menu(via_options := false) -> void:
	return_result = result_open
	result_open = false
	from_options = via_options
	if not return_result and not _attract_active and not _paused:
		_view._pause.toggle()
	if not _attract_active and _session.practice:
		kind = _view._exercise_kind
		target = _view._exercise_target
		difficulty = _view._exercise_difficulty
	else:
		difficulty = _profile.difficulty
	opened = true
	_view._options.opened = false
	choice = 0
	_navigation.reset()
	_audio.set_paused(true)
	_view._pressed = 0
	_view._redraw()


func close_menu() -> void:
	opened = false
	if return_result:
		result_open = true
		choice = 1
	elif from_options:
		_view._options.set_open(true)
		_view._options.choice = _view.OptionsMenu.TRAINING
	_audio.set_paused(_paused or _view._options.opened)
	_view._sync_menu_input()
	_view._redraw()


func row_rect(index: int, result := false) -> Rect2:
	var area := content_rect()
	if result:
		var width := minf(440.0, area.size.x - 40.0)
		return Rect2(area.get_center().x - width / 2.0, area.position.y + 200 + 64 * index, width, 50)
	if index == 3:
		return Rect2(area.position.x + 40, area.position.y + 200, area.size.x - 80, 62)
	if index == 4:
		return Rect2(area.position.x + 70, area.position.y + 280, area.size.x - 140, 48)
	return Rect2(area.position.x + 8, area.position.y + 4 + 60 * index, area.size.x - 16, 50)


func handle_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_F2]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		close_menu()
		return
	var direction := _navigation.direction(event)
	if direction.y != 0:
		choice = posmod(choice + direction.y, 5)
		_view._redraw()
	elif direction.x != 0:
		adjust(direction.x)
	elif (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		confirm()
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point: Vector2 = _view._panel_point(event.position)
		for index in 5:
			if row_rect(index).has_point(point):
				choice = index
				if event is InputEventMouseButton:
					if index < 3:
						adjust(-1 if point.x < row_rect(index).get_center().x else 1)
					else:
						confirm()
				_view._redraw()
				return


func adjust(direction: int) -> void:
	match choice:
		0:
			kind = TrainingSession.Kind.DOCKING if kind == TrainingSession.Kind.WAVE else TrainingSession.Kind.WAVE
			target = 1
		1:
			target = 1 + posmod(target - 1 + direction,
				10 if kind == TrainingSession.Kind.WAVE else 2)
		2:
			difficulty = ArcadeProfile.Difficulty.VETERANS if difficulty == ArcadeProfile.Difficulty.NORMAL else ArcadeProfile.Difficulty.NORMAL
	_view._redraw()


func confirm() -> void:
	if choice < 3:
		adjust(1)
	elif choice == 3:
		_view._exercise_kind = kind
		_view._exercise_target = target
		_view._exercise_difficulty = difficulty
		_view._restart(true)
	else:
		close_menu()


func handle_result_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_R, KEY_F2]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
		_view._restart(true)
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		open_menu()
		return
	var direction := _navigation.direction(event)
	if direction.y != 0:
		choice = posmod(choice + direction.y, 3)
		_view._redraw()
	elif (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		confirm_result()
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point: Vector2 = _view._panel_point(event.position)
		for index in 3:
			if row_rect(index, true).has_point(point):
				choice = index
				if event is InputEventMouseButton:
					confirm_result()
				_view._redraw()
				return


func confirm_result() -> void:
	match choice:
		0: _view._restart(true)
		1: open_menu()
		2: _view._return_to_title()


func target_label(kind: int, target: int) -> String:
	if kind == TrainingSession.Kind.WAVE:
		return _translate("Vague %d") % target
	return _translate("Amarrage %s") % ("I → II" if target == 1 else "I + II → III")


func draw(canvas: Node2D) -> void:
	sheet(canvas)
	header(canvas, _translate("Entraînement"), _translate("Scores hors classement"))
	var rows := [
		[_translate("Exercice"), _translate("Vague" if kind == TrainingSession.Kind.WAVE else "Amarrage")],
		[_translate("Cible"), target_label(kind, target)],
		[_translate("Difficulté"), _translate(ArcadeProfile.DIFFICULTY_LABELS[difficulty])],
	]
	for index in rows.size():
		var rect := row_rect(index)
		var state := row_state(index, choice)
		skin.button_frame(canvas, rect, state)
		var ink := skin.c("focus_text") if state == 2 else skin.c("button_text")
		var y := rect.get_center().y + 1
		skin.text(canvas, Vector2(rect.position.x + rect.size.y * skin.skew + 22, y), skin.caps(rows[index][0]), skin.body_size(30), ink, -1)
		var right := rect.end.x - 26
		var width := skin.text(canvas, Vector2(right - 22, y), skin.caps(rows[index][1]), skin.body_size(30), ink, 1)
		skin.arrow(canvas, Vector2(right - 4, y), 1, 14, ink)
		skin.arrow(canvas, Vector2(right - width - 40, y), -1, 14, ink)
	skin.button(canvas, row_rect(3), _translate("Démarrer"), row_state(3, choice), 40)
	skin.button(canvas, row_rect(4), _translate("Retour"), row_state(4, choice), 30)
	hints(canvas, [
		hint(["key:↑", "key:↓"], ["pad:✚"], "Choisir"),
		hint(["key:←", "key:→"], ["pad:◀▶"], "Régler"),
		hint(["key:Entrée"], ["pad:A"], "Valider"),
		hint(["key:Échap"], ["pad:B"], "Retour"),
	])


func draw_result(canvas: Node2D) -> void:
	sheet(canvas)
	var training := _session as TrainingSession
	header(canvas, _translate("Entraînement"), _exercise_label())
	var area := content_rect()
	var message := "Vague terminée" if training.success else "Vaisseau perdu"
	if training.kind == TrainingSession.Kind.DOCKING:
		message = "Amarrage réussi" if training.success else "Amarrage manqué"
	var box := Rect2(area.position.x + 8, area.position.y + 8, area.size.x - 16, 160)
	skin.panel(canvas, box)
	skin.title(canvas, Vector2(box.get_center().x, box.position.y + 52), _translate(message), 52, 0, box.size.x - 40)
	var points := _run.score() if training.kind == TrainingSession.Kind.WAVE else _run.docking.bonus
	skin.text(canvas, Vector2(box.get_center().x, box.position.y + 112), "%06d" % points, 22,
		skin.c("success") if training.success else skin.c("danger"), 0, skin.score_font)
	var labels := [_translate("Réessayer"), _translate("Choisir un exercice"), _translate("Accueil")]
	for index in labels.size():
		skin.button(canvas, row_rect(index, true), labels[index], row_state(index, choice), 32)
	hints(canvas, [
		hint(["key:R"], ["pad:Y"], "Réessayer"),
		hint(["key:Entrée"], ["pad:A"], "Valider"),
		hint(["key:Échap"], ["pad:B"], "Exercices"),
	])
