extends Node

const SAMPLE_RATE := 24000
# Fréquence de départ, fréquence d'arrivée, durée et part de bruit.
const CUES := {
	"shot": [[1580.0, 270.0, 0.18, 0.12]],
	"impact": [[216.0, 69.0, 0.28, 0.66]],
	"loss": [[142.0, 53.0, 0.76, 0.77], [58.0, 34.0, 0.54, 0.49]],
	"dock": [[196.0, 202.0, 0.29, 0.04], [261.63, 269.0, 0.29, 0.03], [329.63, 349.23, 0.57, 0.05]],
	"success": [[329.63, 329.63, 0.19, 0.02], [493.88, 493.88, 0.20, 0.02], [659.25, 659.25, 0.62, 0.02]],
	"timeout": [[277.18, 240.0, 0.20, 0.08], [185.0, 153.0, 0.40, 0.10]],
	"crash": [[202.0, 62.0, 0.49, 0.85], [86.0, 38.0, 0.64, 0.73]],
	"start": [[164.81, 164.81, 0.21, 0.06], [246.94, 246.94, 0.20, 0.03], [293.66, 329.63, 0.48, 0.03]],
	"wave": [[98.0, 130.81, 0.34, 0.12]],
	"cycle": [[130.81, 130.81, 0.28, 0.03], [220.0, 220.0, 0.26, 0.03], [329.63, 440.0, 0.68, 0.04]],
}
const PLAYBACK_DB := -5.0

var _voices: Array[AudioStreamPlayer] = []
var _tone: AudioStreamPlayer
var _shot: AudioStreamPlayer
var _clips := {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for cue in CUES:
		_clips[cue] = _render_cue(CUES[cue])
	_tone = AudioStreamPlayer.new()
	_shot = AudioStreamPlayer.new()
	_voices.assign([_tone, _shot])
	for voice in _voices:
		add_child(voice)
	set_muted(false)


func play(cue: String) -> void:
	if _voices.is_empty():
		return
	# Le tir peut se superposer aux séquences et aux impacts.
	var voice := _shot if cue == "shot" else _tone
	voice.stream = _clips[cue]
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


func _render_cue(notes: Array) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	var random := RandomNumberGenerator.new()
	random.seed = 0x5a17
	for note in notes:
		var samples := roundi(note[2] * SAMPLE_RATE)
		var offset := pcm.size()
		pcm.resize(offset + samples * 2)
		var phase := 0.0
		var noise := 0.0
		for index in range(samples):
			var position := float(index) / samples
			var frequency := lerpf(note[0], note[1], pow(position, 0.65))
			phase += TAU * frequency / SAMPLE_RATE
			noise = lerpf(noise, random.randf_range(-1.0, 1.0), 0.29)
			var envelope := minf(index / 150.0, 1.0) * pow(1.0 - position, 1.65)
			var tone := sin(phase + 0.74 * sin(phase * 1.5)) * 0.76 + sin(phase * 0.5) * 0.24
			var sample := lerpf(tone, noise * 1.6, note[3]) * envelope
			pcm.encode_s16(offset + index * 2, roundi(sample * 14200.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = pcm
	return stream
