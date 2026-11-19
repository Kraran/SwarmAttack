extends RefCounted

# Shared menu presentation and the narrow services supplied by the game view.
# The view still owns the session, profile persistence, audio and simulation clock.
const ArcadeProfile = preload("res://arcade_profile.gd")
const ArcadeAudio = preload("res://arcade_audio.gd")
const ArcadeSession = preload("res://arcade_session.gd")
const ArcadeRun = preload("res://arcade_run.gd")
const Pilot = preload("res://pilot.gd")
const TrainingSession = preload("res://training_session.gd")
const Controls = preload("res://arcade_controls.gd")
const Language = preload("res://arcade_language.gd")
const MenuNavigation = preload("res://ui/menu_navigation.gd")
const BACKGROUND := Color("#080f1c")
const GRID := Color("#142239")
const BORDER := Color("#314765")
const PRIMARY := Color("#edf5ff")
const MUTED := Color("#9eafc6")
const SHIP := Color("#70edcd")
const SHOT := Color("#ffe59a")
const ARCADE_RED := Color("#ff735d")

var _view: Node2D
var _navigation: MenuNavigation
var _profile: ArcadeProfile:
	get: return _view._profile
var _audio: ArcadeAudio:
	get: return _view._audio
var _session: ArcadeSession:
	get: return _view._session
var _run: ArcadeRun:
	get: return _view._run
var _attract_active: bool:
	get: return _view._attract_active
var _paused: bool:
	get: return _view._pause.active
var _focused: bool:
	get: return _view._focused

func _init(view: Node2D, navigation: MenuNavigation) -> void:
	_view = view
	_navigation = navigation

func _translate(text: String) -> String:
	return _view._translate(text)

func _field_input_position(point: Vector2) -> Vector2:
	return _view._field_input_position(point)

func _field_text(canvas: Node2D, x: float, y: float, text: String, color: Color, size := 8, slide := 1.0) -> void:
	_view._field_text(canvas,x,y,text,color,size,slide)

func _text(canvas: Node2D, y: float, text: String, size: int, color: Color) -> void:
	_view._text(canvas,y,text,size,color)

func _draw_text(canvas: Node2D, at: Vector2, text: String, size: int, color: Color) -> void:
	_view._draw_text(canvas,at,text,size,color)

func _draw_score_action(canvas: Node2D, rect: Rect2, text: String, primary: bool) -> void:
	canvas.draw_rect(rect, GRID if primary else BACKGROUND)
	canvas.draw_rect(rect, SHOT if primary else BORDER, false, 0.65)
	_field_text(canvas, rect.get_center().x, rect.get_center().y + 3, text, SHOT if primary else PRIMARY, 9)

func _key_label(action: StringName) -> String:
	return _view._key_label(action)

func _button_label(action: StringName) -> String:
	return _view._button_label(action)

func _exercise_label() -> String:
	return _view._exercise_label()

func _score_mode() -> int:
	return _view._score_mode()
