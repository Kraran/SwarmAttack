extends SceneTree

# Capture the menu matrix on a real renderer; optionally compare raw pixel hashes.
var view: Node2D
var output := ""
var baseline := ""
var hashes := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		print("Usage: godot --path prototype --script ../tools/audit_menu_render.gd -- OUTPUT_DIRECTORY [BASELINE_DIRECTORY] (graphical renderer required)")
		quit(2)
		return
	output = args[0]
	baseline = args[1] if args.size() > 1 else ""
	var repository := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	if not output.is_absolute_path():
		output = repository.path_join(output).simplify_path()
	if not baseline.is_empty() and not baseline.is_absolute_path():
		baseline = repository.path_join(baseline).simplify_path()
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create capture directory: " + output)
		quit(1)
		return
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	RenderingServer.frame_pre_draw.disconnect(view._advance_starfield)
	view._profile = view.ArcadeProfile.new()
	view._profile.fullscreen = false
	for portrait in [false,true]:
		view._profile.portrait = portrait
		view._apply_display()
		root.size = view.PORTRAIT_SIZE if portrait else view.LANDSCAPE_SIZE
		for language in view.Language.LANGUAGES:
			view._profile.language = language
			view._return_to_title()
			view._attract.frame = 0
			await _capture("home",portrait,language)
			view._options.set_open(true)
			for page in range(view.OptionsMenu.Page.size()):
				view._options.open_page(page)
				await _capture("options-%d" % page,portrait,language)
			view._options.open_page(view.OptionsMenu.Page.KEYBOARD,2)
			view._options.confirm()
			await _capture("binding",portrait,language)
			_key(KEY_F2)
			await _capture("binding-reserved",portrait,language)
			_key(KEY_ESCAPE)
			view._options.open_page(view.OptionsMenu.Page.MAIN)
			view._options.save_failed = true
			await _capture("save-error",portrait,language)
			view._options.save_failed = false
			view._options.set_open(false)
			view._restart(false)
			view._pause.toggle()
			await _capture("pause",portrait,language)
			view._options.set_open(true)
			await _capture("pause-options",portrait,language)
			view._options.set_open(false)
			view._training.open_menu()
			await _capture("training",portrait,language)
			view._training.choice = 3
			view._training.confirm()
			view._session.pending = true
			view._session.completed = true
			view._session.success = false
			view._training.result_open = true
			view._training.choice = 0
			await _capture("training-result",portrait,language)
			view._return_to_title()
			view._scores.open()
			await _capture("score-tables",portrait,language)
			view._return_to_title()
			view._attract.frame = view.Attract.TITLE_TEXT_FRAMES
			view._scores.rows.assign([{"player":1,"score":12000,"cycle":2,"docks":2,"rank":0,"initials":"---"}])
			view._scores.results_open = true
			await _capture("results",portrait,language)
			view._scores.results_page = 1
			await _capture("result-ranking",portrait,language)
			view._scores.results_open = false
			view._scores.candidates.assign([{"player":1,"score":12000}])
			view._scores.entry = view.ScoresMenu.ScoreEntry.new()
			await _capture("initials",portrait,language)
			view._scores.entry.save_failed = true
			await _capture("initials-save-error",portrait,language)
	var file := FileAccess.open(output.path_join("hashes.json"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write capture manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(hashes,"\t"))
	file.close()
	print("MENU CAPTURES: %d" % hashes.size())
	var differences: Array[String] = []
	if not baseline.is_empty():
		var previous = JSON.parse_string(FileAccess.get_file_as_string(baseline.path_join("hashes.json")))
		if not previous is Dictionary or previous.size() != hashes.size():
			push_error("Invalid or incomplete baseline")
			quit(1)
			return
		for name: String in hashes:
			if previous.get(name) != hashes[name]:
				differences.append(name)
		print("MENU PIXELS: %d exact matches, %d differences" % [hashes.size()-differences.size(),differences.size()])
		for name in differences:
			print("DIFF: " + name)
	quit(1 if not differences.is_empty() else 0)

func _capture(label: String, portrait: bool, language: String) -> void:
	for index in 2:
		view._focused = true # Keep OS focus changes out of the visual comparison.
		var pointer := InputEventMouseMotion.new()
		pointer.position = Vector2(2,2)
		pointer.global_position = pointer.position
		Input.parse_input_event(pointer)
		Input.flush_buffered_events()
		view._redraw()
		await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	var name := "%s-%s-%s" % ["portrait" if portrait else "landscape",language,label]
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(pixels.get_data())
	hashes[name] = digest.finish().hex_encode()
	pixels.save_png(output.path_join(name + ".png"))

func _key(code: Key) -> void:
	view._focused = true
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)
