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
	"wave": preload("res://audio/arcade/wave.wav"),
	"cycle": preload("res://audio/arcade/cycle.wav"),
}
const PLAYBACK_DB := -5.0

var _voices: Array[AudioStreamPlayer] = []
var _tone: AudioStreamPlayer
var _shot: AudioStreamPlayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_tone = AudioStreamPlayer.new()
	_shot = AudioStreamPlayer.new()
	_voices.assign([_tone, _shot])
	for voice in _voices:
		add_child(voice)
	set_muted(false)


func play(cue: String) -> void:
	if _voices.is_empty():
		return
	# Le tir a son propre circuit. Les séquences et les impacts partagent la voix tonale.
	var voice := _shot if cue == "shot" else _tone
	voice.stream = CUES[cue]
	voice.play()


func stop() -> void:
	for voice in _voices:
		voice.stop()


func set_muted(value: bool) -> void:
	for voice in _voices:
		voice.volume_db = -80.0 if value else PLAYBACK_DB


func set_paused(value: bool) -> void:
	for voice in _voices:
		voice.stream_paused = value
