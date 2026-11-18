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
var _effects: Array[AudioStreamPlayer] = []
var _effect_cursor := 0
var _jingle: AudioStreamPlayer
var _preview: AudioStreamPlayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_tone = AudioStreamPlayer.new()
	_shot = AudioStreamPlayer.new()
	_voices.assign([_tone, _shot])
	_jingle = AudioStreamPlayer.new()
	_preview = AudioStreamPlayer.new()
	if AudioServer.get_bus_index(MODERN_BUS) < 0:
		AudioServer.add_bus()
		var bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, MODERN_BUS)
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		limiter.release = 0.08
		AudioServer.add_bus_effect(bus, limiter)
	_jingle.bus = MODERN_BUS
	_voices.append(_jingle)
	_voices.append(_preview)
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
		var modern_voice := _jingle
		if cue in ["shot", "impact", "loss", "crash"]:
			for offset in EFFECT_VOICES:
				var index := (_effect_cursor + offset) % EFFECT_VOICES
				if not _effects[index].playing:
					_effect_cursor = index
					break
			modern_voice = _effects[_effect_cursor]
			_effect_cursor = (_effect_cursor + 1) % EFFECT_VOICES
		modern_voice.stream = MODERN_CUES[cue]
		modern_voice.play()
		return
	# Le tir a son propre circuit. Les séquences et les impacts partagent la voix tonale.
	var voice := _shot if cue == "shot" else _tone
	voice.stream = CUES[cue]
	voice.play()


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
	for voice in _voices:
		voice.stream_paused = value
