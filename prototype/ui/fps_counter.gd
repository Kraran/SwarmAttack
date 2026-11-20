extends Node2D

# Count rendered frames against the monotonic clock, never simulation ticks
# or scaled delta. A short rolling window keeps the live display readable.
const WINDOW_USEC := 500_000
const UPDATE_USEC := 100_000
var enabled := false
var left_side := false
var fps := 0.0
var _samples: Array[Dictionary] = []
var _last_update := 0

func _ready() -> void:
	z_index = 100
	hide()
	set_process(false)
	get_viewport().size_changed.connect(queue_redraw)

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	visible = value
	set_process(value)
	_samples.clear()
	fps = 0.0
	_last_update = Time.get_ticks_usec()
	if value:
		_samples.append({"usec": _last_update, "frames": Engine.get_frames_drawn()})
	queue_redraw()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if now - _last_update >= UPDATE_USEC:
		_sample(now, Engine.get_frames_drawn())
		_last_update = now
		queue_redraw()

func _sample(now: int, frames: int) -> void:
	if not _samples.is_empty() and (now <= int(_samples[-1].usec) or frames < int(_samples[-1].frames)):
		_samples.clear()
		fps = 0.0
	_samples.append({"usec": now, "frames": frames})
	while _samples.size() > 2 and now - int(_samples[1].usec) >= WINDOW_USEC:
		_samples.pop_front()
	var elapsed: int = now - int(_samples[0].usec)
	if elapsed > 0:
		fps = float(frames - int(_samples[0].frames)) * 1_000_000.0 / elapsed

func counter_rect() -> Rect2:
	# Top right of the visible screen, wide screens included: the canvas is
	# shifted to centre the game, so remove that shift from the visible width.
	var shift := get_viewport().canvas_transform.origin
	if left_side:
		return Rect2(4 - shift.x, 4 - shift.y, 108, 22)
	return Rect2(get_viewport_rect().size.x - shift.x - 112, 4 - shift.y, 108, 22)

func _draw() -> void:
	if not enabled:
		return
	var rect := counter_rect()
	draw_rect(rect, Color(0.02, 0.01, 0.04, 0.85))
	draw_rect(rect, Color("#7be368"), false, 1.0)
	var label := "FPS : %.1f" % fps if _samples.size() > 1 else "FPS : …"
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(5, 16), label,
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 10, 15, Color("#9cff8a"))
