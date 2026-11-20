extends SceneTree

const Profile = preload("res://arcade_profile.gd")
const Haptics = preload("res://arcade_haptics.gd")
const Language = preload("res://arcade_language.gd")
var failures := 0

class PadSpy extends "res://arcade_haptics.gd":
	var pads: Array[int] = [2]
	var pulses: Array[Array] = []
	var stops: Array[int] = []
	var clock := 1_000_000
	func _devices() -> Array[int]: return pads
	func _now_usec() -> int: return clock
	func _start(id: int, weak: float, strong: float, seconds: float) -> void:
		pulses.append([id, weak, strong, seconds])
	func _stop(id: int) -> void: stops.append(id)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_profile_checks()
	_controller_checks()
	_envelope_checks()
	_view_checks()
	print("CONNECTED GAMEPADS: ", Input.get_connected_joypads())
	if failures == 0:
		print("HAPTICS OK: events, priority, devices, menus, persistence, pause, focus and shutdown.")
	quit(1 if failures else 0)

func _profile_checks() -> void:
	var path := "user://haptics-%d.cfg" % OS.get_process_id()
	var profile := Profile.new()
	_expect(profile.vibration_enabled and profile.vibration_intensity == 70, "Moderate default intensity")
	profile.vibration_enabled = false
	profile.vibration_intensity = 30
	_expect(profile.write(path) == OK, "Save settings")
	var loaded := Profile.new()
	loaded.read(path)
	_expect(not loaded.vibration_enabled and loaded.vibration_intensity == 30, "Restore settings")
	var legacy := ConfigFile.new()
	legacy.set_value("options", "volume", 40)
	legacy.save(path + ".legacy")
	loaded.read(path + ".legacy")
	_expect(loaded.vibration_enabled and loaded.vibration_intensity == 70 and loaded.volume == 40, "Old profile migration")
	for value in ["broken", -20, 200]:
		legacy.set_value("options", "vibration_intensity", value)
		legacy.save(path + ".legacy")
		loaded.read(path + ".legacy")
		_expect(loaded.vibration_intensity == (70 if value is String else clampi(value, 0, 100)), "Invalid intensity bounded")
	for source in ["Vibrations", "Intensité", "actives", "désactivées", "Tester les vibrations"]:
		for language in Language.TRANSLATED_LANGUAGES:
			_expect(Language.text(source, language) != source, "Translated haptic settings")

func _controller_checks() -> void:
	var pad := PadSpy.new()
	pad.play("success")
	_expect(pad.pulses.is_empty(), "No attract or menu gameplay pulses")
	pad.set_gameplay_active(true)
	pad.configure(true, 50)
	pad.play("success")
	_expect(pad.pulses.size() == 1 and pad.pulses[0][0] == 2
		and is_equal_approx(pad.pulses[0][1], sqrt(0.5)) and is_equal_approx(pad.pulses[0][2], sqrt(0.5)),
		"Single pad fallback and powerful docking contact")
	pad.play("loss")
	var count := pad.pulses.size()
	pad.play("success")
	pad.play("hit_ring")
	_expect(pad.pulses.size() == count, "Loss protected from weaker effects")
	pad.clock += 1_100_000
	for cue in ["shot", "bonus", "hit_ring", "hit_claw", "hit_interceptor", "hit_meteor", "hit_row", "impact"]:
		pad.play(cue)
	_expect(pad.pulses.size() == count, "Enemy hit remains silent after strong effect ends")
	pad.play("success")
	_expect(pad.pulses.size() == count + 1 and pad._priority == 2, "Only docking contact starts another short effect")
	count += 1
	for pulse in pad.pulses:
		_expect(pulse[1] >= 0 and pulse[1] <= 1 and pulse[2] >= 0 and pulse[2] <= 1
			and pulse[3] > 0 and pulse[3] <= 0.35, "Bounded finite pulses")
	pad.set_gameplay_active(false)
	_expect(pad._priority == 2, "Leaving play lets the running effect finish")
	count = pad.pulses.size()
	pad.play("loss")
	_expect(pad.pulses.size() == count, "No new gameplay effect outside play")
	pad.stop()
	_expect(pad._priority == -1 and pad.stops[-1] == 2, "Immediate stop on pause")
	pad.preview()
	_expect(pad.pulses.size() == count + 1, "Preview available in settings")
	pad.configure(false, 100)
	pad.preview()
	_expect(pad.pulses.size() == count + 1, "Disabled preview silent")
	pad.configure(true, 0)
	pad.preview()
	_expect(pad.pulses.size() == count + 1, "Zero intensity silent")
	pad.configure(true, 100)
	pad.pads = [2, 7]
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.pressed = true
	pad.handle_input(event)
	pad.preview()
	_expect(pad.device == 7 and pad.pulses[-1][0] == 7 and pad.stops.has(2), "Switch to active controller only")
	pad.connection_changed(7, false)
	_expect(pad.device == -1 and pad.stops[-1] == 7, "Disconnect stops and forgets controller")
	count = pad.pulses.size()
	pad.preview()
	_expect(pad.pulses.size() == count, "Multiple controllers wait for intentional input")
	pad.pads = []
	pad.preview()
	_expect(pad.pulses.size() == count, "No controller is harmless")
	pad.free()
	# The same 70% setting now drives different motors for docking contact and explosions.
	var stronger := PadSpy.new()
	stronger.configure(true, 70)
	stronger.set_gameplay_active(true)
	for cue in ["loss", "crash", "success"]:
		stronger.clock += 1_000_000
		stronger.play(cue)
		var pulse: Array = stronger.pulses[-1]
		if cue == "success":
			_expect(pulse[1] > 0.8 and pulse[2] > 0.8, "Strong docking contact at 70%")
		elif cue in ["loss", "crash"]:
			_expect(pulse[2] > 0.8 and pulse[1] > 0.8, "Heavy explosion at 70%: " + cue)
		_expect(pulse[1] <= 1.0 and pulse[2] <= 1.0, "Motor limits retained")
	var last := 0.0
	for percent in range(10, 101, 10):
		stronger.configure(true, percent)
		stronger.play("success")
		var strength: float = stronger.pulses[-1][1]
		_expect(strength > last, "Intensity steps remain progressive")
		last = strength
	stronger.free()

func _total(steps: Array) -> float:
	var total := 0.0
	for step: Array in steps:
		total += step[2]
	return total

func _advance(pad: PadSpy, seconds: float) -> void:
	pad.clock += int(round(seconds * 1_000_000))
	pad._process(seconds)

func _envelope_checks() -> void:
	var pad := PadSpy.new()
	pad.configure(true, 70)
	pad.set_gameplay_active(true)
	pad.play("success")
	_expect(pad.pulses[-1][1] > 0.8 and pad.pulses[-1][2] > 0.8, "Docking contact starts with a full shock")
	_advance(pad, Haptics.DOCKING[0][2])
	_expect(pad._stage == 1 and pad.stops[-1] == 2, "Docking contact: short gap before the clamps lock")
	_advance(pad, Haptics.DOCKING[1][2])
	_expect(pad._stage == 2 and pad.pulses[-1][2] > 0.8, "Clamps lock with a second strong shock")
	_expect(_total(Haptics.DOCKING) >= 0.5, "Docking contact lasts at least half a second")
	_advance(pad, _total(Haptics.DOCKING) - Haptics.DOCKING[0][2] - Haptics.DOCKING[1][2])
	_expect(pad._priority == -1, "Docking contact ends cleanly")
	for cue in ["loss", "crash"]:
		var steps: Array = Haptics.PATTERNS[cue].steps
		_expect(_total(steps) >= 0.9, "Explosion lasts close to a second: " + cue)
		pad.play(cue)
		var strengths := [pad.pulses[-1][2] + pad.pulses[-1][1]]
		for index in range(1, steps.size()):
			_advance(pad, steps[index - 1][2])
			strengths.append(pad.pulses[-1][2] + pad.pulses[-1][1])
		var fading := true
		for index in range(1, strengths.size()):
			fading = fading and strengths[index] < strengths[index - 1] and strengths[index] > 0.0
		_expect(fading, "Explosion fades through distinct strengths: " + cue)
		var count := pad.pulses.size()
		pad.play("success")
		_expect(pad.pulses.size() == count, "Docking contact cannot replace the explosion tail")
		_advance(pad, steps[-1][2])
		_expect(pad._steps.is_empty() and pad._priority == -1, "Explosion ends at its absolute deadline")
	pad.play("loss")
	_advance(pad, _total(Haptics.EXPLOSION) - 0.04)
	_expect(pad._stage == Haptics.EXPLOSION.size() - 1 and pad.pulses[-1][3] < 0.041,
		"A delayed frame skips stale stages and shortens the remaining tail")
	pad.stop()
	var count := pad.pulses.size()
	_advance(pad, 1.0)
	_expect(pad.pulses.size() == count, "Stopped sequences never restart")
	pad.preview()
	_expect(pad.pulses[-1][1] == pad.pulses[-1][2], "Preview begins with docking contact")
	_advance(pad, _total(Haptics.DOCKING))
	_expect(pad._stage == Haptics.DOCKING.size() and pad.stops[-1] == 2, "Preview has silence between docking contact and explosion")
	_advance(pad, Haptics.PREVIEW_GAP[0][2])
	_expect(pad._stage == Haptics.DOCKING.size() + 1 and pad._steps.size() == Haptics.DOCKING.size() + 1 + Haptics.EXPLOSION.size(),
		"Preview then demonstrates the player explosion")
	pad.stop()
	count = pad.pulses.size()
	_advance(pad, 0.1)
	_expect(pad.pulses.size() == count and pad._steps.is_empty(), "Pause cancels all pending stages")
	pad.free()

func _view_checks() -> void:
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view.remove_child(view._haptics)
	view._haptics.free()
	var pad := PadSpy.new()
	view._haptics = pad
	view.add_child(pad)
	view._profile = Profile.new()
	view._restart(false)
	view._run._begin_combat(112, 255)
	view._audio.set_muted(true)
	view._audio.set_volume(0)
	view._step_session(view.Pilot.FIRE)
	_expect(pad.pulses.is_empty(), "Actual player shot produces no vibration")
	pad.clock += 1_000_000
	var before := pad.pulses.size()
	view._run.combat.impact_age = -1
	view._step_session(0)
	_expect(pad.pulses.size() == before, "Actual enemy impact produces no vibration")
	view._run.combat.outcome = view.ArcadeRun.CombatRound.Outcome.MODULE_LOST
	view._run.combat.lost_module = 1
	view._step_session(0)
	_expect(is_equal_approx(pad.pulses[-1][3], pad.EXPLOSION[0][2]) and pad._steps.size() == pad.EXPLOSION.size(), "Actual module loss gives an explosion envelope")
	view._scores.results_open = true
	view._redraw()
	_expect(not pad.gameplay_active and pad._priority == 3, "A result screen does not cut the explosion short")
	view._scores.results_open = false
	view._redraw()
	_docking_checks(view, pad)
	view._pause.toggle()
	_expect(not pad.gameplay_active and pad._priority == -1, "Pause stops immediately")
	view._options.set_open(true)
	view._options.choice = view.OptionsMenu.VIBRATION
	_key(view, KEY_ENTER)
	_expect(view._options.page == view.OptionsMenu.Page.VIBRATION, "Vibration submenu reachable")
	_key(view, KEY_DOWN)
	_key(view, KEY_LEFT)
	_expect(view._profile.vibration_intensity == 60 and pad.intensity == 60, "Intensity adjusted and applied")
	var saved := Profile.new()
	saved.read()
	_expect(saved.vibration_intensity == 60, "Intensity saved immediately")
	for index in 20: _key(view, KEY_LEFT)
	_expect(pad.intensity == 0, "Intensity lower bound via menu")
	for index in 20: _key(view, KEY_RIGHT)
	_expect(pad.intensity == 100, "Intensity upper bound via menu")
	_key(view, KEY_UP)
	_key(view, KEY_ENTER)
	var count := pad.pulses.size()
	view._options.choice = 2
	_key(view, KEY_ENTER)
	_expect(not pad.enabled and pad.pulses.size() == count, "Off switch also suppresses test button")
	view._options.choice = 0
	_key(view, KEY_ENTER)
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(pad._priority == -1, "Focus loss stops preview immediately")
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	view._options.choice = 2
	_key(view, KEY_ENTER)
	_expect(pad._priority >= 0, "Test button starts preview")
	_key(view, KEY_ESCAPE)
	_expect(pad._priority == -1 and view._options.choice == view.OptionsMenu.VIBRATION, "Back stops preview and restores selection")
	_expect(view._options.item_rect(view.OptionsMenu.BACK).end.y + 40 <= view._options.bar_rect().position.y, "Main menu and hint fit above the hint bar")
	view._options.set_open(false)
	view._pause.toggle()
	pad.play("loss")
	view._open_about()
	_expect(pad._priority == -1, "About stops gameplay vibration")
	view._close_about()
	view._return_to_title()
	_expect(not pad.gameplay_active and pad._priority == -1, "Title has no gameplay vibration")
	pad.preview()
	view.remove_child(pad)
	_expect(pad._priority == -1, "Leaving tree stops motors")
	pad.free()
	view.free()

func _docking_checks(view: Node2D, pad: PadSpy) -> void:
	for practice in [false, true]:
		view._exercise_kind = view.TrainingSession.Kind.DOCKING
		view._exercise_target = 1
		view._restart(practice)
		if not practice:
			view._run.phase = view.ArcadeRun.Phase.DOCKING
			view._run.docking = view.Docking.new(1, view.Pilot.START_X, false)
		var dock = view._run.docking
		dock.stage = view.Docking.Stage.APPROACH
		dock.position = view.Docking.TARGET + Vector2i(14, -7)
		dock._elapsed = 0
		dock._horizontal.velocity = 111
		dock._horizontal.wait = 1
		dock._vertical.velocity = 125
		dock._vertical.wait = 0
		pad.clock += 1_000_000
		var count := pad.pulses.size()
		_expect(dock.stage == view.Docking.Stage.APPROACH, "No contact yet")
		view._step_session(view.Pilot.RIGHT | view.Pilot.FIRE)
		_expect(dock.stage == view.Docking.Stage.SUCCESS and pad.pulses.size() == count + 1
			and is_equal_approx(pad.pulses[-1][3], pad.DOCKING[0][2]) and pad._steps.size() == pad.DOCKING.size(),
			"Docking shock on actual successful contact, practice=%s" % practice)
		for frame in 10:
			view._step_session(0)
		_expect(pad.pulses.size() == count + 1, "No repeated shock during docking bonus")
	view._exercise_kind = view.TrainingSession.Kind.WAVE
	view._restart(true)
	view._run.combat.outcome = view.ArcadeRun.CombatRound.Outcome.CLEARED
	var count := pad.pulses.size()
	view._step_session(0)
	_expect(pad.pulses.size() == count, "Training wave completion is not docking contact")
	view._restart(false)
	view._play_feedback("bonus")
	_expect(pad.pulses.size() == count, "Extra life gives no rumble")

func _key(view: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
