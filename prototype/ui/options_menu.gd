extends "res://ui/menu_screen.gd"

const Flags = preload("res://ui/flags.gd")

const LANGUAGE := 2
const AUDIO := 3
const DISPLAY := 4
const CONTROLS := 5
const TRAINING := 6
const VIBRATION := 7
const BACK := 8
enum Page { MAIN, LANGUAGES, AUDIO, DISPLAY, CONTROLS, KEYBOARD, GAMEPAD, VIBRATION }
var opened := false
var languages_open := false
var page := Page.MAIN
var binding_waiting := -1
var binding_error := false
var save_failed := false
var choice := 0


func set_open(enabled: bool) -> void:
	opened = enabled
	open_page(Page.MAIN, _profile.difficulty)
	_audio.set_paused(_paused or enabled)
	choice = _profile.difficulty
	_view._sync_menu_input()
	_view._redraw()


func render_state(controls: Array) -> Array:
	return [opened, choice, _profile.difficulty, languages_open, page,
		binding_waiting, binding_error, save_failed, _profile.volume,
		_profile.backup_failed, _profile.audio_bank, _profile.muted,
		_profile.fullscreen, _profile.show_fps, _profile.skin, _profile.menu_left, pad_hints(), _profile.vibration_enabled, _profile.vibration_intensity, controls]


func item_rect(index: int) -> Rect2:
	var area := content_rect()
	if page == Page.MAIN:
		if index < 2:
			var half := (area.size.x - 24.0) / 2.0
			return Rect2(area.position.x + 8 + index * (half + 8), area.position.y + 4, half, 70)
		return Rect2(area.position.x + 8, area.position.y + 96 + 50 * (index - 2), area.size.x - 16, 42)
	if page == Page.LANGUAGES:
		# Two columns of flags and names, Back across the full width.
		var rows := ceili(Language.LANGUAGES.size() / 2.0)
		var cell := Vector2((area.size.x - 28.0) / 2.0, 48.0)
		if index >= Language.LANGUAGES.size():
			return Rect2(area.position.x + 8, area.position.y + 4 + rows * (cell.y + 10), area.size.x - 16, cell.y)
		return Rect2(area.position.x + 8 + (index % 2) * (cell.x + 12), area.position.y + 4 + (index / 2) * (cell.y + 10), cell.x, cell.y)
	var height := 44.0 if back_index() > 5 else 50.0
	return Rect2(area.position.x + 8, area.position.y + 4 + (height + 10) * index, area.size.x - 16, height)


func back_index() -> int:
	match page:
		Page.LANGUAGES: return Language.LANGUAGES.size()
		Page.AUDIO: return 3
		Page.VIBRATION: return 3
		Page.DISPLAY: return 5
		Page.CONTROLS: return 3
		Page.KEYBOARD, Page.GAMEPAD: return Controls.ACTIONS.size() + 1
	return BACK


func open_page(next_page: Page, next_choice := 0) -> void:
	_view._haptics.stop()
	page = next_page
	languages_open = next_page == Page.LANGUAGES
	choice = next_choice
	binding_waiting = -1
	binding_error = false
	_navigation.reset()


func cancel_capture() -> void:
	binding_waiting = -1


func gamepad_disconnected() -> bool:
	if binding_waiting < 0 or page != Page.GAMEPAD:
		return false
	cancel_capture()
	return true


func back() -> void:
	if page == Page.MAIN:
		set_open(false)
		return
	match page:
		Page.KEYBOARD: open_page(Page.CONTROLS, 0)
		Page.GAMEPAD: open_page(Page.CONTROLS, 1)
		Page.LANGUAGES: open_page(Page.MAIN, LANGUAGE)
		Page.AUDIO: open_page(Page.MAIN, AUDIO)
		Page.DISPLAY: open_page(Page.MAIN, DISPLAY)
		Page.VIBRATION: open_page(Page.MAIN, VIBRATION)
		_: open_page(Page.MAIN, CONTROLS)
	_view._redraw()


func handle_input(event: InputEvent) -> void:
	if binding_waiting >= 0:
		handle_binding(event)
		return
	var navigation := _navigation.direction(event)
	var direction := navigation.y
	var adjustment := navigation.x
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			back()
			return
		if event.keycode == KEY_F3:
			set_open(false)
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			confirm()
			return
	elif event is InputEventJoypadButton and event.pressed:
		if page == Page.MAIN and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			set_difficulty(1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
			return
		if event.button_index == JOY_BUTTON_B:
			back()
			return
		if event.button_index == JOY_BUTTON_X:
			set_open(false)
			return
		if event.button_index == JOY_BUTTON_A:
			confirm()
			return
	elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var point: Vector2 = _view._panel_point(event.position)
		for index in range(back_index() + 1):
			if item_rect(index).has_point(point):
				choice = index
				if event is InputEventMouseButton:
					if (page == Page.AUDIO and index == 0
							or page == Page.VIBRATION and index == 1):
						adjust(-1 if point.x < item_rect(index).get_center().x else 1)
					else:
						confirm()
				else:
					_view._redraw()
				return
	if languages_open and (direction != 0 or adjustment != 0):
		choice = language_step(choice, direction, adjustment)
		_view._redraw()
		return
	if adjustment != 0:
		adjust(adjustment)
		return
	if direction != 0:
		choice = posmod(choice + direction, back_index() + 1)
		_view._redraw()


# Grid navigation on the language page: up/down by row, left/right by column.
func language_step(from: int, direction: int, adjustment: int) -> int:
	var count := Language.LANGUAGES.size()
	if adjustment != 0:
		if from >= count:
			return from
		var other := from + (1 if from % 2 == 0 else -1)
		return other if other >= 0 and other < count else from
	if from >= count:
		return 0 if direction > 0 else (count - 1 if (count - 1) % 2 == 0 else count - 2)
	var next := from + direction * 2
	if next >= count or next < 0:
		return count
	return next


func confirm() -> void:
	if choice == back_index():
		back()
		return
	if languages_open:
		var language: String = Language.LANGUAGES.keys()[choice]
		if _profile.language != language:
			_profile.language = language
			_view._save_profile()
		else:
			_view._redraw()
		return
	if page == Page.VIBRATION and choice == 2:
		if _focused:
			_view._haptics.preview()
		return
	if page in [Page.AUDIO, Page.DISPLAY, Page.VIBRATION]:
		adjust(1)
		return
	if page == Page.CONTROLS:
		if choice < 2:
			open_page(Page.KEYBOARD if choice == 0 else Page.GAMEPAD)
		else:
			_profile.key_bindings = Controls.DEFAULT_KEYS.duplicate(true)
			_profile.button_bindings = Controls.DEFAULT_BUTTONS.duplicate()
			Controls.apply(_profile.key_bindings, _profile.button_bindings)
			_view._save_profile()
		_view._redraw()
		return
	if page in [Page.KEYBOARD, Page.GAMEPAD]:
		if choice == Controls.ACTIONS.size():
			if page == Page.KEYBOARD:
				_profile.key_bindings = Controls.DEFAULT_KEYS.duplicate(true)
			else:
				_profile.button_bindings = Controls.DEFAULT_BUTTONS.duplicate()
			Controls.apply(_profile.key_bindings, _profile.button_bindings)
			_view._save_profile()
		else:
			binding_waiting = choice
			binding_error = false
		_view._redraw()
		return
	if choice == LANGUAGE:
		open_page(Page.LANGUAGES, Language.LANGUAGES.keys().find(_profile.language))
		_view._redraw()
		return
	if choice == TRAINING:
		_view._training.open_menu(true)
		return
	if choice in [AUDIO, DISPLAY, CONTROLS, VIBRATION]:
		var pages := {AUDIO: Page.AUDIO, DISPLAY: Page.DISPLAY, CONTROLS: Page.CONTROLS, VIBRATION: Page.VIBRATION}
		open_page(pages[choice])
		_view._redraw()
		return
	var difficulty := ArcadeProfile.Difficulty.VETERANS if choice == 1 else ArcadeProfile.Difficulty.NORMAL
	if _profile.difficulty != difficulty:
		_profile.difficulty = difficulty
		_view._save_profile()
	else:
		_view._redraw()


# Main page: left / right and LB / RB pick the difficulty from any row.
func set_difficulty(level: int) -> void:
	if choice < 2:
		choice = level
	if _profile.difficulty != level:
		_profile.difficulty = level
		_view._save_profile()
	else:
		_view._redraw()


func adjust(direction: int) -> void:
	match page:
		Page.MAIN:
			set_difficulty(1 if direction > 0 else 0)
			return
		Page.VIBRATION:
			if choice == 0:
				_profile.vibration_enabled = not _profile.vibration_enabled
			elif choice == 1:
				_profile.vibration_intensity = clampi(_profile.vibration_intensity + direction * 10, 0, 100)
			else:
				return
			_view._haptics.configure(_profile.vibration_enabled, _profile.vibration_intensity)
		Page.AUDIO:
			if choice == 0:
				_profile.volume = clampi(_profile.volume + direction * 10, 0, 100)
				_audio.set_volume(_profile.volume)
			elif choice == 1:
				_profile.muted = not _profile.muted
				_audio.set_muted(_profile.muted)
			elif choice == 2:
				_profile.audio_bank = "modern" if _profile.audio_bank == "original" else "original"
				_audio.set_bank(_profile.audio_bank)
				_audio.preview_shot()
			else:
				return
		Page.DISPLAY:
			if choice == 0:
				_profile.fullscreen = not _profile.fullscreen
			elif choice == 1:
				_profile.portrait = not _profile.portrait
			elif choice == 2:
				_profile.show_fps = not _profile.show_fps
			elif choice == 4:
				_profile.menu_left = not _profile.menu_left
			elif choice == 3:
				var skins := UiSkin.available()
				_profile.skin = skins[posmod(skins.find(_profile.skin) + direction, skins.size())]
				_profile.skin_chosen = true
				_view._apply_skin()
			else:
				return
			_view._apply_display()
		_:
			return
	_view._save_profile()
	if page == Page.VIBRATION and _focused:
		_view._haptics.preview()


func handle_binding(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK):
		binding_waiting = -1
		binding_error = false
		_view._redraw()
		return
	var action: StringName = Controls.ACTIONS[binding_waiting]
	if page == Page.KEYBOARD and event is InputEventKey and event.pressed:
		if not Controls.valid_key(event.keycode, action) or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			binding_error = true
			_view._redraw()
			return
		if not Controls.assign_key(_profile.key_bindings, action, event.keycode):
			binding_error = true
			_view._redraw()
			return
	elif page == Page.GAMEPAD and event is InputEventJoypadButton and event.pressed:
		if not Controls.valid_button(event.button_index):
			binding_error = true
			_view._redraw()
			return
		Controls.assign_button(_profile.button_bindings, action, event.button_index)
	else:
		return
	binding_waiting = -1
	binding_error = false
	Controls.apply(_profile.key_bindings, _profile.button_bindings)
	_view._save_profile()


func draw(canvas: Node2D) -> void:
	sheet(canvas)
	var titles := ["Options", "Langue", "Son", "Affichage", "Commandes", "Clavier", "Manette", "Vibrations"]
	var detail := ""
	if page != Page.MAIN:
		detail = "%s  ›  %s" % [_translate("Options"), _translate(titles[page])]
		if page in [Page.KEYBOARD, Page.GAMEPAD]:
			detail = "%s  ›  %s  ›  %s" % [_translate("Options"), _translate("Commandes"), _translate(titles[page])]
	elif _paused:
		detail = _translate("Difficulté à la prochaine partie")
	header(canvas, _translate(titles[page]), detail)
	var back := back_index()
	for index in range(back + 1):
		var row := item_rect(index)
		var state := row_state(index, choice)
		if index == back:
			skin.button(canvas, row, _translate("Retour"), state, 30)
		elif page == Page.MAIN and index < 2:
			draw_difficulty(canvas, row, index, state)
		elif languages_open:
			var language: String = Language.LANGUAGES.keys()[index]
			draw_language(canvas, row, language, state)
		else:
			draw_row(canvas, row, index, state)
	var hint := ""
	if save_failed:
		hint = _translate("Échec de l’enregistrement")
	elif _profile.backup_failed:
		hint = _translate("Copie de secours indisponible")
	elif page == Page.GAMEPAD:
		hint = _translate("Stick gauche pour déplacer")
	if not hint.is_empty():
		var color := skin.c("danger") if save_failed or _profile.backup_failed else skin.c("muted")
		skin.text(canvas, Vector2(content_rect().get_center().x, item_rect(back).end.y + 26), hint, skin.body_size(22), color, 0, skin.detail_font)
	var items := [hint(["key:↑", "key:↓"], ["pad:✚"], "Choisir")]
	if page == Page.MAIN:
		items.append(hint(["key:←", "key:→"], ["pad:LB", "pad:RB"], "Difficulté"))
	elif page in [Page.AUDIO, Page.VIBRATION, Page.DISPLAY]:
		items.append(hint(["key:←", "key:→"], ["pad:◀▶"], "Régler"))
	items.append(hint(["key:Entrée"], ["pad:A"], "Valider"))
	items.append(hint(["key:Échap"], ["pad:B"], "Retour"))
	hints(canvas, items)
	if binding_waiting >= 0:
		draw_binding(canvas)


func draw_difficulty(canvas: Node2D, rect: Rect2, index: int, state: int) -> void:
	skin.button_frame(canvas, rect, state)
	var ink := skin.c("focus_text") if state == 2 else skin.c("button_text")
	var center := rect.get_center()
	skin.text(canvas, center - Vector2(0, 12), skin.caps(_translate(ArcadeProfile.DIFFICULTY_LABELS[index])), skin.body_size(34), ink, 0, skin.body_font, rect.size.x - 40)
	var points := "30 000" if index == 0 else "50 000"
	var detail := _translate("Cycle %d · Réserve à %s points") % [index + 1, points]
	skin.text(canvas, center + Vector2(0, 18), detail, skin.body_size(19), Color(ink, 0.75), 0, skin.detail_font, rect.size.x - 40)
	if index == _profile.difficulty:
		draw_check(canvas, rect, state)


func draw_language(canvas: Node2D, rect: Rect2, language: String, state: int) -> void:
	skin.button_frame(canvas, rect, state)
	var inset := rect.size.y * skin.skew * 0.5 + 12.0
	var flag := Rect2(rect.position.x + inset, rect.get_center().y - 11.0, 33.0, 22.0)
	Flags.draw(canvas, flag, language)
	var color := skin.c("focus_text") if state == 2 else skin.c("button_text")
	var right := rect.end.x - inset - (22.0 if language == _profile.language else 0.0)
	skin.text(canvas, Vector2(flag.end.x + 12.0, rect.get_center().y + 1.0), Language.LANGUAGES[language],
		skin.body_size(28), color, -1, skin.body_font, right - flag.end.x - 12.0)
	if language == _profile.language:
		var point := Vector2(rect.end.x - inset - 6.0, rect.get_center().y)
		canvas.draw_circle(point, 7.0, skin.c("focus_text") if state == 2 else skin.c("accent"))
		canvas.draw_circle(point, 3.0, skin.c("focus_top") if state == 2 else skin.c("button_bottom"))


func draw_check(canvas: Node2D, rect: Rect2, state: int) -> void:
	var point := Vector2(rect.position.x + rect.size.y * skin.skew + 20, rect.get_center().y)
	canvas.draw_circle(point, 7.0, skin.c("focus_text") if state == 2 else skin.c("accent"))
	canvas.draw_circle(point, 3.0, skin.c("focus_top") if state == 2 else skin.c("button_bottom"))


func draw_row(canvas: Node2D, rect: Rect2, index: int, state: int) -> void:
	skin.button_frame(canvas, rect, state)
	var parts := option_parts(index)
	var ink := skin.c("focus_text") if state == 2 else skin.c("button_text")
	var left := rect.position.x + rect.size.y * skin.skew + 22
	var right := rect.end.x - 24
	var y := rect.get_center().y + 1
	var size := skin.body_size(30 if rect.size.y >= 44 else 26)
	skin.text(canvas, Vector2(left, y), skin.caps(parts[0]), size, ink, -1, skin.body_font, rect.size.x * 0.55)
	var kind: String = parts[1]
	match kind:
		"meter":
			var meter := Rect2(right - 250, y - 8, 180, 16)
			skin.meter(canvas, meter, parts[2] / 100.0, skin.c("focus_border") if state == 2 else skin.c("accent"), Color(ink, 0.18))
			skin.text(canvas, Vector2(right, y), "%d %%" % parts[2], size, ink, 1)
		"choice":
			var width := skin.text(canvas, Vector2(right - 22, y), skin.caps(parts[2]), size, ink, 1)
			skin.arrow(canvas, Vector2(right - 4, y), 1, 14, ink)
			skin.arrow(canvas, Vector2(right - width - 40, y), -1, 14, ink)
		"open":
			if not String(parts[2]).is_empty():
				var width := skin.text(canvas, Vector2(right - 26, y), parts[2], size, Color(ink, 0.8), 1)
				if page == Page.MAIN and index == LANGUAGE:
					Flags.draw(canvas, Rect2(right - 26 - width - 36, y - 9, 27, 18), _profile.language)
			skin.arrow(canvas, Vector2(right - 6, y), 1, 14, ink)
		"keys":
			var x := right
			var labels: PackedStringArray = parts[2]
			for label_index in range(labels.size() - 1, -1, -1):
				var width := keycap_width(labels[label_index])
				x -= width
				if page == Page.KEYBOARD:
					skin.keycap(canvas, Vector2(x, y), labels[label_index], 28)
				else:
					skin.pad(canvas, Vector2(x, y), labels[label_index], 28)
				x -= 8
		"action":
			pass


func keycap_width(label: String) -> float:
	var size := int(28 * 0.55)
	if page == Page.GAMEPAD:
		return 28.0 if UiSkin.PAD_COLORS.has(label) else maxf(28 * 1.4, skin.text_width(skin.symbol_font, label, int(28 * 0.45)) + 12.0)
	return maxf(28.0, skin.text_width(skin.symbol_font, label, size) + 14.0)


# [label, kind, value] where kind is meter, choice, open, keys or action.
func option_parts(index: int) -> Array:
	match page:
		Page.MAIN:
			if index == LANGUAGE:
				return [_translate("Langue"), "open", Language.LANGUAGES[_profile.language]]
			if index == TRAINING:
				return [_translate("Entraînement"), "open", ""]
			return [_translate({AUDIO: "Son", DISPLAY: "Affichage", CONTROLS: "Commandes", VIBRATION: "Vibrations"}[index]), "open", ""]
		Page.VIBRATION:
			if index == 0:
				return [_translate("Vibrations"), "choice", _translate("actives" if _profile.vibration_enabled else "désactivées")]
			if index == 1:
				return [_translate("Intensité"), "meter", _profile.vibration_intensity]
			return [_translate("Tester les vibrations"), "action", ""]
		Page.AUDIO:
			if index == 0:
				return [_translate("Volume"), "meter", _profile.volume]
			if index == 2:
				return [_translate("Sons"), "choice", _translate("Moderne" if _profile.audio_bank == "modern" else "Original")]
			return [_translate("Son"), "choice", _translate("coupé" if _profile.muted else "actif")]
		Page.DISPLAY:
			if index == 0:
				return [_translate("Mode"), "choice", _translate("Plein écran" if _profile.fullscreen else "Fenêtré")]
			if index == 1:
				return [_translate("Orientation"), "choice", _translate("Portrait" if _profile.portrait else "Paysage")]
			if index == 2:
				return [_translate("Compteur FPS"), "choice", _translate("activé" if _profile.show_fps else "désactivé")]
			if index == 3:
				return [_translate("Thème"), "choice", skin.display_name]
			return [_translate("Disposition"), "choice", _translate("Menu à gauche" if _profile.menu_left else "Menu à droite")]
		Page.CONTROLS:
			if index < 2:
				return [_translate(["Clavier", "Manette"][index]), "open", ""]
			return [_translate("Rétablir par défaut"), "action", ""]
		Page.KEYBOARD, Page.GAMEPAD:
			if index == Controls.ACTIONS.size():
				return [_translate("Rétablir par défaut"), "action", ""]
			var action: StringName = Controls.ACTIONS[index]
			var labels := PackedStringArray()
			if page == Page.KEYBOARD:
				for code in _profile.key_bindings[String(action)]:
					labels.append(_translate(Controls.key_name(code)))
			else:
				labels.append(Controls.button_label(_profile.button_bindings[String(action)]))
			return [_translate(Controls.LABELS[index]), "keys", labels]
	return ["", "action", ""]


func option_label(index: int) -> String:
	match page:
		Page.MAIN:
			if index == LANGUAGE:
				return "%s · %s" % [_translate("Langue"), Language.LANGUAGES[_profile.language]]
			return _translate({AUDIO: "Son", DISPLAY: "Affichage",
				CONTROLS: "Commandes", TRAINING: "Entraînement", VIBRATION: "Vibrations"}[index])
		Page.VIBRATION:
			if index == 0:
				return "%s · %s" % [_translate("Vibrations"), _translate("actives" if _profile.vibration_enabled else "désactivées")]
			if index == 1:
				return "%s    −  %d %%  +" % [_translate("Intensité"), _profile.vibration_intensity]
			return _translate("Tester les vibrations")
		Page.AUDIO:
			if index == 0:
				return "%s    −  %d %%  +" % [_translate("Volume"), _profile.volume]
			if index == 2:
				return "%s · %s" % [_translate("Sons"), _translate("Moderne" if _profile.audio_bank == "modern" else "Original")]
			return "%s · %s" % [_translate("Son"), _translate("coupé" if _profile.muted else "actif")]
		Page.DISPLAY:
			if index == 0:
				return _translate("Plein écran" if _profile.fullscreen else "Fenêtré")
			if index == 2:
				return "%s · %s" % [_translate("Compteur FPS"), _translate("activé" if _profile.show_fps else "désactivé")]
			return _translate("Portrait" if _profile.portrait else "Paysage")
		Page.CONTROLS:
			return _translate(["Clavier", "Manette", "Rétablir par défaut"][index])
		Page.KEYBOARD, Page.GAMEPAD:
			if index == Controls.ACTIONS.size():
				return _translate("Rétablir par défaut")
			var action: StringName = Controls.ACTIONS[index]
			var value := _key_label(action) if page == Page.KEYBOARD else Controls.button_label(_profile.button_bindings[String(action)])
			return "%s · %s" % [_translate(Controls.LABELS[index]), value]
	return ""


func draw_binding(canvas: Node2D) -> void:
	var row := item_rect(binding_waiting)
	var box := Rect2(row.position.x + row.size.x * 0.42, row.position.y - 6, row.size.x * 0.58 + 6, row.size.y + 12)
	skin.button_frame(canvas, box, 2)
	var instruction := "Appuyez sur une touche" if page == Page.KEYBOARD else "Appuyez sur un bouton"
	skin.text(canvas, box.get_center() + Vector2(0, 1), skin.caps(_translate(instruction)) + "…", skin.body_size(26), skin.c("focus_text"), 0, skin.body_font, box.size.x - 40)
	var note := _translate("Commande réservée") if binding_error else _translate("Échap / Back pour annuler")
	skin.text(canvas, Vector2(content_rect().get_center().x, item_rect(back_index()).end.y + 26), note,
		skin.body_size(22), skin.c("danger") if binding_error else skin.c("muted"), 0, skin.detail_font)
