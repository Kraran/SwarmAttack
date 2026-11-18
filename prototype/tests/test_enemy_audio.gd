extends SceneTree

const Audio = preload("res://arcade_audio.gd")
const Wave = preload("res://combat_wave.gd")
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
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	_check_playback(view._audio)
	var old_audio: Node = view._audio
	view.remove_child(old_audio)
	old_audio.queue_free()
	var spy := AudioSpy.new()
	view._audio = spy
	view.add_child(spy)
	var expected := ["ring", "ring", "claw", "claw", "interceptor", "interceptor", "meteor", "meteor", "row", "row"]
	for number in range(1, 11):
		view._restart(false)
		var run = view._run
		run.stage = 0 if number <= 4 else (1 if number <= 8 else 2)
		run.wave_number = number - [0, 2, 6][run.stage]
		run._begin_combat(112,255)
		spy.cues.clear()
		for frame in Wave.SPAWN_FRAME - 1:
			view._step_session(0)
		_expect(spy.cues.is_empty(), "Vague %d : silence avant apparition" % number)
		view._step_session(0)
		var flight: String = "enemy_" + expected[number - 1]
		_expect(spy.cues == [flight], "Vague %d : son de vol sans tir ni impact" % number)
		view._step_session(0)
		_expect(spy.cues == [flight], "Le son ne repart pas à chaque image")
		# An impact event from the combat model must select this family's sound.
		run.combat.impact_age = -1
		view._step_session(0)
		_expect(spy.cues[-1] == "hit_" + expected[number - 1], "Impact spécifique : vague %d" % number)
		var wave: Wave = run.combat.wave
		var before := wave.flight_sound_serial
		if not wave.falling:
			var enemy := wave.enemies[0]
			enemy.phase = Wave.Flight.ROW_EXIT if wave.rows else Wave.Flight.RETURNING
			enemy.turns_left = 0
			enemy.return_wait = 0
			wave._wave_clock = 101
			wave.advance(0,112)
			_expect(wave.flight_sound_serial == before + 1, "Un événement à la réapparition : vague %d" % number)
			wave.advance(0,112)
			_expect(wave.flight_sound_serial == before + 1, "Pas de répétition pendant le retour")
		else:
			for index in Wave.FALL_PAIRS[0]:
				wave.enemies[index].alive = false
			wave.credited_remaining = 6
			wave._wave_clock = 101
			wave.advance(0,112)
			_expect(wave.flight_sound_serial == before + 2, "Un son pour chaque nouvelle paire de météorites")
		before = wave.flight_sound_serial
		wave.kill(1)
		_expect(wave.flight_sound_serial == before, "Une destruction ne produit pas un son de vol")
		view._toggle_pause()
		var frame: int = run.frame
		var cues := spy.cues.size()
		view._process(0.2)
		_expect(run.frame == frame and spy.cues.size() == cues, "Pas de nouveau son en pause")
		view._toggle_pause()
	view._restart(false)
	view._run._begin_combat(112,255)
	view._run.combat.score = view._run.bonus_threshold
	spy.cues.clear()
	view._step_session(0)
	view._step_session(0)
	_expect(spy.cues == ["bonus"], "Son de vie supplémentaire une seule fois au seuil")
	for cue in Audio.CUES:
		if not cue.begins_with("enemy_") and not cue.begins_with("hit_") and cue != "bonus":
			continue
		for bank in [Audio.CUES, Audio.MODERN_CUES]:
			var stream: AudioStreamWAV = bank[cue]
			var pcm := stream.data
			_expect(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 48000 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "PCM mono 48 kHz non bouclé : " + cue)
			_expect(not stream.stereo and pcm.decode_s16(0) == 0 and pcm.decode_s16(pcm.size()-2) == 0, "Bords sans clic : " + cue)
	if failures == 0:
		print("ENEMY AUDIO OK: dix vagues, cinq vols et impacts, retours, météorites, pause et banques.")
	quit(1 if failures else 0)

func _check_playback(audio: Node) -> void:
	if audio._voices.is_empty():
		return # Le même test en rendu graphique vérifie les lecteurs réels.
	audio.set_bank("original")
	audio.play("enemy_ring")
	_expect(audio._tone.stream == Audio.CUES.enemy_ring and audio._tone.playing, "Lecture réelle du vol original")
	audio.play("shot")
	_expect(audio._tone.stream == Audio.CUES.enemy_ring and audio._shot.playing, "Tir indépendant du vol")
	audio.play("hit_ring")
	audio.play("enemy_claw")
	_expect(audio._tone.stream == Audio.CUES.hit_ring, "Le vol ne coupe pas un impact original")
	audio._tone.stop()
	audio.play("enemy_claw")
	_expect(audio._tone.stream == Audio.CUES.enemy_claw, "Vol accepté après la fin d'un impact")
	audio.set_paused(true)
	_expect(audio._tone.stream_paused, "Le vol se fige en pause")
	audio.set_paused(false)
	audio.stop_enemy()
	_expect(not audio._tone.playing, "Le vol s'arrête à la sortie du combat")
	audio.play("launch")
	audio.play("enemy_row")
	audio.stop_enemy()
	_expect(audio._tone.stream == Audio.CUES.launch and audio._tone.playing, "Musique de décollage protégée")
	audio.set_bank("modern")
	audio.play("enemy_meteor")
	_expect(audio._enemy.playing and audio._enemy.stream == Audio.MODERN_CUES.enemy_meteor, "Vol moderne sur lecteur dédié")
	audio.play("hit_meteor")
	_expect(audio._enemy.playing and audio._effects.any(func(voice: AudioStreamPlayer): return voice.playing), "Impact moderne et vol simultanés")
	audio.play("dock")
	_expect(not audio._enemy.playing and audio._jingle.playing, "La transition arrête le vol moderne")
	audio.stop()
	audio.set_bank("original")
	audio.play("cycle")
	_expect(audio._tone.stream == Audio.CUES.cycle, "Départ original : thème spécifique au changement de cycle")
	audio.play("enemy_ring")
	_expect(audio._tone.stream == Audio.CUES.cycle, "Le thème de cycle est protégé des sons de vol")
	audio.set_bank("modern")
	audio.play("cycle")
	_expect(audio._jingle.stream == Audio.MODERN_CUES.cycle, "Départ moderne : thème spécifique au changement de cycle")
	audio.stop()
	audio.set_bank("original")
	audio.play("bonus")
	audio.play("hit_ring")
	audio.play("enemy_ring")
	_expect(audio._tone.stream == Audio.CUES.bonus and audio._tone.playing, "La vie supplémentaire est prioritaire sur les ennemis")
	audio.stop()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
