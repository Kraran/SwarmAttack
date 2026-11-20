extends SceneTree

# Xbox (Guide) + Start ouvre la question « Quitter » de partout, Non par défaut.
const Profile = preload("res://arcade_profile.gd")
var view: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = Profile.new()
	await process_frame
	# Accueil
	_combo()
	_expect(view._quit_prompt.opened and view._quit_prompt.answer == 1 and view._attract_active, "Accueil : question ouverte, Non présélectionné")
	_key(KEY_ENTER)
	_expect(not view._quit_prompt.opened and view._attract_active, "Non referme la question et reste à l'accueil")
	_combo()
	_key(KEY_ESCAPE)
	_expect(not view._quit_prompt.opened and view._attract_active, "Échap annule sans quitter l'accueil")
	_button(JOY_BUTTON_GUIDE, true)
	_button(JOY_BUTTON_GUIDE, false)
	_expect(not view._quit_prompt.opened, "Le bouton Xbox seul ne fait rien")
	# Options depuis l'accueil
	view._options.set_open(true)
	view._options.open_page(view.OptionsMenu.Page.AUDIO, 1)
	_combo()
	_expect(view._quit_prompt.opened and view._options.opened, "Options : la question s'ouvre par-dessus")
	_key(KEY_RIGHT)
	_expect(view._quit_prompt.answer == 0 and view._options.choice == 1 and not view._profile.muted, "Les flèches changent la réponse, pas l'option")
	_button(JOY_BUTTON_B, true)
	_button(JOY_BUTTON_B, false)
	_expect(not view._quit_prompt.opened and view._options.opened and view._options.page == view.OptionsMenu.Page.AUDIO, "B annule et garde la page d'options")
	view._options.set_open(false)
	# En partie : pause puis question du menu Pause
	view._restart(false)
	_expect(not view._pause.active, "Partie lancée")
	_combo()
	_expect(view._pause.active and view._pause.asking == view._pause.QUIT and view._pause.answer == 1 and not view._quit_prompt.opened,
		"En partie : pause et question Quitter, Non présélectionné")
	_key(KEY_ENTER)
	_expect(view._pause.active and view._pause.asking == -1 and not view._attract_active, "Non garde la partie en pause")
	# Pause avec les options ouvertes
	view._options.set_open(true)
	_combo()
	_expect(view._quit_prompt.opened and view._options.opened and view._pause.active, "Options en pause : question par-dessus")
	_key(KEY_ESCAPE)
	_expect(not view._quit_prompt.opened and view._options.opened and view._pause.active, "Annuler revient aux options en pause")
	view._options.set_open(false)
	view._pause.toggle()
	# Start seul garde son rôle de pause
	_button(JOY_BUTTON_START, true)
	_button(JOY_BUTTON_START, false)
	_expect(view._pause.active and view._pause.asking == -1, "Start seul met toujours en pause")
	print("QUIT COMBO OK" if failures == 0 else "QUIT COMBO: %d échec(s)" % failures)
	quit(1 if failures else 0)

func _combo() -> void:
	_button(JOY_BUTTON_GUIDE, true)
	_button(JOY_BUTTON_START, true)
	_button(JOY_BUTTON_START, false)
	_button(JOY_BUTTON_GUIDE, false)

func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
