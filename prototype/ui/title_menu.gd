extends "res://ui/menu_screen.gd"

const LABEL_X := 704
const PANEL_END := 1156
const SOLO_BUTTON := Rect2(LABEL_X, 468, PANEL_END - LABEL_X, 50)
const DUO_BUTTON := Rect2(LABEL_X, 529, PANEL_END - LABEL_X, 45)
const OPTIONS_BUTTON := Rect2(LABEL_X, 588, PANEL_END - LABEL_X, 42)
const PORTRAIT_OPTIONS_BUTTON := Rect2(312, 17, 220, 34)
const SCORES_BUTTON := Rect2(LABEL_X, 308, 216, 42)
const TRAINING_BUTTON := Rect2(LABEL_X + 232, 308, 220, 42)
const PORTRAIT_SCORES_BUTTON := Rect2(28, 740, 244, 30)
const PORTRAIT_TRAINING_BUTTON := Rect2(288, 740, 244, 30)


func draw(canvas: Node2D) -> void:
	draw_menu_button(canvas, SCORES_BUTTON, _translate("Classements"), "F4")
	draw_menu_button(canvas, TRAINING_BUTTON, _translate("Entraînement"), "F2")
	_text(canvas, 428, _translate("Partie arcade"), 24, PRIMARY)
	var pointer := _view.get_global_mouse_position()
	draw_button(canvas, SOLO_BUTTON, _translate("1 joueur"), "%s / %s" % [_key_label(&"fire"), _button_label(&"fire")], true, pointer)
	draw_button(canvas, DUO_BUTTON, _translate("2 joueurs en alternance"), "2 / Y", false, pointer)
	draw_options_button(canvas, OPTIONS_BUTTON, pointer)
	draw_hints(canvas)


func draw_menu_button(canvas: Node2D, rect: Rect2, label: String, shortcut: String) -> void:
	canvas.draw_rect(rect, GRID if rect.has_point(_view.get_global_mouse_position()) else Color("#141f32"))
	var baseline := rect.get_center().y + 5
	_draw_text(canvas, Vector2(rect.position.x + 12, baseline), label, 16, PRIMARY)
	_draw_text(canvas, Vector2(rect.end.x - 30, baseline), shortcut, 12, MUTED)


func draw_button(canvas: Node2D, rect: Rect2, label: String, shortcut: String, primary: bool, pointer: Vector2) -> void:
	var fill := SHIP if primary else Color("#141f32")
	if rect.has_point(pointer):
		fill = fill.lightened(0.14)
	canvas.draw_rect(rect, fill)
	var tint := BACKGROUND if primary else PRIMARY
	var baseline := rect.get_center().y + 6
	_draw_text(canvas, Vector2(rect.position.x + 16, baseline), label, 17, tint)
	_draw_text(canvas, Vector2(rect.end.x - 100, baseline - 1), shortcut, 13, tint)


func draw_options_button(canvas: Node2D, rect: Rect2, pointer: Vector2) -> void:
	canvas.draw_rect(rect, GRID if rect.has_point(pointer) else Color("#141f32"))
	var label := "%s · %s" % [_translate("Options"), _translate(ArcadeProfile.DIFFICULTY_LABELS[_profile.difficulty])]
	var y := rect.get_center().y + 5.0
	_draw_text(canvas, Vector2(rect.position.x + 12, y), label, 14, PRIMARY)
	_draw_text(canvas, Vector2(rect.end.x - 45, y), "F3 / X", 12, MUTED)


func draw_hints(canvas: Node2D) -> void:
	var sound := _translate("coupé" if _profile.muted else "actif")
	_text(canvas, 651, _translate("F1 Diagnostic    F2 Entraînement    F5 Son %s") % sound, 14, MUTED)
	_text(canvas, 675, _translate("F10 Portrait    F11 Plein écran"), 14, MUTED)
