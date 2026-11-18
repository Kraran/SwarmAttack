extends SceneTree

const Profile = preload("res://arcade_profile.gd")
const Audio = preload("res://arcade_audio.gd")
var failures := 0

class AudioSpy extends "res://arcade_audio.gd":
	var cues: Array[String] = []
	func _ready() -> void:
		pass
	func play(cue: String) -> void:
		cues.append(cue)

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
	_check_ascent_music(view)
	if failures == 0:
		print("AUDIO BANKS OK: banques, PCM, options et musique à chaque montée sans répétition.")
	quit(1 if failures else 0)

func _check_ascent_music(view: Node2D) -> void:
	var old_audio: Node = view._audio
	view.remove_child(old_audio)
	old_audio.queue_free()
	var audio := AudioSpy.new()
	view._audio = audio
	view.add_child(audio)
	for bank in ["original", "modern"]:
		audio.set_bank(bank)
		audio.cues.clear()
		view._restart(false)
		_expect(audio.cues.count("launch") == 1, bank + " : musique initiale")
		for frame in view.ArcadeRun.ENTRANCE_FRAMES:
			view._step_session(0)
		_expect(audio.cues.count("launch") == 1, "Pas de redémarrage pendant l'arrivée")
		audio.cues.clear()
		view._run.combat.outcome = view.ArcadeRun.CombatRound.Outcome.MODULE_LOST
		view._run.combat.lost_module = 1
		view._step_session(0)
		_expect(audio.cues == ["loss"], "Explosion conservée avant le retour")
		for frame in view.ArcadeRun.COUNTER_DROP_FRAMES + view.ArcadeRun.ENTRANCE_HIDDEN - 1:
			view._step_session(0)
		_expect(audio.cues.count("launch") == 0, "Pas de musique pendant l'attente de remplacement")
		view._step_session(0)
		_expect(audio.cues.count("launch") == 1, bank + " : musique au début de la remontée après perte")
		while view._run.phase == view.ArcadeRun.Phase.REPLACEMENT:
			view._step_session(0)
		_expect(audio.cues.count("launch") == 1, "Un seul déclenchement pendant la montée et la descente")
		view._restart(false)
		view._run._begin_combat(112,255)
		view._run.wave_number = 4
		view._run.combat.outcome = view.ArcadeRun.CombatRound.Outcome.CLEARED
		audio.cues.clear()
		view._step_session(0)
		_expect(audio.cues == ["dock"], "Annonce d'amarrage conservée")
		for frame in view.Docking.LIFT_WAIT:
			view._step_session(0)
		_expect(audio.cues.count("launch") == 0, "Attente avant la montée d'amarrage")
		view._step_session(0)
		_expect(audio.cues.count("launch") == 1, bank + " : musique de montée vers l'amarrage")
		while view._run.docking.stage == view.Docking.Stage.INTRO:
			view._step_session(0)
		_expect(audio.cues.count("launch") == 1, "L'approche manuelle ne relance pas la musique")
		view._restart(false)
		view._run._begin_combat(112,255)
		view._run.stage = 2
		view._run.wave_number = 4
		view._run.combat.outcome = view.ArcadeRun.CombatRound.Outcome.CLEARED
		audio.cues.clear()
		view._step_session(0)
		_expect(audio.cues.is_empty(), "Pas de musique concurrente avant la montée de fin de cycle")
		for frame in view.ArcadeRun.CYCLE_RISE_START - 1:
			view._step_session(0)
		_expect(audio.cues.count("launch") == 0, "Attente avant le départ de fin de cycle")
		view._step_session(0)
		_expect(audio.cues == ["cycle"], bank + " : thème spécifique au changement de cycle")
		while view._run.phase == view.ArcadeRun.Phase.CYCLE_END:
			view._step_session(0)
		for frame in view.ArcadeRun.ENTRANCE_HIDDEN:
			view._step_session(0)
		_expect(audio.cues == ["cycle", "launch"], bank + " : thème de cycle puis arrivée complète, sans musique concurrente")
		var departure: AudioStreamWAV = Audio.MODERN_CUES.cycle if bank == "modern" else Audio.CUES.cycle
		var gap_frames: int = view.ArcadeRun.CYCLE_ENTRANCE_START + view.ArcadeRun.ENTRANCE_HIDDEN - view.ArcadeRun.CYCLE_RISE_START
		var available_duration: float = gap_frames * view.Pilot.FRAME_USEC / 1000000.0
		_expect(departure.get_length() < available_duration, "Le thème de cycle finit avant l'arrivée suivante")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
