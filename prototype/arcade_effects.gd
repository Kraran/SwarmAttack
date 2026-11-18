extends RefCounted

const Presentation = preload("res://flight_presentation.gd")
const CombatWave = preload("res://combat_wave.gd")
const IMPACT_LIFETIME := 18
const AMBER := Color("#ffac4a")
const RED := Color("#e84a22")
const CYAN := Color("#6ddaff")
const WHITE_HOT := Color("#fff2c7")
const INTERCEPTOR_WING_POINTS := [
	Vector2(5.4, -5.8), Vector2(4.3, -4.4), Vector2(3.6, -2.8), Vector2(2.5, -1.6),
	Vector2(1.5, -0.5), Vector2(3.0, 1.4), Vector2(4.1, 3.1), Vector2(5.4, 5.2),
	Vector2(3.5, 5.4), Vector2(2.6, 3.6), Vector2(1.6, 2.2), Vector2(5.9, -3.1),
]

class Impact:
	var wave: CombatWave
	var enemy: CombatWave.Enemy
	var slot: int
	var tick: int
	var kind: int
	var variant: int
	var point: Vector2
	var heading: Vector2
	var growth := 1.0

	func _init(source: CombatWave, index: int, number: int, at_tick: int) -> void:
		wave = source
		enemy = source.enemies[index]
		slot = index
		tick = at_tick
		kind = Presentation.enemy_kind(number)
		variant = (number - 1) % 2
		point = enemy.display_position()
		heading = Presentation.ring_axis(Vector2(enemy.velocity),
			enemy.opening_left if enemy.phase == CombatWave.Flight.OPENING else 0)
		if kind == Presentation.EnemyKind.RING:
			growth = Presentation.ring_scale(enemy.opening_left if enemy.phase == CombatWave.Flight.OPENING else 0)
		elif kind == Presentation.EnemyKind.METEOR:
			growth = Presentation.meteor_scale(enemy.opening_left)
		elif kind == Presentation.EnemyKind.ROW and enemy.phase == CombatWave.Flight.OPENING:
			growth = Presentation.capsule_scale(enemy.opening_left)


static func projectile(canvas: CanvasItem, point: Vector2, length: float) -> void:
	var head := point + Vector2(0.5, 0)
	var tail := head + Vector2(0, length)
	canvas.draw_line(head, tail, Color(AMBER, 0.15), 4.0, true)
	canvas.draw_line(head, tail, Color("#172131"), 2.3, true)
	canvas.draw_line(head, tail, Color("#ffc66b"), 1.6, true)
	canvas.draw_line(head, tail, Color("#fffdf2"), 0.75, true)
	canvas.draw_circle(head, 0.55, Color("#fffdf2"), true, -1.0, true)
	canvas.draw_line(tail, tail + Vector2(0, 2), Color(AMBER, 0.28), 0.75, true)


static func enemy_burst(canvas: CanvasItem, impact: Impact, progress: float) -> void:
	var age := clampf(progress, 0.0, 1.0)
	match impact.kind:
		Presentation.EnemyKind.RING:
			_half_burst(canvas, impact, age)
		Presentation.EnemyKind.METEOR:
			meteor_burst(canvas, impact.point, age, impact.growth, impact.variant)
		_:
			var electric := impact.kind == Presentation.EnemyKind.INTERCEPTOR
			var heavy := impact.kind == Presentation.EnemyKind.ROW
			var size := (1.12 if heavy else 0.85) * impact.growth
			var armor := Color("#a8c5dd") if electric else Color("#d4d9df")
			burst(canvas, impact.point, age, size, heavy, armor, electric)
			var flash := 1.0 - smoothstep(0.02, 0.19, age)
			if flash > 0.0:
				canvas.draw_line(impact.point - Vector2(3, 0) * size, impact.point + Vector2(3, 0) * size,
					Color(WHITE_HOT, flash), 0.8, true)


static func half_damage(canvas: CanvasItem, point: Vector2, heading: Vector2, growth: float, progress: float) -> void:
	var fade := 1.0 - clampf(progress, 0.0, 1.0)
	var seam := heading.orthogonal() * 2.6 * growth
	canvas.draw_line(point - seam, point + seam, Color(AMBER, fade * 0.8), 0.7 * growth, true)
	canvas.draw_circle(point, 0.7 * growth, Color(WHITE_HOT, pow(fade, 3.0)), true, -1.0, true)


static func _half_burst(canvas: CanvasItem, impact: Impact, age: float) -> void:
	var fade := 1.0 - age
	var outward := impact.heading * (1.0 if impact.slot % 2 == 0 else -1.0)
	var center := impact.point + outward * 3.9 * impact.growth
	var radius := lerpf(0.6, 7.8, 1.0 - pow(fade, 1.5)) * impact.growth
	var flash := 1.0 - smoothstep(0.02, 0.20, age)
	if flash > 0.0:
		canvas.draw_circle(center, 2.0 * impact.growth, Color(AMBER, flash * 0.65), true, -1.0, true)
		canvas.draw_circle(center, 0.9 * impact.growth, Color(WHITE_HOT, flash), true, -1.0, true)
	for index in range(8):
		var direction := outward.rotated(-1.15 + index * 2.3 / 7.0)
		var end := center + direction * radius * (0.65 + 0.3 * sin(index * 2.4))
		var color := Color("#c9dcf0") if index % 2 == 0 else AMBER
		canvas.draw_line(end - direction * 1.4 * fade * impact.growth, end, Color(color, fade), 0.65 * impact.growth, true)
		if index % 2 == 0:
			_fragment(canvas, end, direction.rotated(age * 5 + index), impact.growth * 0.9, Color(color, fade))


static func _fragment(canvas: CanvasItem, point: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var edge := direction * size
	canvas.draw_colored_polygon(PackedVector2Array([
		point + edge, point + edge.orthogonal() * 0.55, point - edge,
	]), color)
	canvas.draw_line(point + edge, point + edge.orthogonal() * 0.55, Color(WHITE_HOT, color.a * 0.6), size * 0.3, true)


static func interceptor_appearance(canvas: CanvasItem, point: Vector2, variant: int, progress: float, frame: float) -> void:
	var armor := Color("#91ee66") if variant == 0 else Color("#e66de8")
	var core := Color("#ff663c") if variant == 0 else Color("#ffd061")
	var spread := lerpf(0.68, 1.10, progress)
	var visible_points := roundi(lerpf(5.0, INTERCEPTOR_WING_POINTS.size(), progress))
	var pulse := frame * 0.27
	for side in [-1, 1]:
		for index in range(visible_points):
			var offset: Vector2 = INTERCEPTOR_WING_POINTS[(index * 5) % INTERCEPTOR_WING_POINTS.size()]
			var shine := 0.52 + 0.34 * sin(pulse + index * 1.8 + side)
			var center := point + Vector2(offset.x * side, offset.y) * spread
			canvas.draw_circle(center, 0.52 + progress * 0.16, Color(armor, shine), true, -1.0, true)
	for index in range(5):
		var center := point + Vector2(0.42 * sin(index * 2.7), (index - 2) * 1.7) * spread
		var shine := (0.45 + 0.32 * cos(pulse - index * 1.4)) * lerpf(0.48, 1.0, progress)
		canvas.draw_circle(center, 0.58 + progress * 0.17, Color(core, shine), true, -1.0, true)


static func meteor_burst(canvas: CanvasItem, point: Vector2, progress: float, growth: float, variant: int) -> void:
	var age := clampf(progress, 0.0, 1.0)
	var fade := 1.0 - age
	var scale := maxf(growth, 0.58)
	var radius := lerpf(3.5, 17.0, 1.0 - pow(fade, 1.6)) * scale
	var flash := 1.0 - smoothstep(0.04, 0.30, age)
	if flash > 0.0:
		canvas.draw_circle(point, radius * 0.82, Color(AMBER, flash * 0.46), true, -1.0, true)
		canvas.draw_circle(point, radius * 0.46, Color(WHITE_HOT, flash), true, -1.0, true)

	var mineral := Color("#a5d47f") if variant == 0 else Color("#a5b9df")
	var rotation := point.dot(Vector2(0.19, 0.11))
	var glow := pow(fade, 0.85)
	var ember_tint := AMBER.lerp(RED, age * 0.85)
	for index in range(21):
		var angle := rotation + TAU * index / 21.0
		var direction := Vector2.from_angle(angle)
		var distance := radius * (0.82 + 0.18 * sin(angle * 4.0 + index * 2.6))
		var ember := point + direction * distance
		var tint := CYAN if index % 3 == 0 else ember_tint
		canvas.draw_circle(ember, 0.44 + 0.36 * fade, Color(tint, glow), true, -1.0, true)
		if index % 3 == 1:
			var chip := point + direction * distance * (1.08 + 0.19 * cos(index * 1.6))
			var edge := direction.rotated(index + age * 4.0) * (0.7 + 0.65 * fade) * scale
			canvas.draw_colored_polygon(PackedVector2Array([
				chip + edge, chip + edge.orthogonal() * 0.75, chip - edge,
			]), Color(mineral, fade))


static func burst(canvas: CanvasItem, point: Vector2, progress: float, size := 1.0, heavy := false,
		armor := Color("#c4ac95"), electric := false) -> void:
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
		var tint := CYAN if spark % (2 if electric else 5) == 0 else AMBER.lerp(RED, age * 0.85)
		canvas.draw_line(end - direction * length, end, Color(tint, intensity), 0.57 * size, true)
		if spark % 3 == 0:
			canvas.draw_circle(end, 0.50 * size, Color(WHITE_HOT, intensity * fade), true, -1.0, true)
		if spark % (4 if heavy else 6) == 0:
			var fragment := point + direction * distance * 0.81
			_fragment(canvas, fragment, direction.rotated(0.9 + age * 3.6), size * 0.90,
				Color(armor.lerp(RED, fade * 0.4), intensity))
