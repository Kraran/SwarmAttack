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

var _voices: Array[AudioStreamPlayer] = []
var _tone: AudioStreamPlayer
var _shot: AudioStreamPlayer
var _muted := false
var _volume := 100
var _bank := "original"
var _paused := false
var _effects: Array[AudioStreamPlayer] = []
var _effect_cursor := 0
var _jingle: AudioStreamPlayer
var _preview: AudioStreamPlayer
var _enemy: AudioStreamPlayer
var _tone_cue := ""

# Ordre des familles de FlightPresentation.EnemyKind.
const ENEMY_FAMILIES := ["ring", "interceptor", "claw", "meteor", "row"]

static func enemy_cue(kind: int, hit := false) -> String:
	return ("hit_" if hit else "enemy_") + ENEMY_FAMILIES[kind]


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
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
		_voices.append(effect)
	for voice in _voices:
		add_child(voice)
	set_muted(false)


func play(cue: String) -> void:
	if _voices.is_empty():
		return
	if _bank == "modern":
		if cue.begins_with("enemy_"):
			if not _jingle.playing:
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
			_effect_cursor = (_effect_cursor + 1) % EFFECT_VOICES
		else:
			stop_enemy()
		modern_voice.stream = MODERN_CUES[cue]
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
	voice.play()


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
	_preview.bus = MODERN_BUS if _bank == "modern" else &"Master"
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


func set_paused(value: bool) -> void:
	_paused = value
	for voice in _voices:
		voice.stream_paused = value


func is_paused() -> bool:
	return _paused
