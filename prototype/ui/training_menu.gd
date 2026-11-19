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
	return Rect2(33, (137 if result else 65) + 27 * index, 158, 22)


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
		var point := _field_input_position(event.position)
		for index in 5:
			if row_rect(index).has_point(point):
				choice = index
				if event is InputEventMouseButton:
					if index < 3:
						adjust(-1 if point.x < 112 else 1)
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
		var point := _field_input_position(event.position)
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
	var panel := Rect2(23, 36, 178, 169)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	_field_text(canvas, 112, 53, _translate("Entraînement").to_upper(), SHOT, 11)
	var labels := [
		"%s · %s" % [_translate("Exercice"), _translate("Vague" if kind == TrainingSession.Kind.WAVE else "Amarrage")],
		"‹  %s  ›" % target_label(kind, target),
		"%s · %s" % [_translate("Difficulté"), _translate(ArcadeProfile.DIFFICULTY_LABELS[difficulty])],
		_translate("Démarrer"), _translate("Retour"),
	]
	for index in labels.size():
		_draw_score_action(canvas, row_rect(index), labels[index], index == choice)
	_field_text(canvas, 112, 221, _translate("Scores hors classement"), MUTED, 7)
	_field_text(canvas, 112, 238, _translate("← → ou clic pour régler"), MUTED, 7)


func draw_result(canvas: Node2D) -> void:
	var training := _session as TrainingSession
	var panel := Rect2(23, 36, 178, 192)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	_field_text(canvas, 112, 54, _translate("Entraînement"), SHOT, 12)
	_field_text(canvas, 112, 76, _exercise_label(), MUTED, 9)
	var message := "Vague terminée" if training.success else "Vaisseau perdu"
	if training.kind == TrainingSession.Kind.DOCKING:
		message = "Amarrage réussi" if training.success else "Amarrage manqué"
	_field_text(canvas, 112, 101, _translate(message), SHIP if training.success else ARCADE_RED, 11)
	var points := _run.score() if training.kind == TrainingSession.Kind.WAVE else _run.docking.bonus
	_field_text(canvas, 112, 121, _translate("Score %d") % points, PRIMARY, 9)
	var labels := [_translate("Réessayer") + " · R / Y", _translate("Choisir un exercice"), _translate("Accueil")]
	for index in labels.size():
		_draw_score_action(canvas, row_rect(index, true), labels[index], index == choice)
	_field_text(canvas, 112, 244, _translate("Scores hors classement"), MUTED, 7)
