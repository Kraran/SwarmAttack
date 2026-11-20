extends RefCounted

# Small flags drawn with primitives, one per menu language (no image assets).
# English uses the United Kingdom flag.
const RED := Color("#d52b1e")


static func draw(canvas: CanvasItem, rect: Rect2, language: String) -> void:
	match language:
		"fr": _vertical(canvas, rect, [Color("#0055a4"), Color.WHITE, Color("#ef4135")])
		"it": _vertical(canvas, rect, [Color("#009246"), Color.WHITE, Color("#ce2b37")])
		"de": _horizontal(canvas, rect, [Color("#000000"), Color("#dd0000"), Color("#ffce00")])
		"nl": _horizontal(canvas, rect, [Color("#ae1c28"), Color.WHITE, Color("#21468b")])
		"ru": _horizontal(canvas, rect, [Color.WHITE, Color("#0039a6"), Color("#d52b1e")])
		"pl": _horizontal(canvas, rect, [Color.WHITE, Color("#dc143c")])
		"es":
			_horizontal(canvas, rect, [Color("#aa151b"), Color("#f1bf00"), Color("#f1bf00"), Color("#aa151b")])
		"pt":
			canvas.draw_rect(rect, Color("#da291c"))
			canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.4, rect.size.y)), Color("#046a38"))
			var center := rect.position + Vector2(rect.size.x * 0.4, rect.size.y * 0.5)
			canvas.draw_circle(center, rect.size.y * 0.24, Color("#ffe000"))
			canvas.draw_circle(center, rect.size.y * 0.15, Color("#da291c"))
			canvas.draw_rect(Rect2(center - Vector2(rect.size.y * 0.07, rect.size.y * 0.09),
				Vector2(rect.size.y * 0.14, rect.size.y * 0.18)), Color.WHITE)
		"da": _nordic(canvas, rect, Color("#c8102e"), Color.WHITE, Color.TRANSPARENT)
		"no": _nordic(canvas, rect, Color("#ba0c2f"), Color.WHITE, Color("#00205b"))
		"sv": _nordic(canvas, rect, Color("#006aa7"), Color("#fecc00"), Color.TRANSPARENT)
		"tr": _turkey(canvas, rect)
		"en": _union(canvas, rect)
		_: canvas.draw_rect(rect, Color("#7d93a8"))
	canvas.draw_rect(rect, Color(0, 0, 0, 0.45), false, 1.0)


static func _vertical(canvas: CanvasItem, rect: Rect2, colors: Array) -> void:
	var width := rect.size.x / colors.size()
	for index in colors.size():
		canvas.draw_rect(Rect2(rect.position.x + width * index, rect.position.y, width + 0.5, rect.size.y), colors[index])


static func _horizontal(canvas: CanvasItem, rect: Rect2, colors: Array) -> void:
	var height := rect.size.y / colors.size()
	for index in colors.size():
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + height * index, rect.size.x, height + 0.5), colors[index])


static func _nordic(canvas: CanvasItem, rect: Rect2, field: Color, cross: Color, inner: Color) -> void:
	canvas.draw_rect(rect, field)
	var unit := rect.size.y / 8.0
	var x := rect.position.x + rect.size.x * 0.36
	canvas.draw_rect(Rect2(x - unit * 1.2, rect.position.y, unit * 2.4, rect.size.y), cross)
	canvas.draw_rect(Rect2(rect.position.x, rect.get_center().y - unit * 1.2, rect.size.x, unit * 2.4), cross)
	if inner.a > 0.0:
		canvas.draw_rect(Rect2(x - unit * 0.6, rect.position.y, unit * 1.2, rect.size.y), inner)
		canvas.draw_rect(Rect2(rect.position.x, rect.get_center().y - unit * 0.6, rect.size.x, unit * 1.2), inner)


static func _turkey(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("#e30a17"))
	var h := rect.size.y
	var center := rect.position + Vector2(rect.size.x * 0.36, h * 0.5)
	canvas.draw_circle(center, h * 0.25, Color.WHITE)
	canvas.draw_circle(center + Vector2(h * 0.0625, 0), h * 0.2, Color("#e30a17"))
	var star := center + Vector2(h * 0.29, 0)
	var points := PackedVector2Array()
	for index in 10:
		var radius := h * (0.12 if index % 2 == 0 else 0.05)
		var angle := PI + index * TAU / 10.0
		points.append(star + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, Color.WHITE)


static func _union(canvas: CanvasItem, rect: Rect2) -> void:
	var blue := Color("#012169")
	canvas.draw_rect(rect, blue)
	var a := rect.position
	var b := rect.end
	var diagonal := rect.size.y * 0.2
	canvas.draw_line(a, b, Color.WHITE, diagonal)
	canvas.draw_line(Vector2(a.x, b.y), Vector2(b.x, a.y), Color.WHITE, diagonal)
	canvas.draw_line(a, b, Color("#c8102e"), diagonal * 0.4)
	canvas.draw_line(Vector2(a.x, b.y), Vector2(b.x, a.y), Color("#c8102e"), diagonal * 0.4)
	var unit := rect.size.y / 30.0
	var center := rect.get_center()
	canvas.draw_rect(Rect2(center.x - unit * 5, a.y, unit * 10, rect.size.y), Color.WHITE)
	canvas.draw_rect(Rect2(a.x, center.y - unit * 5, rect.size.x, unit * 10), Color.WHITE)
	canvas.draw_rect(Rect2(center.x - unit * 3, a.y, unit * 6, rect.size.y), Color("#c8102e"))
	canvas.draw_rect(Rect2(a.x, center.y - unit * 3, rect.size.x, unit * 6), Color("#c8102e"))
