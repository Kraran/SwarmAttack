extends SceneTree

const Counter = preload("res://ui/fps_counter.gd")
const Profile = preload("res://arcade_profile.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_measurement_checks()
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = Profile.new()
	view._redraw()
	_expect(not view._fps_counter.enabled and not view._fps_counter.is_processing(), "Optional counter disabled by default")
	view._options.set_open(true)
	view._options.open_page(view.OptionsMenu.Page.DISPLAY, 2)
	_key(view, KEY_ENTER)
	_expect(view._profile.show_fps and view._fps_counter.visible and view._fps_counter.is_processing(), "Options enables live counter immediately")
	var loaded := Profile.new()
	loaded.read()
	_expect(loaded.show_fps, "Counter preference saved")
	var invalid := ConfigFile.new()
	var invalid_path := "user://fps-invalid.cfg"
	invalid.set_value("options", "show_fps", "true")
	invalid.save(invalid_path)
	loaded.read(invalid_path)
	_expect(not loaded.show_fps, "Malformed preference safely disabled")
	view._options.set_open(false)
	view._restart(false)
	view._pause.toggle()
	var tick: int = view._simulation_tick
	await create_timer(0.7).timeout
	_expect(view._simulation_tick == tick and view._fps_counter._samples.size() > 1, "FPS measurement continues while simulation is paused")
	if DisplayServer.get_name() == "headless":
		_expect(view._fps_counter.fps == 0.0, "No rendering means zero FPS, not process or simulation FPS")
	else:
		await _graphical_checks(view)
	view._options.set_open(true)
	view._options.open_page(view.OptionsMenu.Page.DISPLAY,2)
	_key(view, KEY_ENTER)
	_expect(not view._fps_counter.enabled and not view._fps_counter.visible
		and not view._fps_counter.is_processing(), "Disable removes display and measurement work")
	loaded.read()
	_expect(not loaded.show_fps, "Disabled preference saved")
	view.free()
	if failures == 0:
		print("FPS OK: real rendered frames, wall clock, cadence changes, stalls, options, persistence and pause.")
	quit(1 if failures else 0)

func _measurement_checks() -> void:
	var counter := Counter.new()
	for index in range(11):
		counter._sample(1_000_000 + index*100_000, index*6)
	_expect(is_equal_approx(counter.fps,60.0), "60 rendered frames per real second")
	for index in range(1,7):
		counter._sample(2_000_000 + index*100_000,60+index*3)
	_expect(is_equal_approx(counter.fps,30.0), "Live rate responds to 30 FPS, without a 60Hz assumption")
	for index in range(1,7):
		counter._sample(2_600_000 + index*100_000,78)
	_expect(counter.fps == 0.0, "Stalled rendering decays to zero")
	counter._sample(1,0)
	_expect(counter.fps == 0.0 and counter._samples.size() == 1, "Frame counter reset cannot produce a negative or stale rate")
	counter._sample(100_001,12)
	_expect(is_equal_approx(counter.fps,120.0), "Counter also measures rates above 60 FPS")
	counter.free()

func _graphical_checks(view: Node2D) -> void:
	var previous_limit := Engine.max_fps
	for cap in [30,60]:
		Engine.max_fps = cap
		await create_timer(1.0).timeout
		var start_time := Time.get_ticks_usec()
		var start_frames := Engine.get_frames_drawn()
		await create_timer(1.0).timeout
		var reference := (Engine.get_frames_drawn()-start_frames)*1_000_000.0/(Time.get_ticks_usec()-start_time)
		print("FPS LIVE cap=",cap," measured=",view._fps_counter.fps," reference=",reference)
		_expect(absf(view._fps_counter.fps-reference) < 6.0 and view._fps_counter.fps > 0,
			"Counter matches independent rendered-frame measurement")
	RenderingServer.render_loop_enabled = false
	var process_before := Engine.get_process_frames()
	await create_timer(0.8).timeout
	_expect(Engine.get_process_frames() > process_before+5 and view._fps_counter.fps == 0.0,
		"Disabled rendering measures zero while the process loop keeps running")
	RenderingServer.render_loop_enabled = true
	Engine.max_fps = previous_limit
	await create_timer(0.7).timeout
	_expect(view._fps_counter.fps > 0, "Rendering resumption restores live counter")
	var output := ProjectSettings.globalize_path("res://../.reference/fps-captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	view._profile.fullscreen = false
	for portrait in [false,true]:
		view._profile.portrait = portrait
		view._apply_display()
		root.size = view.PORTRAIT_SIZE if portrait else view.LANDSCAPE_SIZE
		view._options.set_open(true)
		view._options.open_page(view.OptionsMenu.Page.DISPLAY,2)
		for language in view.Language.LANGUAGES:
			view._profile.language = language
			view._redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rect: Rect2 = view._fps_counter.counter_rect()
			_expect(rect.position.x > root.size.x*0.75 and rect.end.x <= root.size.x
				and rect.position.y >= 0 and rect.end.y <= 17, "Counter fits top-right header without covering portrait buttons")
			root.get_texture().get_image().save_png(output.path_join("%s-%s.png" % ["portrait" if portrait else "landscape",language]))

func _key(view: Node2D, code: Key) -> void:
	view._focused = true
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
