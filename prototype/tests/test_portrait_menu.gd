extends SceneTree

# En portrait, l'accueil est entièrement accessible au clavier et à la manette.
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
	view._profile.portrait = true
	await process_frame
	view.finish_intro()
	view._return_to_title()
	var title = view._title
	_expect(not title.portrait_open, "L'attraction reste visible au départ")
	_key(KEY_DOWN)
	_expect(title.portrait_open and title.choice == 0 and view._attract_active, "Une direction ouvre le menu sur « 1 joueur »")
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	_expect(title.choice == 2, "Bas descend dans la liste")
	_key(KEY_RIGHT)
	_expect(view._profile.difficulty == 1, "Droite choisit Vétérans")
	_key(KEY_LEFT)
	_expect(view._profile.difficulty == 0, "Gauche revient à Normal")
	_key(KEY_ENTER)
	_expect(view._training.opened and not title.portrait_open, "Entrée ouvre l'entraînement")
	view._training.opened = false
	_pad(JOY_BUTTON_DPAD_UP)
	_expect(title.portrait_open and title.choice == 0, "La croix ouvre aussi le menu")
	_pad(JOY_BUTTON_DPAD_UP)
	_expect(title.choice == title.LABELS.size() - 1, "Haut boucle vers « Quitter »")
	_pad(JOY_BUTTON_DPAD_UP)
	_expect(title.choice == 4, "Haut remonte sur « Options »")
	_pad(JOY_BUTTON_A)
	_expect(view._options.opened, "A ouvre les Options")
	view._options.set_open(false)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_B)
	_expect(not title.portrait_open and view._attract_active, "B referme le menu sans quitter")
	_key(KEY_UP)
	_expect(title.portrait_open, "Le menu se rouvre")
	title._portrait_input_msec -= title.PORTRAIT_IDLE_MSEC
	view._process(0.016)
	_expect(not title.portrait_open, "Sans action, le menu se referme et l'attraction revient")
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	_expect(not view._attract_active and view._session.runs.size() == 2, "« 2 joueurs » lance une partie à deux")
	view._return_to_title()
	_expect(not title.portrait_open, "Le retour à l'accueil referme le menu")
	view._profile.portrait = false
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("PORTRAIT MENU OK")
		quit(0)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	view._input(event)
	event = event.duplicate()
	event.pressed = false
	view._input(event)

func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	view._input(event)
	event = event.duplicate()
	event.pressed = false
	view._input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
