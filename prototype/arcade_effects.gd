extends RefCounted

const AMBER := Color("#ffac4a")
const RED := Color("#e84a22")
const CYAN := Color("#6ddaff")
const WHITE_HOT := Color("#fff2c7")


static func burst(canvas: CanvasItem, point: Vector2, progress: float, size := 1.0, heavy := false) -> void:
	var age := clampf(progress, 0.0, 1.0)
	var fade := 1.0 - age
	var expansion := 1.0 - pow(fade, 1.55)
	var radius := lerpf(2.7, 14.0, expansion) * size
	var flash := 1.0 - smoothstep(0.04, 0.38, age)
	if flash > 0.0:
		canvas.draw_circle(point, radius * 0.94, Color(RED, flash * 0.19), true, -1.0, true)
		canvas.draw_circle(point, radius * 0.63, Color(AMBER, flash * 0.45), true, -1.0, true)
		canvas.draw_circle(point, radius * 0.36, Color(WHITE_HOT, flash), true, -1.0, true)

	# L'anneau se brise en arcs courts à mesure que les particules s'écartent.
	var ring_light := smoothstep(0.06, 0.28, age) * pow(fade, 1.35)
	var rotation := point.x * 0.13 + point.y * 0.068
	if ring_light > 0.0:
		for sector in range(6):
			var angle := rotation + sector * TAU / 6.0
			var span := lerpf(0.95, 0.29, age) * (0.75 + 0.25 * cos(sector * 3.6))
			var tint := CYAN if sector % 3 == 1 else AMBER
			canvas.draw_arc(point, radius * 0.83, angle, angle + span, 7, Color(tint, ring_light * 0.68), 0.45 * size, true)

	for spark in range(25 if heavy else 16):
		var angle := rotation + spark * 2.399963
		var direction := Vector2.from_angle(angle)
		var spread := 0.48 + 0.60 * (0.5 + 0.5 * sin(spark * 8.7 + 0.84))
		var distance := radius * spread * (1.0 + 0.15 * sin(angle * 4.0))
		var end := point + direction * distance
		var length := (0.37 + fade * (1.7 + 0.85 * cos(spark * 4.0))) * size
		var intensity := pow(fade, 0.90 + 0.75 * spread)
		var tint := CYAN if spark % 5 == 0 else AMBER.lerp(RED, age * 0.85)
		canvas.draw_line(end - direction * length, end, Color(tint, intensity), 0.57 * size, true)
		if spark % 3 == 0:
			canvas.draw_circle(end, 0.50 * size, Color(WHITE_HOT, intensity * fade), true, -1.0, true)
		if heavy and spark % 4 == 0:
			var fragment := point + direction * distance * 0.81
			var edge := direction.rotated(0.9 + age * 3.6) * size * 0.90
			canvas.draw_colored_polygon(PackedVector2Array([
				fragment + edge, fragment + edge.orthogonal() * 0.54, fragment - edge,
			]), Color(Color("#c4ac95").lerp(RED, fade * 0.4), intensity))
