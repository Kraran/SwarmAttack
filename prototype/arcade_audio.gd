extends Node

# Extraits audio capturés sur une version arcade.
const CUES := {
	"shot": preload("res://audio/arcade/shot.wav"),
	"impact": preload("res://audio/arcade/impact.wav"),
	"loss": preload("res://audio/arcade/loss.wav"),
	"dock": preload("res://audio/arcade/dock.wav"),
	"success": preload("res://audio/arcade/success.wav"),
	"timeout": preload("res://audio/arcade/timeout.wav"),
	"crash": preload("res://audio/arcade/crash.wav"),
	"start": preload("res://audio/arcade/start.wav"),
	"launch": preload("res://audio/arcade/launch.wav"),
	"wave": preload("res://audio/arcade/wave.wav"),
	"cycle": preload("res://audio/arcade/cycle.wav"),
	"enemy_ring": preload("res://audio/arcade/enemy_ring.wav"),
	"enemy_claw": preload("res://audio/arcade/enemy_claw.wav"),
	"enemy_interceptor": preload("res://audio/arcade/enemy_interceptor.wav"),
	"enemy_meteor": preload("res://audio/arcade/enemy_meteor.wav"),
	"enemy_row": preload("res://audio/arcade/enemy_row.wav"),
	"hit_ring": preload("res://audio/arcade/hit_ring.wav"),
	"hit_claw": preload("res://audio/arcade/hit_claw.wav"),
	"hit_interceptor": preload("res://audio/arcade/hit_interceptor.wav"),
	"hit_meteor": preload("res://audio/arcade/hit_meteor.wav"),
	"hit_row": preload("res://audio/arcade/hit_row.wav"),
	"bonus": preload("res://audio/arcade/bonus.wav"),
}
const MODERN_CUES := {
	"shot": preload("res://audio/modern/shot.wav"),
	"impact": preload("res://audio/modern/impact.wav"),
	"loss": preload("res://audio/modern/loss.wav"),
	"dock": preload("res://audio/modern/dock.wav"),
	"success": preload("res://audio/modern/success.wav"),
	"timeout": preload("res://audio/modern/timeout.wav"),
	"crash": preload("res://audio/modern/crash.wav"),
	"start": preload("res://audio/modern/start.wav"),
	"launch": preload("res://audio/modern/launch.wav"),
	"wave": preload("res://audio/modern/wave.wav"),
	"cycle": preload("res://audio/modern/cycle.wav"),
	"enemy_ring": preload("res://audio/modern/enemy_ring.wav"),
	"enemy_claw": preload("res://audio/modern/enemy_claw.wav"),
	"enemy_interceptor": preload("res://audio/modern/enemy_interceptor.wav"),
	"enemy_meteor": preload("res://audio/modern/enemy_meteor.wav"),
	"enemy_row": preload("res://audio/modern/enemy_row.wav"),
	"hit_ring": preload("res://audio/modern/hit_ring.wav"),
	"hit_claw": preload("res://audio/modern/hit_claw.wav"),
	"hit_interceptor": preload("res://audio/modern/hit_interceptor.wav"),
	"hit_meteor": preload("res://audio/modern/hit_meteor.wav"),
	"hit_row": preload("res://audio/modern/hit_row.wav"),
	"bonus": preload("res://audio/modern/bonus.wav"),
}
const EFFECT_VOICES := 8
const MODERN_BUS := "SwarmModern"
const PLAYBACK_DB := -5.0
const FIELD_WIDTH := 224.0

var _voices: Array[AudioStreamPlayer] = []
var _tone: AudioStreamPlayer
var _shot: AudioStreamPlayer
# Title voice: kept apart from the game voices so pauses and stops never cut it.
const TITLE_VOICE = preload("res://audio/voice/swarm_attack.wav")
# « Game Over », repris de Fluvial Strike avec le même traitement que la voix du titre.
const GAME_OVER_VOICE = preload("res://audio/voice/game_over.wav")
# Startup music, played once after the startup « Swarm Attack » voice.
const START_MUSIC := preload("res://audio/music/swarm_attack_start.ogg")
var _announcer: AudioStreamPlayer
# Menu blips (Phenix Rebirth recipe, tools/make_menu_sounds.py); like the title
# voice, they never pause with the game.
const MENU_CUES := {
	"move": [preload("res://audio/menu/move.wav"), 0.32],
	"confirm": [preload("res://audio/menu/confirm.wav"), 0.45],
	"back": [preload("res://audio/menu/back.wav"), 0.40],
	"deny": [preload("res://audio/menu/deny.wav"), 0.45],
}
var _menu_voice: AudioStreamPlayer
var _menu_gain := 1.0
var _muted := false
var _volume := 100
var _bank := "original"
var _paused := false
var _start_music: AudioStreamPlayer
# 0: not requested, 1: waiting for the voice to end, 2: played or cancelled.
var _start_music_state := 0
var _effects: Array[AudioStreamPlayer] = []
var _effect_cursor := 0
var _effect_cues: PackedStringArray = []
var _jingle: AudioStreamPlayer
var _preview: AudioStreamPlayer
var _enemy: AudioStreamPlayer
var _tone_cue := ""
var _panners := {}
var _stereo_buses: Array[StringName] = []

# Ordre des familles de FlightPresentation.EnemyKind.
const ENEMY_FAMILIES := ["ring", "interceptor", "claw", "meteor", "row"]

static func enemy_cue(kind: int, hit := false) -> String:
	return ("hit_" if hit else "enemy_") + ENEMY_FAMILIES[kind]


static func pan_for_x(x: float) -> float:
	return clampf(x / (FIELD_WIDTH * 0.5) - 1.0, -1.0, 1.0)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_create_voices()


func _create_voices() -> void:
	_tone = AudioStreamPlayer.new()
	_shot = AudioStreamPlayer.new()
	_voices.assign([_tone, _shot])
	_jingle = AudioStreamPlayer.new()
	_preview = AudioStreamPlayer.new()
	_enemy = AudioStreamPlayer.new()
	if AudioServer.get_bus_index(MODERN_BUS) < 0:
		AudioServer.add_bus()
		var bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, MODERN_BUS)
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		limiter.release = 0.08
		AudioServer.add_bus_effect(bus, limiter)
	_jingle.bus = MODERN_BUS
	_enemy.bus = MODERN_BUS
	_voices.append(_jingle)
	_voices.append(_preview)
	_voices.append(_enemy)
	for index in EFFECT_VOICES:
		var effect := AudioStreamPlayer.new()
		effect.bus = MODERN_BUS
		_effects.append(effect)
		_effect_cues.append("")
		_voices.append(effect)
	for voice in _voices:
		var name := StringName("SwarmStereo_%d_%d" % [get_instance_id(), _stereo_buses.size()])
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, voice.bus)
		var panner := AudioEffectPanner.new()
		AudioServer.add_bus_effect(index, panner)
		_stereo_buses.append(name)
		_panners[voice] = panner
		voice.bus = name
		add_child(voice)
	_announcer = AudioStreamPlayer.new()
	_announcer.stream = TITLE_VOICE
	add_child(_announcer)
	_announcer.finished.connect(_on_announcer_finished)
	_menu_voice = AudioStreamPlayer.new()
	add_child(_menu_voice)
	_start_music = AudioStreamPlayer.new()
	_start_music.stream = START_MUSIC
	add_child(_start_music)
	set_muted(false)


func play_menu(cue: String) -> void:
	if _menu_voice == null or not MENU_CUES.has(cue):
		return
	_menu_voice.stream = MENU_CUES[cue][0]
	_menu_gain = MENU_CUES[cue][1]
	_update_volume()
	_menu_voice.play()


# « Swarm Attack » spoken over the logo (startup intro and About).
func play_title() -> void:
	_announce(TITLE_VOICE)


# Startup only: the music follows the voice, once per launch.
func queue_start_music() -> void:
	if _start_music_state == 0:
		_start_music_state = 1


# Starting a game (or quitting the title) silences it for good.
func stop_start_music() -> void:
	_start_music_state = 2
	if _start_music != null:
		_start_music.stop()


# The startup music carries on through every menu (Options, Training,
# About, the quit question); only losing the window focus holds it.
func set_start_music_paused(value: bool) -> void:
	if _start_music != null:
		_start_music.stream_paused = value


func start_music_playing() -> bool:
	return _start_music != null and _start_music.playing


func _on_announcer_finished() -> void:
	if _start_music_state != 1 or _start_music == null:
		return
	_start_music_state = 2
	_start_music.play()


# « Game Over » when the end-of-game message appears.
func play_game_over() -> void:
	_announce(GAME_OVER_VOICE)


func _announce(stream: AudioStream) -> void:
	if _announcer == null:
		return
	_announcer.stop()
	_announcer.stream = stream
	_announcer.play()


func play(cue: String, pan := 0.0) -> void:
	if _voices.is_empty():
		return
	if _bank == "modern":
		if cue.begins_with("enemy_"):
			# Comme sur la borne, un vol ne couvre ni une musique ni un impact en cours.
			if not _jingle.playing and not _modern_impact_playing():
				_route_voice(_enemy, pan, true)
				_enemy.stream = MODERN_CUES[cue]
				_enemy.play()
			return
		var modern_voice := _jingle
		if cue in ["shot", "impact", "loss", "crash"] or cue.begins_with("hit_"):
			for offset in EFFECT_VOICES:
				var index := (_effect_cursor + offset) % EFFECT_VOICES
				if not _effects[index].playing:
					_effect_cursor = index
					break
			modern_voice = _effects[_effect_cursor]
			_effect_cues[_effect_cursor] = cue
			_effect_cursor = (_effect_cursor + 1) % EFFECT_VOICES
			# Sur la borne, l'impact prend la voix du vol : il l'interrompt.
			if cue == "impact" or cue.begins_with("hit_"):
				_enemy.stop()
		else:
			stop_enemy()
		modern_voice.stream = MODERN_CUES[cue]
		_route_voice(modern_voice, pan, true)
		modern_voice.play()
		return
	# Le tir a son propre circuit. Les séquences et les impacts partagent la voix tonale.
	# Un vol peut remplacer un autre vol, jamais un impact ou une musique en cours.
	if cue.begins_with("enemy_") and _tone.playing and not _tone_cue.begins_with("enemy_"):
		return
	if cue.begins_with("hit_") and _tone.playing and _tone_cue == "bonus":
		return
	var voice := _shot if cue == "shot" else _tone
	if voice == _tone:
		_tone_cue = cue
	voice.stream = CUES[cue]
	_route_voice(voice, pan, false)
	voice.play()


func _modern_impact_playing() -> bool:
	for index in _effects.size():
		var cue: String = _effect_cues[index]
		if _effects[index].playing and (cue == "impact" or cue.begins_with("hit_")):
			return true
	return false


func _route_voice(voice: AudioStreamPlayer, pan: float, modern: bool) -> void:
	if not _panners.has(voice):
		return
	pan = clampf(pan, -1.0, 1.0)
	(_panners[voice] as AudioEffectPanner).pan = pan
	var bus := AudioServer.get_bus_index(voice.bus)
	# Panner has linear gains (0.5 per channel at center). Normalize their
	# combined energy to preserve the former centered level across the field.
	AudioServer.set_bus_volume_db(bus, linear_to_db(2.0 / sqrt(1.0 + pan * pan)))
	var destination: StringName = MODERN_BUS if modern else &"Master"
	# Godot 4.7.2 reads Bus.send twice in _mix_step (has + lookup).
	# Reassigning that StringName while it mixes can invalidate the lookup.
	# Pan/volume updates never need to rewrite a stable routing destination.
	if AudioServer.get_bus_send(bus) != destination:
		AudioServer.lock()
		AudioServer.set_bus_send(bus, destination)
		AudioServer.unlock()


func set_enemy_pan(pan: float) -> void:
	if _enemy != null:
		_route_voice(_enemy, pan, true)
	# Never move the music or an impact that replaced the original flight voice.
	if _tone != null and _tone_cue.begins_with("enemy_"):
		_route_voice(_tone, pan, false)


func _exit_tree() -> void:
	stop()
	stop_start_music()
	if _announcer != null:
		_announcer.stop()
	for name in _stereo_buses:
		var index := AudioServer.get_bus_index(name)
		if index >= 0:
			AudioServer.remove_bus(index)
	_stereo_buses.clear()
	_panners.clear()


func stop_enemy() -> void:
	if _enemy != null:
		_enemy.stop()
	if _tone != null and _tone_cue.begins_with("enemy_"):
		_tone.stop()
		_tone_cue = ""


func set_bank(value: String) -> void:
	var bank := value if value in ["original", "modern"] else "original"
	if _bank != bank:
		stop()
		_bank = bank


func preview_shot() -> void:
	if _preview == null:
		return
	_preview.stream = MODERN_CUES.shot if _bank == "modern" else CUES.shot
	_route_voice(_preview, 0.0, _bank == "modern")
	_preview.stream_paused = false
	_preview.play()

func stop() -> void:
	for voice in _voices:
		voice.stop()


func set_muted(value: bool) -> void:
	_muted = value
	_update_volume()


func set_volume(value: int) -> void:
	_volume = clampi(value, 0, 100)
	_update_volume()


func _update_volume() -> void:
	var level := -80.0 if _muted or _volume == 0 else PLAYBACK_DB + linear_to_db(_volume / 100.0)
	for voice in _voices:
		voice.volume_db = level
	if _announcer != null:
		_announcer.volume_db = level
	if _start_music != null:
		_start_music.volume_db = level
	if _menu_voice != null:
		_menu_voice.volume_db = level + linear_to_db(_menu_gain)


func set_paused(value: bool) -> void:
	_paused = value
	for voice in _voices:
		voice.stream_paused = value


func is_paused() -> bool:
	return _paused
