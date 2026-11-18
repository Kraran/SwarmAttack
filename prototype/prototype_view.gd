extends Node2D

const Pilot = preload("res://pilot.gd")
const ArcadeRun = preload("res://arcade_run.gd")
const Docking = preload("res://docking.gd")
const Attract = preload("res://attract.gd")
const FlightView = preload("res://flight_view.gd")
const Starfield = preload("res://starfield.gd")
const FlightMotion = preload("res://flight_motion.gd")
const Presentation = preload("res://flight_presentation.gd")
const CombatWave = preload("res://combat_wave.gd")
const ArcadeAudio = preload("res://arcade_audio.gd")
const ArcadeProfile = preload("res://arcade_profile.gd")
const Controls = preload("res://arcade_controls.gd")
const ScoreEntry = preload("res://score_entry.gd")
const TITLE_LOGO = preload("res://art/swarm_attack_logo.png")
const LOGO_SHADER = preload("res://logo.gdshader")
const Language = preload("res://arcade_language.gd")
const ArcadeSession = preload("res://arcade_session.gd")
const TrainingSession = preload("res://training_session.gd")
const Effects = preload("res://arcade_effects.gd")
const AboutPanel = preload("res://about_panel.gd")
const SHIP_BURST_FRAMES := 36
const MAX_CATCHUP_USEC := 8 * Pilot.FRAME_USEC
const CURSOR_HIDE_USEC := 3_000_000
const LANDSCAPE_SIZE := Vector2i(1280, 720)
const PORTRAIT_SIZE := Vector2i(560, 780)
const FULL_HD := Vector2i(1920, 1080)
const FIELD := Rect2(124, 24, 504, 672)
const PORTRAIT_FIELD := Rect2(28, 65, 504, 672)
const LABEL_X := 704
const PANEL_END := 1156
const HEADER_LOGO := Rect2(LABEL_X, 0, 224, 126)
const PORTRAIT_HEADER_LOGO := Rect2(83, 0, 100, 56.25)
const SOLO_BUTTON := Rect2(LABEL_X, 468, PANEL_END - LABEL_X, 50)
const DUO_BUTTON := Rect2(LABEL_X, 529, PANEL_END - LABEL_X, 45)
const OPTIONS_BUTTON := Rect2(LABEL_X, 588, PANEL_END - LABEL_X, 42)
const PORTRAIT_OPTIONS_BUTTON := Rect2(312, 17, 220, 34)
const SCORES_BUTTON := Rect2(LABEL_X, 308, 216, 42)
const TRAINING_BUTTON := Rect2(LABEL_X + 232, 308, 220, 42)
const PORTRAIT_SCORES_BUTTON := Rect2(28, 740, 244, 30)
const PORTRAIT_TRAINING_BUTTON := Rect2(288, 740, 244, 30)
const OPTIONS_LANGUAGE := 2
const OPTIONS_AUDIO := 3
const OPTIONS_DISPLAY := 4
const OPTIONS_CONTROLS := 5
const OPTIONS_TRAINING := 6
const OPTIONS_BACK := 7
enum OptionsPage { MAIN, LANGUAGES, AUDIO, DISPLAY, CONTROLS, KEYBOARD, GAMEPAD }
const PAUSE_LABELS := ["Reprendre", "Options", "Entraînement", "Accueil", "Quitter"]
const PAUSE_BUTTON := Rect2(52, 107, 120, 17)
const PAUSE_SPACING := 20.0
const SCORE_LETTER := Rect2(57, 96, 32, 33)
const SCORE_SAVE := Rect2(25, 179, 84, 20)
const SCORE_SKIP := Rect2(115, 179, 84, 20)
const SCORE_BACK := Rect2(62, 212, 100, 20)
const RESULT_SCORES := Rect2(35, 207, 154, 20)
const RESULT_HOME := Rect2(62, 233, 100, 17)
const BACKGROUND := Color("#080f1c")
const GRID := Color("#142239")
const BORDER := Color("#314765")
const PRIMARY := Color("#edf5ff")
const MUTED := Color("#9eafc6")
const SHIP := Color("#70edcd")
const SHOT := Color("#ffe59a")
const ARCADE_CYAN := Color("#67d8ff")
const ARCADE_GREEN := Color("#99dd68")
const ARCADE_PINK := Color("#e786ef")
const ARCADE_RED := Color("#ff735d")
const SCORE_RANK_COLORS := [
	ARCADE_RED, Color("#ff9b61"), Color("#ffc16c"), SHOT, Color("#c9e97b"),
	ARCADE_GREEN, Color("#69e4b8"), ARCADE_CYAN, Color("#91aeff"), Color("#bc87ff"),
]
const MODULE_COLORS := [Color("#b482ef"), ARCADE_CYAN, ARCADE_GREEN]
const ENEMY := Color("#bc87ff")
const ENEMY_CORE := Color("#b7e9ff")

class InterfaceLayer extends Node2D:
	var state: Array = []

	func refresh(next_state: Array) -> void:
		if state != next_state:
			state = next_state
			queue_redraw()


var _session := ArcadeSession.new()
var _run: ArcadeRun:
	get:
		return _session.current
var _attract := Attract.new()
var _profile := ArcadeProfile.new()
var _audio := ArcadeAudio.new()
var _attract_active := true
var _last_usec := 0
var _elapsed_usec := 0
var _held := 0
var _pressed := 0
var _last_input := 0
var _simulation_tick := 0
var _visual_tick := 0.0
var _motion := FlightMotion.new()
var _focused := true
var _paused := false
var _pause_choice := 0
var _options_open := false
var _languages_open := false
var _options_page := OptionsPage.MAIN
var _binding_waiting := -1
var _binding_error := false
var _options_save_failed := false
var _options_stick := Vector2i.ZERO
var _options_choice := 0
var _score_entry: ScoreEntry
var _score_candidates: Array[Dictionary] = []
var _score_results_open := false
var _result_rows: Array[Dictionary] = []
var _results_page := 0
var _result_choice := 0
var _scores_menu_open := false
var _run_difficulty := ArcadeProfile.Difficulty.NORMAL
var _training_open := false
var _training_result_open := false
var _training_from_options := false
var _training_return_result := false
var _training_choice := 0
var _training_kind := TrainingSession.Kind.WAVE
var _training_target := 1
var _training_difficulty := ArcadeProfile.Difficulty.NORMAL
var _exercise_kind := TrainingSession.Kind.DOCKING
var _exercise_target := 1
var _exercise_difficulty := ArcadeProfile.Difficulty.NORMAL
var _combat_impacts: Array[Effects.Impact] = []
var _wait_for_fire_release := false
var _diagnostics := false
var _last_mouse_motion_usec := 0
var _cursor_hidden := false
var _flight_view: FlightView
var _starfield: Starfield
var _dock_layer: InterfaceLayer
var _hud_layer: InterfaceLayer
var _pause_layer: InterfaceLayer
var _frame_layer: InterfaceLayer
var _panel_layer: InterfaceLayer
var _logo_layer: InterfaceLayer
var _about: AboutPanel
var _about_audio_was_paused := false
var _logo_hovered := false


func _ready() -> void:
	get_window().title = Language.TITLE
	_profile.read()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	add_child(_audio)
	_audio.set_muted(_profile.muted)
	_audio.set_volume(_profile.volume)
	_audio.set_bank(_profile.audio_bank)
	if DisplayServer.get_name() != "headless":
		_starfield = Starfield.new()
		add_child(_starfield)
		RenderingServer.frame_pre_draw.connect(_advance_starfield)
		_flight_view = FlightView.new()
		add_child(_flight_view)
	_dock_layer = _add_interface_layer(_draw_live_docking_status)
	_hud_layer = _add_interface_layer(_draw_arcade_hud)
	_logo_layer = _add_interface_layer(_draw_logos)
	var logo_material := ShaderMaterial.new()
	logo_material.shader = LOGO_SHADER
	_logo_layer.material = logo_material
	_pause_layer = _add_interface_layer(_draw_pause_overlay)
	_frame_layer = _add_interface_layer(_draw_static_interface)
	_panel_layer = _add_interface_layer(_draw_panel)
	_about = AboutPanel.new()
	_about.closed.connect(_close_about)
	_about.link_requested.connect(_open_about_link)
	add_child(_about)
	if _flight_view != null:
		_apply_display()
	Controls.apply(_profile.key_bindings, _profile.button_bindings)
	_last_usec = Time.get_ticks_usec()


func _add_interface_layer(paint: Callable) -> InterfaceLayer:
	var layer := InterfaceLayer.new()
	layer.draw.connect(paint.bind(layer))
	add_child(layer)
	return layer


func _read_controls() -> int:
	var mask := 0
	if Input.is_action_pressed(&"move_left"):
		mask |= Pilot.LEFT
	if Input.is_action_pressed(&"move_right"):
		mask |= Pilot.RIGHT
	if Input.is_action_pressed(&"fire"):
		mask |= Pilot.FIRE
	return mask


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_last_mouse_motion_usec = Time.get_ticks_usec()
		_update_cursor()
		_update_logo_hover(event.position)
	if not _focused:
		return
	if _about_is_open():
		if _about.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _logo_contains(event.position):
		_open_about()
		get_viewport().set_input_as_handled()
		return
	if _score_entry != null:
		_handle_score_entry(event)
		return
	if event.is_echo():
		return
	if _training_open:
		_handle_training_menu(event)
		return
	if _training_result_open:
		_handle_training_result(event)
		return
	if _score_results_open or _scores_menu_open:
		_handle_score_results(event)
		return
	if _options_open:
		_handle_options_input(event)
		return
	if _paused and _handle_pause_input(event):
		return
	if not _attract_active and event.is_action_pressed(&"pause"):
		_toggle_pause()
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_restart(not _attract_active and _session.practice, _session.runs.size() if not _attract_active else 1)
				return
			KEY_F2:
				if not _attract_active and _session.practice:
					_restart(true)
				else:
					_open_training_menu()
				return
			KEY_2, KEY_KP_2:
				if _attract_active:
					_restart(false, 2)
				return
			KEY_ESCAPE:
				if not _attract_active:
					_toggle_pause()
				else:
					get_tree().quit()
				return
			KEY_T:
				if _paused:
					_return_to_title()
				return
			KEY_F3:
				if _attract_active or _paused:
					_set_options_open(true)
				return
			KEY_F4:
				if _attract_active:
					_open_scores_menu()
				return
			KEY_F5:
				_profile.muted = not _profile.muted
				_audio.set_muted(_profile.muted)
				_save_profile()
				return
			KEY_F10:
				_profile.portrait = not _profile.portrait
				_apply_display()
				_save_profile()
				return
			KEY_F11:
				_profile.fullscreen = not _profile.fullscreen
				_apply_display()
				_save_profile()
				return
			KEY_F1:
				_diagnostics = not _diagnostics
				if _starfield != null:
					_starfield.visible = not _diagnostics
				_redraw()
				return
	if event is InputEventJoypadButton and event.pressed:
		if not _attract_active and _session.practice and event.button_index == JOY_BUTTON_Y:
			_restart(true)
			return
		if _attract_active and event.button_index == JOY_BUTTON_BACK:
			_open_scores_menu()
			return
		if (_attract_active or _paused) and event.button_index == JOY_BUTTON_X:
			_set_options_open(true)
			return
		if _attract_active and event.button_index == JOY_BUTTON_Y:
			_restart(false, 2)
			return
		if _paused and event.button_index == JOY_BUTTON_START:
			_toggle_pause()
			return
		if _paused and event.button_index == JOY_BUTTON_B:
			_return_to_title()
			return
	if _attract_active and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var training_button := PORTRAIT_TRAINING_BUTTON if _profile.portrait else TRAINING_BUTTON
			if training_button.has_point(event.position):
				_open_training_menu()
				return
			var scores_button := PORTRAIT_SCORES_BUTTON if _profile.portrait else SCORES_BUTTON
			if scores_button.has_point(event.position):
				_open_scores_menu()
				return
			var options_button := PORTRAIT_OPTIONS_BUTTON if _profile.portrait else OPTIONS_BUTTON
			if options_button.has_point(event.position):
				_set_options_open(true)
				return
			if not _profile.portrait and SOLO_BUTTON.has_point(event.position):
				_restart(false)
				return
			if not _profile.portrait and DUO_BUTTON.has_point(event.position):
				_restart(false, 2)
				return
	var mask := _read_controls()
	if not (mask & Pilot.FIRE):
		_wait_for_fire_release = false
	if not _paused:
		_pressed |= mask & ~_held
	_held = mask


func _toggle_pause() -> void:
	_paused = not _paused
	_pause_choice = 0
	_audio.set_paused(_paused)
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	_redraw()


func _about_is_open() -> bool:
	return _about != null and _about.visible


func _logo_regions() -> Array[Rect2]:
	var regions: Array[Rect2] = []
	if not _focused or _about_is_open() or _score_entry != null or _score_results_open or _scores_menu_open:
		return regions
	regions.append(PORTRAIT_HEADER_LOGO if _profile.portrait else HEADER_LOGO)
	if not _attract_active or _paused or _options_open or _training_open or _training_result_open or _attract.screen() != Attract.Screen.TITLE_TEXT:
		return regions
	var progress := _attract.title_line_progress(1, _visual_tick - _simulation_tick)
	if progress <= 0.0:
		return regions
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	var scale := field.size / Vector2(Pilot.FIELD_SIZE)
	var height := 184.0 * TITLE_LOGO.get_height() / TITLE_LOGO.get_width() * scale.x / scale.y
	var target := Rect2(lerpf(224,20,progress),58,184,height)
	var visible := target.intersection(Rect2(Vector2.ZERO,Vector2(Pilot.FIELD_SIZE)))
	regions.append(Rect2(field.position + visible.position * scale,visible.size * scale))
	return regions


func _logo_contains(point: Vector2) -> bool:
	for region in _logo_regions():
		if region.has_point(point):
			return true
	return false


func _update_logo_hover(point: Vector2) -> void:
	var hovered := _logo_contains(point)
	if hovered == _logo_hovered:
		return
	_logo_hovered = hovered
	if DisplayServer.get_name() != "headless":
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW)
	_redraw()


func _open_about() -> void:
	if _about_is_open():
		return
	_about_audio_was_paused = _audio.is_paused()
	_audio.set_paused(true)
	_about.present(PORTRAIT_SIZE if _profile.portrait else LANDSCAPE_SIZE,_profile.language)
	_pressed = 0
	_held = 0
	_update_logo_hover(Vector2(-1,-1))
	_update_cursor()
	_redraw()


func _close_about() -> void:
	_about.hide()
	_audio.set_paused(_about_audio_was_paused or not _focused)
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_last_input = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	_update_logo_hover(get_global_mouse_position())
	_update_cursor()
	_redraw()


func _open_about_link(url: String) -> void:
	if url in [AboutPanel.AUTHOR_URL,AboutPanel.REPOSITORY_URL] and DisplayServer.get_name() != "headless":
		OS.shell_open(url)


func _pause_button(index: int) -> Rect2:
	return Rect2(PAUSE_BUTTON.position + Vector2(0, PAUSE_SPACING * index), PAUSE_BUTTON.size)


func _field_input_position(position: Vector2) -> Vector2:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	return (position - field.position) * Vector2(Pilot.FIELD_SIZE) / field.size


func _handle_pause_input(event: InputEvent) -> bool:
	var direction := 0
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_confirm_pause_choice()
			return true
		direction = int(event.keycode == KEY_DOWN) - int(event.keycode == KEY_UP)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			_confirm_pause_choice()
			return true
		direction = int(event.button_index == JOY_BUTTON_DPAD_DOWN) - int(event.button_index == JOY_BUTTON_DPAD_UP)
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point := _field_input_position(event.position)
		for index in range(PAUSE_LABELS.size()):
			if _pause_button(index).has_point(point):
				_pause_choice = index
				_redraw()
				if event is InputEventMouseButton:
					_confirm_pause_choice()
				return true
	if direction != 0:
		_pause_choice = posmod(_pause_choice + direction, PAUSE_LABELS.size())
		_redraw()
		return true
	return false


func _set_options_open(enabled: bool) -> void:
	_options_open = enabled
	_open_options_page(OptionsPage.MAIN, _profile.difficulty)
	_audio.set_paused(_paused or enabled)
	_options_choice = _profile.difficulty
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	_redraw()


func _options_item(index: int) -> Rect2:
	if _options_page == OptionsPage.MAIN:
		if index < 2:
			return Rect2(33, 62 + 29 * index, 158, 26)
		return Rect2(33, 120 + 18 * (index - 2), 158, 16)
	var height := 18 if _languages_open else 24
	return Rect2(33, 65 + (height + 3) * index, 158, height)


func _options_back_index() -> int:
	match _options_page:
		OptionsPage.LANGUAGES: return Language.LANGUAGES.size()
		OptionsPage.AUDIO: return 3
		OptionsPage.DISPLAY: return 2
		OptionsPage.CONTROLS: return 3
		OptionsPage.KEYBOARD, OptionsPage.GAMEPAD: return Controls.ACTIONS.size() + 1
	return OPTIONS_BACK


func _open_options_page(page: OptionsPage, choice := 0) -> void:
	_options_page = page
	_languages_open = page == OptionsPage.LANGUAGES
	_options_choice = choice
	_binding_waiting = -1
	_binding_error = false
	_options_stick = Vector2i.ZERO


func _back_options() -> void:
	if _options_page == OptionsPage.MAIN:
		_set_options_open(false)
		return
	match _options_page:
		OptionsPage.KEYBOARD: _open_options_page(OptionsPage.CONTROLS, 0)
		OptionsPage.GAMEPAD: _open_options_page(OptionsPage.CONTROLS, 1)
		OptionsPage.LANGUAGES: _open_options_page(OptionsPage.MAIN, OPTIONS_LANGUAGE)
		OptionsPage.AUDIO: _open_options_page(OptionsPage.MAIN, OPTIONS_AUDIO)
		OptionsPage.DISPLAY: _open_options_page(OptionsPage.MAIN, OPTIONS_DISPLAY)
		_: _open_options_page(OptionsPage.MAIN, OPTIONS_CONTROLS)
	_redraw()


func _handle_options_input(event: InputEvent) -> void:
	if _binding_waiting >= 0:
		_handle_binding_input(event)
		return
	var direction := 0
	var adjustment := 0
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_back_options()
			return
		if event.keycode == KEY_F3:
			_set_options_open(false)
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_confirm_options_choice()
			return
		direction = int(event.keycode == KEY_DOWN) - int(event.keycode == KEY_UP)
		adjustment = int(event.keycode == KEY_RIGHT) - int(event.keycode == KEY_LEFT)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			_back_options()
			return
		if event.button_index == JOY_BUTTON_X:
			_set_options_open(false)
			return
		if event.button_index == JOY_BUTTON_A:
			_confirm_options_choice()
			return
		direction = int(event.button_index == JOY_BUTTON_DPAD_DOWN) - int(event.button_index == JOY_BUTTON_DPAD_UP)
		adjustment = int(event.button_index == JOY_BUTTON_DPAD_RIGHT) - int(event.button_index == JOY_BUTTON_DPAD_LEFT)
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var axis := int(event.axis == JOY_AXIS_LEFT_Y)
		if absf(event.axis_value) < 0.4:
			_options_stick[axis] = 0
		elif absf(event.axis_value) >= 0.65:
			var tilt := int(signf(event.axis_value))
			if tilt != _options_stick[axis]:
				if axis == 0:
					adjustment = tilt
				else:
					direction = tilt
			_options_stick[axis] = tilt
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point := _field_input_position(event.position)
		for index in range(_options_back_index() + 1):
			if _options_item(index).has_point(point):
				_options_choice = index
				if event is InputEventMouseButton:
					if _options_page == OptionsPage.AUDIO and index == 0:
						_adjust_option(-1 if point.x < 112 else 1)
					else:
						_confirm_options_choice()
				else:
					_redraw()
				return
	if adjustment != 0:
		_adjust_option(adjustment)
		return
	if direction != 0:
		_options_choice = posmod(_options_choice + direction, _options_back_index() + 1)
		_redraw()


func _confirm_options_choice() -> void:
	if _options_choice == _options_back_index():
		_back_options()
		return
	if _languages_open:
		var language: String = Language.LANGUAGES.keys()[_options_choice]
		if _profile.language != language:
			_profile.language = language
			_save_profile()
		else:
			_redraw()
		return
	if _options_page in [OptionsPage.AUDIO, OptionsPage.DISPLAY]:
		_adjust_option(1)
		return
	if _options_page == OptionsPage.CONTROLS:
		if _options_choice < 2:
			_open_options_page(OptionsPage.KEYBOARD if _options_choice == 0 else OptionsPage.GAMEPAD)
		else:
			_profile.key_bindings = Controls.DEFAULT_KEYS.duplicate(true)
			_profile.button_bindings = Controls.DEFAULT_BUTTONS.duplicate()
			Controls.apply(_profile.key_bindings, _profile.button_bindings)
			_save_profile()
		_redraw()
		return
	if _options_page in [OptionsPage.KEYBOARD, OptionsPage.GAMEPAD]:
		if _options_choice == Controls.ACTIONS.size():
			if _options_page == OptionsPage.KEYBOARD:
				_profile.key_bindings = Controls.DEFAULT_KEYS.duplicate(true)
			else:
				_profile.button_bindings = Controls.DEFAULT_BUTTONS.duplicate()
			Controls.apply(_profile.key_bindings, _profile.button_bindings)
			_save_profile()
		else:
			_binding_waiting = _options_choice
			_binding_error = false
		_redraw()
		return
	if _options_choice == OPTIONS_LANGUAGE:
		_open_options_page(OptionsPage.LANGUAGES, Language.LANGUAGES.keys().find(_profile.language))
		_redraw()
		return
	if _options_choice == OPTIONS_TRAINING:
		_open_training_menu(true)
		return
	if _options_choice in [OPTIONS_AUDIO, OPTIONS_DISPLAY, OPTIONS_CONTROLS]:
		var pages := {OPTIONS_AUDIO: OptionsPage.AUDIO, OPTIONS_DISPLAY: OptionsPage.DISPLAY, OPTIONS_CONTROLS: OptionsPage.CONTROLS}
		_open_options_page(pages[_options_choice])
		_redraw()
		return
	var difficulty := ArcadeProfile.Difficulty.VETERANS if _options_choice == 1 else ArcadeProfile.Difficulty.NORMAL
	if _profile.difficulty != difficulty:
		_profile.difficulty = difficulty
		_save_profile()
	else:
		_redraw()


func _adjust_option(direction: int) -> void:
	match _options_page:
		OptionsPage.AUDIO:
			if _options_choice == 0:
				_profile.volume = clampi(_profile.volume + direction * 10, 0, 100)
				_audio.set_volume(_profile.volume)
			elif _options_choice == 1:
				_profile.muted = not _profile.muted
				_audio.set_muted(_profile.muted)
			elif _options_choice == 2:
				_profile.audio_bank = "modern" if _profile.audio_bank == "original" else "original"
				_audio.set_bank(_profile.audio_bank)
				_audio.preview_shot()
			else:
				return
		OptionsPage.DISPLAY:
			if _options_choice == 0:
				_profile.fullscreen = not _profile.fullscreen
			elif _options_choice == 1:
				_profile.portrait = not _profile.portrait
			else:
				return
			_apply_display()
		_:
			return
	_save_profile()


func _handle_binding_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK):
		_binding_waiting = -1
		_binding_error = false
		_redraw()
		return
	var action: StringName = Controls.ACTIONS[_binding_waiting]
	if _options_page == OptionsPage.KEYBOARD and event is InputEventKey and event.pressed:
		if not Controls.valid_key(event.keycode, action) or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			_binding_error = true
			_redraw()
			return
		if not Controls.assign_key(_profile.key_bindings, action, event.keycode):
			_binding_error = true
			_redraw()
			return
	elif _options_page == OptionsPage.GAMEPAD and event is InputEventJoypadButton and event.pressed:
		if not Controls.valid_button(event.button_index):
			_binding_error = true
			_redraw()
			return
		Controls.assign_button(_profile.button_bindings, action, event.button_index)
	else:
		return
	_binding_waiting = -1
	_binding_error = false
	Controls.apply(_profile.key_bindings, _profile.button_bindings)
	_save_profile()


func _confirm_pause_choice() -> void:
	match _pause_choice:
		0:
			_toggle_pause()
		1:
			_set_options_open(true)
		2:
			_open_training_menu()
		3:
			_return_to_title()
		4:
			get_tree().quit()


func _open_training_menu(from_options := false) -> void:
	_training_return_result = _training_result_open
	_training_result_open = false
	_training_from_options = from_options
	if not _training_return_result and not _attract_active and not _paused:
		_toggle_pause()
	if not _attract_active and _session.practice:
		_training_kind = _exercise_kind
		_training_target = _exercise_target
		_training_difficulty = _exercise_difficulty
	else:
		_training_difficulty = _profile.difficulty
	_training_open = true
	_options_open = false
	_training_choice = 0
	_options_stick = Vector2i.ZERO
	_audio.set_paused(true)
	_pressed = 0
	_redraw()


func _close_training_menu() -> void:
	_training_open = false
	if _training_return_result:
		_training_result_open = true
		_training_choice = 1
	elif _training_from_options:
		_set_options_open(true)
		_options_choice = OPTIONS_TRAINING
	_audio.set_paused(_paused or _options_open)
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	_redraw()


func _menu_direction(event: InputEvent) -> Vector2i:
	if event is InputEventKey and event.pressed:
		return Vector2i(int(event.keycode == KEY_RIGHT) - int(event.keycode == KEY_LEFT),
			int(event.keycode == KEY_DOWN) - int(event.keycode == KEY_UP))
	if event is InputEventJoypadButton and event.pressed:
		return Vector2i(int(event.button_index == JOY_BUTTON_DPAD_RIGHT) - int(event.button_index == JOY_BUTTON_DPAD_LEFT),
			int(event.button_index == JOY_BUTTON_DPAD_DOWN) - int(event.button_index == JOY_BUTTON_DPAD_UP))
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var axis := int(event.axis == JOY_AXIS_LEFT_Y)
		if absf(event.axis_value) < 0.4:
			_options_stick[axis] = 0
		elif absf(event.axis_value) >= 0.65:
			var tilt := int(signf(event.axis_value))
			if tilt != _options_stick[axis]:
				_options_stick[axis] = tilt
				return Vector2i(tilt, 0) if axis == 0 else Vector2i(0, tilt)
	return Vector2i.ZERO


func _training_row(index: int, result := false) -> Rect2:
	return Rect2(33, (137 if result else 65) + 27 * index, 158, 22)


func _handle_training_menu(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_F2]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		_close_training_menu()
		return
	var direction := _menu_direction(event)
	if direction.y != 0:
		_training_choice = posmod(_training_choice + direction.y, 5)
		_redraw()
	elif direction.x != 0:
		_adjust_training(direction.x)
	elif (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		_confirm_training()
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point := _field_input_position(event.position)
		for index in 5:
			if _training_row(index).has_point(point):
				_training_choice = index
				if event is InputEventMouseButton:
					if index < 3:
						_adjust_training(-1 if point.x < 112 else 1)
					else:
						_confirm_training()
				_redraw()
				return


func _adjust_training(direction: int) -> void:
	match _training_choice:
		0:
			_training_kind = TrainingSession.Kind.DOCKING if _training_kind == TrainingSession.Kind.WAVE else TrainingSession.Kind.WAVE
			_training_target = 1
		1:
			_training_target = 1 + posmod(_training_target - 1 + direction,
				10 if _training_kind == TrainingSession.Kind.WAVE else 2)
		2:
			_training_difficulty = ArcadeProfile.Difficulty.VETERANS if _training_difficulty == ArcadeProfile.Difficulty.NORMAL else ArcadeProfile.Difficulty.NORMAL
	_redraw()


func _confirm_training() -> void:
	if _training_choice < 3:
		_adjust_training(1)
	elif _training_choice == 3:
		_exercise_kind = _training_kind
		_exercise_target = _training_target
		_exercise_difficulty = _training_difficulty
		_restart(true)
	else:
		_close_training_menu()


func _handle_training_result(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_R, KEY_F2]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
		_restart(true)
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		_open_training_menu()
		return
	var direction := _menu_direction(event)
	if direction.y != 0:
		_training_choice = posmod(_training_choice + direction.y, 3)
		_redraw()
	elif (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		_confirm_training_result()
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point := _field_input_position(event.position)
		for index in 3:
			if _training_row(index, true).has_point(point):
				_training_choice = index
				if event is InputEventMouseButton:
					_confirm_training_result()
				_redraw()
				return


func _confirm_training_result() -> void:
	match _training_choice:
		0: _restart(true)
		1: _open_training_menu()
		2: _return_to_title()


func _exercise_label() -> String:
	return _target_label(_exercise_kind, _exercise_target)


func _target_label(kind: int, target: int) -> String:
	if kind == TrainingSession.Kind.WAVE:
		return _translate("Vague %d") % target
	return _translate("Amarrage %s") % ("I → II" if target == 1 else "I + II → III")


func _return_to_title() -> void:
	_training_open = false
	_training_result_open = false
	_combat_impacts.clear()
	_audio.stop()
	_audio.set_paused(false)
	_attract = Attract.new()
	_attract_active = true
	_motion.reset()
	_visual_tick = float(_simulation_tick)
	_paused = false
	_options_open = false
	_score_entry = null
	_score_candidates.clear()
	_score_results_open = false
	_result_rows.clear()
	_results_page = 0
	_result_choice = 0
	_scores_menu_open = false
	_elapsed_usec = 0
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	_redraw()


func _restart(practice: bool, players := 1) -> void:
	_training_open = false
	_training_result_open = false
	_combat_impacts.clear()
	_score_results_open = false
	_results_page = 0
	_result_choice = 0
	_result_rows.clear()
	_score_candidates.clear()
	_score_entry = null
	_scores_menu_open = false
	_run_difficulty = _exercise_difficulty if practice else _profile.difficulty
	_attract_active = false
	_paused = false
	_options_open = false
	if practice:
		_session = TrainingSession.new(_exercise_kind, _exercise_target,
			2 if _exercise_difficulty == ArcadeProfile.Difficulty.VETERANS else 1,
			ArcadeProfile.BONUS_THRESHOLDS[_exercise_difficulty])
	else:
		_session = ArcadeSession.new(players, _profile.bonus_threshold(), false, _profile.starting_cycle())
	if not practice:
		for run in _session.runs:
			run.begin_launch()
	_motion.reset()
	_motion.capture_live(_run, _simulation_tick, 0.0, [])
	_visual_tick = float(_simulation_tick)
	_audio.stop()
	_audio.set_paused(false)
	if not practice or _exercise_kind == TrainingSession.Kind.DOCKING:
		_audio.play("dock" if practice else "launch")
	_elapsed_usec = 0
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_last_input = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	_redraw()


func _finish_session() -> void:
	var candidates: Array[Dictionary] = []
	var results: Array[Dictionary] = []
	if not _session.practice:
		for player in _session.runs.size():
			var run := _session.runs[player]
			var score := run.score()
			results.append({"player": player + 1, "score": score, "cycle": run.cycle,
				"docks": run.successful_dockings, "rank": 0, "initials": "---"})
			if _profile.qualifies(score, _run_difficulty):
				candidates.append({"player": player + 1, "score": score})
	_return_to_title()
	if results.is_empty():
		return
	_result_rows = results
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.player < b.player if a.score == b.score else a.score > b.score)
	_score_candidates = candidates
	_next_score_entry()


func _next_score_entry() -> void:
	while not _score_candidates.is_empty() and not _profile.qualifies(_score_candidates[0].score, _run_difficulty):
		_score_candidates.pop_front()
	if _score_candidates.is_empty():
		_score_entry = null
		_score_results_open = true
		_results_page = 0
		_attract.frame = Attract.TITLE_TEXT_FRAMES
	else:
		_score_entry = ScoreEntry.new()
	_redraw()


func _resolve_score_entry(save: bool) -> void:
	if save:
		var candidate := _score_candidates[0]
		var rank := _profile.insertion_rank(candidate.score, _run_difficulty)
		var error := _profile.submit_score(_score_candidates[0].score, _score_entry.initials,
			ArcadeProfile.SAVE_PATH, _run_difficulty)
		if error != OK and error != ERR_UNAVAILABLE:
			_score_entry.save_failed = true
			_redraw()
			return
		if error == OK:
			var result: Dictionary = _result_rows[candidate.player - 1]
			result.rank = rank
			result.initials = _score_entry.initials
	_score_candidates.pop_front()
	_next_score_entry()


func _score_letter_rect(index: int) -> Rect2:
	return Rect2(SCORE_LETTER.position + Vector2(39 * index, 0), SCORE_LETTER.size)


func _handle_score_entry(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := _field_input_position(event.position)
		if SCORE_SAVE.has_point(point) or SCORE_SKIP.has_point(point):
			_resolve_score_entry(SCORE_SAVE.has_point(point))
			return
		for index in 3:
			if _score_letter_rect(index).has_point(point):
				_score_entry.cursor = index
				_redraw()
				return
	match _score_entry.handle(event):
		ScoreEntry.Result.CHANGED:
			_redraw()
		ScoreEntry.Result.SAVE:
			_resolve_score_entry(true)
		ScoreEntry.Result.SKIP:
			_resolve_score_entry(false)


func _handle_score_results(event: InputEvent) -> void:
	if _score_results_open and _results_page == 0:
		if event is InputEventMouseMotion:
			var point := _field_input_position(event.position)
			if RESULT_SCORES.has_point(point) or RESULT_HOME.has_point(point):
				_result_choice = int(RESULT_HOME.has_point(point))
				_redraw()
			return
		if (event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN]
				or event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]):
			_result_choice = 1 - _result_choice
			_redraw()
			return
	if not event.is_pressed():
		return
	if _scores_menu_open:
		if (event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_F4]
			or event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_BACK]
			or event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
				and SCORE_BACK.has_point(_field_input_position(event.position))):
			_return_to_title()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := _field_input_position(event.position)
		if _results_page == 0 and RESULT_HOME.has_point(point):
			_return_to_title()
			return
		if not (RESULT_SCORES.has_point(point) if _results_page == 0 else SCORE_BACK.has_point(point)):
			return
		_results_page = 1 - _results_page
	elif (event is InputEventKey and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F4]
			or event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]):
		if _results_page == 0 and _result_choice == 1 and not (event is InputEventKey and event.keycode == KEY_F4):
			_return_to_title()
			return
		_results_page = 1 - _results_page
	elif (event is InputEventKey and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]):
		if _results_page == 1:
			_results_page = 0
		else:
			_return_to_title()
			return
	else:
		return
	if _results_page == 0:
		_result_choice = 0
	_redraw()


func _open_scores_menu() -> void:
	_scores_menu_open = true
	_elapsed_usec = 0
	_pressed = 0
	_redraw()


func _score_mode() -> int:
	return _profile.difficulty if _attract_active and not _score_results_open and _score_entry == null else _run_difficulty


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and _score_entry != null:
		_score_entry.release_pad(device)
	if not connected and _binding_waiting >= 0 and _options_page == OptionsPage.GAMEPAD:
		_binding_waiting = -1
		_redraw()


func _save_profile() -> void:
	_options_save_failed = _profile.write() != OK
	if _options_save_failed:
		push_warning("Impossible d’enregistrer les réglages ou les scores.")
	_redraw()


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	_starfield.position = field.position
	_starfield.size = field.size
	var window := get_window()
	window.content_scale_size = PORTRAIT_SIZE if _profile.portrait else LANDSCAPE_SIZE
	var mode := Window.MODE_FULLSCREEN if _profile.fullscreen else Window.MODE_WINDOWED
	if window.mode != mode:
		window.mode = mode
	if not _profile.fullscreen:
		var monitor := DisplayServer.screen_get_usable_rect(window.current_screen)
		var preferred := window.content_scale_size
		var scale_limit := float(FULL_HD.y) / preferred.y
		var scale_factor := minf(scale_limit, minf((monitor.size.x - 48.0) / preferred.x, (monitor.size.y - 80.0) / preferred.y))
		window.size = Vector2i(Vector2(preferred) * scale_factor)
		window.position = monitor.get_center() - window.size / 2
	_redraw()


func _in_play() -> bool:
	return (
		_focused and not _attract_active and not _paused and not _options_open
		and _score_entry == null and not _score_results_open and not _scores_menu_open
		and not _training_open and not _training_result_open
		and not _about_is_open()
	)


# En jeu, le curseur disparaît après 3 s sans mouvement de la souris.
func _update_cursor() -> void:
	var should_hide := _in_play() and Time.get_ticks_usec() - _last_mouse_motion_usec >= CURSOR_HIDE_USEC
	if should_hide == _cursor_hidden:
		return
	_cursor_hidden = should_hide
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if should_hide else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_update_cursor()
			_audio.set_paused(true)
			_held = 0
			_pressed = 0
			_last_input = 0
			_binding_waiting = -1
			if _score_entry != null:
				_score_entry.release_pad()
			_redraw()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_audio.set_paused(_paused or _options_open or _about_is_open())
			_last_usec = Time.get_ticks_usec()
			_redraw()


func _process(delta: float) -> void:
	_update_cursor()
	_update_logo_hover(get_global_mouse_position())
	if not _focused or _paused or _options_open or _score_results_open or _scores_menu_open or _training_open or _training_result_open or _about_is_open():
		return
	if _score_entry != null:
		if _score_entry.repeat(delta):
			_redraw()
		return
	var now := Time.get_ticks_usec()
	var duration_usec := now - _last_usec
	_last_usec = now
	_advance_frame(duration_usec, _read_controls())


func _advance_starfield() -> void:
	# Une mise à jour par image de rendu. La VSync cadence sa présentation.
	if _focused and not _paused and not _about_is_open() and _starfield.is_visible_in_tree() and get_window().mode != Window.MODE_MINIMIZED:
		_starfield.advance()


func _advance_frame(duration_usec: int, input_mask: int) -> void:
	_elapsed_usec = mini(_elapsed_usec + duration_usec, MAX_CATCHUP_USEC)
	_held = input_mask
	while _elapsed_usec >= Pilot.FRAME_USEC:
		_simulation_tick += 1
		_last_input = _held | _pressed
		if _wait_for_fire_release:
			_last_input &= ~Pilot.FIRE
		_pressed = 0
		_elapsed_usec -= Pilot.FRAME_USEC
		if _attract_active:
			if _last_input & Pilot.FIRE:
				_restart(false)
				break
			_attract.step()
			_motion.capture_demo(_attract, _simulation_tick)
			continue
		_step_session(_last_input)
		if _training_result_open:
			_elapsed_usec = 0
			break
		if _session.finished:
			_finish_session()
			break
	_visual_tick = _simulation_tick + float(_elapsed_usec) / Pilot.FRAME_USEC
	_redraw()


func _step_session(input_mask: int) -> void:
	var was_training_pending := _session is TrainingSession and (_session as TrainingSession).pending
	var previous := _run
	var previous_combat := previous.combat
	var alive_before := previous_combat.wave.survivors()
	var flight_sound_before := previous_combat.wave.flight_sound_serial
	var number := _cycle_wave()
	var phase := previous.phase
	var was_ascending := _ship_ascending(previous)
	var had_reserve := previous.bonus_reserve
	var wave := previous.wave_number
	var dock_stage := previous.docking.stage if previous.docking != null else -1
	var frame := previous.combat.pilot.frame
	var shots := previous.combat.pilot.active_shots()
	_session.step(input_mask)
	if _run != previous or _run.combat != previous_combat:
		_combat_impacts.clear()
	elif phase == ArcadeRun.Phase.COMBAT:
		_capture_combat_impacts(previous_combat, alive_before, number)
	for index in range(_combat_impacts.size() - 1, -1, -1):
		if _simulation_tick - _combat_impacts[index].tick >= Effects.IMPACT_LIFETIME:
			_combat_impacts.remove_at(index)
	_motion.capture_live(_run, _simulation_tick, _bank_command() if _run == previous else 0.0, shots)
	if _run != previous or _run.combat != previous_combat or _run.phase != ArcadeRun.Phase.COMBAT:
		_audio.stop_enemy()
	elif previous_combat.wave.flight_sound_serial != flight_sound_before:
		_audio.play(ArcadeAudio.enemy_cue(Presentation.enemy_kind(_cycle_wave())))
	if _session is TrainingSession:
		var training := _session as TrainingSession
		if training.completed:
			_training_result_open = true
			_training_choice = 0
		if training.pending:
			if not was_training_pending:
				_audio.stop()
				var cue := "success" if training.success else "loss"
				if training.kind == TrainingSession.Kind.DOCKING and not training.success:
					cue = "crash" if _run.docking.stage == Docking.Stage.COLLISION else "timeout"
				_audio.play(cue)
			return
	if _run != previous:
		_audio.stop()
		_audio.play("launch" if _ship_ascending(_run) else "start")
		return
	if not was_ascending and _ship_ascending(_run):
		_audio.play("cycle" if _run.phase == ArcadeRun.Phase.CYCLE_END else "launch")
		return
	if _run.phase != phase:
		if _run.phase == ArcadeRun.Phase.REPLACEMENT and phase == ArcadeRun.Phase.COMBAT:
			_audio.play("loss")
		elif _run.phase == ArcadeRun.Phase.DOCKING:
			_audio.play("dock")
	elif _run.docking != null and _run.docking.stage != dock_stage:
		match _run.docking.stage:
			Docking.Stage.SUCCESS:
				_audio.play("success")
			Docking.Stage.COLLISION:
				_audio.play("crash")
			Docking.Stage.TIMED_OUT:
				_audio.play("timeout")
	elif phase == ArcadeRun.Phase.COMBAT and _run.wave_number == wave and _run.combat.pilot.frame > frame:
		if _run.combat.impact_age == 0:
			_audio.play(ArcadeAudio.enemy_cue(Presentation.enemy_kind(_cycle_wave()), true))
		for shot in _run.combat.pilot.active_shots():
			if (shot + Vector2i(0, Pilot.SHOT_STEP)) not in shots:
				_audio.play("shot")
				break
	if not had_reserve and _run.bonus_reserve:
		_audio.play("bonus")


func _ship_ascending(run: ArcadeRun) -> bool:
	match run.phase:
		ArcadeRun.Phase.LAUNCH:
			return true # La musique commence dès le lancement de la séquence.
		ArcadeRun.Phase.REPLACEMENT:
			var elapsed := run.entrance_elapsed()
			return elapsed >= ArcadeRun.ENTRANCE_HIDDEN and elapsed < ArcadeRun.ENTRANCE_HIDDEN + ArcadeRun.ENTRANCE_RISE
		ArcadeRun.Phase.CYCLE_END:
			return run.cycle_end_elapsed >= ArcadeRun.CYCLE_RISE_START and run.cycle_end_elapsed < ArcadeRun.CYCLE_RESET
		ArcadeRun.Phase.DOCKING:
			return run.docking.lifting()
	return false


func _capture_combat_impacts(combat: ArcadeRun.CombatRound, alive_before: int, number: int) -> void:
	var destroyed := alive_before & ~combat.wave.survivors()
	for slot in combat.wave.enemies.size():
		if not (destroyed & (1 << slot)):
			continue
		var enemy := combat.wave.enemies[slot]
		# Leaving the playfield retires a meteor or capsule without an impact.
		if enemy.phase in [CombatWave.Flight.FALL_EXIT, CombatWave.Flight.ROW_EXIT]:
			continue
		_combat_impacts.append(Effects.Impact.new(combat.wave, slot, number, _simulation_tick))


func _redraw() -> void:
	if _panel_layer != null:
		_refresh_interface()
	queue_redraw()


func _refresh_interface() -> void:
	var portrait := _profile.portrait
	var language := _profile.language
	var title_visible := _attract_active and not _scores_menu_open and _score_entry == null and _attract.screen() == Attract.Screen.TITLE_TEXT
	_logo_layer.refresh([portrait, title_visible, _logo_hovered,
		_attract.title_line_progress(1, _visual_tick - _simulation_tick) if title_visible else 0.0])
	var controls_state := [hash(_profile.key_bindings), hash(_profile.button_bindings)]
	_frame_layer.refresh([portrait, _uses_hd(), language, controls_state])
	_pause_layer.refresh([portrait, _paused, _focused, _pause_choice,
		_options_open, _options_choice, _profile.difficulty, _languages_open, language,
		_options_page, _binding_waiting, _binding_error, _options_save_failed, _profile.volume,
		_profile.backup_failed,
		_profile.audio_bank, _training_open, _training_result_open, _training_choice,
		_training_kind, _training_target, _training_difficulty,
		_profile.muted, _profile.fullscreen, controls_state,
		_score_candidates[0] if _score_entry != null else null,
		_score_entry.initials if _score_entry != null else "",
		_score_entry.cursor if _score_entry != null else -1,
		_score_entry.save_failed if _score_entry != null else false])
	var demo := _attract_active and _attract.screen() == Attract.Screen.DEMO
	var results := _score_results_open and not _result_rows.is_empty()
	var duo := _result_rows.size() == 2 if results else not _attract_active and _session.runs.size() == 2
	var first_score: int = _result_rows[0].score if results else (0 if _attract_active else _session.runs[0].score())
	var second_score: int = _result_rows[1].score if results and duo else (_session.runs[1].score() if duo else 0)
	var modules := _hud_modules(demo)
	_hud_layer.refresh([portrait, _profile.scores_for(_score_mode())[0], _score_mode(),
		first_score, second_score, duo, _session.player, _attract_active and not demo, modules, language, results])

	var docking := not _attract_active and _run.phase == ArcadeRun.Phase.DOCKING
	var dock := _run.docking if docking else null
	var dock_state: Array = [portrait, language]
	if dock != null:
		dock_state.append(dock.stage)
		match dock.stage:
			Docking.Stage.INTRO, Docking.Stage.APPROACH:
				dock_state.append(-1 if dock.briefing_visible() else dock.display_clock_tenths())
			Docking.Stage.SUCCESS:
				dock_state.append(dock.bonus)
				dock_state.append(_docking_multiplier(dock))
			Docking.Stage.COLLISION:
				dock_state.append(dock.collision_shows_message())
			Docking.Stage.TIMED_OUT:
				dock_state.append(dock.timeout_shows_message())
	_dock_layer.refresh(dock_state)
	_refresh_panel(duo, dock)


func _refresh_panel(duo: bool, dock: Docking) -> void:
	var pointer := get_global_mouse_position()
	var state: Array = [_profile.portrait, _attract_active, _profile.language,
		_session.practice, _exercise_kind, _exercise_target,
		TRAINING_BUTTON.has_point(pointer), PORTRAIT_TRAINING_BUTTON.has_point(pointer),
		hash(_profile.key_bindings), hash(_profile.button_bindings),
		_score_mode(),
		SCORES_BUTTON.has_point(pointer), PORTRAIT_SCORES_BUTTON.has_point(pointer),
		_score_entry != null or _score_results_open or _scores_menu_open]
	if _profile.portrait:
		if _attract_active:
			state.append(_profile.difficulty)
			state.append(PORTRAIT_OPTIONS_BUTTON.has_point(get_global_mouse_position()))
		else:
			state.append_array([_run.lives, _run.phase, _run.cycle, _cycle_wave(),
				duo, _session.player, _run.attached])
	else:
		state.append(_focused)
		if _focused:
			state.append(_profile.muted)
			if _attract_active:
				state.append_array([_profile.difficulty, SOLO_BUTTON.has_point(pointer),
					DUO_BUTTON.has_point(pointer), OPTIONS_BUTTON.has_point(pointer)])
			else:
				state.append_array([_run.phase, _run.lives, duo, _session.player, _run.attached, _diagnostics])
				if dock != null:
					state.append(dock.stage)
					match dock.stage:
						Docking.Stage.INTRO, Docking.Stage.APPROACH:
							state.append(dock.display_clock_tenths())
						Docking.Stage.SUCCESS:
							state.append(dock.bonus)
							state.append(_docking_multiplier(dock))
					if _diagnostics:
						state.append(dock.display_position())
						state.append(dock.module)
				else:
					state.append_array([_run.cycle, _cycle_wave(), _run.combat.wave.remaining,
						_run.is_cycle_entrance(), _run.entrance_elapsed() >= 0, _run.game_over_shows_message()])
					if _diagnostics:
						state.append(_run.frame)
	_panel_layer.refresh(state)


func _draw() -> void:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	if _uses_hd():
		_flight_view.start_frame()
		draw_texture_rect(_flight_view.get_texture(), field, false)
	else:
		draw_rect(field, BACKGROUND)
	draw_set_transform(field.position, 0.0, field.size / Vector2(Pilot.FIELD_SIZE))
	if _attract_active:
		if _scores_menu_open:
			_draw_both_score_tables()
		elif _score_results_open and _results_page == 0:
			_draw_session_results()
		elif _score_entry == null:
			_draw_attract()
		if not _options_open and not _score_results_open and not _scores_menu_open and _score_entry == null and (_profile.recovered_backup or _profile.unreadable_profile):
			var notice := "Profil restauré depuis la sauvegarde" if _profile.recovered_backup else "Profil illisible · Réglages par défaut"
			_field_text(self, 112, 250, _translate(notice), SHOT, 7)
	else:
		if _diagnostics:
			_draw_grid()
		if _run.phase == ArcadeRun.Phase.DOCKING:
			_draw_docking()
		else:
			_draw_combat()
			if _run.phase == ArcadeRun.Phase.GAME_OVER and _run.game_over_shows_message():
				_field_text(self, 112, 110, _translate("JEU %d TERMINÉ") % (_session.player + 1), SHOT, 11)
				_field_text(self, 112, 126, _translate("ESSAYEZ À NOUVEAU"), SHOT, 9)
	if _uses_hd():
		_flight_view.finish_frame()


func _draw_live_docking_status(canvas: Node2D) -> void:
	if not _attract_active and _run.phase == ArcadeRun.Phase.DOCKING:
		_draw_field_docking_status(canvas)


func _draw_pause_overlay(canvas: Node2D) -> void:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	canvas.draw_set_transform(field.position, 0.0, field.size / Vector2(Pilot.FIELD_SIZE))
	if _options_open:
		_draw_options_menu(canvas)
	elif _training_open:
		_draw_training_menu(canvas)
	elif _training_result_open:
		_draw_training_result(canvas)
	elif _score_entry != null:
		_draw_score_entry(canvas)
	elif _paused:
		_draw_pause_menu(canvas)
	elif not _focused:
		canvas.draw_rect(Rect2(14, 102, 196, 50), Color(0.02, 0.04, 0.07, 0.92))
		_field_text(canvas, 112, 123, _translate("PAUSE"), PRIMARY, 13)


func _draw_pause_menu(canvas: Node2D) -> void:
	var panel := Rect2(43, 83, 138, 128)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	_field_text(canvas, 112, 100, _translate("PAUSE"), PRIMARY, 11)
	for index in range(PAUSE_LABELS.size()):
		var button := _pause_button(index)
		var selected := index == _pause_choice
		canvas.draw_rect(button, GRID if selected else BACKGROUND)
		canvas.draw_rect(button, SHOT if selected else BORDER, false, 0.5)
		_field_text(canvas, 112, button.position.y + 11.5, _translate(PAUSE_LABELS[index]), SHOT if selected else PRIMARY, 8)


func _draw_training_menu(canvas: Node2D) -> void:
	var panel := Rect2(23, 36, 178, 169)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	_field_text(canvas, 112, 53, _translate("Entraînement").to_upper(), SHOT, 11)
	var labels := [
		"%s · %s" % [_translate("Exercice"), _translate("Vague" if _training_kind == TrainingSession.Kind.WAVE else "Amarrage")],
		"‹  %s  ›" % _target_label(_training_kind, _training_target),
		"%s · %s" % [_translate("Difficulté"), _translate(ArcadeProfile.DIFFICULTY_LABELS[_training_difficulty])],
		_translate("Démarrer"), _translate("Retour"),
	]
	for index in labels.size():
		_draw_score_action(canvas, _training_row(index), labels[index], index == _training_choice)
	_field_text(canvas, 112, 221, _translate("Scores hors classement"), MUTED, 7)
	_field_text(canvas, 112, 238, _translate("← → ou clic pour régler"), MUTED, 7)


func _draw_training_result(canvas: Node2D) -> void:
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
		_draw_score_action(canvas, _training_row(index, true), labels[index], index == _training_choice)
	_field_text(canvas, 112, 244, _translate("Scores hors classement"), MUTED, 7)


func _draw_score_entry(canvas: Node2D) -> void:
	var panel := Rect2(17, 37, 190, 185)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	var candidate := _score_candidates[0]
	_field_text(canvas, 112, 55, _translate("NOUVEAU RECORD"), SHOT, 11)
	_field_text(canvas, 112, 207, _translate(ArcadeProfile.DIFFICULTY_LABELS[_run_difficulty]), MUTED, 8)
	var result := "%06d" % candidate.score
	if _session.runs.size() == 2:
		result = "%s · %s" % [_translate("Joueur %d") % candidate.player, result]
	_field_text(canvas, 112, 72, result, ARCADE_CYAN, 12)
	_field_text(canvas, 112, 86, _translate("Saisissez vos trois initiales"), MUTED)
	for index in 3:
		var tile := _score_letter_rect(index)
		var selected := index == _score_entry.cursor
		canvas.draw_rect(tile, GRID if selected else BACKGROUND)
		canvas.draw_rect(tile, SHOT if selected else BORDER, false, 0.65)
		_field_text(canvas, tile.get_center().x, tile.position.y + 23, _score_entry.initials[index], SHOT if selected else PRIMARY, 19)
	_field_text(canvas, 112, 142, _translate("← → Case    ↑ ↓ Lettre"), MUTED, 8)
	_field_text(canvas, 112, 155, _translate("A Suivant    B Précédent"), MUTED, 8)
	_field_text(canvas, 112, 168, _translate("Entrée / Start  Valider"), MUTED, 8)
	_draw_score_action(canvas, SCORE_SAVE, _translate("Enregistrer"), true)
	_draw_score_action(canvas, SCORE_SKIP, _translate("Passer"), false)
	if _score_entry.save_failed:
		_field_text(canvas, 112, 218, _translate("Échec de l’enregistrement"), ARCADE_RED, 7)


func _draw_score_action(canvas: Node2D, rect: Rect2, label: String, primary: bool) -> void:
	canvas.draw_rect(rect, GRID if primary else BACKGROUND)
	canvas.draw_rect(rect, SHOT if primary else BORDER, false, 0.65)
	_field_text(canvas, rect.get_center().x, rect.get_center().y + 3, label, SHOT if primary else PRIMARY, 9)


func _draw_options_menu(canvas: Node2D) -> void:
	const PANEL_TOP := 36.0
	var languages := Language.LANGUAGES.keys()
	var back := _options_back_index()
	var panel := Rect2(23, PANEL_TOP, 178, _options_item(back).end.y - PANEL_TOP + 8)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	var titles := ["Options", "Langue", "Son", "Affichage", "Commandes", "Clavier", "Manette"]
	_field_text(canvas, 112, 53, _translate(titles[_options_page]).to_upper(), SHOT, 11)
	for index in range(back + 1):
		var row := _options_item(index)
		var selected := index == _options_choice
		canvas.draw_rect(row, GRID if selected else BACKGROUND)
		canvas.draw_rect(row, SHOT if selected else BORDER, false, 0.5)
		var tint := SHOT if selected else PRIMARY
		var baseline := row.get_center().y + 3.0
		if index == back:
			_field_text(canvas, 112, baseline, _translate("Retour"), tint, 9)
		elif _languages_open:
			var language: String = languages[index]
			_field_text(canvas, 112, baseline, Language.LANGUAGES[language], tint, 9)
			_draw_option_marker(canvas, Vector2(row.position.x + 10, row.get_center().y), language == _profile.language)
		elif _options_page == OptionsPage.MAIN and index < 2:
			_field_text(canvas, 112, row.position.y + 10.5, _translate(ArcadeProfile.DIFFICULTY_LABELS[index]), tint, 9)
			var points := "30 000" if index == 0 else "50 000"
			var detail := _translate("Cycle %d · Réserve à %s points") % [index + 1, points]
			_field_text(canvas, 112, row.position.y + 21, detail, MUTED, 7)
			_draw_option_marker(canvas, Vector2(row.position.x + 10, row.position.y + 9.5), index == _profile.difficulty)
		else:
			var label := _option_label(index)
			_field_text(canvas, 112, baseline, label, tint, 8)
	var hint := ""
	if _options_save_failed:
		hint = _translate("Échec de l’enregistrement")
	elif _profile.backup_failed:
		hint = _translate("Copie de secours indisponible")
	elif _options_page == OptionsPage.MAIN and _paused:
		hint = _translate("Difficulté à la prochaine partie")
	elif _options_page == OptionsPage.AUDIO:
		hint = _translate("← → ou clic pour régler")
	elif _options_page == OptionsPage.GAMEPAD:
		hint = _translate("Stick gauche pour déplacer")
	if not hint.is_empty():
		_field_text(canvas, 112, _options_item(back).end.y + 19, hint,
			ARCADE_RED if _options_save_failed or _profile.backup_failed else MUTED, 7)
	if _binding_waiting >= 0:
		_draw_binding_prompt(canvas)


func _option_label(index: int) -> String:
	match _options_page:
		OptionsPage.MAIN:
			if index == OPTIONS_LANGUAGE:
				return "%s · %s" % [_translate("Langue"), Language.LANGUAGES[_profile.language]]
			return _translate({OPTIONS_AUDIO: "Son", OPTIONS_DISPLAY: "Affichage",
				OPTIONS_CONTROLS: "Commandes", OPTIONS_TRAINING: "Entraînement"}[index])
		OptionsPage.AUDIO:
			if index == 0:
				return "%s    −  %d %%  +" % [_translate("Volume"), _profile.volume]
			if index == 2:
				return "%s · %s" % [_translate("Sons"), _translate("Moderne" if _profile.audio_bank == "modern" else "Original")]
			return "%s · %s" % [_translate("Son"), _translate("coupé" if _profile.muted else "actif")]
		OptionsPage.DISPLAY:
			if index == 0:
				return _translate("Plein écran" if _profile.fullscreen else "Fenêtré")
			return _translate("Portrait" if _profile.portrait else "Paysage")
		OptionsPage.CONTROLS:
			return _translate(["Clavier", "Manette", "Rétablir par défaut"][index])
		OptionsPage.KEYBOARD, OptionsPage.GAMEPAD:
			if index == Controls.ACTIONS.size():
				return _translate("Rétablir par défaut")
			var action: StringName = Controls.ACTIONS[index]
			var value := _key_label(action) if _options_page == OptionsPage.KEYBOARD else Controls.button_label(_profile.button_bindings[String(action)])
			return "%s · %s" % [_translate(Controls.LABELS[index]), value]
	return ""


func _draw_binding_prompt(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(25, 88, 174, 80), BACKGROUND)
	canvas.draw_rect(Rect2(25, 88, 174, 80), SHOT, false, 0.65)
	_field_text(canvas, 112, 105, _translate(Controls.LABELS[_binding_waiting]), SHOT, 9)
	var instruction := "Appuyez sur une touche" if _options_page == OptionsPage.KEYBOARD else "Appuyez sur un bouton"
	_field_text(canvas, 112, 123, _translate(instruction), PRIMARY, 8)
	_field_text(canvas, 112, 140, _translate("Échap / Back pour annuler"), MUTED, 7)
	if _binding_error:
		_field_text(canvas, 112, 158, _translate("Commande réservée"), ARCADE_RED, 8)


func _draw_option_marker(canvas: Node2D, point: Vector2, active: bool) -> void:
	canvas.draw_circle(point, 2.0, SHIP if active else BORDER, active, -1.0 if active else 0.6, true)


func _draw_chrome_frame(canvas: Node2D, field: Rect2) -> void:
	var surround := field.grow(7.0)
	canvas.draw_rect(surround, Color("#121d2a"), false, 4.0)
	canvas.draw_rect(surround.grow(2.0), Color("#334359"), false, 1.0)
	for x in [surround.position.x, surround.end.x]:
		for y in [surround.position.y, surround.end.y]:
			var point := Vector2(x, y)
			var inward := (surround.get_center() - point).sign()
			canvas.draw_polyline(PackedVector2Array([
				point + Vector2(0, inward.y * 17.0), point, point + Vector2(inward.x * 25.0, 0)
			]), Color("#9db6cc"), 1.6, true)


func _draw_grid() -> void:
	for x in range(16, Pilot.FIELD_SIZE.x, 16):
		draw_line(Vector2(x, 0), Vector2(x, Pilot.FIELD_SIZE.y), GRID)
	for y in range(16, Pilot.FIELD_SIZE.y, 16):
		draw_line(Vector2(0, y), Vector2(Pilot.FIELD_SIZE.x, y), GRID)
	if _run.phase == ArcadeRun.Phase.COMBAT:
		for x in [Pilot.MIN_X, Pilot.MAX_X]:
			draw_line(Vector2(x, 184), Vector2(x, 224), BORDER, 0.5)


func _draw_module(origin: Vector2, module: int, tint: Color, thrust := false) -> void:
	if _uses_hd():
		var bank := _motion.bank.point(_motion.bank.target, _visual_tick).x if not _attract_active else 0.0
		var frame := _render_frame(_attract.frame if _attract_active else _run.frame)
		_flight_view.ship(origin, module, bank if tint == SHIP else 0.0, thrust, frame)
		return
	var wing := float(4 + 2 * module)
	var hull := PackedVector2Array([
		origin, origin + Vector2(3, 5), origin + Vector2(wing, 9),
		origin + Vector2(2, 8), origin + Vector2(0, 11),
		origin + Vector2(-2, 8), origin + Vector2(-wing, 9), origin + Vector2(-3, 5)
	])
	draw_colored_polygon(hull, tint)
	draw_line(origin + Vector2(0, 3), origin + Vector2(0, 8), BACKGROUND, 0.8)
	if thrust:
		draw_line(origin + Vector2(0, 12), origin + Vector2(0, 15), SHOT, 1.0)


func _bank_command() -> float:
	if _last_input & Pilot.LEFT:
		return -9.0
	if _last_input & Pilot.RIGHT:
		return 9.0
	return 0.0


func _render_frame(frame: int) -> float:
	return frame + (_visual_tick - _simulation_tick)


func _visual_point(track: FlightMotion.Track, point: Vector2) -> Vector2:
	return track.point(point, _visual_tick) if not _diagnostics else point


func _draw_combat() -> void:
	if _run.phase == ArcadeRun.Phase.LAUNCH:
		_draw_entrance(_run.frame, 1)
		return
	var combat := _run.combat
	if _run.phase == ArcadeRun.Phase.COMBAT:
		_draw_enemies()
	elif _run.phase == ArcadeRun.Phase.REPLACEMENT:
		_draw_enemy_withdrawal()
	var pilot := combat.pilot
	var last_module := _last_module(_run.attached)
	if _run.phase == ArcadeRun.Phase.REPLACEMENT:
		# Seul le module touché disparaît dans l'explosion. Les autres restent
		# visibles jusqu'au départ de la séquence de déploiement du relais.
		if not _run._counter_dropped:
			var survivors := pilot.attached & _run.available_modules()
			for module in range(3, 0, -1):
				if survivors & (1 << (module - 1)):
					_draw_module(Vector2(pilot.ship_x, pilot.module_y(module) + pilot.assembly_y_offset), module, SHIP, module == _last_module(survivors))
		if _run.reserve_shows_message():
			_field_text(self, 112, 111, _translate("UNE PARTIE DE PLUS"), ARCADE_RED, 10)
		else:
			_draw_entrance(_run.entrance_elapsed(), _run.front_module())
	elif _run.phase == ArcadeRun.Phase.CYCLE_END:
		# pr11c : le vaisseau monte, « PLUS LOIN » (x 73-143, y 112-118 sur les PNG).
		if _run.cycle_end_shows_ship():
			var rise := _run.cycle_end_rise()
			var anchor := _visual_point(_motion.ship, Vector2(pilot.ship_x, pilot.assembly_y_offset - rise))
			for module in range(3, 0, -1):
				if pilot.has_module(module):
					_draw_module(anchor + Vector2(0, pilot.module_y(module)), module, SHIP, module == last_module)
		if _run.cycle_end_shows_message():
			_field_text(self, 108, 119, _translate("PLUS LOIN"), ARCADE_CYAN)
	elif _run.phase != ArcadeRun.Phase.GAME_OVER:
		# Dessiner la base d'abord, puis les modules supérieurs.
		var anchor := _visual_point(_motion.ship, Vector2(pilot.ship_x, pilot.assembly_y_offset))
		for module in range(3, 0, -1):
			if pilot.has_module(module):
				_draw_module(anchor + Vector2(0, pilot.module_y(module)), module, SHIP, module == last_module)
	if _run.phase == ArcadeRun.Phase.COMBAT:
		for point in pilot.active_shots():
			_draw_shot(_motion.projectile(point, _visual_tick) if _uses_hd() else Vector2(point))
		if _diagnostics:
			for module in range(1, 4):
				if pilot.has_module(module):
					var contact := Rect2(CombatWave.module_contact_rect(pilot.ship_x, module, pilot.attached, pilot.assembly_y_offset))
					contact.position += Vector2(-8, 8)
					draw_rect(contact, Color(ARCADE_RED, 0.65), false, 0.5)
	_draw_impact(combat)


func _draw_entrance(frame: int, released_module: int) -> void:
	var modules := _run.entrance_modules()
	if modules == 0:
		return
	var elapsed := _render_frame(frame) if _uses_hd() else float(frame)
	var thruster := _last_module(modules) if elapsed < ArcadeRun.ENTRANCE_HIDDEN + ArcadeRun.ENTRANCE_RISE else 0
	for module in range(3, 0, -1):
		if not (modules & (1 << (module - 1))):
			continue
		var y := _run.entrance_module_y(module, elapsed, released_module)
		if y < Pilot.FIELD_SIZE.y:
			_draw_module(Vector2(Pilot.START_X, y), module, SHIP, module == thruster)


func _draw_enemy_withdrawal() -> void:
	var tick := _run.replacement_elapsed() - ArcadeRun.DEATH_FLAG_FRAMES
	# pr1-suite 8251–8330 : les objets se ramassent au centre en
	# rétrécissant, avant l'entrée du module suivant. Trajet visuel interpolé.
	const WITHDRAWAL_FRAMES := 80
	if tick < 0 or tick >= WITHDRAWAL_FRAMES:
		return
	var number := _cycle_wave()
	var kind := Presentation.enemy_kind(number)
	var frames_left := 1.0 - _render_frame(tick) / WITHDRAWAL_FRAMES
	var blend := frames_left * frames_left * frames_left
	var center := Vector2(112, 128)
	var enemies := _run.combat.wave.enemies
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not enemy.has_visible_pose():
			continue
		var point := center.lerp(enemy.display_position(), blend)
		if _uses_hd():
			var scale_factor := (0.22 + 0.78 * frames_left) * (0.55 if _run.combat.wave.falling else 1.0)
			_flight_view.enemy(point, kind, (number - 1) % 2, center - point, _render_frame(_run.frame), scale_factor, false, index)
		else:
			draw_circle(point, 1.0 + 2.0 * frames_left, Color(ENEMY, frames_left), true, -1.0, true)


func _draw_docking() -> void:
	var dock := _run.docking
	if dock.stage == Docking.Stage.COLLISION:
		_draw_docking_collision(dock)
		return
	var target := dock.target_module
	if dock.stage == Docking.Stage.SUCCESS:
		var assembled := _run.attached | (1 << (target - 1))
		for module in range(3, 0, -1):
			if assembled & (1 << (module - 1)):
				var origin := Presentation.docked_module_origin(module, target, Docking.TARGET.y, Docking.TARGET.x)
				_draw_module(origin, module, SHIP, module == target)
		return
	var target_y := _visual_point(_motion.dock_target, Vector2(0, dock.target_y)).y
	var target_origin := Presentation.docking_module_origin(target, target_y, Docking.TARGET.x)
	if target_origin.y < Pilot.FIELD_SIZE.y:
		_draw_module(target_origin, target, ENEMY_CORE, true)
	var point := dock.display_position()
	if not _diagnostics:
		point = _motion.docking_ship(point, _visual_tick)
	var stack := dock.is_i_and_ii()
	if stack:
		point.y -= 16
	var thrust := dock.lifting() or (dock.stage == Docking.Stage.APPROACH and dock.thrusting)
	_draw_module(point, dock.module, SHIP, thrust and not stack)
	if stack:
		_draw_module(point + Vector2(0, 8), 2, SHIP, thrust)
	if _diagnostics:
		draw_line(Vector2(Docking.TARGET.x, 36), Vector2(Docking.TARGET.x, 238), BORDER)
		var delta := dock.display_position() - Vector2(dock.position) - Vector2(0, 16 if stack else 0)
		var capture := Rect2(dock.capture_rect())
		capture.position += Vector2(Docking.TARGET) + delta
		var collision := Rect2(dock.collision_rect())
		collision.position += Vector2(Docking.TARGET) + delta
		draw_rect(collision, Color(ARCADE_RED, 0.65), false, 0.5)
		draw_rect(capture, Color(SHIP, 0.8), false, 0.5)


func _draw_docking_collision(dock: Docking) -> void:
	var age := dock._result_frames
	if age >= SHIP_BURST_FRAMES:
		return
	var point := dock.display_position()
	if dock.is_i_and_ii():
		point.y -= 8
	if _uses_hd():
		Effects.burst(self, point, _render_frame(age) / SHIP_BURST_FRAMES, 1.6, true)
	else:
		draw_arc(point, 12.0, 0.0, TAU, 16, Color(SHOT, 1.0 - float(age) / SHIP_BURST_FRAMES), 1.0, true)


func _last_module(mask: int) -> int:
	for module in range(3, 0, -1):
		if mask & (1 << (module - 1)):
			return module
	return 0


func _draw_shot(point: Vector2) -> void:
	if _uses_hd():
		Effects.projectile(self, point, Pilot.SHOT_LENGTH)
	else:
		draw_rect(Rect2(point, Vector2(1, Pilot.SHOT_LENGTH)), SHOT)


func _draw_field_docking_status(canvas: Node2D) -> void:
	var dock := _run.docking
	match dock.stage:
		Docking.Stage.INTRO:
			if dock.briefing_visible():
				_draw_docking_briefing(canvas)
			else:
				_draw_docking_clock(canvas, dock.display_clock())
		Docking.Stage.APPROACH:
			_draw_docking_clock(canvas, dock.display_clock())
		Docking.Stage.SUCCESS:
			_draw_congratulations(canvas, dock.bonus, _docking_multiplier(dock))
		Docking.Stage.COLLISION:
			if dock.collision_shows_message():
				_draw_no_docking_bonus(canvas)
		Docking.Stage.TIMED_OUT:
			_draw_docking_timeout(canvas, dock.timeout_shows_message())


func _draw_docking_clock(canvas: Node2D, value: String) -> void:
	_field_text(canvas, 112, 55, _translate("TEMPS D’AMARRAGE"), SHOT, 10)
	_field_text(canvas, 112, 71, value, PRIMARY, 10)


func _draw_docking_timeout(canvas: Node2D, show_message: bool) -> void:
	if show_message:
		_draw_no_docking_bonus(canvas)
		_field_text(canvas, 112, 71, "00:0", PRIMARY, 10)
	else:
		_draw_docking_clock(canvas, "00:0")


func _draw_no_docking_bonus(canvas: Node2D) -> void:
	_field_text(canvas, 112, 55, _translate("AUCUN BONUS"), ARCADE_CYAN, 10)


func _draw_docking_briefing(canvas: Node2D) -> void:
	_field_text(canvas, 112, 84, _translate("MISSION"), SHOT, 11)
	_field_text(canvas, 112, 100, _translate("AMARREZ LES MODULES"), ARCADE_GREEN, 10)
	_field_text(canvas, 112, 116, _translate("DIRIGEZ · TIREZ POUR FREINER"), ARCADE_CYAN, 9)


func _draw_congratulations(canvas: Node2D, bonus: int, multiplier: int) -> void:
	_field_text(canvas, 112, 55, _translate("BONUS D’AMARRAGE"), ARCADE_CYAN, 10)
	_field_text(canvas, 112, 71, "%02d × %d = %d" % [bonus / multiplier, multiplier, bonus], ARCADE_CYAN, 10)
	_field_text(canvas, 112, 188, _translate("BRAVO !!"), SHOT, 11)


func _docking_multiplier(dock: Docking) -> int:
	return 300 if dock.is_i_and_ii() else dock.module * 100


func _draw_enemies() -> void:
	var positions: Array[Vector2] = []
	var wave := _run.combat.wave
	var number := _cycle_wave()
	var kind := Presentation.enemy_kind(number)
	var variant := (number - 1) % 2
	var has_halves := kind == Presentation.EnemyKind.RING
	var margin := 8 if _uses_hd() else -7
	var visible_field := Rect2(Vector2.ZERO, Vector2(Pilot.FIELD_SIZE)).grow(margin)
	for index in range(wave.enemies.size()):
		var enemy := wave.enemies[index]
		if not enemy.has_visible_pose():
			continue
		var logical_point: Vector2 = enemy.display_position()
		var track := _motion.enemies[index]
		var point := _visual_point(track, logical_point)
		if not visible_field.has_point(point):
			continue
		if not has_halves and logical_point in positions:
			continue
		if not has_halves:
			positions.append(logical_point)
		var heading := Vector2(enemy.velocity)
		if has_halves:
			var opening_left := enemy.opening_left if enemy.phase == CombatWave.Flight.OPENING else 0
			heading = Presentation.ring_axis(heading, opening_left)
			var growth := Presentation.ring_scale(opening_left)
			if _uses_hd():
				heading = track.heading(logical_point, heading, _visual_tick)
			_draw_ring_half(point, variant, heading, growth, index & 1, _render_frame(_run.frame))
			if _uses_hd():
				for impact in _combat_impacts:
					if impact.wave == wave and impact.slot == (index ^ 1):
						var progress := (_visual_tick - impact.tick) / Effects.IMPACT_LIFETIME
						Effects.half_damage(self, point, heading, growth, progress)
			if _diagnostics:
				_draw_enemy_bounds(enemy.position)
			continue
		if _uses_hd():
			var frame := _render_frame(_run.frame)
			if kind == Presentation.EnemyKind.INTERCEPTOR:
				var reveal := Presentation.interceptor_reveal(enemy)
				if reveal < 1.0:
					Effects.interceptor_appearance(self, point, variant, reveal, frame)
					continue
			var growth := Presentation.meteor_scale(enemy.opening_left) if wave.falling else 1.0
			if wave.rows and enemy.phase == CombatWave.Flight.OPENING:
				growth = Presentation.capsule_scale(enemy.opening_left)
			var diving := wave.rows and enemy.phase == CombatWave.Flight.ROW_DIVE
			_flight_view.enemy(point, kind, variant, track.heading(logical_point, heading, _visual_tick), frame, growth, diving, index)
			continue
		if _diagnostics:
			_draw_enemy_bounds(enemy.position)
		if wave.falling:
			var radius := 7.0 * Presentation.meteor_scale(enemy.opening_left)
			draw_circle(point, radius, ENEMY.darkened(0.3), true, -1.0, true)
			draw_circle(point, radius * 0.32, ENEMY_CORE, true, -1.0, true)
			continue
		var tint := SHOT if wave.wide_entry else ENEMY
		draw_arc(point, 6.0, 0.0, TAU, 14, tint, 1.0, true)
		draw_line(point - Vector2(7, 0), point + Vector2(7, 0), ENEMY, 1.0)
		draw_circle(point, 2.4, ENEMY_CORE, true, -1.0, true)


func _draw_enemy_bounds(position: Vector2i) -> void:
	var hitbox := Rect2(CombatWave.shot_contact_rect(position))
	draw_rect(hitbox.intersection(Rect2(Vector2.ZERO, Vector2(Pilot.FIELD_SIZE))), ENEMY.darkened(0.65), false)


func _draw_ring_half(point: Vector2, variant: int, heading: Vector2, growth: float, side: int, frame: float) -> void:
	if _uses_hd():
		_flight_view.enemy(point, Presentation.EnemyKind.RING, variant, heading, frame, growth, false, side)
		return
	var angle := heading.angle() + side * PI
	var from := angle - PI / 2.0 + 0.025
	var to := angle + PI / 2.0 - 0.025
	draw_arc(point, 6.0 * growth, from, to, 12, ENEMY if variant == 0 else SHOT, 1.35 * growth, true)
	draw_arc(point, 1.75 * growth, from, to, 8, ENEMY_CORE, 1.35 * growth, true)


func _uses_hd() -> bool:
	return not _diagnostics and _flight_view != null


func _draw_impact(combat: ArcadeRun.CombatRound) -> void:
	if _uses_hd():
		for impact in _combat_impacts:
			Effects.enemy_burst(self, impact, (_visual_tick - impact.tick) / Effects.IMPACT_LIFETIME)
	if _uses_hd() and _run.phase == ArcadeRun.Phase.REPLACEMENT and combat.outcome == ArcadeRun.CombatRound.Outcome.MODULE_LOST:
		var age := _run.replacement_elapsed()
		if age < SHIP_BURST_FRAMES:
			Effects.burst(self, combat.impact_position, _render_frame(age) / SHIP_BURST_FRAMES, 0.8, true)
		return
	if combat.impact_age >= ArcadeRun.CombatRound.IMPACT_FRAMES:
		return
	var progress := _render_frame(combat.impact_age) / ArcadeRun.CombatRound.IMPACT_FRAMES
	var enemy := combat.impacted_enemy
	if _uses_hd() and enemy != null:
		for impact in _combat_impacts:
			if impact.enemy == enemy:
				return
		var slot := combat.wave.enemies.find(enemy)
		if slot >= 0:
			var impact := Effects.Impact.new(combat.wave, slot, _cycle_wave(), _simulation_tick - combat.impact_age)
			Effects.enemy_burst(self, impact, _render_frame(combat.impact_age) / Effects.IMPACT_LIFETIME)
		return
	if enemy != null and _cycle_wave() <= 2:
		var side := combat.wave.enemies.find(enemy) & 1
		var opening_left := enemy.opening_left if enemy.phase == CombatWave.Flight.OPENING else 0
		var heading := Presentation.ring_axis(Vector2(enemy.velocity), opening_left)
		var growth := Presentation.ring_scale(opening_left)
		var center := combat.impact_position + heading * (3.9 * growth if side == 0 else -3.9 * growth)
		draw_arc(center, (2.0 + 4.0 * progress) * growth, 0.0, TAU, 12, Color(SHOT, 1.0 - progress), 0.8, true)
		return
	if _uses_hd():
		Effects.burst(self, combat.impact_position, progress)
		return
	var tint := Color(SHOT, 1.0 - progress)
	draw_arc(combat.impact_position, 4.0 + 8.0 * progress, 0.0, TAU, 18, tint, 1.0, true)


func _draw_static_interface(canvas: Node2D) -> void:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	canvas.draw_rect(field, BORDER, false, 1.0)
	if _uses_hd():
		_draw_chrome_frame(canvas, field)
	if _profile.portrait:
		return
	_draw_text(canvas, Vector2(946, 77), _translate("Défense orbitale"), 18, SHIP)
	canvas.draw_line(Vector2(LABEL_X, 127), Vector2(PANEL_END, 127), BORDER)
	_text(canvas, 169, _translate("COMMANDES"), 13, MUTED)
	_text(canvas, 200, _translate("%s / %s   Déplacer") % [_key_label(&"move_left"), _key_label(&"move_right")], 18, PRIMARY)
	_text(canvas, 235, _translate("%s / %s   Tirer · Freiner en approche") % [_key_label(&"fire"), _button_label(&"fire")], 16, MUTED)
	_text(canvas, 270, _translate("%s   Pause     R   Recommencer") % _key_label(&"pause"), 16, MUTED)
	canvas.draw_line(Vector2(LABEL_X, 384), Vector2(PANEL_END, 384), BORDER)


func _draw_logos(canvas: Node2D) -> void:
	var tint := Color(1.12,1.12,1.12) if _logo_hovered else Color.WHITE
	if _profile.portrait:
		canvas.draw_texture_rect(TITLE_LOGO, PORTRAIT_HEADER_LOGO, false, tint)
	else:
		canvas.draw_texture_rect(TITLE_LOGO, HEADER_LOGO, false, tint)
	if not _attract_active or _scores_menu_open or _score_entry != null or _attract.screen() != Attract.Screen.TITLE_TEXT:
		return
	var progress := _attract.title_line_progress(1, _visual_tick - _simulation_tick)
	if progress <= 0.0:
		return
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	var scale := field.size / Vector2(Pilot.FIELD_SIZE)
	var height := 184.0 * TITLE_LOGO.get_height() / TITLE_LOGO.get_width() * scale.x / scale.y
	var target := Rect2(lerpf(224, 20, progress), 58, 184, height)
	var visible := target.intersection(Rect2(Vector2.ZERO, Vector2(Pilot.FIELD_SIZE)))
	var source := Rect2((visible.position - target.position) / target.size * TITLE_LOGO.get_size(),
		visible.size / target.size * TITLE_LOGO.get_size())
	canvas.draw_set_transform(field.position, 0.0, scale)
	canvas.draw_texture_rect_region(TITLE_LOGO, visible, source)


func _draw_panel(canvas: Node2D) -> void:
	if _score_entry != null or _score_results_open or _scores_menu_open:
		return
	if _profile.portrait:
		_draw_portrait_hud(canvas)
		return
	var difficulty := "%s · %s" % [_translate("Difficulté"),
		_translate(ArcadeProfile.DIFFICULTY_LABELS[_score_mode()])]
	_text(canvas, 373, difficulty, 17, SHOT)
	if not _attract_active and _session.practice:
		_text(canvas, 331, _translate("Entraînement"), 20, SHOT)
		_text(canvas, 356, "%s · R / Y %s" % [_exercise_label(), _translate("Réessayer")], 15, MUTED)
	if not _focused:
		_text(canvas, 425, _translate("En pause"), 20, SHOT)
		return
	if _attract_active:
		_draw_attract_panel(canvas)
		return
	if _run.phase == ArcadeRun.Phase.DOCKING:
		_draw_docking_panel(canvas)
		return
	match _run.phase:
		ArcadeRun.Phase.LAUNCH:
			_text(canvas, 425, _translate("Décollage"), 20, SHOT)
		ArcadeRun.Phase.REPLACEMENT:
			var status := _translate("Vaisseau perdu")
			if _run.combat.lost_module > 0:
				status = _translate("Module %s perdu") % ["I", "II", "III"][_run.combat.lost_module - 1]
			if _run.is_cycle_entrance():
				status = _translate("Cycle %d · entrée du module I") % _run.cycle
			elif _run.entrance_elapsed() >= 0:
				status = _translate("Déploiement du module %s") % _run.ship_label()
			_text(canvas, 425, status, 20, SHOT)
		ArcadeRun.Phase.CYCLE_END:
			_text(canvas, 425, _translate("Plus loin · fin du cycle %d") % _run.cycle, 20, PRIMARY)
		ArcadeRun.Phase.GAME_OVER:
			if _run.game_over_shows_message():
				_text(canvas, 425, _translate("JOUEUR %d · PARTIE TERMINÉE") % (_session.player + 1), 20, SHOT)
				_text(canvas, 448, _translate("ESSAYEZ À NOUVEAU"), 17, SHOT)
			else:
				_text(canvas, 425, _translate("Vaisseau perdu"), 20, SHOT)
		_:
			_text(canvas, 425, _translate("Cycle %d · vague %d / %d") % [_run.cycle, _cycle_wave(), Presentation.WAVES_PER_CYCLE], 20, PRIMARY)
	_text(canvas, 463, _translate("Vies %d") % _run.lives if _run.phase == ArcadeRun.Phase.LAUNCH
		else _translate("%d cibles   ·   Vies %d") % [_run.combat.wave.remaining, _run.lives], 17, MUTED)
	if _session.runs.size() == 2:
		_text(canvas, 489, _turn_label(), 16, SHIP)
	if _diagnostics:
		_draw_readout(canvas)
	_draw_options(canvas)


func _draw_docking_panel(canvas: Node2D) -> void:
	var dock := _run.docking
	match dock.stage:
		Docking.Stage.SUCCESS:
			_text(canvas, 425, _translate("Bravo ! Amarrage réussi"), 20, SHIP)
			var multiplier := _docking_multiplier(dock)
			_text(canvas, 463, _translate("Bonus   %d × %d = %d") % [dock.bonus / multiplier, multiplier, dock.bonus], 17, SHOT)
		Docking.Stage.COLLISION:
			_text(canvas, 425, _translate("Collision à l’amarrage"), 20, SHOT)
		Docking.Stage.TIMED_OUT:
			_text(canvas, 425, _translate("Temps écoulé"), 20, ARCADE_CYAN)
		_:
			_text(canvas, 425, _translate("Mission amarrage"), 20, PRIMARY)
			_text(canvas, 463, _translate("Chrono   %s") % dock.display_clock(), 17, SHOT)
	_text(canvas, 510, _translate("Vies %d") % _run.lives, 17, MUTED)
	if _session.runs.size() == 2:
		_text(canvas, 569, _turn_label(), 16, SHIP)
	if _diagnostics:
		var point := dock.display_position()
		_text(canvas, 543, _translate("Module %d    x %d    y %d") % [dock.module, point.x, point.y], 17, SHIP)
	_draw_options(canvas)


func _draw_readout(canvas: Node2D) -> void:
	var pilot := _run.combat.pilot
	_text(canvas, 510, _translate("Image %d   ·   Pas de 16,5 ms") % _run.frame, 17, MUTED)
	_text(canvas, 543, _translate("Vaisseau %s    x %d    y %d") % [
		_run.ship_label(), pilot.ship_x, pilot.ship_y()
	], 17, SHIP)
	var shots := pilot.active_shots()
	if shots.is_empty():
		_text(canvas, 576, _translate("Projectile    prêt"), 17, MUTED)
	else:
		var point: Vector2i = shots[0]
		var suffix := "" if shots.size() == 1 else "    +%d" % (shots.size() - 1)
		_text(canvas, 576, _translate("Projectile    x %d    y %d%s") % [point.x, point.y, suffix], 17, SHOT)
	var commands := PackedStringArray()
	if _last_input & Pilot.LEFT:
		commands.append(_translate("gauche"))
	if _last_input & Pilot.RIGHT:
		commands.append(_translate("droite"))
	if _last_input & Pilot.FIRE:
		commands.append(_translate("tir"))
	_text(canvas, 609, _translate("Entrées    %s") % (" + ".join(commands) if not commands.is_empty() else "—"), 17, MUTED)


func _field_text(canvas: Node2D, center_x: float, y: float, label: String, color: Color, size := 8, slide := 1.0) -> void:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	var scale := field.size / Vector2(Pilot.FIELD_SIZE)
	var font_size := size * 3
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var right := (Pilot.FIELD_SIZE.x - 2.0) * 3.0
	var x := lerpf(right, center_x * 3.0 - width / 2.0, slide)
	canvas.draw_set_transform(field.position, 0.0, scale / 3.0)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(x, y * 3), label, HORIZONTAL_ALIGNMENT_LEFT,
		right - x if slide < 1.0 else -1.0, font_size, color)
	canvas.draw_set_transform(field.position, 0.0, scale)


func _draw_arcade_hud(canvas: Node2D) -> void:
	var results := _score_results_open and not _result_rows.is_empty()
	var score: int = _result_rows[0].score if results else (0 if _attract_active else _session.runs[0].score())
	var duo := _result_rows.size() == 2 if results else not _attract_active and _session.runs.size() == 2
	var second_score: int = _result_rows[1].score if results and duo else (_session.runs[1].score() if duo else 0)
	_field_text(canvas, 26, 9, _translate("1 J"), ARCADE_CYAN if results or not duo or _session.player == 0 else MUTED, 7)
	_field_text(canvas, 26, 18, "%06d" % score, PRIMARY, 8)
	_field_text(canvas, 112, 9, _translate("RECORD"), ARCADE_CYAN, 7)
	_field_text(canvas, 112, 18, "%06d" % _profile.scores_for(_score_mode())[0], PRIMARY, 8)
	if duo or (_attract_active and not results and _attract.screen() != Attract.Screen.DEMO):
		_field_text(canvas, 198, 9, _translate("2 J"), ARCADE_CYAN if results or _attract_active or _session.player == 1 else MUTED, 7)
		_field_text(canvas, 198, 18, "%06d" % second_score, PRIMARY, 8)
	var modules := _hud_modules(_attract_active and _attract.screen() == Attract.Screen.DEMO)
	for module in range(3):
		if modules.x & (1 << module):
			var point := Vector2(208, (24.0 if duo else 8.0) + module * 5.4)
			_draw_module_mark(canvas, point, module, bool(modules.y & (1 << module)))


func _hud_modules(demo: bool) -> Vector2i:
	var modules := 0
	var active := 0
	if demo:
		active = _attract.demo_attached()
		for module in range(3):
			if _attract.demo_value(Attract.Column.MODULE_I + module) != 0:
				modules |= 1 << module
	elif not _attract_active and _run.lives > 0:
		modules = _run.available_modules()
		active = _run.attached
	return Vector2i(modules, active)


func _draw_module_mark(canvas: Node2D, point: Vector2, module: int, active: bool) -> void:
	var width := 3.0 + module * 1.65
	var hull := PackedVector2Array([
		point + Vector2(0, -2.4), point + Vector2(width, 1.2),
		point + Vector2(width, 2.4), point + Vector2(0, 1.6),
		point + Vector2(-width, 2.4), point + Vector2(-width, 1.2),
	])
	var tint: Color = MODULE_COLORS[module]
	canvas.draw_colored_polygon(hull, tint if active else tint.darkened(0.28))
	canvas.draw_line(point + Vector2(0, -1.25), point + Vector2(0, 1.15), SHOT if active else tint, 0.7, true)


# Le cycle d'attraction rejoue les positions et les états du relevé pr10e.
func _draw_attract() -> void:
	match _attract.screen():
		Attract.Screen.TITLE_TEXT:
			const ROWS := [43, 78, 168, 191, 214]
			const COLORS := [ARCADE_GREEN, SHOT, ARCADE_PINK, ARCADE_GREEN, ARCADE_CYAN]
			for index in range(Attract.TITLE_LINES.size()):
				if index == 1:
					continue
				var progress := _attract.title_line_progress(index, _visual_tick - _simulation_tick)
				if progress <= 0.0:
					continue
				var label: String = Attract.TITLE_LINES[index][0]
				if index == Attract.TITLE_LINES.size() - 1:
					label = _translate("%s / %s POUR JOUER") % [_key_label(&"fire").to_upper(), _button_label(&"fire")]
				_field_text(self, 112, ROWS[index], _translate(label), COLORS[index], 14 if index == 1 else 10, progress)
		Attract.Screen.SCORE_TABLE:
			_draw_score_table()
		Attract.Screen.DEMO:
			_draw_demo()


func _draw_score_table() -> void:
	var mode := _score_mode()
	_field_text(self, 112, 26, _translate(ArcadeProfile.DIFFICULTY_LABELS[mode]), SHOT, 8)
	_field_text(self, 39, 35, _translate("RANG"), ARCADE_PINK, 9)
	_field_text(self, 105, 35, _translate("INITIALES"), ARCADE_PINK, 9)
	_field_text(self, 175, 35, _translate("SCORE"), ARCADE_PINK, 9)
	var scores := _profile.scores_for(mode)
	var names := _profile.initials_for(mode)
	for index in scores.size():
		var y := 53 + index * 15
		var color: Color = SCORE_RANK_COLORS[index]
		var score := scores[index]
		if _score_results_open:
			for result in _result_rows:
				if result.rank == index + 1:
					draw_rect(Rect2(25, y - 11, 174, 14), Color(SHOT, 0.10))
					draw_rect(Rect2(25, y - 11, 174, 14), Color(SHOT, 0.75), false, 0.5)
		_field_text(self, 39, y, "%02d" % (index + 1), color, 10)
		_field_text(self, 105, y, names[index] if score > 0 else "—", color, 10)
		_field_text(self, 175, y, "%06d" % score if score > 0 else "—", color, 10)
	if _score_results_open:
		_draw_score_action(self, SCORE_BACK, _translate("Retour"), true)


func _draw_session_results() -> void:
	_field_text(self, 112, 36, _translate("Résultats"), SHOT, 12)
	_field_text(self, 112, 54, _translate(ArcadeProfile.DIFFICULTY_LABELS[_run_difficulty]), MUTED, 9)
	var duo := _result_rows.size() == 2
	if duo:
		draw_line(Vector2(112, 65), Vector2(112, 198), BORDER, 0.5)
	for index in _result_rows.size():
		var result := _result_rows[index]
		var x := 58.0 + index * 108.0 if duo else 112.0
		var player := _translate("Joueur %d") % result.player
		if result.rank > 0:
			player += " · " + result.initials
		_field_text(self, x, 77, player, ARCADE_CYAN, 9)
		_field_text(self, x, 102, "%06d" % result.score, PRIMARY, 13 if duo else 17)
		var rank := _translate("Hors classement")
		var tint := MUTED
		if result.rank > 0:
			rank = "%s %02d" % [_translate("RANG"), result.rank]
			tint = SCORE_RANK_COLORS[result.rank - 1]
		_field_text(self, x, 127, rank, tint, 9)
		_field_text(self, x, 151, _translate("Cycle atteint %d") % result.cycle, PRIMARY, 8)
		_field_text(self, x, 174, _translate("Amarrages réussis"), MUTED, 7)
		_field_text(self, x, 194, str(result.docks), SHIP, 12)
	_draw_score_action(self, RESULT_SCORES, _translate("Voir le classement"), _result_choice == 0)
	_draw_score_action(self, RESULT_HOME, _translate("Accueil"), _result_choice == 1)


func _draw_both_score_tables() -> void:
	_field_text(self, 112, 34, _translate("Classements"), SHOT, 12)
	draw_line(Vector2(112, 48), Vector2(112, 202), BORDER, 0.5)
	for mode in ArcadeProfile.RECORD_SECTIONS.size():
		var offset := 108.0 * mode
		var scores := _profile.scores_for(mode)
		var names := _profile.initials_for(mode)
		_field_text(self, offset + 58, 53, _translate(ArcadeProfile.DIFFICULTY_LABELS[mode]), PRIMARY, 10)
		for index in scores.size():
			var y := 71 + index * 13
			var color: Color = SCORE_RANK_COLORS[index]
			var score := scores[index]
			_field_text(self, offset + 20, y, "%02d" % (index + 1), color, 7)
			_field_text(self, offset + 49, y, names[index] if score > 0 else "—", color, 8)
			_field_text(self, offset + 86, y, "%06d" % score if score > 0 else "—", color, 8)
	_draw_score_action(self, SCORE_BACK, _translate("Retour"), true)


func _draw_demo() -> void:
	var screen_code := _attract.demo_value(Attract.Column.SCREEN)
	var step := _attract.demo_value(Attract.Column.STEP)
	var track := _attract.demo_objects()
	if track.is_empty():
		return
	for module in range(3, 0, -1):
		var index := Attract.MODULE_OFFSET + (module - 1) * 2
		if track[index] != 255:
			var point := _visual_point(_motion.demo_modules[module - 1], Vector2(track[index], track[index + 1]))
			_draw_module(point, module, SHIP, track[Attract.THRUST_OFFSET] == module)
	_draw_demo_objects(track)
	match screen_code:
		Attract.SCREEN_PLAY:
			if step in [2, 5]:
				var target := Attract.Column.MODULE_II if step == 2 else Attract.Column.MODULE_III
				if _attract.demo_value(target) == 2:
					_draw_docking_clock(self, _attract.demo_clock())
				elif _attract.demo_value(target) == 3:
					_draw_docking_briefing(self)
		Attract.SCREEN_RESULT:
			if step == 2:
				_draw_congratulations(self, 1000, 100)
		Attract.SCREEN_TIMEOUT, Attract.SCREEN_TIMEOUT_TEXT:
			_draw_docking_timeout(self, screen_code == Attract.SCREEN_TIMEOUT_TEXT)


func _draw_demo_objects(track: PackedByteArray) -> void:
	var style := track[Attract.STYLE_OFFSET]
	var kind := style >> 1
	var has_halves := kind == Presentation.EnemyKind.RING
	var previous := _attract.demo_objects(2)
	var drawn: Array[Vector2] = []
	for slot in range(0, 16, 2):
		if track[slot] == 255 or style == 255:
			continue
		var logical_point := Vector2(track[slot], track[slot + 1])
		if not has_halves and logical_point in drawn:
			continue
		if not has_halves:
			drawn.append(logical_point)
		var motion_track := _motion.enemies[slot >> 1]
		var point := _visual_point(motion_track, logical_point)
		var heading := logical_point - Vector2(previous[slot], previous[slot + 1])
		if previous[slot] == 255 or heading.length_squared() > 400:
			heading = Vector2.DOWN
		if _uses_hd():
			heading = motion_track.heading(logical_point, heading, _visual_tick)
		if has_halves:
			_draw_ring_half(point, style & 1, Presentation.ring_axis(heading, 0), 1.0, (slot >> 1) & 1, _render_frame(_attract.frame))
		elif _uses_hd():
			var diving := bool(track[Attract.DIVING_OFFSET] & (1 << (slot >> 1)))
			_flight_view.enemy(point, kind, style & 1, heading, _render_frame(_attract.frame), 1.0, diving, slot >> 1)
		else:
			draw_circle(point, 2.8, ENEMY)
	for slot in range(16, 26, 2):
		if track[slot] != 255:
			_draw_shot(Vector2(track[slot], track[slot + 1]))


func _draw_attract_panel(canvas: Node2D) -> void:
	_draw_menu_button(canvas, SCORES_BUTTON, _translate("Classements"), "F4")
	_draw_menu_button(canvas, TRAINING_BUTTON, _translate("Entraînement"), "F2")
	_text(canvas, 428, _translate("Partie arcade"), 24, PRIMARY)
	var pointer := get_global_mouse_position()
	_draw_button(canvas, SOLO_BUTTON, _translate("1 joueur"), "%s / %s" % [_key_label(&"fire"), _button_label(&"fire")], true, pointer)
	_draw_button(canvas, DUO_BUTTON, _translate("2 joueurs en alternance"), "2 / Y", false, pointer)
	_draw_options_button(canvas, OPTIONS_BUTTON, pointer)
	_draw_options(canvas)


func _draw_menu_button(canvas: Node2D, rect: Rect2, label: String, shortcut: String) -> void:
	canvas.draw_rect(rect, GRID if rect.has_point(get_global_mouse_position()) else Color("#141f32"))
	var baseline := rect.get_center().y + 5
	_draw_text(canvas, Vector2(rect.position.x + 12, baseline), label, 16, PRIMARY)
	_draw_text(canvas, Vector2(rect.end.x - 30, baseline), shortcut, 12, MUTED)


func _draw_button(canvas: Node2D, rect: Rect2, label: String, shortcut: String, primary: bool, pointer: Vector2) -> void:
	var fill := SHIP if primary else Color("#141f32")
	if rect.has_point(pointer):
		fill = fill.lightened(0.14)
	canvas.draw_rect(rect, fill)
	var tint := BACKGROUND if primary else PRIMARY
	var baseline := rect.get_center().y + 6
	_draw_text(canvas, Vector2(rect.position.x + 16, baseline), label, 17, tint)
	_draw_text(canvas, Vector2(rect.end.x - 100, baseline - 1), shortcut, 13, tint)


func _draw_options(canvas: Node2D) -> void:
	var sound := _translate("coupé" if _profile.muted else "actif")
	_text(canvas, 651, _translate("F1 Diagnostic    F2 Entraînement    F5 Son %s") % sound, 14, MUTED)
	_text(canvas, 675, _translate("F10 Portrait    F11 Plein écran"), 14, MUTED)


func _draw_options_button(canvas: Node2D, rect: Rect2, pointer: Vector2) -> void:
	canvas.draw_rect(rect, GRID if rect.has_point(pointer) else Color("#141f32"))
	var label := "%s · %s" % [_translate("Options"), _translate(ArcadeProfile.DIFFICULTY_LABELS[_profile.difficulty])]
	var y := rect.get_center().y + 5.0
	_draw_text(canvas, Vector2(rect.position.x + 12, y), label, 14, PRIMARY)
	_draw_text(canvas, Vector2(rect.end.x - 45, y), "F3 / X", 12, MUTED)


func _draw_portrait_hud(canvas: Node2D) -> void:
	_draw_text(canvas, Vector2(198, 24), _translate("Difficulté"), 12, MUTED)
	_draw_text(canvas, Vector2(198, 44), _translate(ArcadeProfile.DIFFICULTY_LABELS[_score_mode()]), 15, SHOT)
	if _attract_active:
		_draw_options_button(canvas, PORTRAIT_OPTIONS_BUTTON, get_global_mouse_position())
		_draw_menu_button(canvas, PORTRAIT_SCORES_BUTTON, _translate("Classements"), "F4")
		_draw_menu_button(canvas, PORTRAIT_TRAINING_BUTTON, _translate("Entraînement"), "F2")
		return
	else:
		_draw_text(canvas, Vector2(421, 43), _translate("VIES %d") % _run.lives, 20, SHOT)
	var label := _translate("Espace / A   Solo      2 / Y   Duo      F10   Paysage")
	if not _attract_active:
		var status := _translate("Décollage") if _run.phase == ArcadeRun.Phase.LAUNCH else _translate("Cycle %d · Vague %d") % [_run.cycle, _cycle_wave()]
		label = _translate("%s     %s     %s   Pause") % [_turn_label(), status, _key_label(&"pause")]
	if _session.practice:
		label = "%s · %s · R / Y %s" % [_translate("Entraînement"), _exercise_label(), _translate("Réessayer")]
	_draw_text(canvas, Vector2(28, 761), label, 16, MUTED)


func _turn_label() -> String:
	return _translate("Joueur %d") % (_session.player + 1) if _session.runs.size() == 2 else _run.ship_label()


func _cycle_wave() -> int:
	return Presentation.cycle_wave(_run.wave_number, _run.stage)


func _translate(source: String) -> String:
	return Language.text(source, _profile.language)


func _key_label(action: StringName) -> String:
	var labels := PackedStringArray()
	for code in _profile.key_bindings[String(action)]:
		labels.append(_translate(Controls.key_name(code)))
	return " / ".join(labels)


func _button_label(action: StringName) -> String:
	return Controls.button_label(_profile.button_bindings[String(action)])


func _text(canvas: Node2D, y: float, label: String, size: int, color: Color) -> void:
	_draw_text(canvas, Vector2(LABEL_X, y), label, size, color)


func _draw_text(canvas: Node2D, at: Vector2, label: String, size: int, color: Color) -> void:
	canvas.draw_string(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
