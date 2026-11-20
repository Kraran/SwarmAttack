extends RefCounted

# Interface skin: colours, fonts and shapes for every menu.
# Built-in skins are declared in SKINS; Orbital is the default. Players may add their own as
# user://skins/<name>.cfg (section [skin], keys identical to SKINS entries).
const DEFAULT_SKIN := "orbital"
const SKINS := {
	"orbital": {
		"name": "Orbital",
		"backdrop_center": "#0f2a44", "backdrop_mid": "#0a1626", "backdrop_edge": "#03070d",
		"rays": "#3ff0d214", "halftone": "#7fc8ff26",
		"panel": "#06101ce8", "panel_border": "#2a5a7a",
		"button_top": "#14304a", "button_bottom": "#0a1a2c", "button_border": "#2a5a7a", "button_text": "#d8f2ff",
		"hover_border": "#3ff0d2",
		"focus_top": "#6ffbe2", "focus_mid": "#3ff0d2", "focus_bottom": "#1fbfa6",
		"focus_border": "#e6fffb", "focus_text": "#03221c", "focus_glow": "#3ff0d255",
		"title": "#e6f4ff", "title_shadow": "#1aa58f", "shadow": "#000000",
		"text": "#e6f4ff", "muted": "#7d93a8", "accent": "#3ff0d2", "danger": "#ff6a5f", "success": "#7be368",
		"bar_line": "#3ff0d2", "field_dim": "#03070d8c",
		"skew": 0.0, "radius": 0, "shadow_offset": 0.0,
		"title_font": "res://fonts/Orbitron-ExtraBold.ttf",
		"body_font": "res://fonts/Rajdhani-SemiBold.ttf",
		"detail_font": "res://fonts/Rajdhani-Medium.ttf",
		"score_font": "res://fonts/Rajdhani-SemiBold.ttf",
		"body_scale": 0.8, "upper": true,
	},	"arcade": {
		"name": "Arcade",
		"backdrop_center": "#4a1257", "backdrop_mid": "#2a0b3a", "backdrop_edge": "#0b0418",
		"rays": "#ff782826", "halftone": "#ffb43c30",
		"panel": "#1e082ceb", "panel_border": "#7a2a8a",
		"button_top": "#3a1050", "button_bottom": "#22072f", "button_border": "#7a2a8a", "button_text": "#f2d7ff",
		"hover_border": "#c25ad6",
		"focus_top": "#fff36a", "focus_mid": "#ffd21f", "focus_bottom": "#ff9d14",
		"focus_border": "#d81e2c", "focus_text": "#120614", "focus_glow": "#ffc8264d",
		"title": "#ffd21f", "title_shadow": "#d81e2c", "shadow": "#000000",
		"text": "#fff4d6", "muted": "#b79ac7", "accent": "#ffd21f", "danger": "#ff5a1f", "success": "#7be368",
		"bar_line": "#d81e2c", "field_dim": "#0b04188c",
		"skew": 0.21, "radius": 0, "shadow_offset": 4.0,
		"title_font": "res://fonts/BebasNeue-Regular.ttf",
		"body_font": "res://fonts/Teko-SemiBold.ttf",
		"detail_font": "res://fonts/Teko-Medium.ttf",
		"score_font": "res://fonts/PressStart2P-Regular.ttf",
		"body_scale": 1.0, "upper": true,
	},



	"phosphor": {
		"name": "Phosphore",
		"backdrop_center": "#06200b", "backdrop_mid": "#031207", "backdrop_edge": "#010601",
		"rays": "#5dff7a10", "halftone": "#5dff7a26",
		"panel": "#020a03f0", "panel_border": "#2b7a38",
		"button_top": "#03140a", "button_bottom": "#020a03", "button_border": "#2b7a38", "button_text": "#9dffb0",
		"hover_border": "#5dff7a",
		"focus_top": "#7dff95", "focus_mid": "#5dff7a", "focus_bottom": "#3ddc5c",
		"focus_border": "#c8ffd2", "focus_text": "#001a05", "focus_glow": "#5dff7a55",
		"title": "#5dff7a", "title_shadow": "#1d6b2a", "shadow": "#000000",
		"text": "#c8ffd2", "muted": "#5fae6c", "accent": "#5dff7a", "danger": "#ffd24a", "success": "#5dff7a",
		"bar_line": "#2b7a38", "field_dim": "#0106018c",
		"skew": 0.0, "radius": 0, "shadow_offset": 0.0,
		"title_font": "res://fonts/PressStart2P-Regular.ttf",
		"body_font": "res://fonts/PressStart2P-Regular.ttf",
		"detail_font": "res://fonts/PressStart2P-Regular.ttf",
		"score_font": "res://fonts/PressStart2P-Regular.ttf",
		"body_scale": 0.56, "upper": false,
	},
}
const PAD_COLORS := {"A": "#5ec84b", "B": "#e5443b", "X": "#3d8eef", "Y": "#f0c02c"}

var id := "arcade"
var display_name := "Arcade"
var colors := {}
var skew := 0.21
var radius := 0
var shadow_offset := 4.0
var body_scale := 1.0
var upper := true
var title_font: Font
var body_font: Font
var detail_font: Font
var score_font: Font
var symbol_font: Font


static func available() -> PackedStringArray:
	var names := PackedStringArray(SKINS.keys())
	var directory := DirAccess.open("user://skins")
	if directory != null:
		for file in directory.get_files():
			if file.get_extension() == "cfg" and not names.has(file.get_basename()):
				names.append(file.get_basename())
	return names


static func create(skin_id: String):
	var skin = load("res://ui/skin.gd").new()
	skin.configure(skin_id)
	return skin


func configure(skin_id: String) -> void:
	var values: Dictionary = SKINS[DEFAULT_SKIN].duplicate()
	if SKINS.has(skin_id):
		values.merge(SKINS[skin_id], true)
	else:
		var config := ConfigFile.new()
		if config.load("user://skins/%s.cfg" % skin_id) == OK and config.has_section("skin"):
			for key in config.get_section_keys("skin"):
				var value: Variant = config.get_value("skin", key)
				if values.has(key) and typeof(value) in [TYPE_STRING, TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
					values[key] = value
		else:
			skin_id = DEFAULT_SKIN
	id = skin_id
	display_name = String(values["name"])
	colors.clear()
	for key in values:
		if values[key] is String and String(values[key]).begins_with("#"):
			colors[key] = Color(values[key])
	skew = float(values["skew"])
	radius = int(values["radius"])
	shadow_offset = float(values["shadow_offset"])
	body_scale = float(values["body_scale"])
	upper = bool(values["upper"])
	symbol_font = ThemeDB.fallback_font
	title_font = _font(values["title_font"])
	body_font = _font(values["body_font"])
	detail_font = _font(values["detail_font"])
	score_font = _font(values["score_font"])


# Style-matched fallbacks for scripts the theme fonts lack (Cyrillic, and
# Latin Extended for Orbitron): Polish, Turkish and Russian stay in the look.
const FONT_FALLBACKS := {
	"Orbitron": "res://fonts/RussoOne-Regular.ttf",
	"BebasNeue": "res://fonts/RussoOne-Regular.ttf",
	"Rajdhani": "res://fonts/Exo2-SemiBold.ttf",
	"Teko": "res://fonts/Oswald-Medium.ttf",
}


func _font(path: Variant) -> Font:
	var font: Font = null
	var source := String(path)
	if source.begins_with("res://") and ResourceLoader.exists(source):
		font = load(source)
	elif source.begins_with("user://") and FileAccess.file_exists(source):
		var file := FontFile.new()
		if file.load_dynamic_font(source) == OK:
			font = file
	if font == null:
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = font
	var fallbacks: Array[Font] = []
	for family in FONT_FALLBACKS:
		if source.get_file().begins_with(family):
			fallbacks.append(load(FONT_FALLBACKS[family]))
	fallbacks.append(ThemeDB.fallback_font)
	variation.fallbacks = fallbacks
	return variation


func c(key: String) -> Color:
	return colors.get(key, Color.MAGENTA)


func caps(text: String) -> String:
	return text.to_upper() if upper else text


# --- Text -----------------------------------------------------------------

func text_width(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


func body_size(size: float) -> int:
	return maxi(6, roundi(size * body_scale))


# Draws text vertically centred on center.y. align: -1 left, 0 centre, 1 right.
func text(canvas: CanvasItem, center: Vector2, label: String, size: int, color: Color, align := 0, font: Font = null, max_width := -1.0) -> float:
	font = body_font if font == null else font
	var width := text_width(font, label, size)
	if max_width > 0.0 and width > max_width:
		size = maxi(6, floori(size * max_width / width))
		width = text_width(font, label, size)
	var x := center.x - (width / 2.0 if align == 0 else (width if align > 0 else 0.0))
	var baseline := center.y + (font.get_ascent(size) - font.get_descent(size)) / 2.0
	canvas.draw_string(font, Vector2(x, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
	return width


func title(canvas: CanvasItem, center: Vector2, label: String, size: int, align := 0, max_width := -1.0) -> void:
	label = caps(label)
	size = body_size(size)
	var depth := shadow_offset * size / 64.0
	if depth > 0.0:
		text(canvas, center + Vector2(depth * 2.0, depth * 2.0), label, size, c("shadow"), align, title_font, max_width)
		text(canvas, center + Vector2(depth, depth), label, size, c("title_shadow"), align, title_font, max_width)
	text(canvas, center, label, size, c("title"), align, title_font, max_width)


# --- Shapes ---------------------------------------------------------------

func slant_points(rect: Rect2, amount := -1.0) -> PackedVector2Array:
	var offset := rect.size.y * (skew if amount < 0.0 else amount)
	return PackedVector2Array([
		rect.position + Vector2(offset, 0), Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(offset, 0), Vector2(rect.position.x, rect.end.y),
	])


func shape(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color, border: Color, border_width := 2.0, amount := -1.0) -> void:
	var points := slant_points(rect, amount)
	if shadow_offset > 0.0:
		var shade := PackedVector2Array()
		for point in points:
			shade.append(point + Vector2(shadow_offset, shadow_offset))
		canvas.draw_colored_polygon(shade, Color(c("shadow"), 0.85))
	canvas.draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))
	if border_width > 0.0:
		var outline := points.duplicate()
		outline.append(points[0])
		canvas.draw_polyline(outline, border, border_width, true)


func panel(canvas: CanvasItem, rect: Rect2) -> void:
	shape(canvas, rect, c("panel"), c("panel"), c("panel_border"), 2.0, 0.0)


# state: 0 normal, 1 hover, 2 focus
func button_frame(canvas: CanvasItem, rect: Rect2, state: int) -> void:
	if state == 2:
		var points := slant_points(rect)
		if shadow_offset > 0.0:
			var shade := PackedVector2Array()
			for point in points:
				shade.append(point + Vector2(shadow_offset, shadow_offset) * 1.4)
			canvas.draw_colored_polygon(shade, c("shadow"))
		var full := slant_points(rect)
		canvas.draw_polygon(full, PackedColorArray([c("focus_top"), c("focus_top"), c("focus_bottom"), c("focus_bottom")]))
		var shine := PackedVector2Array([full[0].lerp(full[3], 0.06), full[1].lerp(full[2], 0.06), full[1].lerp(full[2], 0.26), full[0].lerp(full[3], 0.26)])
		canvas.draw_colored_polygon(shine, Color(1, 1, 1, 0.18))
		var outline := full.duplicate()
		outline.append(full[0])
		canvas.draw_polyline(outline, c("focus_border"), 3.0, true)
		return
	shape(canvas, rect, c("button_top"), c("button_bottom"),
		c("hover_border") if state == 1 else c("button_border"), 2.0)


func button(canvas: CanvasItem, rect: Rect2, label: String, state: int, size := 26, align := 0) -> void:
	button_frame(canvas, rect, state)
	var color := c("focus_text") if state == 2 else c("button_text")
	var inset := rect.size.y * skew * 0.5 + 14.0
	var center := rect.get_center() + Vector2(0, 1)
	if align < 0:
		center.x = rect.position.x + inset
	text(canvas, center, caps(label), body_size(size), color, align, body_font, rect.size.x - inset * 2.0)


func arrow(canvas: CanvasItem, center: Vector2, direction: int, size: float, color: Color) -> void:
	var tip := Vector2(direction * size * 0.6, 0)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + tip, center - Vector2(tip.x, size * 0.6), center - Vector2(tip.x, -size * 0.6)]), color)


func meter(canvas: CanvasItem, rect: Rect2, value: float, on_color: Color, off_color: Color) -> void:
	var segments := 10
	var gap := 3.0
	var width := (rect.size.x - gap * (segments - 1)) / segments
	for index in segments:
		var cell := Rect2(rect.position.x + index * (width + gap), rect.position.y, width, rect.size.y)
		var lit := value * segments >= index + 0.5
		canvas.draw_colored_polygon(slant_points(cell, skew * 0.6), on_color if lit else off_color)


# --- Glyphs ---------------------------------------------------------------

const ARROWS := {"←": Vector2.LEFT, "→": Vector2.RIGHT, "↑": Vector2.UP, "↓": Vector2.DOWN}


func _glyph_arrow(canvas: CanvasItem, center: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var side := Vector2(-direction.y, direction.x)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + direction * size * 0.55, center - direction * size * 0.4 + side * size * 0.5,
		center - direction * size * 0.4 - side * size * 0.5]), color)


func keycap(canvas: CanvasItem, left: Vector2, label: String, height := 22.0) -> float:
	var size := int(height * 0.55)
	var width := maxf(height, text_width(symbol_font, label, size) + 14.0)
	if ARROWS.has(label):
		width = height
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#2c2238")
	box.border_color = Color("#8b6c9c")
	box.set_border_width_all(1)
	box.border_width_bottom = 3
	box.set_corner_radius_all(5)
	var rect := Rect2(left - Vector2(0, height / 2.0), Vector2(width, height))
	box.draw(canvas.get_canvas_item(), rect)
	if ARROWS.has(label):
		_glyph_arrow(canvas, rect.get_center() - Vector2(0, 1), ARROWS[label], height * 0.42, Color("#f1e6f7"))
	else:
		text(canvas, rect.get_center() - Vector2(0, 1), label, size, Color("#f1e6f7"), 0, symbol_font)
	return width


func pad(canvas: CanvasItem, left: Vector2, label: String, height := 22.0) -> float:
	var round_button := PAD_COLORS.has(label)
	var size := int(height * (0.6 if round_button else 0.45))
	var shaped := label in ["✚", "◀▶", "▲▼", "←", "→", "↑", "↓"]
	var width := height if round_button or label == "✚" or ARROWS.has(label) else maxf(height * 1.4, text_width(symbol_font, label, size) + 12.0)
	if shaped and label in ["◀▶", "▲▼"]:
		width = height * 1.5
	var tint := Color(PAD_COLORS.get(label, "#aab3c2"))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#15111c")
	box.border_color = tint
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(height / 2.0) if round_button else 6)
	var rect := Rect2(left - Vector2(0, height / 2.0), Vector2(width, height))
	box.draw(canvas.get_canvas_item(), rect)
	var ink := tint.lightened(0.25)
	var middle := rect.get_center()
	match label:
		"✚":
			var arm := height * 0.32
			var thick := height * 0.12
			canvas.draw_rect(Rect2(middle - Vector2(arm, thick), Vector2(arm * 2, thick * 2)), ink)
			canvas.draw_rect(Rect2(middle - Vector2(thick, arm), Vector2(thick * 2, arm * 2)), ink)
		"◀▶":
			_glyph_arrow(canvas, middle - Vector2(height * 0.3, 0), Vector2.LEFT, height * 0.38, ink)
			_glyph_arrow(canvas, middle + Vector2(height * 0.3, 0), Vector2.RIGHT, height * 0.38, ink)
		"▲▼":
			_glyph_arrow(canvas, middle - Vector2(height * 0.3, 0), Vector2.UP, height * 0.38, ink)
			_glyph_arrow(canvas, middle + Vector2(height * 0.3, 0), Vector2.DOWN, height * 0.38, ink)
		_:
			if ARROWS.has(label):
				_glyph_arrow(canvas, middle, ARROWS[label], height * 0.45, ink)
			else:
				text(canvas, middle, label, size, ink, 0, symbol_font)
	return width


func mouse(canvas: CanvasItem, left: Vector2, button_side: int, height := 22.0) -> float:
	var width := height * 0.68
	var rect := Rect2(left - Vector2(0, height / 2.0), Vector2(width, height))
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color("#d8c6e2")
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(width / 2.0))
	box.draw(canvas.get_canvas_item(), rect)
	var half := rect.position + Vector2(2 if button_side < 0 else width / 2.0, 2)
	canvas.draw_rect(Rect2(half, Vector2(width / 2.0 - 2, height * 0.38)), c("accent"))
	canvas.draw_line(rect.position + Vector2(width / 2.0, 0), rect.position + Vector2(width / 2.0, height * 0.42), Color("#d8c6e2"), 2.0)
	return width


# items: Array of [Array[String] glyphs, String label]; glyph "pad:A", "key:Échap", "mouse:L"
func hint_bar(canvas: CanvasItem, rect: Rect2, items: Array, size := 22) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), c("bar_line"))
	var glyph_height := minf(24.0, rect.size.y - 12.0)
	var label_size := body_size(size)
	# Shrink labels until the whole bar fits, so long translations never overflow.
	while label_size > 8 and _hint_width(items, glyph_height, label_size) > rect.size.x:
		label_size -= 1
	var x := rect.position.x
	var y := rect.position.y + 3 + (rect.size.y - 3) / 2.0
	for item in items:
		if item[0].is_empty():
			continue
		for glyph in item[0]:
			var kind: String = String(glyph).get_slice(":", 0)
			var value: String = String(glyph).substr(kind.length() + 1)
			match kind:
				"pad": x += pad(canvas, Vector2(x, y), value, glyph_height) + 4
				"mouse": x += mouse(canvas, Vector2(x, y), -1 if value == "L" else 1, glyph_height) + 4
				_: x += keycap(canvas, Vector2(x, y), value, glyph_height) + 4
		x += 4
		x += text(canvas, Vector2(x, y + 1), caps(item[1]), label_size, c("text"), -1) + 18


func _hint_width(items: Array, glyph_height: float, label_size: int) -> float:
	var width := 0.0
	for item in items:
		if item[0].is_empty():
			continue
		for glyph in item[0]:
			var kind: String = String(glyph).get_slice(":", 0)
			var value: String = String(glyph).substr(kind.length() + 1)
			if kind == "pad":
				if PAD_COLORS.has(value) or value == "✚" or ARROWS.has(value):
					width += glyph_height
				elif value in ["◀▶", "▲▼"]:
					width += glyph_height * 1.5
				else:
					width += maxf(glyph_height * 1.4, text_width(symbol_font, value, int(glyph_height * 0.45)) + 12.0)
			elif kind == "mouse":
				width += glyph_height * 0.68
			else:
				width += glyph_height if ARROWS.has(value) else maxf(glyph_height, text_width(symbol_font, value, int(glyph_height * 0.55)) + 14.0)
			width += 4
		width += 4 + text_width(body_font, caps(item[1]), label_size) + 18
	return width - 18


# --- Backdrop -------------------------------------------------------------

func configure_backdrop(material: ShaderMaterial, origin: Vector2, size: Vector2, focus: Vector2, reach: float) -> void:
	material.set_shader_parameter(&"origin", origin)
	material.set_shader_parameter(&"size", size)
	material.set_shader_parameter(&"focus", focus)
	material.set_shader_parameter(&"reach", reach)
	material.set_shader_parameter(&"center_color", c("backdrop_center"))
	material.set_shader_parameter(&"mid_color", c("backdrop_mid"))
	material.set_shader_parameter(&"edge_color", c("backdrop_edge"))
	material.set_shader_parameter(&"ray_color", c("rays"))
	material.set_shader_parameter(&"dot_color", c("halftone"))
