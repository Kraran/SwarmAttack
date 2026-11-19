extends "res://ui/menu_screen.gd"

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
		_profile.fullscreen, _profile.show_fps, _profile.vibration_enabled, _profile.vibration_intensity, controls]


func item_rect(index: int) -> Rect2:
	if page == Page.MAIN:
		if index < 2:
			return Rect2(33, 62 + 29 * index, 158, 26)
		return Rect2(33, 120 + 16 * (index - 2), 158, 14)
	var height := 18 if languages_open else 24
	return Rect2(33, 65 + (height + 3) * index, 158, height)


func back_index() -> int:
	match page:
		Page.LANGUAGES: return Language.LANGUAGES.size()
		Page.AUDIO: return 3
		Page.VIBRATION: return 3
		Page.DISPLAY: return 3
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
		var point := _field_input_position(event.position)
		for index in range(back_index() + 1):
			if item_rect(index).has_point(point):
				choice = index
				if event is InputEventMouseButton:
					if (page == Page.AUDIO and index == 0
							or page == Page.VIBRATION and index == 1):
						adjust(-1 if point.x < 112 else 1)
					else:
						confirm()
				else:
					_view._redraw()
				return
	if adjustment != 0:
		adjust(adjustment)
		return
	if direction != 0:
		choice = posmod(choice + direction, back_index() + 1)
		_view._redraw()


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


func adjust(direction: int) -> void:
	match page:
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
	const PANEL_TOP := 36.0
	var languages := Language.LANGUAGES.keys()
	var back := back_index()
	var panel := Rect2(23, PANEL_TOP, 178, item_rect(back).end.y - PANEL_TOP + 8)
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.07, 0.97))
	canvas.draw_rect(panel, BORDER, false, 0.65)
	var titles := ["Options", "Langue", "Son", "Affichage", "Commandes", "Clavier", "Manette", "Vibrations"]
	_field_text(canvas, 112, 53, _translate(titles[page]).to_upper(), SHOT, 11)
	for index in range(back + 1):
		var row := item_rect(index)
		var selected := index == choice
		canvas.draw_rect(row, GRID if selected else BACKGROUND)
		canvas.draw_rect(row, SHOT if selected else BORDER, false, 0.5)
		var tint := SHOT if selected else PRIMARY
		var baseline := row.get_center().y + 3.0
		if index == back:
			_field_text(canvas, 112, baseline, _translate("Retour"), tint, 9)
		elif languages_open:
			var language: String = languages[index]
			_field_text(canvas, 112, baseline, Language.LANGUAGES[language], tint, 9)
			draw_marker(canvas, Vector2(row.position.x + 10, row.get_center().y), language == _profile.language)
		elif page == Page.MAIN and index < 2:
			_field_text(canvas, 112, row.position.y + 10.5, _translate(ArcadeProfile.DIFFICULTY_LABELS[index]), tint, 9)
			var points := "30 000" if index == 0 else "50 000"
			var detail := _translate("Cycle %d · Réserve à %s points") % [index + 1, points]
			_field_text(canvas, 112, row.position.y + 21, detail, MUTED, 7)
			draw_marker(canvas, Vector2(row.position.x + 10, row.position.y + 9.5), index == _profile.difficulty)
		else:
			var label := option_label(index)
			_field_text(canvas, 112, baseline, label, tint, 8)
	var hint := ""
	if save_failed:
		hint = _translate("Échec de l’enregistrement")
	elif _profile.backup_failed:
		hint = _translate("Copie de secours indisponible")
	elif page == Page.MAIN and _paused:
		hint = _translate("Difficulté à la prochaine partie")
	elif page in [Page.AUDIO, Page.VIBRATION]:
		hint = _translate("← → ou clic pour régler")
	elif page == Page.GAMEPAD:
		hint = _translate("Stick gauche pour déplacer")
	if not hint.is_empty():
		_field_text(canvas, 112, item_rect(back).end.y + 19, hint,
			ARCADE_RED if save_failed or _profile.backup_failed else MUTED, 7)
	if binding_waiting >= 0:
		draw_binding(canvas)


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
	canvas.draw_rect(Rect2(25, 88, 174, 80), BACKGROUND)
	canvas.draw_rect(Rect2(25, 88, 174, 80), SHOT, false, 0.65)
	_field_text(canvas, 112, 105, _translate(Controls.LABELS[binding_waiting]), SHOT, 9)
	var instruction := "Appuyez sur une touche" if page == Page.KEYBOARD else "Appuyez sur un bouton"
	_field_text(canvas, 112, 123, _translate(instruction), PRIMARY, 8)
	_field_text(canvas, 112, 140, _translate("Échap / Back pour annuler"), MUTED, 7)
	if binding_error:
		_field_text(canvas, 112, 158, _translate("Commande réservée"), ARCADE_RED, 8)


func draw_marker(canvas: Node2D, point: Vector2, active: bool) -> void:
	canvas.draw_circle(point, 2.0, SHIP if active else BORDER, active, -1.0 if active else 0.6, true)
