extends SceneTree

const Audio = preload("res://arcade_audio.gd")
const Wave = preload("res://combat_wave.gd")
var failures := 0

class AudioSpy extends "res://arcade_audio.gd":
	var events: Array[Array] = []
	var enemy_pan := 0.0
	func _ready() -> void: pass
	func play(cue: String, pan := 0.0) -> void: events.append([cue, pan])
	func set_enemy_pan(pan: float) -> void: enemy_pan = pan

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for pair in [[-40.0,-1.0],[0.0,-1.0],[56.0,-0.5],[112.0,0.0],[168.0,0.5],[224.0,1.0],[300.0,1.0]]:
		_expect(is_equal_approx(Audio.pan_for_x(pair[0]), pair[1]), "Proportional clamped balance")
	_view_checks()
	await _routing_and_mix_checks()
	if failures == 0:
		print("STEREO OK: source positions, moving enemies, independent voices, both banks, measured left/right mix and bus cleanup.")
	quit(1 if failures else 0)

func _view_checks() -> void:
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view.remove_child(view._audio)
	view._audio.free()
	var spy := AudioSpy.new()
	view._audio = spy
	view.add_child(spy)
	for portrait in [false, true]:
		view._profile.portrait = portrait
		view._restart(false)
		view._run._begin_combat(56,255)
		spy.events.clear()
		view._step_session(view.Pilot.FIRE)
		_expect(spy.events.size() == 1 and spy.events[0][0] == "shot" and spy.events[0][1] < -0.45,
			"Shot at actual ship position in both orientations")
		view._run.combat.impact_position = Vector2(196, 80)
		view._run.combat.impact_age = -1
		view._step_session(0)
		_expect(spy.events[-1][0] == "hit_ring" and spy.events[-1][1] > 0.7, "Enemy explosion uses impact, not ship position")
		view._run.combat.outcome = view.ArcadeRun.CombatRound.Outcome.MODULE_LOST
		view._run.combat.lost_module = 1
		view._run.combat.impact_position = Vector2(28, 200)
		view._step_session(0)
		_expect(spy.events[-1][0] == "loss" and spy.events[-1][1] < -0.7, "Player explosion stays at impacted module")
		view._play_feedback("cycle")
		_expect(spy.events[-1] == ["cycle",0.0], "Cycle music is centered")
		view._restart(false)
		view._run._begin_combat(112,255)
		for frame in Wave.SPAWN_FRAME:
			view._step_session(0)
		var enemy: Wave.Enemy = view._run.combat.wave.flight_sound_source
		_expect(enemy != null and spy.events[-1][0] == "enemy_ring"
			and is_equal_approx(spy.events[-1][1], Audio.pan_for_x(enemy.display_position().x)), "Flight source matches emitting enemy")
		enemy.position.x = 64
		view._redraw()
		var left := spy.enemy_pan
		enemy.position.x = 184
		view._redraw()
		_expect(left < 0 and spy.enemy_pan > 0, "Active flight sound follows enemy across field")
		view._run.phase = view.ArcadeRun.Phase.DOCKING
		view._run.docking = view.Docking.new(1,112,false)
		view._run.docking.position.x = 180
		view._play_feedback("success")
		_expect(spy.events[-1][0] == "success" and spy.events[-1][1] > 0.5, "Docking contact uses docking position")
	view.free()

func _routing_and_mix_checks() -> void:
	var before := AudioServer.bus_count
	var audio := Audio.new()
	root.add_child(audio)
	# Exercise the real audio graph on the Dummy driver too, without a device.
	if audio._voices.is_empty():
		audio._create_voices()
	var bus_count := AudioServer.bus_count
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0,capture)
	var capture_index := AudioServer.get_bus_effect_count(0)-1
	for bank in ["original","modern"]:
		audio.set_bank(bank)
		var energies: Array[float] = []
		for pan in [-1.0,-0.5,0.0,0.5,1.0]:
			audio.stop()
			await create_timer(0.1).timeout
			capture.clear_buffer()
			audio.play("shot",pan)
			await create_timer(0.3).timeout
			var frames := capture.get_buffer(capture.get_frames_available())
			var energy := Vector2.ZERO
			for frame in frames:
				energy += Vector2(frame.x*frame.x,frame.y*frame.y)
			print("STEREO MIX ",bank," pan=",pan," frames=",frames.size()," energy=",energy)
			energies.append(energy.x+energy.y)
			_expect(not frames.is_empty() and energy.x + energy.y > 0.001, "Audio mix actually captured")
			var expected_left: float = pow(1.0-pan,2)/(pow(1.0-pan,2)+pow(1.0+pan,2))
			_expect(absf(energy.x/(energy.x+energy.y)-expected_left) < 0.02, "Measured balance follows proportional channel gains")
			if pan == -1.0:
				_expect(energy.x > 20 * energy.y, "Left source predominantly left")
			elif pan == 1.0:
				_expect(energy.y > 20 * energy.x, "Right source predominantly right")
			elif pan == 0.0:
				_expect(absf(energy.x-energy.y) < 0.01*(energy.x+energy.y), "Center source balanced")
		for energy in energies:
			_expect(absf(energy-energies[2]) < energies[2]*0.03, "Constant mix energy across stereo field")
		audio.stop()
		audio.play("enemy_ring",-0.6)
		audio.play("shot",0.8)
		var shot: AudioStreamPlayer = audio._shot if bank == "original" else audio._effects[(audio._effect_cursor+Audio.EFFECT_VOICES-1)%Audio.EFFECT_VOICES]
		var enemy: AudioStreamPlayer = audio._tone if bank == "original" else audio._enemy
		_expect(is_equal_approx(audio._panners[shot].pan,0.8) and is_equal_approx(audio._panners[enemy].pan,-0.6), "Simultaneous voices keep separate balance")
		audio.set_enemy_pan(0.4)
		_expect(is_equal_approx(audio._panners[shot].pan,0.8) and is_equal_approx(audio._panners[enemy].pan,0.4), "Enemy motion never moves shot")
		audio.play("hit_ring",-0.7)
		var impact: AudioStreamPlayer = audio._tone if bank == "original" else audio._effects[(audio._effect_cursor+Audio.EFFECT_VOICES-1)%Audio.EFFECT_VOICES]
		audio.set_enemy_pan(0.9)
		_expect(is_equal_approx(audio._panners[impact].pan,-0.7), "Explosion remains at original impact position")
		audio.stop()
		audio.play("launch")
		audio.set_enemy_pan(-1.0)
		var music: AudioStreamPlayer = audio._tone if bank == "original" else audio._jingle
		_expect(audio._panners[music].pan == 0.0, "Enemy motion never moves music")
		audio.preview_shot()
		_expect(audio._panners[audio._preview].pan == 0.0, "Options preview centered")
		_expect(AudioServer.get_bus_send(AudioServer.get_bus_index(audio._preview.bus))
			== (Audio.MODERN_BUS if bank == "modern" else &"Master"), "Preview retains bank output routing")
		audio.set_paused(true)
		_expect(audio._voices.all(func(voice: AudioStreamPlayer): return not voice.playing or voice.stream_paused), "Pause includes all active stereo voices")
		audio.set_paused(false)
		_expect(AudioServer.bus_count == bus_count, "Playback creates no additional buses")
	AudioServer.remove_bus_effect(0,capture_index)
	var private_count := audio._stereo_buses.size()
	audio.free()
	_expect(AudioServer.bus_count == bus_count-private_count and AudioServer.bus_count >= before, "Private stereo buses cleaned up")
	await create_timer(0.1).timeout

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
