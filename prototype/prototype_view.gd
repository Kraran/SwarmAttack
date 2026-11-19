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
const ArcadeHaptics = preload("res://arcade_haptics.gd")
const ArcadeProfile = preload("res://arcade_profile.gd")
const Controls = preload("res://arcade_controls.gd")
const TITLE_LOGO = preload("res://art/swarm_attack_logo.png")
const LOGO_SHADER = preload("res://logo.gdshader")
const Language = preload("res://arcade_language.gd")
const ArcadeSession = preload("res://arcade_session.gd")
const TrainingSession = preload("res://training_session.gd")
const Effects = preload("res://arcade_effects.gd")
const MenuScreen = preload("res://ui/menu_screen.gd")
const MenuNavigation = preload("res://ui/menu_navigation.gd")
const OptionsMenu = preload("res://ui/options_menu.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const TrainingMenu = preload("res://ui/training_menu.gd")
const TitleMenu = preload("res://ui/title_menu.gd")
const ScoresMenu = preload("res://ui/scores_menu.gd")
const MenuOverlay = preload("res://ui/menu_overlay.gd")
const MenuInput = preload("res://ui/menu_input.gd")
const AboutPanel = preload("res://about_panel.gd")
const FpsCounter = preload("res://ui/fps_counter.gd")
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
const BACKGROUND = MenuScreen.BACKGROUND
const GRID = MenuScreen.GRID
const BORDER = MenuScreen.BORDER
const PRIMARY = MenuScreen.PRIMARY
const MUTED = MenuScreen.MUTED
const SHIP = MenuScreen.SHIP
const SHOT = MenuScreen.SHOT
const ARCADE_CYAN := Color("#67d8ff")
const ARCADE_GREEN := Color("#99dd68")
const ARCADE_PINK := Color("#e786ef")
const ARCADE_RED = MenuScreen.ARCADE_RED
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
var _haptics := ArcadeHaptics.new()
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
var _run_difficulty := ArcadeProfile.Difficulty.NORMAL
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
var _pause_layer: MenuOverlay
var _frame_layer: InterfaceLayer
var _panel_layer: InterfaceLayer
var _logo_layer: InterfaceLayer
var _about: AboutPanel
var _fps_counter := FpsCounter.new()
var _about_audio_was_paused := false
var _logo_hovered := false
var _navigation := MenuNavigation.new()
var _pause := PauseMenu.new(self,_navigation)
var _options := OptionsMenu.new(self,_navigation)
var _training := TrainingMenu.new(self,_navigation)
var _title := TitleMenu.new(self,_navigation)
var _scores := ScoresMenu.new(self,_navigation)
var _menu_input := MenuInput.new(self,_navigation)


func _ready() -> void:
	get_window().title = Language.TITLE
	_profile.read()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	add_child(_audio)
	add_child(_haptics)
	_haptics.configure(_profile.vibration_enabled, _profile.vibration_intensity)
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
	_pause_layer = MenuOverlay.new(self,_options,_pause,_training,_scores)
	add_child(_pause_layer)
	_frame_layer = _add_interface_layer(_draw_static_interface)
	_panel_layer = _add_interface_layer(_draw_panel)
	_about = AboutPanel.new()
	_about.closed.connect(_close_about)
	_about.link_requested.connect(_open_about_link)
	add_child(_about)
	add_child(_fps_counter)
	_fps_counter.set_enabled(_profile.show_fps)
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
	if _focused:
		_haptics.handle_input(event)
	if _menu_input.handle_input(event):
		return
	var mask := _read_controls()
	if not (mask & Pilot.FIRE):
		_wait_for_fire_release = false
	if not _pause.active:
		_pressed |= mask & ~_held
	_held = mask


func _about_is_open() -> bool:
	return _about != null and _about.visible


func _logo_regions() -> Array[Rect2]:
	var regions: Array[Rect2] = []
	if not _focused or _about_is_open() or _scores.entry != null or _scores.results_open or _scores.tables_open:
		return regions
	regions.append(PORTRAIT_HEADER_LOGO if _profile.portrait else HEADER_LOGO)
	if not _attract_active or _pause.active or _options.opened or _training.opened or _training.result_open or _attract.screen() != Attract.Screen.TITLE_TEXT:
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
	_haptics.stop()
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


func _field_input_position(position: Vector2) -> Vector2:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	return (position - field.position) * Vector2(Pilot.FIELD_SIZE) / field.size


func _exercise_label() -> String:
	return _training.target_label(_exercise_kind, _exercise_target)


func _return_to_title() -> void:
	_haptics.stop()
	_training.opened = false
	_training.result_open = false
	_combat_impacts.clear()
	_audio.stop()
	_audio.set_paused(false)
	_attract = Attract.new()
	_attract_active = true
	_motion.reset()
	_visual_tick = float(_simulation_tick)
	_pause.active = false
	_options.opened = false
	_scores.reset()
	_elapsed_usec = 0
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	_redraw()


func _restart(practice: bool, players := 1) -> void:
	_haptics.stop()
	_training.opened = false
	_training.result_open = false
	_combat_impacts.clear()
	_scores.reset()
	_run_difficulty = _exercise_difficulty if practice else _profile.difficulty
	_attract_active = false
	_pause.active = false
	_options.opened = false
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


func _score_mode() -> int:
	return _profile.difficulty if _attract_active and not _scores.results_open and _scores.entry == null else _run_difficulty


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_haptics.connection_changed(device, connected)
	if not connected and _scores.entry != null:
		_scores.entry.release_pad(device)
	if not connected and _options.gamepad_disconnected():
		_redraw()


func _save_profile() -> void:
	_options.save_failed = _profile.write() != OK
	if _options.save_failed:
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
		_focused and not _attract_active and not _pause.active and not _options.opened
		and _scores.entry == null and not _scores.results_open and not _scores.tables_open
		and not _training.opened and not _training.result_open
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
			_haptics.stop()
			_focused = false
			_update_cursor()
			_audio.set_paused(true)
			_held = 0
			_pressed = 0
			_last_input = 0
			_options.cancel_capture()
			if _scores.entry != null:
				_scores.entry.release_pad()
			_redraw()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_audio.set_paused(_pause.active or _options.opened or _about_is_open())
			_last_usec = Time.get_ticks_usec()
			_redraw()


func _process(delta: float) -> void:
	_haptics.set_gameplay_active(_in_play())
	_update_cursor()
	_update_logo_hover(get_global_mouse_position())
	if not _focused or _pause.active or _options.opened or _scores.results_open or _scores.tables_open or _training.opened or _training.result_open or _about_is_open():
		return
	if _scores.entry != null:
		if _scores.entry.repeat(delta):
			_redraw()
		return
	var now := Time.get_ticks_usec()
	var duration_usec := now - _last_usec
	_last_usec = now
	_advance_frame(duration_usec, _read_controls())


func _advance_starfield() -> void:
	# Une mise à jour par image de rendu. La VSync cadence sa présentation.
	if _focused and not _pause.active and not _about_is_open() and _starfield.is_visible_in_tree() and get_window().mode != Window.MODE_MINIMIZED:
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
		if _training.result_open:
			_elapsed_usec = 0
			break
		if _session.finished:
			_scores.finish_session()
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
	if _run != previous or _run.combat != previous_combat or _run.phase != phase:
		print("SESSION cycle=%d wave=%d phase=%s modules=%d lives=%d audio=%s" % [
			_run.cycle, _cycle_wave(), ArcadeRun.Phase.keys()[_run.phase],
			_run.attached, _run.lives, _profile.audio_bank])
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
		_play_feedback(ArcadeAudio.enemy_cue(Presentation.enemy_kind(_cycle_wave())))
	if _session is TrainingSession:
		var training := _session as TrainingSession
		if training.completed:
			_training.result_open = true
			_training.choice = 0
		if training.pending:
			if not was_training_pending:
				_audio.stop()
				var cue := "success" if training.success else "loss"
				if training.kind == TrainingSession.Kind.DOCKING and not training.success:
					cue = "crash" if _run.docking.stage == Docking.Stage.COLLISION else "timeout"
				_play_feedback(cue)
			return
	if _run != previous:
		_audio.stop()
		_play_feedback("launch" if _ship_ascending(_run) else "start")
		return
	if not was_ascending and _ship_ascending(_run):
		_play_feedback("cycle" if _run.phase == ArcadeRun.Phase.CYCLE_END else "launch")
		return
	if _run.phase != phase:
		if _run.phase == ArcadeRun.Phase.REPLACEMENT and phase == ArcadeRun.Phase.COMBAT:
			_play_feedback("loss")
		elif _run.phase == ArcadeRun.Phase.DOCKING:
			_play_feedback("dock")
	elif _run.docking != null and _run.docking.stage != dock_stage:
		match _run.docking.stage:
			Docking.Stage.SUCCESS:
				_play_feedback("success")
			Docking.Stage.COLLISION:
				_play_feedback("crash")
			Docking.Stage.TIMED_OUT:
				_play_feedback("timeout")
	elif phase == ArcadeRun.Phase.COMBAT and _run.wave_number == wave and _run.combat.pilot.frame > frame:
		if _run.combat.impact_age == 0:
			_play_feedback(ArcadeAudio.enemy_cue(Presentation.enemy_kind(_cycle_wave()), true))
		for shot in _run.combat.pilot.active_shots():
			if (shot + Vector2i(0, Pilot.SHOT_STEP)) not in shots:
				_play_feedback("shot")
				break
	if not had_reserve and _run.bonus_reserve:
		_play_feedback("bonus")


func _play_feedback(cue: String) -> void:
	var x := Pilot.FIELD_SIZE.x * 0.5
	if cue == "shot":
		x = _run.combat.pilot.ship_x - 1.0
	elif cue in ["loss", "impact"] or cue.begins_with("hit_"):
		x = _run.combat.impact_position.x
	elif cue in ["success", "crash"] and _run.docking != null:
		x = _run.docking.display_position().x
	elif cue.begins_with("enemy_") and _run.combat.wave.flight_sound_source != null:
		x = _run.combat.wave.flight_sound_source.display_position().x
	_audio.play(cue, ArcadeAudio.pan_for_x(x))
	if (cue in ["loss", "crash"] or cue == "success"
			and _run.phase == ArcadeRun.Phase.DOCKING and _run.docking != null
			and _run.docking.stage == Docking.Stage.SUCCESS):
		_haptics.play(cue)


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
	_fps_counter.set_enabled(_profile.show_fps)
	_haptics.set_gameplay_active(_in_play())
	if not _attract_active and _run.combat.wave.flight_sound_source != null:
		_audio.set_enemy_pan(ArcadeAudio.pan_for_x(_run.combat.wave.flight_sound_source.display_position().x))
	if _panel_layer != null:
		_refresh_interface()
	queue_redraw()


func _refresh_interface() -> void:
	var portrait := _profile.portrait
	var language := _profile.language
	var title_visible := _attract_active and not _scores.tables_open and _scores.entry == null and _attract.screen() == Attract.Screen.TITLE_TEXT
	_logo_layer.refresh([portrait, title_visible, _logo_hovered,
		_attract.title_line_progress(1, _visual_tick - _simulation_tick) if title_visible else 0.0])
	var controls_state := [hash(_profile.key_bindings), hash(_profile.button_bindings)]
	_frame_layer.refresh([portrait, _uses_hd(), language, controls_state])
	_pause_layer.refresh(controls_state)
	var demo := _attract_active and _attract.screen() == Attract.Screen.DEMO
	var results := _scores.results_open and not _scores.rows.is_empty()
	var duo := _scores.rows.size() == 2 if results else not _attract_active and _session.runs.size() == 2
	var first_score: int = _scores.rows[0].score if results else (0 if _attract_active else _session.runs[0].score())
	var second_score: int = _scores.rows[1].score if results and duo else (_session.runs[1].score() if duo else 0)
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
		TitleMenu.TRAINING_BUTTON.has_point(pointer), TitleMenu.PORTRAIT_TRAINING_BUTTON.has_point(pointer),
		hash(_profile.key_bindings), hash(_profile.button_bindings),
		_score_mode(),
		TitleMenu.SCORES_BUTTON.has_point(pointer), TitleMenu.PORTRAIT_SCORES_BUTTON.has_point(pointer),
		_scores.entry != null or _scores.results_open or _scores.tables_open]
	if _profile.portrait:
		if _attract_active:
			state.append(_profile.difficulty)
			state.append(TitleMenu.PORTRAIT_OPTIONS_BUTTON.has_point(get_global_mouse_position()))
		else:
			state.append_array([_run.lives, _run.phase, _run.cycle, _cycle_wave(),
				duo, _session.player, _run.attached])
	else:
		state.append(_focused)
		if _focused:
			state.append(_profile.muted)
			if _attract_active:
				state.append_array([_profile.difficulty, TitleMenu.SOLO_BUTTON.has_point(pointer),
					TitleMenu.DUO_BUTTON.has_point(pointer), TitleMenu.OPTIONS_BUTTON.has_point(pointer)])
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
		if _scores.tables_open:
			_scores.draw_tables(self)
		elif _scores.results_open and _scores.results_page == 0:
			_scores.draw_results(self)
		elif _scores.entry == null:
			_draw_attract()
		if not _options.opened and not _scores.results_open and not _scores.tables_open and _scores.entry == null and (_profile.recovered_backup or _profile.unreadable_profile):
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
	if not _attract_active or _scores.tables_open or _scores.entry != null or _attract.screen() != Attract.Screen.TITLE_TEXT:
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
	if _scores.entry != null or _scores.results_open or _scores.tables_open:
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
		_title.draw(canvas)
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
	_title.draw_hints(canvas)


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
	_title.draw_hints(canvas)


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
	var results := _scores.results_open and not _scores.rows.is_empty()
	var score: int = _scores.rows[0].score if results else (0 if _attract_active else _session.runs[0].score())
	var duo := _scores.rows.size() == 2 if results else not _attract_active and _session.runs.size() == 2
	var second_score: int = _scores.rows[1].score if results and duo else (_session.runs[1].score() if duo else 0)
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
			_scores.draw_table(self)
		Attract.Screen.DEMO:
			_draw_demo()


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


func _draw_portrait_hud(canvas: Node2D) -> void:
	_draw_text(canvas, Vector2(198, 24), _translate("Difficulté"), 12, MUTED)
	_draw_text(canvas, Vector2(198, 44), _translate(ArcadeProfile.DIFFICULTY_LABELS[_score_mode()]), 15, SHOT)
	if _attract_active:
		_title.draw_options_button(canvas, TitleMenu.PORTRAIT_OPTIONS_BUTTON, get_global_mouse_position())
		_title.draw_menu_button(canvas, TitleMenu.PORTRAIT_SCORES_BUTTON, _translate("Classements"), "F4")
		_title.draw_menu_button(canvas, TitleMenu.PORTRAIT_TRAINING_BUTTON, _translate("Entraînement"), "F2")
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


func _sync_menu_input() -> void:
	_haptics.stop()
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
