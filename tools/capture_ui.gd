extends SceneTree

# Full HD captures of the menus for visual review.
# godot --path prototype --script ../tools/capture_ui.gd -- OUTPUT [languages] [landscape|portrait|both] [skin] [WIDTHxHEIGHT] [left|right]
var view: Node2D
var output := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		print("Usage: godot --path prototype --script ../tools/capture_ui.gd -- OUTPUT [fr,en] [landscape|portrait|both] [skin]")
		quit(2)
		return
	output = args[0]
	var languages := (args[1] if args.size() > 1 else "fr").split(",")
	var orientation := args[2] if args.size() > 2 else "landscape"
	DirAccess.make_dir_recursive_absolute(output)
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view.finish_intro()
	view._focused = true
	RenderingServer.frame_pre_draw.disconnect(view._advance_starfield)
	view._profile = view.ArcadeProfile.new()
	view._profile.fullscreen = false
	if args.size() > 3 and not args[3].is_empty():
		view._profile.skin = args[3]
	if args.size() > 5:
		view._profile.menu_left = args[5] == "left"
	var screen := Vector2i.ZERO
	if args.size() > 4:
		screen = Vector2i(int(args[4].get_slice("x", 0)), int(args[4].get_slice("x", 1)))
	view._apply_skin()
	var orientations := [false, true] if orientation == "both" else [orientation == "portrait"]
	for portrait in orientations:
		view._profile.portrait = portrait
		view._apply_display()
		root.size = screen if screen != Vector2i.ZERO else (Vector2i(776, 1080) if portrait else Vector2i(1920, 1080))
		await process_frame
		for language in languages:
			view._profile.language = language
			view._return_to_title()
			view._attract.frame = 0
			view._pad_hints = true
			await _capture("home-pad", portrait, language)
			view._pad_hints = false
			view._title.choice = 2
			await _capture("home-keyboard", portrait, language)
			view._title.choice = 0
			view._open_about()
			await _capture("about", portrait, language)
			view._close_about()
			view._options.set_open(true)
			for page in range(view.OptionsMenu.Page.size()):
				view._options.open_page(page, 1 if page > 0 else 0)
				await _capture("options-%d" % page, portrait, language)
			view._options.open_page(view.OptionsMenu.Page.KEYBOARD, 2)
			view._options.confirm()
			await _capture("binding", portrait, language)
			_key(KEY_ESCAPE)
			view._options.set_open(false)
			view._restart(false)
			for frame in 900:
				view._advance_frame(view.Pilot.FRAME_USEC, 0)
			await _capture("playing", portrait, language)
			view._pause.toggle()
			view._pad_hints = true
			await _capture("pause", portrait, language)
			view._pad_hints = false
			view._options.set_open(true)
			view._options.open_page(view.OptionsMenu.Page.AUDIO, 0)
			await _capture("pause-options-audio", portrait, language)
			view._options.set_open(false)
			view._training.open_menu()
			await _capture("training", portrait, language)
			view._training.choice = 3
			view._training.confirm()
			view._session.pending = true
			view._session.completed = true
			view._session.success = true
			view._training.result_open = true
			view._training.choice = 0
			await _capture("training-result", portrait, language)
			view._return_to_title()
			view._scores.open()
			await _capture("score-tables", portrait, language)
			view._return_to_title()
			view._scores.candidates.assign([{"player": 1, "score": 12000}])
			view._scores.entry = view.ScoresMenu.ScoreEntry.new()
			await _capture("initials", portrait, language)
			view._scores.entry = null
			view._return_to_title()
	print("UI CAPTURES DONE")
	quit(0)

func _capture(label: String, portrait: bool, language: String) -> void:
	for index in 3:
		view._focused = true
		view._redraw()
		await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	pixels.save_png(output.path_join("%s-%s-%s.png" % ["portrait" if portrait else "landscape", language, label]))

func _key(code: Key) -> void:
	view._focused = true
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)
