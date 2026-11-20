extends "res://ui/menu_screen.gd"

# Routes modal input before gameplay controls, preserving the original priority.
const QuitPrompt = preload("res://ui/quit_prompt.gd")

func handle_input(event: InputEvent) -> bool:
	_track_device(event)
	if event is InputEventMouseMotion:
		_view._last_mouse_motion_usec = Time.get_ticks_usec()
		_view._update_cursor()
		_view._update_logo_hover(event.position)
	if not _focused:
		return true
	if QuitPrompt.is_combo(event):
		_view._ask_quit()
		return true
	if _view._quit_prompt.opened:
		_view._quit_prompt.handle_input(event)
		return true
	if _view._intro_active():
		# Any key, button or click skips the intro without starting a game.
		if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
			_view.finish_intro()
			_view._wait_for_fire_release = true
		return true
	if _view._about_is_open():
		if _view._about.handle_input(event):
			_view.get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _view._logo_contains(event.position):
		_view._open_about()
		_view.get_viewport().set_input_as_handled()
		return true
	if _view._scores.entry != null:
		_view._scores.handle_entry_input(event)
		return true
	if event.is_echo():
		return true
	if _view._training.opened:
		_view._training.handle_input(event)
		return true
	if _view._training.result_open:
		_view._training.handle_result_input(event)
		return true
	if _view._scores.results_open or _view._scores.tables_open:
		_view._scores.handle_results_input(event)
		return true
	if _view._options.opened:
		_view._options.handle_input(event)
		return true
	if _view._pause.active and _view._pause.handle_input(event):
		return true
	if _attract_active and not _view._scores.results_open and not _view._scores.tables_open and _view._title.handle_input(event):
		return true
	if not _attract_active and event.is_action_pressed(&"pause"):
		_view._pause.toggle()
		return true
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_view._restart(not _attract_active and _session.practice, _session.runs.size() if not _attract_active else 1)
				return true
			KEY_F2:
				if not _attract_active and _session.practice:
					_view._restart(true)
				else:
					_view._training.open_menu()
				return true
			KEY_2, KEY_KP_2:
				if _attract_active:
					_view._restart(false, 2)
				return true
			KEY_ESCAPE:
				if not _attract_active:
					_view._pause.toggle()
				else:
					_view.get_tree().quit()
				return true
			KEY_T:
				if _view._pause.active:
					_view._pause.ask(_view._pause.HOME)
				return true
			KEY_F3:
				if _attract_active or _view._pause.active:
					_view._options.set_open(true)
				return true
			KEY_F4:
				if _attract_active:
					_view._scores.open()
				return true
			KEY_F5:
				_profile.muted = not _profile.muted
				_audio.set_muted(_profile.muted)
				_view._save_profile()
				return true
			KEY_F10:
				_profile.portrait = not _profile.portrait
				_view._apply_display()
				_view._save_profile()
				return true
			KEY_F11:
				_profile.fullscreen = not _profile.fullscreen
				_view._apply_display()
				_view._save_profile()
				return true
			KEY_F1:
				_view._diagnostics = not _view._diagnostics
				if _view._starfield != null:
					_view._starfield.visible = not _view._diagnostics
				_view._redraw()
				return true
	if event is InputEventJoypadButton and event.pressed:
		if not _attract_active and _session.practice and event.button_index == JOY_BUTTON_Y:
			_view._restart(true)
			return true
		if _attract_active and event.button_index == JOY_BUTTON_BACK:
			_view._scores.open()
			return true
		if (_attract_active or _view._pause.active) and event.button_index == JOY_BUTTON_X:
			_view._options.set_open(true)
			return true
		if _attract_active and event.button_index == JOY_BUTTON_Y:
			_view._restart(false, 2)
			return true
		if _view._pause.active and event.button_index == JOY_BUTTON_START:
			_view._pause.toggle()
			return true
		if _view._pause.active and event.button_index == JOY_BUTTON_B:
			_view._pause.ask(_view._pause.HOME)
			return true
	if _attract_active and _profile.portrait and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _view.TitleMenu.PORTRAIT_TRAINING_BUTTON.has_point(event.position):
				_view._training.open_menu()
				return true
			if _view.TitleMenu.PORTRAIT_SCORES_BUTTON.has_point(event.position):
				_view._scores.open()
				return true
			if _view.TitleMenu.PORTRAIT_OPTIONS_BUTTON.has_point(event.position):
				_view._options.set_open(true)
				return true
	return false


# Hints follow the last device that produced a deliberate input; the pad
# that last did so is the one in play (-1: keyboard or mouse).
func _track_device(event: InputEvent) -> void:
	var pad: bool = _view._pad_hints
	if event is InputEventJoypadButton and event.pressed:
		pad = true
		_view._play_pad = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.65:
		pad = true
		_view._play_pad = event.device
	elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed:
		pad = false
		_view._play_pad = -1
	if pad != _view._pad_hints:
		_view._pad_hints = pad
		_view._redraw()
