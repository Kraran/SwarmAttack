extends RefCounted

const Chrome = preload("res://chrome.gdshader")
const ExhaustShader = preload("res://exhaust.gdshader")
const MeteorModel = preload("res://meteor_model.gd")
const Presentation = preload("res://flight_presentation.gd")
const SILVER := Color("#d9e9fb")
const GUNMETAL := Color("#3c4b62")


static func build_ship(module: int) -> Node3D:
	var ship := Node3D.new()
	var chrome := _finish(SILVER)
	var recess := _finish(GUNMETAL, 0.42)
	match module:
		1:
			var lime := _finish(Color("#75e64e"), 0.8)
			var violet := _finish(Color("#9d83ff"), 0.78)
			# Aiguille centrale, épaulements courts et extrémités relevées.
			_hull(ship, [0, -0.7, 1, 2.2, 2.7, 3.7, 5.7, 4.8, 5.9, 7.5, 3.4, 6.3, 1.6, 8.2], lime, 1.0)
			_hull(ship, [0, 0.2, 0.65, 3, 2.2, 4.2, 4.9, 5.45, 5.1, 6.65, 2.35, 5.9, 1.25, 7.65], violet, 1.28)
			_hull(ship, [0, 0, 0.88, 3.4, 0.9, 6.7, 0.55, 8.1], chrome, 1.6)
			_panel(ship, _points([0, 2.1, 0.62, 3.7, 0.52, 5.45, 0, 5.9, -0.52, 5.45, -0.62, 3.7]), recess, 1.66)
			_bar(ship, Vector2(0, 4.0), Vector2(0.36, 1.6), _finish(Color("#68dcff"), 0.35, 0.65), 1.8)
			_thruster(ship, 7.45, 0.88, 5.8)
		2:
			var cyan := _finish(Color("#52dfff"), 0.87)
			var gold := _finish(Color("#ffda66"), 0.76)
			var red := _finish(Color("#ef6750"), 0.73)
			# Aile delta étagée, cockpit rouge et deux pointes sur le bord de fuite.
			_hull(ship, [0, -0.5, 2.2, 0, 2.1, 1.25, 4.1, 2.7, 6.1, 5.25, 7.1, 6.1, 7.8, 3.8, 8.3, 6.8, 9.1, 7.45, 9.1, 8.25, 5.4, 7.65, 2.6, 6.85, 2.3, 8.55], gold, 1.08)
			_hull(ship, [0, -0.2, 1.72, 0.25, 1.8, 1.6, 4.05, 3.2, 6.3, 6.0, 7.0, 7.15, 5.55, 7.05, 3.0, 6.2, 2.1, 7.15], cyan, 1.39)
			_hull(ship, [0, 1.35, 1.9, 2.45, 2.28, 3.95, 1.95, 7.2], red, 1.58)
			_bar(ship, Vector2(0, 4.8), Vector2(0.7, 4), chrome, 1.72)
			for side in [-1, 1]:
				_panel(ship, _points([side * 2.5, 2.84, side * 5.85, 6.12, side * 4.2, 5.7]), chrome, 1.52)
			_thruster(ship, 7.95, 1.3, 6.45)
		3:
			var green := _finish(Color("#8be34b"), 0.78)
			var blue := _finish(Color("#687be3"), 0.86)
			var gold := _finish(Color("#ffdc70"), 0.84)
			# Bouclier ventral, larges nacelles et ouvertures de radiateur.
			_hull(ship, [0, -0.7, 2.05, 0.1, 2.9, 3.95, 4.9, 5.72, 8.2, 7.4, 10.6, 7.05, 11.2, 4.5, 12.0, 7.35, 13.5, 8.8, 13.1, 15.5, 11.74, 13.1, 10.8, 11.4, 7.2, 11.85, 4.65, 11.85, 3.9, 14.15, 1.9, 16.0, 0, 17.2], green, 1.2)
			_hull(ship, [0, 0.35, 1.25, 1.15, 2.34, 4.5, 4.0, 6.1, 7.7, 8.15, 10.7, 7.75, 12.5, 9.5, 12.4, 11.55, 10.5, 10.8, 7.4, 10.92, 4.5, 11.0, 3.03, 13.5, 1.65, 15.1, 0, 15.9], blue, 1.65)
			_hull(ship, [0, 4.8, 2.1, 6.1, 3.6, 7.6, 3.6, 11.6, 2, 13.0, 0, 13.1], gold, 2.0)
			for count in range(-2, 3):
				_bar(ship, Vector2(count * 1.1, 9.3), Vector2(0.61, 4.25), recess, 2.12)
			for side in [-1, 1]:
				_panel(ship, _points([side * 6.2, 9.5, side * 9.7, 7.9, side * 11.8, 9.15, side * 9.7, 10.2]), chrome, 1.82)
			_thruster(ship, 15.6, 1.65, 7.4)
	return ship


static func build_enemy(kind: int, variant: int) -> Node3D:
	var enemy := Node3D.new()
	if kind == Presentation.EnemyKind.METEOR:
		enemy.add_child(MeteorModel.build(variant))
		return enemy
	if kind == Presentation.EnemyKind.ROW:
		_build_capsule(enemy, variant)
		return enemy
	var neutral := _finish(SILVER)
	var colors := [
		[Color("#a971f3"), Color("#b8df29")],
		[Color("#74d438"), Color("#d557e2")],
		[Color("#78df52"), Color("#de51db")],
	]
	var lights := [
		[Color("#62e955"), Color("#6672ed")],
		[Color("#ef5533"), Color("#ffc962")],
		[Color("#f1a13b"), Color("#47dcfb")],
	]
	var color: Color = colors[kind][variant]
	var light: Color = lights[kind][variant]
	var frame := _finish(color, 0.9)
	var inset := _finish(color.darkened(0.55), 0.61)
	var core := _finish(light, 0.5, 0.71)
	match kind:
		Presentation.EnemyKind.RING:
			# Une seule moitié de rotor. L'autre créneau dessine le même
			# demi-anneau tourné de 180° autour du pivot du sprite.
			var half := Node3D.new()
			half.name = "Half"
			enemy.add_child(half)
			var armor := SurfaceTool.new()
			armor.begin(Mesh.PRIMITIVE_TRIANGLES)
			var exposed := SurfaceTool.new()
			exposed.begin(Mesh.PRIMITIVE_TRIANGLES)
			for sector in range(6):
				var angle := -PI + (sector + 0.5) * PI / 6.0
				var blade := [-0.251, -0.13, 0.09, 0.251]
				var outer := [5.1, 6.7, 6.55, 5.2] if sector % 2 == 0 else [5.25, 6.1, 6.2, 5.3]
				var outline := PackedVector2Array()
				for i in range(4):
					outline.append(Vector2.from_angle(angle + blade[i]) * outer[i])
				outline.append(Vector2.from_angle(angle + 0.251) * 3.05)
				outline.append(Vector2.from_angle(angle - 0.251) * 3.05)
				_add_bevel(armor if sector % 3 != 0 else exposed, outline, 1.33, 0.68)
			_commit(half, armor, frame)
			_commit(half, exposed, neutral)
			_bevel(half, _half_disc(2.75), inset, 0.88, 0.31)
			_bevel(half, _half_disc(1.68), core, 1.4, 0.75)
		Presentation.EnemyKind.INTERCEPTOR:
			# Les intercepteurs des vagues 5 et 6 ont un thorax étroit et
			# des appendices séparés en X, visibles de face et de profil.
			var polished_core := _finish(light, 0.85, 0.30)
			_hull(enemy, [0, -4.8, 1.3, -3.5, 1.95, -0.5, 1.65, 2.2, 0.65, 4.35], polished_core, 1.74)
			for side in [-1, 1]:
				_bevel(enemy, _points([0, -1.65, side * 2.4, -2.72, side * 3.6, -5.65, side * 5.48, -5.85, side * 4.72, -3.8, side * 3.52, -1.38, side * 1.45, 0.25]), frame, 1.25, 0.55)
				_bevel(enemy, _points([side * 0.9, 0.06, side * 3.14, 1.3, side * 3.86, 3.65, side * 5.42, 5.25, side * 3.48, 5.45, side * 2.52, 4.02, side * 2.1, 2.94, 0, 1.3]), frame, 1.39, 0.55)
				_bar(enemy, Vector2(side * 0.87, 0.65), Vector2(0.54, 1.63), core, 1.88)
			_panel(enemy, _points([-1.03, -1.8, 0.12, -2.77, 1.09, -1.59, 0.19, -0.36]), neutral, 1.81)
		Presentation.EnemyKind.CLAW:
			# Ailes en crochets, deux griffes et pont mécanique central.
			var outline := [0, -3.7, 1.35, -3.45, 1.9, -1.65, 3.05, -1.5, 3.6, -4.95, 5.7, -2.6, 6.1, 1.45, 4.65, 4.35, 3.5, 4.8, 4.08, 1.7, 2.8, 1.4, 2.4, 3.45, 1.02, 4.3]
			_hull(enemy, outline, frame, 1.35)
			_hull(enemy, [0, -3.2, 1.2, -2.21, 1.32, 2.7, 0.66, 3.62], neutral, 1.67)
			for side in [-1, 1]:
				_panel(enemy, _points([side * 3.75, -2.65, side * 5.52, -1.03, side * 5.77, 0.95, side * 4.46, 1.2]), inset, 1.48)
				_bar(enemy, Vector2(side * 0.78, -1.02), Vector2(0.54, 1.35), core, 1.9)
	return enemy


static func _build_capsule(enemy: Node3D, variant: int) -> void:
	var magenta := variant == 1
	var rim := _finish(Color("#d55fd4") if magenta else Color("#b5d857"), 0.84)
	var shield := _finish(Color("#43b4c9") if magenta else Color("#d4b943"), 0.91)
	var gasket := _finish(Color("#212837"), 0.38)
	var sensor := _finish(Color("#ffdb76") if magenta else Color("#ff5a29"), 0.6, 0.86)
	var alloy := _finish(Color("#8897b0"), 0.83)

	# Bouclier large, bords biseautés et col de tuyère central.
	_hull(enemy, [0, -3.65, 2.25, -3.65, 3.22, -2.75, 3.55, -1.12, 3.38, 0.32, 2.83, 1.05, 1.25, 1.72, 0.91, 3.58, 0, 3.58], rim, 1.45)
	_hull(enemy, [0, -3.25, 2.03, -3.25, 2.87, -2.24, 3.02, -0.78, 2.51, 0.65, 1.2, 1.35, 0, 1.35], gasket, 1.72)
	_hull(enemy, [0, -3.03, 1.89, -3.03, 2.64, -1.98, 2.62, -0.84, 2.18, 0.42, 1.08, 0.96, 0, 0.96], shield, 2.03)
	_hull(enemy, [0, -1.09, 1.14, -0.85, 1.63, -0.08, 1.23, 0.48, 0, 0.54], gasket, 2.12)
	_hull(enemy, [0, -0.85, 0.83, -0.66, 1.28, 0.08, 0.92, 0.26, 0, 0.33], sensor, 2.20)
	_bar(enemy, Vector2(0, 2.06), Vector2(1.48, 1.91), alloy, 1.59)
	_bar(enemy, Vector2(0, 3.03), Vector2(1.25, 0.50), gasket, 1.68)

	var hot := Color("#98ffb6") if magenta else Color("#56eddd")
	var trail := Color("#cf43ee") if magenta else Color("#94e849")
	_add_exhaust(enemy, "Wake", 2.75, 2.05, 18.0, hot, trail).hide()


static func _finish(tint: Color, polish := 0.9, emission := 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Chrome
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"polish", polish)
	material.set_shader_parameter(&"emission", emission)
	return material


static func _thruster(ship: Node3D, start: float, width: float, length: float) -> void:
	_add_exhaust(ship, "Exhaust", start, width * 2.1, length * 1.8, Color("#fff3b8"), Color("#ff7d27"), true)


static func _add_exhaust(parent: Node3D, label: String, start: float, width: float, length: float,
		hot: Color, trail: Color, rocket := false) -> Node3D:
	var exhaust := Node3D.new()
	exhaust.name = label
	exhaust.position.z = start
	parent.add_child(exhaust)
	var material := ShaderMaterial.new()
	material.shader = ExhaustShader
	material.set_shader_parameter(&"hot", hot)
	material.set_shader_parameter(&"trail", trail)
	material.set_shader_parameter(&"rocket", rocket)
	var plane := PlaneMesh.new()
	plane.size = Vector2(width * 2.0, length)
	var plume := MeshInstance3D.new()
	plume.mesh = plane
	plume.material_override = material
	plume.position = Vector3(0, 0.78, length * 0.5)
	exhaust.add_child(plume)
	return exhaust


static func _points(values: Array) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for i in range(0, values.size(), 2):
		outline.append(Vector2(values[i], values[i + 1]))
	return outline


static func _half_disc(radius: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in range(7):
		outline.append(Vector2.from_angle(-PI + index * PI / 6.0) * radius - Vector2(0, 0.085))
	return outline


static func _hull(parent: Node3D, half: Array, material: Material, height: float) -> void:
	var outline := _points(half)
	for i in range(outline.size() - 1, 0, -1):
		if outline[i].x != 0.0:
			outline.append(Vector2(-outline[i].x, outline[i].y))
	_bevel(parent, outline, material, height, height * 0.72)


static func _bar(parent: Node3D, at: Vector2, size: Vector2, material: Material, height: float) -> void:
	var a := at - size / 2.0
	var b := at + size / 2.0
	_bevel(parent, _points([a.x, a.y, b.x, a.y, b.x, b.y, a.x, b.y]), material, height, 0.19)


static func _panel(parent: Node3D, outline: PackedVector2Array, material: Material, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bounds := _bounds(outline)
	for index in Geometry2D.triangulate_polygon(outline):
		_vertex(surface, outline[index], height, Vector3.UP, bounds)
	_commit(parent, surface, material)


static func _bevel(parent: Node3D, outline: PackedVector2Array, material: Material, height: float, depth: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_bevel(surface, outline, height, depth)
	_commit(parent, surface, material)


static func _add_bevel(surface: SurfaceTool, outline: PackedVector2Array, height: float, depth: float) -> void:
	var cap := PackedVector2Array()
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= outline.size()
	for point in outline:
		cap.append(point.lerp(center, 0.155))
	var bounds := _bounds(outline)
	for index in Geometry2D.triangulate_polygon(cap):
		_vertex(surface, cap[index], height, Vector3.UP, bounds)
	var winding := -1.0 if Geometry2D.is_polygon_clockwise(outline) else 1.0
	for i in range(outline.size()):
		var next := (i + 1) % outline.size()
		var edge := (outline[next] - outline[i]).normalized()
		var normal := Vector3(edge.y * winding, 0.73, -edge.x * winding).normalized()
		_vertex(surface, outline[i], height - depth, normal, bounds)
		_vertex(surface, cap[i], height, normal, bounds)
		_vertex(surface, outline[next], height - depth, normal, bounds)
		_vertex(surface, outline[next], height - depth, normal, bounds)
		_vertex(surface, cap[i], height, normal, bounds)
		_vertex(surface, cap[next], height, normal, bounds)


static func _bounds(outline: PackedVector2Array) -> Rect2:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	return bounds


static func _vertex(surface: SurfaceTool, at: Vector2, height: float, normal: Vector3, bounds: Rect2) -> void:
	surface.set_uv((at - bounds.position) / bounds.size)
	surface.set_normal(normal)
	surface.add_vertex(Vector3(at.x, height, at.y))


static func _commit(parent: Node3D, surface: SurfaceTool, material: Material) -> void:
	var item := MeshInstance3D.new()
	item.mesh = surface.commit()
	item.material_override = material
	parent.add_child(item)
