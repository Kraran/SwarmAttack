extends Node2D

# Keeps the original cached drawing layer and its ordering above the playfield.
const OptionsMenu = preload("res://ui/options_menu.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const TrainingMenu = preload("res://ui/training_menu.gd")
const ScoresMenu = preload("res://ui/scores_menu.gd")
const Profile = preload("res://arcade_profile.gd")
const Pilot = preload("res://pilot.gd")

var state: Array = []
var _view: Node2D
var _options: OptionsMenu
var _pause: PauseMenu
var _training: TrainingMenu
var _scores: ScoresMenu
var _profile: Profile:
	get: return _view._profile

func _init(view: Node2D, options: OptionsMenu, pause: PauseMenu, training: TrainingMenu, scores: ScoresMenu) -> void:
	_view = view
	_options = options
	_pause = pause
	_training = training
	_scores = scores

func refresh(controls: Array) -> void:
	var next_state := [_view._quit_prompt.render_state(),_view._menu_feedback.slide_time,_profile.portrait, _profile.language, _view._focused,
		_pause.render_state(), _options.render_state(controls), _training.render_state(),
		_scores.overlay_state()]
	if state != next_state:
		state = next_state
		queue_redraw()

func _draw() -> void:
	var field: Rect2 = _view._field()
	modulate.a = _view._menu_feedback.slide_alpha()
	draw_set_transform(Vector2(_view._panel_shift() + _view._menu_feedback.slide_offset(), 0))
	if _options.opened:
		_options.draw(self)
	elif _training.opened:
		_training.draw(self)
	elif _training.result_open:
		_training.draw_result(self)
	elif _scores.entry != null:
		_scores.draw_entry(self)
	elif _pause.active:
		_pause.draw(self)
	# Xbox + Start asks over whatever is on screen, the title menu included.
	if _view._quit_prompt.opened:
		_view._quit_prompt.draw(self)
