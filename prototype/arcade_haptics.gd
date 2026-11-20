extends Node

# Finite pulses, independent from the selected audio bank and volume.
# Each stage: high-frequency motor, low-frequency motor, seconds.
# Only player destruction and successful docking contact produce game rumble.
# A ship explosion: full shock, then a long rumble that fades (about 0.95 s).
const EXPLOSION := [
	[1.0, 1.0, 0.12], [0.75, 1.0, 0.16], [0.45, 0.85, 0.2], [0.2, 0.6, 0.22], [0.06, 0.3, 0.25]]
# A docking collision destroys the whole assembly: a longer first shock.
const CRASH := [
	[1.0, 1.0, 0.2], [0.75, 1.0, 0.18], [0.45, 0.85, 0.22], [0.2, 0.6, 0.24], [0.06, 0.3, 0.26]]
# Docking contact: the hull meets the module, a short gap, the clamps lock.
const DOCKING := [[1.0, 1.0, 0.16], [0.0, 0.0, 0.06], [0.6, 1.0, 0.16], [0.2, 0.5, 0.2]]
const PREVIEW_GAP := [[0.0, 0.0, 0.3]]
const PATTERNS := {
	"loss": {"priority": 3, "steps": EXPLOSION},
	"crash": {"priority": 3, "steps": CRASH},
	"success": {"priority": 2, "steps": DOCKING},
	# A docking contact, a pause, then a player explosion.
	"preview": {"priority": 3, "steps": DOCKING + PREVIEW_GAP + EXPLOSION},
}

var enabled := true
var intensity := 70
var device := -1
var gameplay_active := false
var _until_usec := 0
var _priority := -1
var _steps: Array = []
var _started_usec := 0
var _stage := -1


func configure(value: bool, percent: int) -> void:
	enabled = value
	intensity = clampi(percent, 0, 100)
	stop()


func handle_input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton and event.pressed
			or event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
		if device != event.device and event.device in _devices():
			stop()
			device = event.device


func connection_changed(id: int, connected: bool) -> void:
	if not connected and device == id:
		stop()
		device = -1


# Leaving play only blocks new effects: a running explosion still ends
# normally when a result screen opens. Pause, options, focus loss and the
# other menus the player opens stop the motors explicitly.
func set_gameplay_active(value: bool) -> void:
	gameplay_active = value


func play(cue: String) -> void:
	if not gameplay_active:
		return
	# Enemy flight/impact sounds never cause rumble, even on the firing frame.
	_pulse(cue)


func preview() -> void:
	stop()
	_pulse("preview")


func _pulse(cue: String) -> void:
	if not enabled or intensity == 0 or not PATTERNS.has(cue):
		return
	var pads := _devices()
	if device not in pads:
		# With multiple pads, wait for an intentional input to choose the owner.
		if pads.size() != 1:
			return
		device = pads[0]
	var pattern: Dictionary = PATTERNS[cue]
	var now := _now_usec()
	if now < _until_usec and pattern.priority < _priority:
		return
	_priority = pattern.priority
	_steps = pattern.steps
	_started_usec = now
	_until_usec = now
	for step: Array in _steps:
		_until_usec += int(round(step[2] * 1_000_000))
	_stage = -1
	_update_envelope(now)


func _process(_delta: float) -> void:
	if not _steps.is_empty():
		_update_envelope(_now_usec())


func _update_envelope(now: int) -> void:
	if now >= _until_usec:
		stop()
		return
	# Absolute deadlines skip expired stages after a stalled frame; they never
	# replay a late attack or extend an explosion beyond its intended duration.
	var boundary := _started_usec
	for index in _steps.size():
		var step: Array = _steps[index]
		boundary += int(round(step[2] * 1_000_000))
		if now >= boundary:
			continue
		if _stage != index:
			_stage = index
			_send_stage(step, float(boundary - now) / 1_000_000.0)
		return


func _send_stage(step: Array, duration: float) -> void:
	# Give intermediate settings more motor power while keeping 0 silent,
	# 100 at full strength and every slider step strictly progressive.
	var scale := sqrt(intensity / 100.0)
	if step[0] == 0.0 and step[1] == 0.0:
		_stop(device)
	else:
		_start(device, step[0] * scale, step[1] * scale, duration)


func stop() -> void:
	if device >= 0:
		_stop(device)
	_until_usec = 0
	_priority = -1
	_steps = []
	_stage = -1


func _exit_tree() -> void:
	stop()


# Small hardware boundary, overridden by deterministic tests.
func _devices() -> Array[int]:
	return Input.get_connected_joypads()


func _now_usec() -> int:
	return Time.get_ticks_usec()


func _start(id: int, weak: float, strong: float, seconds: float) -> void:
	Input.start_joy_vibration(id, weak, strong, seconds)


func _stop(id: int) -> void:
	Input.stop_joy_vibration(id)
