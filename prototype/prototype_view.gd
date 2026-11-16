extends Node2D

const Pilot = preload("res://pilot.gd")
const ArcadeRun = preload("res://arcade_run.gd")
const Docking = preload("res://docking.gd")
const Attract = preload("res://attract.gd")
const FlightView = preload("res://flight_view.gd")
const FlightMotion = preload("res://flight_motion.gd")
const Presentation = preload("res://flight_presentation.gd")
const CombatWave = preload("res://combat_wave.gd")
const ArcadeAudio = preload("res://arcade_audio.gd")
const ArcadeProfile = preload("res://arcade_profile.gd")
const ArcadeSession = preload("res://arcade_session.gd")
const Effects = preload("res://arcade_effects.gd")
const SHIP_BURST_FRAMES := 36
const MAX_CATCHUP_USEC := 8 * Pilot.FRAME_USEC
const LANDSCAPE_SIZE := Vector2i(1280, 720)
const PORTRAIT_SIZE := Vector2i(560, 780)
const FULL_HD := Vector2i(1920, 1080)
const FIELD := Rect2(124, 24, 504, 672)
const PORTRAIT_FIELD := Rect2(28, 65, 504, 672)
const LABEL_X := 704
const PANEL_END := 1156
const RECORD_X := 952
const SOLO_BUTTON := Rect2(LABEL_X, 468, PANEL_END - LABEL_X, 50)
const DUO_BUTTON := Rect2(LABEL_X, 529, PANEL_END - LABEL_X, 45)
const PAUSE_LABELS := ["Reprendre", "Accueil", "Quitter"]
const PAUSE_BUTTON := Rect2(52, 107, 120, 17)
const PAUSE_SPACING := 20.0
const BACKGROUND := Color("#080f1c")
const GRID := Color("#142239")
const BORDER := Color("#314765")
const PRIMARY := Color("#edf5ff")
const MUTED := Color("#9eafc6")
const SHIP := Color("#70edcd")
const SHOT := Color("#ffe59a")
const ENEMY := Color("#bc87ff")
const ENEMY_CORE := Color("#b7e9ff")

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
var _star_frame := 0
var _visual_tick := 0.0
var _motion := FlightMotion.new()
var _focused := true
var _paused := false
var _pause_choice := 0
var _wait_for_fire_release := false
var _diagnostics := false
var _flight_view: FlightView


func _ready() -> void:
	_profile.read()
	add_child(_audio)
	_audio.set_muted(_profile.muted)
	if DisplayServer.get_name() != "headless":
		_flight_view = FlightView.new()
		add_child(_flight_view)
		_apply_display()
	_bind_action(&"move_left", [KEY_LEFT, KEY_Q, KEY_A], JOY_BUTTON_DPAD_LEFT, -1.0)
	_bind_action(&"move_right", [KEY_RIGHT, KEY_D], JOY_BUTTON_DPAD_RIGHT, 1.0)
	_bind_action(&"fire", [KEY_SPACE], JOY_BUTTON_A)
	_last_usec = Time.get_ticks_usec()


func _bind_action(action: StringName, keys: Array[int], button: int, axis_value := 0.0) -> void:
	InputMap.add_action(action, 0.5)
	for code in keys:
		var key := InputEventKey.new()
		key.keycode = code
		InputMap.action_add_event(action, key)
	var joy_button := InputEventJoypadButton.new()
	joy_button.device = -1
	joy_button.button_index = button
	InputMap.action_add_event(action, joy_button)
	if axis_value != 0.0:
		var joy_axis := InputEventJoypadMotion.new()
		joy_axis.device = -1
		joy_axis.axis = JOY_AXIS_LEFT_X
		joy_axis.axis_value = axis_value
		InputMap.action_add_event(action, joy_axis)


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
	if not _focused or event.is_echo():
		return
	if _paused and _handle_pause_input(event):
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R, KEY_F2:
				_restart(event.keycode == KEY_F2, _session.runs.size() if not _attract_active else 1)
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
				if _attract_active:
					_profile.bonus_index = 1 - _profile.bonus_index
					_save_profile()
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
				queue_redraw()
				return
	if event is InputEventJoypadButton and event.pressed:
		if _attract_active and event.button_index == JOY_BUTTON_Y:
			_restart(false, 2)
			return
		if not _attract_active and event.button_index == JOY_BUTTON_START:
			_toggle_pause()
			return
		if _paused and event.button_index == JOY_BUTTON_B:
			_return_to_title()
			return
	if _attract_active and not _profile.portrait and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if SOLO_BUTTON.has_point(event.position):
				_restart(false)
				return
			if DUO_BUTTON.has_point(event.position):
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
	queue_redraw()


func _pause_button(index: int) -> Rect2:
	return Rect2(PAUSE_BUTTON.position + Vector2(0, PAUSE_SPACING * index), PAUSE_BUTTON.size)


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
		var field := PORTRAIT_FIELD if _profile.portrait else FIELD
		var point: Vector2 = (event.position - field.position) * Vector2(Pilot.FIELD_SIZE) / field.size
		for index in range(PAUSE_LABELS.size()):
			if _pause_button(index).has_point(point):
				_pause_choice = index
				queue_redraw()
				if event is InputEventMouseButton:
					_confirm_pause_choice()
				return true
	if direction != 0:
		_pause_choice = posmod(_pause_choice + direction, PAUSE_LABELS.size())
		queue_redraw()
		return true
	return false


func _confirm_pause_choice() -> void:
	match _pause_choice:
		0:
			_toggle_pause()
		1:
			_return_to_title()
		2:
			get_tree().quit()


func _return_to_title() -> void:
	_audio.stop()
	_audio.set_paused(false)
	_attract = Attract.new()
	_attract_active = true
	_motion.reset()
	_visual_tick = float(_star_frame)
	_paused = false
	_elapsed_usec = 0
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	queue_redraw()


func _restart(practice: bool, players := 1) -> void:
	_attract_active = false
	_paused = false
	var threshold: int = ArcadeProfile.BONUS_THRESHOLDS[_profile.bonus_index]
	_session = ArcadeSession.new(1 if practice else players, threshold, practice)
	_motion.reset()
	_motion.capture_live(_run, _star_frame, 0.0, [])
	_visual_tick = float(_star_frame)
	_audio.stop()
	_audio.set_paused(false)
	_audio.play("dock" if practice else "start")
	_elapsed_usec = 0
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_last_input = 0
	_held = _read_controls()
	_wait_for_fire_release = bool(_held & Pilot.FIRE)
	queue_redraw()


func _save_profile() -> void:
	if _profile.write() != OK:
		push_warning("Impossible d’enregistrer les réglages ou les scores.")
	queue_redraw()


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
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
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_audio.set_paused(true)
			_held = 0
			_pressed = 0
			_last_input = 0
			queue_redraw()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_audio.set_paused(_paused)
			_last_usec = Time.get_ticks_usec()
			queue_redraw()


func _process(_delta: float) -> void:
	if not _focused or _paused:
		return
	var now := Time.get_ticks_usec()
	var duration_usec := now - _last_usec
	_last_usec = now
	_advance_frame(duration_usec, _read_controls())


func _advance_frame(duration_usec: int, input_mask: int) -> void:
	_elapsed_usec = mini(_elapsed_usec + duration_usec, MAX_CATCHUP_USEC)
	_held = input_mask
	while _elapsed_usec >= Pilot.FRAME_USEC:
		_star_frame += 1
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
			_motion.capture_demo(_attract, _star_frame)
			continue
		_step_session(_last_input)
		if _session.finished:
			if not _session.practice:
				var changed := false
				for player_run in _session.runs:
					changed = _profile.record(player_run.score()) or changed
				if changed:
					_save_profile()
			_return_to_title()
			break
	_visual_tick = _star_frame + float(_elapsed_usec) / Pilot.FRAME_USEC
	queue_redraw()


func _step_session(input_mask: int) -> void:
	var previous := _run
	var phase := previous.phase
	var wave := previous.wave_number
	var dock_stage := previous.docking.stage if previous.docking != null else -1
	var frame := previous.combat.pilot.frame
	var shots := previous.combat.pilot.active_shots()
	_session.step(input_mask)
	_motion.capture_live(_run, _star_frame, _bank_command() if _run == previous else 0.0, shots)
	if _run != previous:
		_audio.stop()
		_audio.play("start")
		return
	if _run.phase != phase:
		if _run.phase == ArcadeRun.Phase.REPLACEMENT and phase == ArcadeRun.Phase.COMBAT:
			_audio.play("loss")
		elif _run.phase == ArcadeRun.Phase.DOCKING:
			_audio.play("dock")
		elif _run.phase == ArcadeRun.Phase.CYCLE_END:
			_audio.play("cycle")
		elif _run.phase == ArcadeRun.Phase.COMBAT:
			_audio.play("wave")
	elif _run.docking != null and _run.docking.stage != dock_stage:
		match _run.docking.stage:
			Docking.Stage.SUCCESS:
				_audio.play("success")
			Docking.Stage.COLLISION:
				_audio.play("crash")
			Docking.Stage.TIMED_OUT:
				_audio.play("timeout")
	elif phase == ArcadeRun.Phase.COMBAT and _run.wave_number != wave:
		_audio.play("wave")
	elif phase == ArcadeRun.Phase.COMBAT and _run.combat.pilot.frame > frame:
		if _run.combat.impact_age == 0:
			_audio.play("impact")
		for shot in _run.combat.pilot.active_shots():
			if (shot + Vector2i(0, Pilot.SHOT_STEP)) not in shots:
				_audio.play("shot")
				break


func _draw() -> void:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	draw_rect(field, BACKGROUND)
	if _uses_hd():
		_flight_view.start_frame(_visual_tick)
		draw_texture_rect(_flight_view.get_texture(), field, false)
	draw_set_transform(field.position, 0.0, field.size / Vector2(Pilot.FIELD_SIZE))
	if _attract_active:
		_draw_attract()
	else:
		if _diagnostics:
			_draw_grid()
		if _run.phase == ArcadeRun.Phase.DOCKING:
			_draw_docking()
			_draw_field_docking_status()
		else:
			_draw_combat()
			if _run.phase == ArcadeRun.Phase.GAME_OVER and _run.game_over_shows_message():
				_field_text(112, 110, "JEU %d TERMINÉ" % (_session.player + 1), SHOT, 11)
				_field_text(112, 126, "ESSAYEZ À NOUVEAU", SHOT, 9)
	if _paused:
		_draw_pause_menu()
	elif not _focused:
		draw_rect(Rect2(14, 102, 196, 50), Color(0.02, 0.04, 0.07, 0.92))
		_field_text(112, 123, "PAUSE", PRIMARY, 13)
	if _uses_hd():
		_flight_view.finish_frame()
	draw_set_transform(Vector2.ZERO)
	draw_rect(field, BORDER, false, 1.0)
	if _uses_hd():
		_draw_chrome_frame(field)
	if _profile.portrait:
		_draw_portrait_hud()
	else:
		_draw_panel()


func _draw_pause_menu() -> void:
	var panel := Rect2(43, 83, 138, 88)
	draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	draw_rect(panel, BORDER, false, 0.65)
	_field_text(112, 100, "PAUSE", PRIMARY, 11)
	for index in range(PAUSE_LABELS.size()):
		var button := _pause_button(index)
		var selected := index == _pause_choice
		draw_rect(button, GRID if selected else BACKGROUND)
		draw_rect(button, SHOT if selected else BORDER, false, 0.5)
		_field_text(112, button.position.y + 11.5, PAUSE_LABELS[index], SHOT if selected else PRIMARY, 8)


func _draw_chrome_frame(field: Rect2) -> void:
	var surround := field.grow(7.0)
	draw_rect(surround, Color("#121d2a"), false, 4.0)
	draw_rect(surround.grow(2.0), Color("#334359"), false, 1.0)
	for x in [surround.position.x, surround.end.x]:
		for y in [surround.position.y, surround.end.y]:
			var point := Vector2(x, y)
			var inward := (surround.get_center() - point).sign()
			draw_polyline(PackedVector2Array([
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
	draw_line(origin + Vector2(0, 12), origin + Vector2(0, 15), SHOT, 1.0)


func _bank_command() -> float:
	if _last_input & Pilot.LEFT:
		return -9.0
	if _last_input & Pilot.RIGHT:
		return 9.0
	return 0.0


func _render_frame(frame: int) -> float:
	return frame + (_visual_tick - _star_frame)


func _visual_point(track: FlightMotion.Track, point: Vector2) -> Vector2:
	return track.point(point, _visual_tick) if not _diagnostics else point


func _draw_combat() -> void:
	var combat := _run.combat
	if _run.phase == ArcadeRun.Phase.COMBAT:
		_draw_enemies()
	elif _run.phase == ArcadeRun.Phase.REPLACEMENT:
		_draw_enemy_withdrawal()
	var pilot := combat.pilot
	var last_module := _last_module(_run.attached)
	if _run.phase == ArcadeRun.Phase.REPLACEMENT:
		var entrance_y := _run.entrance_ship_y()
		if entrance_y >= 0:
			var anchor := _visual_point(_motion.ship, Vector2(Pilot.START_X, entrance_y))
			for module in range(3, 0, -1):
				if _run.attached & (1 << (module - 1)):
					_draw_module(anchor + Vector2(0, (module - 1) * 8), module, SHIP, module == last_module)
	elif _run.phase == ArcadeRun.Phase.CYCLE_END:
		# pr11c : le vaisseau monte, « PLUS LOIN » (x 73-143, y 112-118 sur les PNG).
		if _run.cycle_end_shows_ship():
			var rise := _run.cycle_end_rise()
			var anchor := _visual_point(_motion.ship, Vector2(pilot.ship_x, pilot.assembly_y_offset - rise))
			for module in range(3, 0, -1):
				if pilot.has_module(module):
					_draw_module(anchor + Vector2(0, pilot.module_y(module)), module, SHIP, module == last_module)
		if _run.cycle_end_shows_message():
			_field_text(108, 119, "PLUS LOIN", PRIMARY)
	elif _run.phase != ArcadeRun.Phase.GAME_OVER:
		# Dessiner la base d'abord, puis les modules supérieurs.
		var anchor := _visual_point(_motion.ship, Vector2(pilot.ship_x, pilot.assembly_y_offset))
		for module in range(3, 0, -1):
			if pilot.has_module(module):
				_draw_module(anchor + Vector2(0, pilot.module_y(module)), module, SHIP, module == last_module)
	if _run.phase == ArcadeRun.Phase.COMBAT:
		for point in pilot.active_shots():
			_draw_shot(_motion.projectile(point, _visual_tick) if _uses_hd() else Vector2(point))
	_draw_impact(combat)


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
	var target := _run.docking_target()
	if dock.stage == Docking.Stage.SUCCESS:
		var assembled := _run.attached | (1 << (target - 1))
		for module in range(3, 0, -1):
			if assembled & (1 << (module - 1)):
				var origin := Presentation.docked_module_origin(module, target, Docking.TARGET.y, Docking.TARGET.x)
				_draw_module(origin, module, SHIP, module == target)
		return
	if dock.target_y <= 233:
		var target_y := _visual_point(_motion.dock_target, Vector2(0, dock.target_y)).y
		_draw_module(Presentation.docking_module_origin(target, target_y, Docking.TARGET.x), target, ENEMY_CORE)
	var point := dock.display_position()
	if dock.stage != Docking.Stage.COLLISION and not _diagnostics:
		point = _motion.docking_ship(point, _visual_tick)
	if dock.is_i_and_ii():
		point.y -= 16
	if dock.stage == Docking.Stage.COLLISION:
		if _uses_hd():
			var age := dock._result_frames
			if age < SHIP_BURST_FRAMES:
				Effects.burst(self, point, _render_frame(age) / SHIP_BURST_FRAMES, 1.6, true)
		else:
			draw_arc(point, 12.0, 0.0, TAU, 16, SHOT, 1.0, true)
	else:
		_draw_module(point, dock.module, SHIP, not dock.is_i_and_ii())
		if dock.is_i_and_ii():
			_draw_module(point + Vector2(0, 8), 2, SHIP, true)
	if _diagnostics:
		draw_line(Vector2(Docking.TARGET.x, 36), Vector2(Docking.TARGET.x, 238), BORDER)


func _last_module(mask: int) -> int:
	for module in range(3, 0, -1):
		if mask & (1 << (module - 1)):
			return module
	return 0


func _draw_shot(point: Vector2) -> void:
	if _uses_hd():
		var center := point + Vector2(0.5, 0)
		var end := center + Vector2(0, Pilot.SHOT_LENGTH)
		draw_line(center, end, Color(0.38, 0.66, 1.0, 0.20), 2.5, true)
		draw_line(center, end, Color("#f2f8ff"), 0.85, true)
	else:
		draw_rect(Rect2(point, Vector2(1, Pilot.SHOT_LENGTH)), SHOT)


func _draw_field_docking_status() -> void:
	var dock := _run.docking
	match dock.stage:
		Docking.Stage.INTRO:
			_field_text(112, 115, "RAVITAILLEMENT", SHIP, 11)
		Docking.Stage.APPROACH:
			_field_text(112, 55, "CHRONO", SHOT, 10)
			_field_text(112, 71, dock.display_clock(), PRIMARY, 10)
		Docking.Stage.SUCCESS:
			_draw_congratulations(dock.bonus, _docking_multiplier(dock))
		Docking.Stage.TIMED_OUT:
			_field_text(112, 55, "CHRONO", SHOT, 10)
			_field_text(112, 71, "00:0", PRIMARY, 10)
			_field_text(112, 188, "DOMMAGE !!", SHOT, 11)


func _draw_congratulations(bonus: int, multiplier: int) -> void:
	_field_text(112, 55, "BONUS", SHIP, 10)
	_field_text(112, 71, "%02d × %d = %d" % [bonus / multiplier, multiplier, bonus], SHIP, 10)
	_field_text(112, 188, "BRAVO !!", SHOT, 11)


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
			if _diagnostics:
				_draw_enemy_bounds(enemy.position)
			continue
		if _uses_hd():
			var growth := Presentation.meteor_scale(enemy.opening_left) if wave.falling else 1.0
			if wave.rows and enemy.phase == CombatWave.Flight.OPENING:
				growth = Presentation.capsule_scale(enemy.opening_left)
			var diving := wave.rows and enemy.phase == CombatWave.Flight.ROW_DIVE
			_flight_view.enemy(point, kind, variant, track.heading(logical_point, heading, _visual_tick), _render_frame(_run.frame), growth, diving, index)
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
	var hitbox := Rect2(Vector2(position) - Vector2(17, 4), Vector2(16, 12))
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
	if _uses_hd() and _run.phase == ArcadeRun.Phase.REPLACEMENT and combat.outcome == ArcadeRun.CombatRound.Outcome.MODULE_LOST:
		var age := _run.replacement_elapsed()
		if age < SHIP_BURST_FRAMES:
			Effects.burst(self, combat.impact_position, _render_frame(age) / SHIP_BURST_FRAMES, 1.55, true)
		return
	if combat.impact_age >= ArcadeRun.CombatRound.IMPACT_FRAMES:
		return
	var progress := _render_frame(combat.impact_age) / ArcadeRun.CombatRound.IMPACT_FRAMES
	var enemy := combat.impacted_enemy
	if enemy != null and _cycle_wave() <= 2:
		var side := combat.wave.enemies.find(enemy) & 1
		var opening_left := enemy.opening_left if enemy.phase == CombatWave.Flight.OPENING else 0
		var heading := Presentation.ring_axis(Vector2(enemy.velocity), opening_left)
		var growth := Presentation.ring_scale(opening_left)
		var center := combat.impact_position + heading * (3.9 * growth if side == 0 else -3.9 * growth)
		if _uses_hd():
			Effects.burst(self, center, progress, 0.62 * growth)
		else:
			draw_arc(center, (2.0 + 4.0 * progress) * growth, 0.0, TAU, 12, Color(SHOT, 1.0 - progress), 0.8, true)
		return
	if _uses_hd():
		Effects.burst(self, combat.impact_position, progress)
		return
	var tint := Color(SHOT, 1.0 - progress)
	draw_arc(combat.impact_position, 4.0 + 8.0 * progress, 0.0, TAU, 18, tint, 1.0, true)


func _draw_panel() -> void:
	_text(73, "SWARMATTACK", 39, PRIMARY)
	_text(104, "Défense orbitale", 18, SHIP)
	draw_line(Vector2(LABEL_X, 127), Vector2(PANEL_END, 127), BORDER)
	_text(163, "SCORE", 13, MUTED)
	_text(205, "%06d" % _run.score(), 36, PRIMARY)
	_draw_text(Vector2(RECORD_X, 163), "CHAMPION", 13, MUTED)
	_draw_text(Vector2(RECORD_X, 205), "%06d" % maxi(_profile.scores[0], _run.score()), 32, SHOT)
	_text(257, "COMMANDES", 13, MUTED)
	_text(286, "← / → ou Q / D   Déplacer", 18, PRIMARY)
	_text(318, "Espace / A   Tirer · Freiner en approche", 16, MUTED)
	_text(348, "Échap   Pause     R   Recommencer", 16, MUTED)
	draw_line(Vector2(LABEL_X, 384), Vector2(PANEL_END, 384), BORDER)
	if not _focused:
		_text(425, "En pause", 20, SHOT)
		return
	if _attract_active:
		_draw_attract_panel()
		return
	if _run.phase == ArcadeRun.Phase.DOCKING:
		_draw_docking_panel()
		return
	match _run.phase:
		ArcadeRun.Phase.REPLACEMENT:
			_text(425, "Cycle %d · entrée du module I" % _run.cycle if _run.is_cycle_entrance() else "Vaisseau perdu", 20, SHOT)
		ArcadeRun.Phase.CYCLE_END:
			_text(425, "Plus loin · fin du cycle %d" % _run.cycle, 20, PRIMARY)
		ArcadeRun.Phase.GAME_OVER:
			if _run.game_over_shows_message():
				_text(425, "JOUEUR %d · PARTIE TERMINÉE" % (_session.player + 1), 20, SHOT)
				_text(448, "ESSAYEZ A NOUVEAU", 17, SHOT)
			else:
				_text(425, "Vaisseau perdu", 20, SHOT)
		_:
			_text(425, "Cycle %d · vague %d / %d" % [_run.cycle, _cycle_wave(), Presentation.WAVES_PER_CYCLE], 20, PRIMARY)
	_text(463, "%03d points   ·   %d cibles   ·   Vies %d" % [
		_run.score(), _run.combat.wave.remaining, _run.lives
	], 17, MUTED)
	if _session.runs.size() == 2:
		_text(489, _turn_label(), 16, SHIP)
	if _diagnostics:
		_draw_readout()
	_draw_options()


func _draw_docking_panel() -> void:
	var dock := _run.docking
	match dock.stage:
		Docking.Stage.SUCCESS:
			_text(425, "Bravo ! Amarrage réussi", 20, SHIP)
			var multiplier := _docking_multiplier(dock)
			_text(463, "Bonus   %d × %d = %d" % [dock.bonus / multiplier, multiplier, dock.bonus], 17, SHOT)
		Docking.Stage.COLLISION:
			_text(425, "Collision à l’amarrage", 20, SHOT)
		Docking.Stage.TIMED_OUT:
			_text(425, "Dommage ! Temps écoulé", 20, SHOT)
		_:
			_text(425, "Mission amarrage", 20, PRIMARY)
			_text(463, "Chrono   %s" % dock.display_clock(), 17, SHOT)
	_text(510, "%03d points   ·   Vies %d" % [_run.score(), _run.lives], 17, MUTED)
	if _session.runs.size() == 2:
		_text(569, _turn_label(), 16, SHIP)
	if _diagnostics:
		var point := dock.display_position()
		_text(543, "Module %d    x %d    y %d" % [dock.module, point.x, point.y], 17, SHIP)
	_draw_options()


func _draw_readout() -> void:
	var pilot := _run.combat.pilot
	_text(510, "Image %d   ·   Pas de 16,5 ms" % _run.frame, 17, MUTED)
	_text(543, "Vaisseau %s    x %d    y %d" % [
		_run.ship_label(), pilot.ship_x, pilot.ship_y()
	], 17, SHIP)
	var shots := pilot.active_shots()
	if shots.is_empty():
		_text(576, "Projectile    prêt", 17, MUTED)
	else:
		var point: Vector2i = shots[0]
		var suffix := "" if shots.size() == 1 else "    +%d" % (shots.size() - 1)
		_text(576, "Projectile    x %d    y %d%s" % [point.x, point.y, suffix], 17, SHOT)
	var commands := PackedStringArray()
	if _last_input & Pilot.LEFT:
		commands.append("gauche")
	if _last_input & Pilot.RIGHT:
		commands.append("droite")
	if _last_input & Pilot.FIRE:
		commands.append("tir")
	_text(609, "Entrées    %s" % (" + ".join(commands) if not commands.is_empty() else "—"), 17, MUTED)


func _field_text(center_x: float, y: float, label: String, color: Color, size := 8) -> void:
	var field := PORTRAIT_FIELD if _profile.portrait else FIELD
	var scale := field.size / Vector2(Pilot.FIELD_SIZE)
	var font_size := size * 3
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_set_transform(field.position, 0.0, scale / 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(center_x * 3 - width / 2.0, y * 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	draw_set_transform(field.position, 0.0, scale)


# Le cycle d'attraction rejoue les positions et les états du relevé pr10e.
func _draw_attract() -> void:
	match _attract.screen():
		Attract.Screen.TITLE_TEXT:
			_field_text(112, 103, "SWARMATTACK", PRIMARY, 17)
			var rows := [133, 147, 164, 179, 193]
			for index in range(Attract.TITLE_LINES.size()):
				var progress := _attract.title_line_progress(index)
				if progress <= 0.0:
					continue
				var label: String = Attract.TITLE_LINES[index][0]
				_field_text(112, rows[index], label.substr(0, ceili(label.length() * progress)), SHIP if index < 2 else SHOT)
		Attract.Screen.SCORE_TABLE:
			_field_text(112, 75, "TABLEAU DES SCORES", SHIP, 11)
			for index in range(_profile.scores.size()):
				_field_text(112, 98 + index * 16, "%02d     %06d" % [index + 1, _profile.scores[index]], PRIMARY, 9)
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
					_field_text(112, 55, "CHRONO", SHOT, 10)
					_field_text(112, 71, _attract.demo_clock(), PRIMARY, 10)
				elif _attract.demo_value(target) == 3:
					_field_text(112, 115, "RAVITAILLEMENT", SHIP, 11)
		Attract.SCREEN_RESULT:
			if step == 2:
				_draw_congratulations(1000, 100)
		Attract.SCREEN_TIMEOUT, Attract.SCREEN_TIMEOUT_TEXT:
			_field_text(112, 55, "CHRONO", SHOT, 10)
			_field_text(112, 71, "00:0", PRIMARY, 10)
			if screen_code == Attract.SCREEN_TIMEOUT_TEXT:
				_field_text(112, 188, "DOMMAGE !!", SHOT, 11)


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


func _draw_attract_panel() -> void:
	_text(428, "Partie arcade", 24, PRIMARY)
	var pointer := get_global_mouse_position()
	_draw_button(SOLO_BUTTON, "1 joueur", "ESPACE / A", true, pointer)
	_draw_button(DUO_BUTTON, "2 joueurs en alternance", "2 / Y", false, pointer)
	_text(614, "F3   Réserve à %d points" % ArcadeProfile.BONUS_THRESHOLDS[_profile.bonus_index], 16, MUTED)
	_draw_options()


func _draw_button(rect: Rect2, label: String, shortcut: String, primary: bool, pointer: Vector2) -> void:
	var fill := SHIP if primary else Color("#141f32")
	if rect.has_point(pointer):
		fill = fill.lightened(0.14)
	draw_rect(rect, fill)
	var tint := BACKGROUND if primary else PRIMARY
	_draw_text(rect.position + Vector2(16, 31), label, 17, tint)
	_draw_text(Vector2(rect.end.x - 100, rect.position.y + 30), shortcut, 13, tint)


func _draw_options() -> void:
	_text(651, "F1 Diagnostic    F2 Amarrage    F5 Son %s" % ("coupé" if _profile.muted else "actif"), 14, MUTED)
	_text(675, "F10 Portrait    F11 Plein écran", 14, MUTED)


func _draw_portrait_hud() -> void:
	_draw_text(Vector2(28, 43), "SWARMATTACK", 25, PRIMARY)
	_draw_text(Vector2(328, 43), "%06d    VIES %d" % [_run.score(), _run.lives], 20, SHOT)
	var label := "Espace / A   Solo      2 / Y   Duo      F10   Paysage"
	if not _attract_active:
		label = "%s     Cycle %d · Vague %d     Échap   Pause" % [
			_turn_label(), _run.cycle, _cycle_wave()
		]
	_draw_text(Vector2(28, 761), label, 16, MUTED)


func _turn_label() -> String:
	return "Joueur %d" % (_session.player + 1) if _session.runs.size() == 2 else _run.ship_label()


func _cycle_wave() -> int:
	return Presentation.cycle_wave(_run.wave_number, _run.stage)


func _text(y: float, label: String, size: int, color: Color) -> void:
	_draw_text(Vector2(LABEL_X, y), label, size, color)


func _draw_text(at: Vector2, label: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
