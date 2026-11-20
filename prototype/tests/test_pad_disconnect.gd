extends SceneTree

# Une manette débranchée ou perdue en cours de partie met le jeu en pause.
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
	view._on_joy_connection_changed(0, false)
	_expect(not view._pause.active and view._attract_active, "Accueil : pas de pause")
	view._restart(false)
	_expect(not view._pause.active, "Partie lancée")
	_pad(0)
	view._on_joy_connection_changed(1, false)
	_expect(not view._pause.active, "Une autre manette débranchée est ignorée")
	view._on_joy_connection_changed(0, false)
	_expect(view._pause.active and view._pause.pad_lost and view._pause.asking == -1, "Débranchement en partie : pause avec message")
	_expect(view._audio.is_paused(), "Le son est coupé pendant la pause")
	view._on_joy_connection_changed(0, true)
	_expect(view._pause.active and not view._pause.pad_lost, "Rebranchement : la pause reste, le message disparaît")
	view._pause.toggle()
	_expect(not view._pause.active and not view._pause.pad_lost, "Reprise manuelle")
	_key(KEY_LEFT)
	view._on_joy_connection_changed(0, false)
	_expect(not view._pause.active, "Partie au clavier : la manette débranchée est ignorée")
	_pad(0)
	view._pause.toggle()
	view._on_joy_connection_changed(0, false)
	_expect(view._pause.active and view._pause.pad_lost, "Déjà en pause : la pause reste active")
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("PAD DISCONNECT OK")
		quit(0)

func _pad(device: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_DPAD_LEFT
	event.pressed = true
	view._input(event)
	event = event.duplicate()
	event.pressed = false
	view._input(event)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)
	event = event.duplicate()
	event.pressed = false
	view._input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
