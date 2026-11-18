extends SceneTree

const Profile = preload("res://arcade_profile.gd")
var view: Node2D
var failures := 0
var links: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = Profile.new()
	view._profile.language = "fr"
	_click(view.HEADER_LOGO.get_center())
	_expect(view._about_is_open() and view._attract_active and view._audio.is_paused(),"Clic sur le logo : À propos sans démarrer une partie")
	var tick: int = view._simulation_tick
	view._process(0.2)
	_expect(view._simulation_tick == tick,"L'attraction est figée pendant À propos")
	view._about.link_requested.connect(func(url: String): links.append(url))
	_key(KEY_UP)
	_key(KEY_ENTER)
	_expect(links == [view.AboutPanel.AUTHOR_URL],"La photo ouvre le profil GitHub de l'auteur")
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	_pad(JOY_BUTTON_A)
	_expect(links[-1] == view.AboutPanel.REPOSITORY_URL,"Le bouton Projet vise le dépôt SWARM ATTACK")
	_pad(JOY_BUTTON_B)
	_expect(not view._about_is_open() and view._attract_active and not view._audio.is_paused(),"B ferme et restitue l'accueil")
	view._attract.frame = 300
	view._redraw()
	var regions: Array[Rect2] = view._logo_regions()
	_expect(regions.size() == 2,"Le logo animé visible est également cliquable")
	_click(regions[1].get_center())
	_expect(view._about_is_open(),"Clic sur le logo dans le terrain")
	_key(KEY_ESCAPE)
	view._profile.portrait = true
	_click(view.PORTRAIT_HEADER_LOGO.get_center())
	_expect(view._about_is_open() and view._about.size == Vector2(view.PORTRAIT_SIZE),"Ouverture depuis le logo en portrait")
	var expected_close := ["Close","Fermer","Cerrar","Fechar","Schließen","Chiudi"]
	var index := 0
	for language in view.Language.LANGUAGES:
		view._about.present(view.PORTRAIT_SIZE,language)
		_expect(view._about._close.text == expected_close[index],"Traduction À propos : " + language)
		index += 1
	_key(KEY_ESCAPE)
	view._profile.portrait = false
	view._set_options_open(true)
	_click(view.HEADER_LOGO.get_center())
	_expect(view._about_is_open() and view._options_open,"Ouverture depuis Options sans perdre le contexte")
	var muted: bool = view._profile.muted
	_key(KEY_F5)
	_expect(view._profile.muted == muted,"Le dialogue n'active pas les raccourcis du jeu")
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(view._audio.is_paused(),"Le retour du focus ne relance pas le son derrière À propos")
	_key(KEY_ESCAPE)
	_expect(view._options_open and view._audio.is_paused(),"Fermer retrouve Options et son état audio")
	view._set_options_open(false)
	view._restart(false)
	view._run._begin_combat(112,255)
	view._advance_frame(view.Pilot.FRAME_USEC/2,0)
	var fraction: int = view._elapsed_usec
	var run = view._run
	var frame: int = run.frame
	view._last_mouse_motion_usec = Time.get_ticks_usec() - view.CURSOR_HIDE_USEC - 1
	view._update_cursor()
	_expect(view._cursor_hidden,"Le curseur peut être masqué avant l'ouverture")
	_click(view.HEADER_LOGO.get_center())
	view._process(0.2)
	_expect(run.frame == frame and not view._cursor_hidden and not view._paused,"Partie figée et curseur visible, sans changer son état de pause")
	Input.action_press(&"fire")
	_key(KEY_ENTER)
	_expect(not view._about_is_open() and view._run == run and not view._paused and view._wait_for_fire_release,
		"Fermer restitue la même partie sans tirer avec le bouton maintenu")
	_expect(view._elapsed_usec == fraction,"La reprise conserve la fraction de frame, sans recul de la pose interpolée")
	view._advance_frame(view.Pilot.FRAME_USEC,view.Pilot.FIRE)
	_expect(run.combat.pilot.active_shots().is_empty(),"Aucun tir involontaire à la fermeture")
	Input.action_release(&"fire")
	view._toggle_pause()
	_click(view.HEADER_LOGO.get_center())
	_key(KEY_ESCAPE)
	_expect(view._paused and view._audio.is_paused(),"Une partie déjà en pause reste en pause")
	if failures == 0:
		print("ABOUT OK: logos, portrait, liens, six langues, navigation, focus, reprise et absence de tir involontaire.")
	quit(1 if failures else 0)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)

func _pad(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	view._input(event)

func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view._input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
