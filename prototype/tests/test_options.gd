extends SceneTree

const Profile = preload("res://arcade_profile.gd")
const Controls = preload("res://arcade_controls.gd")
const Pilot = preload("res://pilot.gd")
const Run = preload("res://arcade_run.gd")
const Audio = preload("res://arcade_audio.gd")
var view: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_profile_checks()
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = Profile.new()
	Controls.apply(view._profile.key_bindings, view._profile.button_bindings)
	_key(KEY_F3)
	_expect(view._options_open and view._options_back_index() == 7, "Options depuis l’accueil")
	view._options_choice = view.OPTIONS_AUDIO
	_key(KEY_ENTER)
	_key(KEY_LEFT)
	_expect(view._profile.volume == 90 and view._audio._volume == 90, "Volume immédiat")
	for i in range(12):
		_key(KEY_LEFT)
	_expect(view._profile.volume == 0, "Volume borné à zéro")
	for i in range(12):
		_key(KEY_RIGHT)
	_expect(view._profile.volume == 100, "Volume borné à cent")
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	_expect(view._profile.muted and view._audio._muted, "Coupure du son")
	_key(KEY_ENTER)
	_key(KEY_ESCAPE)
	view._options_choice = view.OPTIONS_CONTROLS
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	view._options_choice = 2
	_key(KEY_ENTER)
	_key(KEY_F2)
	_expect(view._binding_waiting == 2 and view._binding_error and view._attract_active, "Un raccourci réservé ne démarre pas une partie")
	_key(KEY_Z)
	_expect(view._binding_waiting == -1 and view._profile.key_bindings.fire == [KEY_Z]
		and _mapped(&"fire",KEY_Z), "Le tir utilise sa nouvelle touche")
	view._options_choice = 0
	_key(KEY_ENTER)
	_key(KEY_RIGHT)
	_expect(view._profile.key_bindings.move_left == [KEY_RIGHT]
		and view._profile.key_bindings.move_right == [KEY_LEFT, KEY_Q, KEY_A], "Échange d’affectations en cas de conflit")
	view._options_choice = 3
	_key(KEY_ENTER)
	_key(KEY_P)
	_expect(_mapped(&"pause",KEY_P), "Pause configurable")
	view._options_choice = 1
	_key(KEY_ENTER)
	_key(KEY_ESCAPE)
	_expect(view._binding_waiting == -1 and _mapped(&"move_right",KEY_LEFT), "Annulation de la saisie sans changement")
	_key(KEY_ESCAPE)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	view._options_choice = 2
	_key(KEY_ENTER)
	_pad(JOY_BUTTON_B)
	_expect(view._profile.button_bindings.fire == JOY_BUTTON_B, "Remappage du tir sur B")
	_key(KEY_ENTER)
	_pad(JOY_BUTTON_START)
	_expect(view._profile.button_bindings.fire == JOY_BUTTON_START
		and view._profile.button_bindings.pause == JOY_BUTTON_B, "Le bouton Start peut échanger sa fonction de pause avec le tir")
	view._options_choice = 0
	_key(KEY_ENTER)
	_pad(JOY_BUTTON_BACK)
	_expect(view._binding_waiting == -1, "Back annule l’affectation manette")
	var saved := Profile.new()
	saved.read()
	_expect(saved.key_bindings == view._profile.key_bindings and saved.button_bindings == view._profile.button_bindings
		and saved.volume == view._profile.volume, "Persistance des commandes et du volume")
	_key(KEY_F3)
	view._restart(false)
	for i in range(Run.ENTRANCE_FRAMES + 1):
		view._advance_frame(Pilot.FRAME_USEC,0)
	_native_key(KEY_Z,true)
	_expect(Input.is_action_pressed(&"fire"), "L’événement clavier natif utilise l’affectation")
	view._advance_frame(Pilot.FRAME_USEC,view._read_controls())
	_expect(not view._run.combat.pilot.active_shots().is_empty(), "Le tir remappé fonctionne dans la partie")
	_native_key(KEY_Z,false)
	_native_pad(JOY_BUTTON_START,true)
	_expect(not view._paused and bool(view._read_controls() & Pilot.FIRE), "Le bouton Start remappé tire pendant la partie")
	_native_pad(JOY_BUTTON_START,false)
	var ship_x: int = view._run.combat.pilot.ship_x
	_native_key(KEY_RIGHT,true)
	view._advance_frame(Pilot.FRAME_USEC,view._read_controls())
	_expect(view._run.combat.pilot.ship_x == ship_x-Pilot.MOVE_STEP, "Le déplacement remappé fonctionne dans la partie")
	_native_key(KEY_RIGHT,false)
	var tick: int = view._simulation_tick
	var phase: int = view._run.phase
	var score: int = view._run.score()
	_key(KEY_P)
	_expect(view._paused, "La nouvelle touche met en pause")
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	_expect(view._options_open and view._paused, "Options depuis la pause")
	view._options_choice = 1
	_key(KEY_ENTER)
	_expect(view._profile.difficulty == 1 and view._run_difficulty == 0 and view._run.cycle == 1, "La difficulté choisie en pause concerne la partie suivante")
	view._options_choice = view.OPTIONS_LANGUAGE
	_key(KEY_ENTER)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	_expect(view._profile.language == "fr", "Langue en pause")
	view._process(3.0)
	_expect(view._simulation_tick == tick and view._run.phase == phase and view._run.score() == score, "La partie reste figée pendant les options")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_expect(view._paused and not view._options_open, "Retour des options vers la pause")
	_key(KEY_P)
	_expect(not view._paused, "Reprise par la touche affectée")
	view._advance_frame(Pilot.FRAME_USEC,0)
	_expect(view._simulation_tick == tick+1, "Reprise sans rattrapage du temps passé dans les menus")
	view._toggle_pause()
	_key(KEY_F3)
	view._options_choice = view.OPTIONS_CONTROLS
	_key(KEY_ENTER)
	view._options_choice = 2
	_key(KEY_ENTER)
	_expect(view._profile.key_bindings == Controls.DEFAULT_KEYS and view._profile.button_bindings == Controls.DEFAULT_BUTTONS, "Restauration des commandes par défaut")
	_key(KEY_F3)
	_key(KEY_ESCAPE)
	if failures == 0:
		print("OPTIONS OK: volume, sauvegarde, remappage, conflits, annulation, pause, langue, restauration et reprise.")
	quit(1 if failures else 0)

func _profile_checks() -> void:
	var path := "user://test-options-%d.cfg" % OS.get_process_id()
	var profile := Profile.new()
	profile.volume = 60
	profile.muted = true
	profile.difficulty = 1
	Controls.assign_key(profile.key_bindings,&"fire",KEY_Z)
	Controls.assign_button(profile.button_bindings,&"fire",JOY_BUTTON_RIGHT_SHOULDER)
	_expect(profile.submit_score(11000,"VET",path) == OK, "Écriture des nouveaux réglages avec un record")
	var restored := Profile.new()
	restored.read(path)
	_expect(restored.volume == 60 and restored.muted and restored.key_bindings == profile.key_bindings
		and restored.button_bindings == profile.button_bindings and restored.initials[0] == "VET", "Relecture des nouveaux réglages et scores")
	var invalid := ConfigFile.new()
	var invalid_path := path + ".invalid"
	invalid.set_value("options","volume","invalid")
	invalid.set_value("controls","keys",{"fire":[KEY_Z]})
	invalid.set_value("controls","buttons",{"fire":-500})
	_expect(invalid.save(invalid_path) == OK, "Profil mal formé écrit")
	restored.read(invalid_path)
	_expect(restored.volume == 100 and restored.key_bindings == Controls.DEFAULT_KEYS
		and restored.button_bindings == Controls.DEFAULT_BUTTONS, "Un profil mal formé conserve des commandes utilisables")
	invalid.set_value("options","volume",500)
	_expect(invalid.save(invalid_path) == OK, "Profil avec volume excessif écrit")
	restored.read(invalid_path)
	_expect(restored.volume == 100, "Volume chargé borné")
	var duplicates := Controls.DEFAULT_KEYS.duplicate(true)
	duplicates.fire = [KEY_LEFT]
	_expect(Controls.read_keys(duplicates) == Controls.DEFAULT_KEYS, "Affectations conflictuelles chargées rejetées")
	var locked := Controls.DEFAULT_KEYS.duplicate(true)
	_expect(not Controls.assign_key(locked,&"pause",KEY_SPACE) and locked == Controls.DEFAULT_KEYS,
		"Un échange qui attribuerait Échap à une autre action conserve une configuration valide")
	DirAccess.remove_absolute(path)

func _mapped(action: StringName, code: Key) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event.is_action_pressed(action)


func _native_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _native_pad(button: JoyButton, pressed: bool) -> void:
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

func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	view._input(event)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

