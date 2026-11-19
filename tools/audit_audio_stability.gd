extends SceneTree

# Run with a real mixer (Dummy is sufficient). The wall-clock duration bounds
# the test independently of rendering or the fixed simulation step.
const Audio = preload("res://arcade_audio.gd")
var audio: Audio
var start_usec := 0
var frames := 0
var updates := 0
var duration := 20.0
var finishing := false
var switch_destinations := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		duration = float(args[0])
	switch_destinations = args.size() > 1 and args[1] == "switch"
	audio = Audio.new()
	root.add_child(audio)
	if audio._voices.is_empty():
		audio._create_voices()
	AudioServer.set_bus_mute(0, true)
	for cue in [Audio.CUES.enemy_ring, Audio.MODERN_CUES.enemy_ring]:
		cue.loop_mode = AudioStreamWAV.LOOP_FORWARD
		cue.loop_begin = 0
		cue.loop_end = cue.data.size() / 2
	audio.play("enemy_ring", -0.7)
	audio._enemy.stream = Audio.MODERN_CUES.enemy_ring
	audio._enemy.play()
	if switch_destinations:
		audio._preview.stream = Audio.CUES.enemy_ring
		audio._preview.play()
	start_usec = Time.get_ticks_usec()
	print("AUDIO STRESS START duration=", duration)

func _process(_delta: float) -> bool:
	if audio == null or finishing:
		return false
	for index in 4000:
		audio.set_enemy_pan(sin(float(updates) * 0.007))
		if switch_destinations and updates % 16 == 0:
			audio._route_voice(audio._preview, sin(float(updates) * 0.007), bool(updates & 16))
		updates += 1
	frames += 1
	if frames % 100 == 0:
		print("AUDIO STRESS frames=", frames, " routing_updates=", updates)
	if Time.get_ticks_usec() - start_usec >= duration * 1_000_000:
		finishing = true
		call_deferred("_finish")
	return false

func _finish() -> void:
	# Stop the looping test voices and let the real mixer consume its fade-out
	# before removing their buses. Under concurrent rendering load, freeing
	# everything immediately can leave a pending playback at engine shutdown.
	audio.stop()
	await create_timer(0.25).timeout
	audio.free()
	audio = null
	await create_timer(0.1).timeout
	print("AUDIO STRESS OK frames=", frames, " routing_updates=", updates, " switch=", switch_destinations)
	quit()
