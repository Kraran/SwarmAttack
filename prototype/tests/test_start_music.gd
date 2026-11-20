extends SceneTree

# La musique de démarrage suit la voix « Swarm Attack », une seule fois.
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
	var audio = view._audio
	if audio._start_music == null:
		audio._create_voices()
	_expect(audio._start_music.stream.get_length() > 15.0, "Musique de démarrage chargée")
	_expect(not audio._start_music.stream.loop, "La musique ne boucle pas")
	audio._on_announcer_finished()
	_expect(not audio.start_music_playing(), "Pas de musique sans voix de démarrage")
	view._intro_time = 0.0
	view._intro_voice_played = false
	view._advance_intro(0.1)
	_expect(audio._announcer.playing and not audio.start_music_playing(), "La voix passe d'abord, sans la musique")
	audio._announcer.stop()
	audio._on_announcer_finished()
	_expect(audio.start_music_playing(), "La musique démarre à la fin de la voix")
	view.finish_intro()
	view._options.set_open(true)
	_expect(audio.start_music_playing() and not audio._start_music.stream_paused, "Options : la musique continue")
	view._options.set_open(false)
	view._training.open_menu()
	_expect(not audio._start_music.stream_paused, "Menu Entraînement : la musique continue")
	view._training.opened = false
	view._quit_prompt.open()
	_expect(not audio._start_music.stream_paused, "Question Quitter : la musique continue")
	view._quit_prompt.close()
	view._open_about()
	_expect(not audio._start_music.stream_paused, "À propos : la musique continue sous la voix")
	view._close_about()
	view._scores.open()
	_expect(not audio._start_music.stream_paused, "Classements : la musique continue")
	view._return_to_title()
	_expect(audio.start_music_playing(), "Retour à l'accueil : la musique continue")
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(audio._start_music.stream_paused, "Perte du focus : la musique attend")
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(not audio._start_music.stream_paused, "Retour du focus : la musique reprend")
	audio._start_music.stop()
	audio.play_title()
	audio._on_announcer_finished()
	_expect(not audio.start_music_playing(), "Une seule fois : la voix d'À propos ne la relance pas")
	audio._start_music.play()
	view._restart(false)
	_expect(not audio.start_music_playing(), "Lancer une partie coupe la musique")
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("START MUSIC OK")
		quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
