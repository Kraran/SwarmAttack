extends SceneTree

const Profile = preload("res://arcade_profile.gd")
const Audio = preload("res://arcade_audio.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := Profile.new()
	_expect(profile.audio_bank == "original", "Banque originale par défaut")
	profile.audio_bank = "modern"
	_expect(profile.write("user://audio-bank-test.cfg") == OK, "Sauvegarde de la banque")
	var loaded := Profile.new()
	loaded.read("user://audio-bank-test.cfg")
	_expect(loaded.audio_bank == "modern", "Banque restaurée")
	for cue in Audio.CUES:
		var stream: AudioStreamWAV = Audio.MODERN_CUES[cue]
		_expect(stream.mix_rate == 48000 and stream.get_length() > 0.1
			and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Son moderne valide : " + cue)
		var pcm := stream.data
		_expect(pcm.decode_s16(0) == 0 and pcm.decode_s16(pcm.size() - 2) == 0, "Bords sans clic : " + cue)
		var peak := 0
		for index in range(0, pcm.size(), 2):
			peak = maxi(peak, absi(pcm.decode_s16(index)))
		_expect(peak > 1000 and peak < 32767, "Dynamique sans écrêtage : " + cue)
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._set_options_open(true)
	view._open_options_page(view.OptionsPage.AUDIO)
	view._options_choice = 2
	view._adjust_option(1)
	_expect(view._profile.audio_bank == "modern" and view._audio._bank == "modern", "Choix immédiat dans Options Son")
	view._adjust_option(-1)
	_expect(view._profile.audio_bank == "original" and view._audio._bank == "original", "Retour aux sons originaux")
	if failures == 0:
		print("AUDIO BANKS OK: défaut original, persistance, 11 sons modernes, PCM sans clic ni écrêtage, options.")
	quit(1 if failures else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
