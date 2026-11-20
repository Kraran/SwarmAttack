extends "res://ui/menu_screen.gd"

# Home screen list. The first entry keeps the historical fire-to-start behaviour.
const LABELS := ["1 joueur", "2 joueurs", "Entraînement", "Classements", "Options", "Quitter"]
const BIG_LOGO := Rect2(800, 6, 320, 180)
const LIST_TOP := 198.0
const PORTRAIT_OPTIONS_BUTTON := Rect2(312, 14, 220, 38)
const PORTRAIT_SCORES_BUTTON := Rect2(28, 741, 244, 34)
const PORTRAIT_TRAINING_BUTTON := Rect2(288, 741, 244, 34)
# Idle time before the portrait menu closes and the attraction shows again.
const PORTRAIT_IDLE_MSEC := 20000
var choice := 0
# Portrait has no side panel: the same list opens over the playfield as soon
# as a direction is pressed, and hides again after a while without input.
var portrait_open := false
var _portrait_input_msec := 0


func render_state() -> Array:
	return [choice, hover_index(pointer()), difficulty_hover(pointer()), portrait_open]


func open_portrait() -> void:
	portrait_open = true
	_portrait_input_msec = Time.get_ticks_msec()
	_navigation.reset()
	_view._redraw()


func close_portrait() -> void:
	if portrait_open:
		portrait_open = false
		_view._redraw()


func expire_portrait() -> void:
	if portrait_open and Time.get_ticks_msec() - _portrait_input_msec >= PORTRAIT_IDLE_MSEC:
		close_portrait()


func portrait_button_rect(index: int) -> Rect2:
	var area := content_rect()
	var width := 380.0
	return Rect2(area.get_center().x - width / 2.0, area.position.y + 20 + index * 62.0, width, 52.0)


func portrait_difficulty_rect(index: int) -> Rect2:
	var area := content_rect()
	var width := 186.0
	return Rect2(area.get_center().x - width - 4 + index * (width + 8), area.position.y + 20 + LABELS.size() * 62.0 + 46, width, 58)


func button_rect(index: int) -> Rect2:
	var y := LIST_TOP
	for previous in index:
		y += (52.0 if previous == choice else 42.0) + 10.0
	var width := 360.0 if index == choice else 320.0
	var height := 52.0 if index == choice else 42.0
	return Rect2(PANEL_CENTER - width / 2.0, y, width, height)


func difficulty_rect(index: int) -> Rect2:
	return Rect2(976 + index * 134, 574, 124, 64)


func scores_rect() -> Rect2:
	return Rect2(688, 534, 262, 122)


func hover_index(point: Vector2) -> int:
	if _profile.portrait and not portrait_open:
		return -1
	for index in LABELS.size():
		if (portrait_button_rect(index) if _profile.portrait else button_rect(index)).has_point(point):
			return index
	return -1


func difficulty_hover(point: Vector2) -> int:
	if _profile.portrait and not portrait_open:
		return -1
	for index in 2:
		if (portrait_difficulty_rect(index) if _profile.portrait else difficulty_rect(index)).has_point(point):
			return index
	return -1


func handle_input(event: InputEvent) -> bool:
	if _profile.portrait:
		return _handle_portrait_input(event)
	return _handle_list_input(event)


func _handle_portrait_input(event: InputEvent) -> bool:
	if not portrait_open:
		# A direction (keys, D-pad or stick) opens the list; fire still starts
		# a game and the mouse keeps its header and footer buttons.
		if event is InputEventMouse or event.is_echo():
			return false
		if _navigation.direction(event) != Vector2i.ZERO:
			choice = 0
			open_portrait()
			return true
		return false
	if event is InputEventMouseMotion:
		return _handle_list_input(event)
	_portrait_input_msec = Time.get_ticks_msec()
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		close_portrait()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _view.PORTRAIT_FIELD.has_point(event.position):
			close_portrait()
			return false
	return _handle_list_input(event) or event is InputEventKey or event is InputEventJoypadButton


func _handle_list_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var index := hover_index(_view._panel_point(event.position))
		if index >= 0 and index != choice:
			choice = index
			_view._redraw()
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := hover_index(_view._panel_point(event.position))
		if index >= 0:
			choice = index
			activate()
			return true
		var level := difficulty_hover(_view._panel_point(event.position))
		if level >= 0:
			set_difficulty(level)
			return true
		return false
	if event.is_echo():
		return false
	if (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]):
		set_difficulty(1 - _profile.difficulty)
		return true
	var direction := _navigation.direction(event)
	if direction.y != 0:
		choice = posmod(choice + direction.y, LABELS.size())
		_view._redraw()
		return true
	if direction.x != 0 and not (event is InputEventKey and not event.keycode in [KEY_LEFT, KEY_RIGHT]):
		set_difficulty(1 if direction.x > 0 else 0)
		return true
	var confirm: bool = (event.is_action_pressed(&"fire")
		or event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
		or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
	if confirm:
		activate()
		return true
	return false


func set_difficulty(level: int) -> void:
	if _profile.difficulty != level:
		_profile.difficulty = level
		_view._save_profile()
	else:
		_view._redraw()


func activate() -> void:
	portrait_open = false
	match choice:
		0: _view._restart(false)
		1: _view._restart(false, 2)
		2: _view._training.open_menu()
		3: _view._scores.open()
		4: _view._options.set_open(true)
		5: _view.get_tree().quit()


func draw(canvas: Node2D) -> void:
	for index in LABELS.size():
		var rect := button_rect(index)
		skin.button(canvas, rect, _translate(LABELS[index]), 2 if index == choice else 0, 40 if index == choice else 32)
		if index == choice:
			for side in [-1, 1]:
				var center := Vector2(PANEL_CENTER + side * (rect.size.x / 2.0 + 30.0), rect.get_center().y)
				skin.arrow(canvas, center + Vector2(2, 2), -side, 18, skin.c("shadow"))
				skin.arrow(canvas, center, -side, 18, skin.c("accent"))
	draw_scores(canvas)
	draw_difficulty(canvas)
	var start := hint(["key:Entrée"], ["pad:A"], "Décoller")
	if choice != 0:
		start = hint(["key:Entrée"], ["pad:A"], "Valider")
	hints(canvas, [
		hint(["key:↑", "key:↓"], ["pad:✚"], "Choisir"),
		start,
		hint(["key:←", "key:→"], ["pad:LB", "pad:RB"], "Difficulté"),
		hint(["key:F3"], ["pad:X"], "Options"),
	])


func draw_portrait(canvas: Node2D) -> void:
	sheet(canvas)
	# The attraction keeps running underneath: hide its text behind the list.
	canvas.draw_rect(_view.PORTRAIT_FIELD.grow(-10), Color(skin.c("panel"), 0.6))
	for index in LABELS.size():
		var rect := portrait_button_rect(index)
		var state := 2 if index == choice else (1 if hover_index(pointer()) == index else 0)
		skin.button(canvas, rect, _translate(LABELS[index]), state, 32)
	var first := portrait_difficulty_rect(0)
	skin.title(canvas, Vector2(first.position.x, first.position.y - 22), _translate("Difficulté"), 26, -1, 380)
	for index in 2:
		var rect := portrait_difficulty_rect(index)
		var active := index == _profile.difficulty
		skin.button_frame(canvas, rect, 2 if active else (1 if difficulty_hover(pointer()) == index else 0))
		var ink := skin.c("focus_text") if active else skin.c("button_text")
		skin.text(canvas, rect.get_center() - Vector2(0, 9), skin.caps(_translate(ArcadeProfile.DIFFICULTY_LABELS[index])), skin.body_size(28), ink, 0, skin.body_font, rect.size.x - 24)
		skin.text(canvas, rect.get_center() + Vector2(0, 16), _translate("Réserve %s") % ("30 000" if index == 0 else "50 000"), skin.body_size(17), Color(ink, 0.75), 0, skin.detail_font, rect.size.x - 24)
	hints(canvas, [
		hint(["key:↑", "key:↓"], ["pad:✚"], "Choisir"),
		hint(["key:Entrée"], ["pad:A"], "Valider"),
		hint(["key:←", "key:→"], ["pad:LB", "pad:RB"], "Difficulté"),
		hint(["key:Échap"], ["pad:B"], "Retour"),
	])


func draw_scores(canvas: Node2D) -> void:
	var box := scores_rect()
	skin.panel(canvas, box)
	skin.title(canvas, Vector2(box.position.x + 18, box.position.y + 24), _translate("Meilleurs pilotes"), 30, -1, box.size.x - 30)
	var mode := _score_mode()
	var table := _profile.scores_for(mode)
	var names := _profile.initials_for(mode)
	for rank in 3:
		var y := box.position.y + 58 + rank * 24
		var tint := skin.c("text") if rank > 0 else skin.c("accent")
		skin.text(canvas, Vector2(box.position.x + 18, y), "%d   %s" % [rank + 1, names[rank]], skin.body_size(26), tint, -1, skin.body_font, box.size.x * 0.5)
		skin.text(canvas, Vector2(box.end.x - 16, y), "%06d" % table[rank], skin.body_size(26), skin.c("accent"), 1, skin.body_font, box.size.x * 0.45)


func draw_difficulty(canvas: Node2D) -> void:
	skin.title(canvas, Vector2(978, 546), _translate("Difficulté"), 32, -1, 250)
	for index in 2:
		var rect := difficulty_rect(index)
		var active := index == _profile.difficulty
		skin.button_frame(canvas, rect, 2 if active else (1 if difficulty_hover(pointer()) == index else 0))
		var ink := skin.c("focus_text") if active else skin.c("button_text")
		skin.text(canvas, rect.get_center() - Vector2(0, 10), skin.caps(_translate(ArcadeProfile.DIFFICULTY_LABELS[index])), skin.body_size(30), ink, 0, skin.body_font, rect.size.x - 30)
		skin.text(canvas, rect.get_center() + Vector2(0, 17), _translate("Réserve %s") % ("30 000" if index == 0 else "50 000"), skin.body_size(18), Color(ink, 0.75), 0, skin.detail_font, rect.size.x - 34)


# Portrait keeps its compact header and footer buttons.
func draw_menu_button(canvas: Node2D, rect: Rect2, label: String, shortcut: String) -> void:
	var hovered := rect.has_point(pointer())
	skin.button(canvas, rect, label, 1 if hovered else 0, 24)


func draw_options_button(canvas: Node2D, rect: Rect2, point: Vector2) -> void:
	var label := "%s · %s" % [_translate("Options"), _translate(ArcadeProfile.DIFFICULTY_LABELS[_profile.difficulty])]
	skin.button(canvas, rect, label, 1 if rect.has_point(point) else 0, 24)


func draw_hints(canvas: Node2D) -> void:
	if _profile.portrait:
		return
	var items := [hint(["key:%s" % _key_label(&"pause")], ["pad:Start"], "Pause")]
	if _session.practice:
		items.append(hint(["key:R"], ["pad:Y"], "Réessayer"))
	else:
		items.append(hint(["key:R"], [], "Recommencer"))
	items.append(hint(["key:F2"], [], "Entraînement"))
	skin.hint_bar(canvas, LANDSCAPE_BAR, items, 22)
