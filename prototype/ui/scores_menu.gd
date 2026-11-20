extends "res://ui/menu_screen.gd"

const ScoreEntry = preload("res://score_entry.gd")
const Attract = preload("res://attract.gd")
const ARCADE_CYAN := Color("#67d8ff")
const ARCADE_PINK := Color("#e786ef")
const ARCADE_GREEN := Color("#99dd68")
const SCORE_RANK_COLORS := [
	ARCADE_RED, Color("#ff9b61"), Color("#ffc16c"), SHOT, Color("#c9e97b"),
	ARCADE_GREEN, Color("#69e4b8"), ARCADE_CYAN, Color("#91aeff"), Color("#bc87ff"),
]
const LETTER := Rect2(57, 96, 32, 33)
const SAVE := Rect2(25, 179, 84, 20)
const SKIP := Rect2(115, 179, 84, 20)
const BACK := Rect2(62, 212, 100, 20)
const RESULT_SCORES := Rect2(35, 207, 154, 20)
const RESULT_HOME := Rect2(62, 233, 100, 17)
var entry: ScoreEntry
var candidates: Array[Dictionary] = []
var results_open := false
var rows: Array[Dictionary] = []
var results_page := 0
var result_choice := 0
var tables_open := false

func reset() -> void:
	entry = null
	candidates.clear()
	results_open = false
	rows.clear()
	results_page = 0
	result_choice = 0
	tables_open = false

func overlay_state() -> Array:
	return [candidates[0] if entry != null else null,
		entry.initials if entry != null else "",
		entry.cursor if entry != null else -1,
		entry.save_failed if entry != null else false]

func finish_session() -> void:
	var eligible: Array[Dictionary] = []
	var results: Array[Dictionary] = []
	if not _session.practice:
		for player in _session.runs.size():
			var run := _session.runs[player]
			var score := run.score()
			results.append({"player": player + 1, "score": score, "cycle": run.cycle,
				"docks": run.successful_dockings, "rank": 0, "initials": "---"})
			if _profile.qualifies(score, _view._run_difficulty):
				eligible.append({"player": player + 1, "score": score})
	_view._return_to_title()
	if results.is_empty():
		return
	rows = results
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.player < b.player if a.score == b.score else a.score > b.score)
	candidates = eligible
	next_entry()


func next_entry() -> void:
	while not candidates.is_empty() and not _profile.qualifies(candidates[0].score, _view._run_difficulty):
		candidates.pop_front()
	if candidates.is_empty():
		entry = null
		results_open = true
		_navigation.reset()
		results_page = 0
		_view._attract.frame = Attract.TITLE_TEXT_FRAMES
	else:
		entry = ScoreEntry.new()
	_view._redraw()


func resolve_entry(save: bool) -> void:
	if save:
		var candidate := candidates[0]
		var rank := _profile.insertion_rank(candidate.score, _view._run_difficulty)
		var error := _profile.submit_score(candidates[0].score, entry.initials,
			ArcadeProfile.SAVE_PATH, _view._run_difficulty)
		if error != OK and error != ERR_UNAVAILABLE:
			entry.save_failed = true
			_view._redraw()
			return
		if error == OK:
			var result: Dictionary = rows[candidate.player - 1]
			result.rank = rank
			result.initials = entry.initials
	candidates.pop_front()
	next_entry()


func letter_rect(index: int) -> Rect2:
	var area := content_rect()
	return Rect2(area.get_center().x - 150 + 106 * index, area.position.y + 150, 88, 104)


func entry_button(save: bool) -> Rect2:
	var area := content_rect()
	var width := minf(240.0, area.size.x / 2.0 - 20.0)
	return Rect2(area.get_center().x + (-width - 10 if save else 10), area.position.y + 330, width, 52)


func handle_entry_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = _view._panel_point(event.position)
		if entry_button(true).has_point(point) or entry_button(false).has_point(point):
			resolve_entry(entry_button(true).has_point(point))
			return
		for index in 3:
			if letter_rect(index).has_point(point):
				entry.cursor = index
				_view._redraw()
				return
	match entry.handle(event):
		ScoreEntry.Result.CHANGED:
			_view._redraw()
		ScoreEntry.Result.SAVE:
			resolve_entry(true)
		ScoreEntry.Result.SKIP:
			resolve_entry(false)


func handle_results_input(event: InputEvent) -> void:
	if results_open and results_page == 0:
		if event is InputEventMouseMotion:
			var point := _field_input_position(event.position)
			if RESULT_SCORES.has_point(point) or RESULT_HOME.has_point(point):
				result_choice = int(RESULT_HOME.has_point(point))
				_view._redraw()
			return
		# Arrows, D-pad and left stick share the menus' navigation (stick hysteresis included).
		if _navigation.direction(event).y != 0:
			result_choice = 1 - result_choice
			_view._redraw()
			return
	if not event.is_pressed():
		return
	if tables_open:
		if (event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_F4]
			or event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_BACK]
			or event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
				and BACK.has_point(_field_input_position(event.position))):
			_view._return_to_title()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := _field_input_position(event.position)
		if results_page == 0 and RESULT_HOME.has_point(point):
			_view._return_to_title()
			return
		if not (RESULT_SCORES.has_point(point) if results_page == 0 else BACK.has_point(point)):
			return
		results_page = 1 - results_page
	elif (event is InputEventKey and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F4]
			or event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]):
		if results_page == 0 and result_choice == 1 and not (event is InputEventKey and event.keycode == KEY_F4):
			_view._return_to_title()
			return
		results_page = 1 - results_page
	elif (event is InputEventKey and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]):
		if results_page == 1:
			results_page = 0
		else:
			_view._return_to_title()
			return
	else:
		return
	if results_page == 0:
		result_choice = 0
	_view._redraw()


func open() -> void:
	tables_open = true
	_view._elapsed_usec = 0
	_view._pressed = 0
	_view._redraw()


func draw_entry(canvas: Node2D) -> void:
	sheet(canvas)
	var candidate := candidates[0]
	var detail := _translate(ArcadeProfile.DIFFICULTY_LABELS[_view._run_difficulty])
	if _session.runs.size() == 2:
		detail = "%s · %s" % [_translate("Joueur %d") % candidate.player, detail]
	header(canvas, _translate("NOUVEAU RECORD"), detail)
	var area := content_rect()
	var box := Rect2(area.position.x + 8, area.position.y + 4, area.size.x - 16, 112)
	skin.panel(canvas, box)
	skin.text(canvas, Vector2(box.get_center().x, box.position.y + 40), "%06d" % candidate.score, 30, skin.c("accent"), 0, skin.score_font)
	skin.text(canvas, Vector2(box.get_center().x, box.position.y + 84), _translate("Saisissez vos trois initiales"), skin.body_size(24), skin.c("muted"), 0, skin.detail_font)
	for index in 3:
		var tile := letter_rect(index)
		var state := 2 if index == entry.cursor else 0
		skin.button_frame(canvas, tile, state)
		skin.text(canvas, tile.get_center() + Vector2(0, 2), entry.initials[index], 40,
			skin.c("focus_text") if state == 2 else skin.c("text"), 0, skin.score_font)
	skin.button(canvas, entry_button(true), _translate("Enregistrer"), 2, 30)
	skin.button(canvas, entry_button(false), _translate("Passer"), 0, 30)
	if entry.save_failed:
		skin.text(canvas, Vector2(area.get_center().x, area.position.y + 410), _translate("Échec de l’enregistrement"), skin.body_size(22), skin.c("danger"), 0, skin.detail_font)
	hints(canvas, [
		hint(["key:←", "key:→"], ["pad:◀▶"], "Case"),
		hint(["key:↑", "key:↓"], ["pad:▲▼"], "Lettre"),
		hint(["key:Entrée"], ["pad:Start"], "Valider"),
	])


func draw_table(canvas: Node2D) -> void:
	var mode := _score_mode()
	_field_text(canvas, 112, 36, _translate(ArcadeProfile.DIFFICULTY_LABELS[mode]), SHOT, 9)
	_field_text(canvas, 39, 52, _translate("RANG"), ARCADE_PINK, 9)
	_field_text(canvas, 105, 52, _translate("INITIALES"), ARCADE_PINK, 9)
	_field_text(canvas, 175, 52, _translate("SCORE"), ARCADE_PINK, 9)
	var scores := _profile.scores_for(mode)
	var names := _profile.initials_for(mode)
	for index in scores.size():
		var y := 70 + index * 15
		var color: Color = SCORE_RANK_COLORS[index]
		var score := scores[index]
		if results_open:
			for result in rows:
				if result.rank == index + 1:
					canvas.draw_rect(Rect2(25, y - 11, 174, 14), Color(SHOT, 0.10))
					canvas.draw_rect(Rect2(25, y - 11, 174, 14), Color(SHOT, 0.75), false, 0.5)
		_field_text(canvas, 39, y, "%02d" % (index + 1), color, 10)
		_field_text(canvas, 105, y, names[index] if score > 0 else "—", color, 10)
		_field_text(canvas, 175, y, "%06d" % score if score > 0 else "—", color, 10)
	if results_open:
		_draw_score_action(canvas, BACK, _translate("Retour"), true)


func draw_results(canvas: Node2D) -> void:
	_field_text(canvas, 112, 36, _translate("Résultats"), SHOT, 12)
	_field_text(canvas, 112, 54, _translate(ArcadeProfile.DIFFICULTY_LABELS[_view._run_difficulty]), MUTED, 9)
	var duo := rows.size() == 2
	if duo:
		canvas.draw_line(Vector2(112, 65), Vector2(112, 198), BORDER, 0.5)
	for index in rows.size():
		var result := rows[index]
		var x := 58.0 + index * 108.0 if duo else 112.0
		var player := _translate("Joueur %d") % result.player
		if result.rank > 0:
			player += " · " + result.initials
		_field_text(canvas, x, 77, player, ARCADE_CYAN, 9)
		_field_text(canvas, x, 102, "%06d" % result.score, PRIMARY, 13 if duo else 17)
		var rank := _translate("Hors classement")
		var tint := MUTED
		if result.rank > 0:
			rank = "%s %02d" % [_translate("RANG"), result.rank]
			tint = SCORE_RANK_COLORS[result.rank - 1]
		_field_text(canvas, x, 127, rank, tint, 9)
		_field_text(canvas, x, 151, _translate("Cycle atteint %d") % result.cycle, PRIMARY, 8)
		_field_text(canvas, x, 174, _translate("Amarrages réussis"), MUTED, 7)
		_field_text(canvas, x, 194, str(result.docks), SHIP, 12)
	_draw_score_action(canvas, RESULT_SCORES, _translate("Voir le classement"), result_choice == 0)
	_draw_score_action(canvas, RESULT_HOME, _translate("Accueil"), result_choice == 1)


func draw_tables(canvas: Node2D) -> void:
	_field_text(canvas, 112, 34, _translate("Classements"), SHOT, 12)
	canvas.draw_line(Vector2(112, 48), Vector2(112, 202), BORDER, 0.5)
	for mode in ArcadeProfile.RECORD_SECTIONS.size():
		var offset := 108.0 * mode
		var scores := _profile.scores_for(mode)
		var names := _profile.initials_for(mode)
		_field_text(canvas, offset + 58, 53, _translate(ArcadeProfile.DIFFICULTY_LABELS[mode]), PRIMARY, 10)
		for index in scores.size():
			var y := 71 + index * 13
			var color: Color = SCORE_RANK_COLORS[index]
			var score := scores[index]
			_field_text(canvas, offset + 20, y, "%02d" % (index + 1), color, 7)
			_field_text(canvas, offset + 49, y, names[index] if score > 0 else "—", color, 8)
			_field_text(canvas, offset + 86, y, "%06d" % score if score > 0 else "—", color, 8)
	_draw_score_action(canvas, BACK, _translate("Retour"), true)
