extends Node2D

const Pilot = preload("res://pilot.gd")
const ArcadeRun = preload("res://arcade_run.gd")
const Docking = preload("res://docking.gd")
const Attract = preload("res://attract.gd")
const MAX_CATCHUP_USEC := 8 * Pilot.FRAME_USEC
const FIELD := Rect2(28, 24, 504, 672)
const BACKGROUND := Color("#080f1c")
const GRID := Color("#142239")
const BORDER := Color("#314765")
const PRIMARY := Color("#edf5ff")
const MUTED := Color("#9eafc6")
const SHIP := Color("#70edcd")
const SHOT := Color("#ffe59a")
const ENEMY := Color("#bc87ff")
const ENEMY_CORE := Color("#b7e9ff")
const LABEL_X := 568

var _run := ArcadeRun.new()
var _attract := Attract.new()
var _attract_active := true
var _last_usec := 0
var _elapsed_usec := 0
var _held := 0
var _pressed := 0
var _last_input := 0
var _focused := true
var _diagnostics := true


func _ready() -> void:
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
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R, KEY_F2:
				_restart(event.keycode == KEY_F2)
				return
			KEY_F1:
				_diagnostics = not _diagnostics
				queue_redraw()
				return
	var mask := _read_controls()
	_pressed |= mask & ~_held
	_held = mask


func _restart(practice: bool) -> void:
	_attract_active = false
	_run = ArcadeRun.new()
	if practice:
		_run.practice_docking()
	_elapsed_usec = 0
	_last_usec = Time.get_ticks_usec()
	_pressed = 0
	_last_input = 0
	_held = _read_controls()
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_elapsed_usec = 0
			_held = 0
			_pressed = 0
			_last_input = 0
			queue_redraw()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_last_usec = Time.get_ticks_usec()
			queue_redraw()


func _process(_delta: float) -> void:
	if not _focused:
		return
	var now := Time.get_ticks_usec()
	_elapsed_usec = mini(_elapsed_usec + now - _last_usec, MAX_CATCHUP_USEC)
	_last_usec = now
	if _elapsed_usec < Pilot.FRAME_USEC:
		return
	_held = _read_controls()
	while _elapsed_usec >= Pilot.FRAME_USEC:
		_last_input = _held | _pressed
		_pressed = 0
		_elapsed_usec -= Pilot.FRAME_USEC
		if _attract_active:
			if _last_input & Pilot.FIRE:
				_restart(false)
				break
			_attract.step()
			continue
		_run.step(_last_input)
		if _run.game_over_finished():
			_attract = Attract.new()
			_attract_active = true
	queue_redraw()


func _draw() -> void:
	draw_rect(FIELD, BACKGROUND)
	draw_set_transform(FIELD.position, 0.0, FIELD.size / Vector2(Pilot.FIELD_SIZE))
	if _attract_active:
		_draw_attract()
		draw_set_transform(Vector2.ZERO)
		draw_rect(FIELD, BORDER, false, 1.0)
		_draw_panel()
		return
	if _diagnostics:
		_draw_grid()
	if _run.phase == ArcadeRun.Phase.DOCKING:
		_draw_docking()
	else:
		_draw_combat()
	draw_set_transform(Vector2.ZERO)
	draw_rect(FIELD, BORDER, false, 1.0)
	_draw_panel()


func _draw_grid() -> void:
	for x in range(16, Pilot.FIELD_SIZE.x, 16):
		draw_line(Vector2(x, 0), Vector2(x, Pilot.FIELD_SIZE.y), GRID)
	for y in range(16, Pilot.FIELD_SIZE.y, 16):
		draw_line(Vector2(0, y), Vector2(Pilot.FIELD_SIZE.x, y), GRID)
	if _run.phase == ArcadeRun.Phase.COMBAT:
		for x in [Pilot.MIN_X, Pilot.MAX_X]:
			draw_line(Vector2(x, 184), Vector2(x, 224), BORDER, 0.5)


func _draw_module(origin: Vector2, module: int, tint: Color) -> void:
	var wing := float(4 + 2 * module)
	var hull := PackedVector2Array([
		origin, origin + Vector2(3, 5), origin + Vector2(wing, 9),
		origin + Vector2(2, 8), origin + Vector2(0, 11),
		origin + Vector2(-2, 8), origin + Vector2(-wing, 9), origin + Vector2(-3, 5)
	])
	draw_colored_polygon(hull, tint)
	draw_line(origin + Vector2(0, 3), origin + Vector2(0, 8), BACKGROUND, 0.8)
	draw_line(origin + Vector2(0, 12), origin + Vector2(0, 15), SHOT, 1.0)


func _draw_combat() -> void:
	var combat := _run.combat
	_draw_enemies()
	var pilot := combat.pilot
	if _run.phase == ArcadeRun.Phase.REPLACEMENT:
		var entrance_y := _run.entrance_ship_y()
		if entrance_y >= 0:
			for module in range(3, 0, -1):
				if _run.attached & (1 << (module - 1)):
					_draw_module(Vector2(Pilot.START_X, entrance_y + (module - 1) * 8), module, SHIP)
	elif _run.phase == ArcadeRun.Phase.CYCLE_END:
		# pr11c : le vaisseau monte, « PLUS LOIN » (x 73-143, y 112-118 sur les PNG).
		if _run.cycle_end_shows_ship():
			var rise := _run.cycle_end_rise()
			for module in range(3, 0, -1):
				if pilot.has_module(module):
					_draw_module(Vector2(pilot.ship_x, pilot.module_y(module) - rise), module, SHIP)
		if _run.cycle_end_shows_message():
			_field_text(108, 119, "PLUS LOIN", PRIMARY)
	elif _run.phase != ArcadeRun.Phase.GAME_OVER:
		# Dessiner la base d'abord, puis les modules supérieurs.
		for module in range(3, 0, -1):
			if pilot.has_module(module):
				_draw_module(Vector2(pilot.ship_x, pilot.module_y(module)), module, SHIP)
	for point in pilot.active_shots():
		draw_rect(Rect2(Vector2(point), Vector2(1, Pilot.SHOT_LENGTH)), SHOT)
	_draw_impact(combat)


func _draw_docking() -> void:
	var dock := _run.docking
	if dock.target_y <= 233:
		_draw_module(Vector2(Docking.TARGET.x, dock.target_y + 8), dock.module + 1, ENEMY_CORE)
	var point := dock.display_position()
	if dock.stage == Docking.Stage.COLLISION:
		draw_arc(point, 12.0, 0.0, TAU, 16, SHOT, 1.0, true)
	else:
		_draw_module(point, dock.module, SHIP)
	if _diagnostics:
		draw_line(Vector2(Docking.TARGET.x, 36), Vector2(Docking.TARGET.x, 238), BORDER)


func _draw_enemies() -> void:
	var positions: Array[Vector2] = []
	for enemy in _run.combat.wave.enemies:
		if not enemy.alive:
			continue
		var point: Vector2 = enemy.display_position()
		if point.x < 7 or point.x > 217 or point.y < 7 or point.y > 249:
			continue
		if point in positions:
			continue
		positions.append(point)
		if _diagnostics:
			var hitbox := Rect2(Vector2(enemy.position) - Vector2(17, 4), Vector2(16, 12))
			draw_rect(hitbox.intersection(Rect2(Vector2.ZERO, Vector2(Pilot.FIELD_SIZE))), ENEMY.darkened(0.65), false)
		if _run.combat.wave.falling:
			# Objet en chute (0x09, 0x0a) : losange, forme provisoire.
			var diamond := PackedVector2Array([point + Vector2(0, -7), point + Vector2(4, 0), point + Vector2(0, 7), point + Vector2(-4, 0)])
			draw_colored_polygon(diamond, ENEMY.darkened(0.3))
			draw_circle(point, 2.0, ENEMY_CORE, true, -1.0, true)
			continue
		var tint := SHOT if _run.combat.wave.wide_entry else ENEMY
		draw_arc(point, 6.0, 0.0, TAU, 14, tint, 1.0, true)
		draw_line(point - Vector2(7, 0), point + Vector2(7, 0), ENEMY, 1.0)
		draw_circle(point, 2.4, ENEMY_CORE, true, -1.0, true)


func _draw_impact(combat: ArcadeRun.CombatRound) -> void:
	if combat.impact_age >= ArcadeRun.CombatRound.IMPACT_FRAMES:
		return
	var progress := float(combat.impact_age) / ArcadeRun.CombatRound.IMPACT_FRAMES
	var tint := Color(SHOT, 1.0 - progress)
	draw_arc(combat.impact_position, 4.0 + 8.0 * progress, 0.0, TAU, 18, tint, 1.0, true)


func _draw_panel() -> void:
	_text(72, "SwarmAttack", 36, PRIMARY)
	_text(108, "Moune Creste · Prototype Jeutel", 19, SHIP)
	draw_line(Vector2(LABEL_X, 140), Vector2(928, 140), BORDER)
	_text(181, "Commandes", 20, PRIMARY)
	_text(219, "← / → ou Q / D   Déplacer", 17, MUTED)
	_text(252, "Espace   Tirer ou freiner à l’amarrage", 17, MUTED)
	_text(285, "Manette   Stick ou croix, bouton A", 17, MUTED)
	_text(318, "R   Recommencer   ·   F2   Essai amarrage", 17, MUTED)
	_text(351, "F1   Afficher ou masquer les relevés", 17, MUTED)
	draw_line(Vector2(LABEL_X, 384), Vector2(928, 384), BORDER)
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
				_text(425, "JEU 1 TERMINE", 20, SHOT)
				_text(448, "ESSAYEZ A NOUVEAU", 17, SHOT)
			else:
				_text(425, "Vaisseau perdu", 20, SHOT)
		_:
			_text(425, "Cycle %d · vague %d / %d" % [_run.cycle, _run.wave_number, _run.last_wave()], 20, PRIMARY)
	_text(463, "%03d points   ·   %d cibles   ·   Vies %d" % [
		_run.score(), _run.combat.wave.remaining, _run.lives
	], 17, MUTED)
	if _diagnostics:
		_draw_readout()


func _draw_docking_panel() -> void:
	var dock := _run.docking
	match dock.stage:
		Docking.Stage.SUCCESS:
			_text(425, "Bravo ! Amarrage réussi", 20, SHIP)
			_text(463, "Bonus   %d × %d = %d" % [dock.bonus / (dock.module * 100), dock.module * 100, dock.bonus], 17, SHOT)
		Docking.Stage.COLLISION:
			_text(425, "Collision à l’amarrage", 20, SHOT)
		Docking.Stage.TIMED_OUT:
			_text(425, "Dommage ! Temps écoulé", 20, SHOT)
		_:
			_text(425, "Mission amarrage", 20, PRIMARY)
			_text(463, "Chrono   %s" % dock.display_clock(), 17, SHOT)
	_text(510, "%03d points   ·   Vies %d" % [_run.score(), _run.lives], 17, MUTED)
	if _diagnostics:
		var point := dock.display_position()
		_text(543, "Module %d    x %d    y %d" % [dock.module, point.x, point.y], 17, SHIP)


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
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(ThemeDB.fallback_font, Vector2(center_x - width / 2.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


# Cycle d'attraction relevé sur pr10e. La démo rejoue les positions et les
# états de la carte (attract_demo_data.gd) ; les ennemis ne sont pas reproduits.
func _draw_attract() -> void:
	match _attract.screen():
		Attract.Screen.TITLE_TEXT:
			var rows := [40, 56, 80, 96, 106]
			for index in range(Attract.TITLE_LINES.size()):
				var progress := _attract.title_line_progress(index)
				if progress <= 0.0:
					continue
				var label: String = Attract.TITLE_LINES[index][0]
				_field_text(112, rows[index], label.substr(0, ceili(label.length() * progress)), SHIP if index < 2 else SHOT)
		Attract.Screen.SCORE_TABLE:
			for index in range(Attract.SCORE_LINES.size()):
				_field_text(112, 40 + index * 12, Attract.SCORE_LINES[index], PRIMARY if index == 0 else SHOT)
		Attract.Screen.DEMO:
			_draw_demo()


func _draw_demo() -> void:
	var screen_code := _attract.demo_value(Attract.Column.SCREEN)
	var step := _attract.demo_value(Attract.Column.STEP)
	var x := _attract.demo_value(Attract.Column.X)
	var y := _attract.demo_value(Attract.Column.Y)
	var docking := (step == 2 or step == 5) and screen_code == Attract.SCREEN_PLAY and _attract.demo_value(Attract.Column.CLOCK) != 0
	if docking:
		# Position d'approche : 0x822b − 16, 0x822c (comme Docking.display_position).
		_draw_module(Vector2(Docking.TARGET.x, Docking.TARGET.y + 8), 2 if step == 2 else 3, ENEMY_CORE)
		_draw_module(Vector2(x - 16, y), 1, SHIP)
		if step == 5:
			_draw_module(Vector2(x - 16, y + 8), 2, SHIP)
		_field_text(112, 40, "CHRONO", SHOT)
		_field_text(112, 52, _attract.demo_clock(), PRIMARY)
	elif x != 0 and y != 0:
		var attached := _attract.demo_attached()
		var count := 0
		for module in range(3):
			if attached & (1 << module):
				count += 1
		# Affichage approché : nez du module supérieur à 0x822c − 24 pour un
		# assemblage (192 et 208 relevés pour le I + II), 0x822c sinon.
		var top := y - (24 if count > 1 else 0)
		var row := 0
		for module in range(1, 4):
			if attached & (1 << (module - 1)):
				_draw_module(Vector2(x - 16, top + row * 8), module, SHIP)
				row += 1
	if _attract.demo_volley():
		draw_circle(Vector2(x - 16, y - 30), 2.0, SHOT)
	match screen_code:
		Attract.SCREEN_RESULT:
			if step == 2:
				_field_text(112, 60, "BONUS", SHIP)
				_field_text(112, 72, "10 x 100 = 1000", SHIP)
				_field_text(112, 150, "BRAVO !!", SHOT)
			else:
				draw_arc(Vector2(x - 16, y - 8), 10.0, 0.0, TAU, 16, SHOT, 1.0, true)
		Attract.SCREEN_TIMEOUT, Attract.SCREEN_TIMEOUT_TEXT:
			_field_text(112, 60, "DOMMAGE !!", SHIP)
			_field_text(112, 72, "00:0", PRIMARY)


func _draw_attract_panel() -> void:
	const LABELS := ["Présentation", "Tableau des scores", "Démo"]
	_text(425, "Attraction · %s" % LABELS[_attract.screen()], 20, PRIMARY)
	_text(463, "Espace   Jouer", 17, SHOT)
	if _attract.screen() == Attract.Screen.DEMO:
		_text(510, "Vies %d   ·   étape %d" % [_attract.demo_value(Attract.Column.LIVES), _attract.demo_value(Attract.Column.STEP)], 17, MUTED)
	if _diagnostics:
		_text(543, "Image %d / %d" % [_attract.frame, _attract.cycle_length()], 17, MUTED)


func _text(y: float, label: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(LABEL_X, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
