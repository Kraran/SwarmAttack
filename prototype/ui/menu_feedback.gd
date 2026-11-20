extends RefCounted

# Menu feedback, as in Phenix Rebirth: a tick when the cursor moves, a chime when
# a choice is validated, a softer one going back, a buzz when something is refused,
# and a 0.22 s slide when the screen changes.
#
# Rather than add a sound to each input path, the view takes a picture of the menus
# before and after each input (`snapshot`) and `react` plays what the difference
# means. Only an input can make a menu sound: nothing during play, nothing when a
# menu changes by itself.
const MOVE := "move"
const CONFIRM := "confirm"
const BACK := "back"
const DENY := "deny"
const SLIDE_SEC := 0.22
const SLIDE_PX := 90.0

var _view: Node2D
var slide_time := SLIDE_SEC
var slide_direction := 1


func _init(view: Node2D) -> void:
	_view = view


# 'confirm', 'back', 'nav', 'hover' or '' for events that are not menu input.
static func kind_of(event: InputEvent) -> String:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return ""
		if event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			return "back"
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F2, KEY_F3, KEY_F4]:
			return "confirm"
		return "nav"
	if event is InputEventJoypadButton:
		if not event.pressed:
			return ""
		if load("res://ui/quit_prompt.gd").is_combo(event):
			return "confirm"
		if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y]:
			return "confirm"
		if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK, JOY_BUTTON_START]:
			return "back"
		return "nav"
	if event is InputEventJoypadMotion:
		return "nav" if absf(event.axis_value) >= 0.65 else ""
	if event is InputEventMouseButton:
		if not event.pressed:
			return ""
		if event.button_index == MOUSE_BUTTON_LEFT:
			return "confirm"
		if event.button_index == MOUSE_BUTTON_RIGHT:
			return "back"
		return ""
	if event is InputEventMouseMotion:
		return "hover"
	return ""


func in_play() -> bool:
	var v := _view
	return not v._attract_active and not v._menu_open() and not v._about_is_open() \
		and not v._scores.results_open and not v._scores.tables_open


# What the menus show, as plain values that can be compared.
func snapshot() -> Dictionary:
	var v := _view
	var options = v._options
	var scores = v._scores
	return {
		"play": in_play(),
		"screen": [v._about_is_open(), v._attract_active, options.opened, options.page, v._pause.active,
			v._training.opened, v._training.result_open, scores.tables_open, scores.results_open,
			scores.results_page, scores.entry != null, v._quit_prompt.opened],
		"cursor": [v._title.choice, v._profile.difficulty, options.choice, options.binding_waiting,
			options.render_state([]), v._pause.choice, v._training.render_state(), scores.overlay_state(),
			scores.result_choice, v._about._choice, v._quit_prompt.answer, v._profile.menu_left, v._profile.portrait],
		"error": options.binding_error,
		"bank": [options.page, options.choice, v._profile.audio_bank],
	}


# The sound for one input ('' for silence).
func choose(before: Dictionary, after: Dictionary, kind: String) -> String:
	if kind.is_empty():
		return ""
	if after.error and not before.error:
		return DENY                       # a reserved key or button
	if before.play and after.play:
		return ""                         # gameplay input
	if not before.play and after.play:
		return ""                         # a game starts or resumes: its own sounds take over
	if before.screen != after.screen:
		if kind == "hover":
			return ""
		if before.play:
			return CONFIRM                # the game is paused
		return BACK if kind == "back" else CONFIRM
	if before.cursor != after.cursor:
		if before.bank != after.bank and before.bank[2] != after.bank[2]:
			return ""                     # the sound bank change already plays a shot
		if kind == "confirm":
			return CONFIRM
		if kind == "back":
			return BACK
		return MOVE
	return ""


func react(before: Dictionary, after: Dictionary, kind: String) -> String:
	var name := choose(before, after, kind)
	if not name.is_empty():
		_view._audio.play_menu(name)
	# The new screen slides in: from the right going on, from the left going back.
	if before.screen != after.screen and not after.play and kind != "hover" and not kind.is_empty():
		slide_direction = -1 if kind == "back" else 1
		slide_time = 0.0
	return name


func sliding() -> bool:
	return slide_time < SLIDE_SEC


func advance(delta: float) -> bool:
	if not sliding():
		return false
	slide_time = minf(slide_time + delta, SLIDE_SEC)
	return true


# Horizontal offset and opacity of the menu during a slide.
func slide_offset() -> float:
	var t := clampf(slide_time / SLIDE_SEC, 0.0, 1.0)
	return slide_direction * SLIDE_PX * pow(1.0 - t, 3.0)


func slide_alpha() -> float:
	return clampf(slide_time / SLIDE_SEC, 0.0, 1.0)
