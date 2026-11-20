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
const UiSkin = preload("res://ui/skin.gd")
const PANEL := Rect2(664, 0, 592, 720)
const PANEL_CENTER := 960.0
const LANDSCAPE_CONTENT := Rect2(684, 126, 552, 532)
const LANDSCAPE_BAR := Rect2(684, 670, 552, 40)
const PORTRAIT_CONTENT := Rect2(48, 168, 464, 552)
const PORTRAIT_BAR := Rect2(28, 741, 504, 36)
const SMALL_LOGO := Rect2(676, 12, 150, 84)
const BACKGROUND := Color("#080f1c")
const GRID := Color("#142239")
const BORDER := Color("#314765")
const PRIMARY := Color("#edf5ff")
const MUTED := Color("#9eafc6")
const SHIP := Color("#70edcd")
const SHOT := Color("#ffe59a")
const ARCADE_RED := Color("#ff735d")

var _view: Node2D
var skin: UiSkin:
	get: return _view._skin
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
	var field: Rect2 = _view._field()
	var scale := field.size / Vector2(Pilot.FIELD_SIZE)
	canvas.draw_set_transform(Vector2.ZERO)
	var target := Rect2(field.position + rect.position * scale, rect.size * scale)
	skin.button(canvas, target, text, 2 if primary else 0, int(target.size.y * 0.72))
	canvas.draw_set_transform(field.position, 0.0, scale)


func portrait() -> bool:
	return _profile.portrait


func content_rect() -> Rect2:
	return PORTRAIT_CONTENT if _profile.portrait else LANDSCAPE_CONTENT


func bar_rect() -> Rect2:
	return PORTRAIT_BAR if _profile.portrait else LANDSCAPE_BAR


func pointer() -> Vector2:
	return _view._panel_point(_view.get_global_mouse_position())


func pad_hints() -> bool:
	return _view._pad_hints


# Dark sheet over the playfield in portrait, where the panel does not exist.
func sheet(canvas: Node2D) -> void:
	if _profile.portrait:
		var field: Rect2 = _view.PORTRAIT_FIELD
		canvas.draw_rect(field, skin.c("field_dim"))
		var sheet_rect := field.grow(-8)
		canvas.draw_rect(sheet_rect, Color(skin.c("panel"), 0.72))
		canvas.draw_rect(sheet_rect, skin.c("panel_border"), false, 2.0)


func header(canvas: Node2D, label: String, detail := "") -> void:
	if _profile.portrait:
		skin.title(canvas, Vector2(280, 108), label, 48, 0, 440)
		if not detail.is_empty():
			skin.text(canvas, Vector2(280, 146), detail, skin.body_size(20), skin.c("muted"), 0, skin.detail_font)
		return
	skin.title(canvas, Vector2(842, 52), label, 68, -1, 400)
	if not detail.is_empty():
		skin.text(canvas, Vector2(846, 96), detail, skin.body_size(22), skin.c("muted"), -1, skin.detail_font, 390)


# A hint chooses gamepad or keyboard glyphs from the last device used.
func hint(keys: Array, pads: Array, label: String) -> Array:
	var glyphs: Array = pads if pad_hints() else []
	if not pad_hints():
		for glyph in keys:
			glyphs.append("key:" + _translate(String(glyph).substr(4)))
	return [glyphs, _translate(label)]


func hints(canvas: Node2D, items: Array) -> void:
	skin.hint_bar(canvas, bar_rect(), items, 21 if _profile.portrait else 22)


func row_state(index: int, choice: int) -> int:
	return 2 if index == choice else 0


func _key_label(action: StringName) -> String:
	return _view._key_label(action)

func _button_label(action: StringName) -> String:
	return _view._button_label(action)

func _exercise_label() -> String:
	return _view._exercise_label()

func _score_mode() -> int:
	return _view._score_mode()
