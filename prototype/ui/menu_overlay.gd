extends Node2D

# Keeps the original cached drawing layer and its ordering above the playfield.
const OptionsMenu = preload("res://ui/options_menu.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const TrainingMenu = preload("res://ui/training_menu.gd")
const ScoresMenu = preload("res://ui/scores_menu.gd")
const Profile = preload("res://arcade_profile.gd")
const Pilot = preload("res://pilot.gd")
const Style = preload("res://ui/menu_screen.gd")

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
	var next_state := [_profile.portrait, _profile.language, _view._focused,
		_pause.render_state(), _options.render_state(controls), _training.render_state(),
		_scores.overlay_state()]
	if state != next_state:
		state = next_state
		queue_redraw()

func _draw() -> void:
	var field: Rect2 = _view.PORTRAIT_FIELD if _profile.portrait else _view.FIELD
	draw_set_transform(field.position, 0.0, field.size / Vector2(Pilot.FIELD_SIZE))
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
	elif not _view._focused:
		draw_rect(Rect2(14, 102, 196, 50), Color(0.02, 0.04, 0.07, 0.92))
		_view._field_text(self, 112, 123, _view._translate("PAUSE"), Style.PRIMARY, 13)
