extends SubViewport

const Models = preload("res://flight_models.gd")
const Presentation = preload("res://flight_presentation.gd")
const SpaceShader = preload("res://space.gdshader")
const ScrollShader = preload("res://space_scroll.gdshader")
const X_SCALE := 192.0 / 224.0

var _ships: Array[Node3D] = []
var _enemies: Array[Node3D] = []
var _enemy_count := 0
var _enemy_style := Vector2i(-1, -1)
var _ship_mask := 0
var _backdrop_material := ShaderMaterial.new()


func _ready() -> void:
	own_world_3d = true
	# Le champ occupe 756 × 1008 pixels dans la composition Full HD.
	size = Vector2i(756, 1008)
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_add_camera(self)

	# Calcule le champ périodique d'étoiles une seule fois. En jeu,
	# un échantillonnage bilinéaire suffit pour le défilement sous-pixel.
	var sky := SubViewport.new()
	sky.own_world_3d = true
	sky.size = size
	sky.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sky)
	_add_camera(sky)
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SpaceShader
	_add_backdrop(sky, sky_material)

	_backdrop_material.shader = ScrollShader
	_backdrop_material.set_shader_parameter(&"star_map", sky.get_texture())
	_add_backdrop(self, _backdrop_material)

	for module in range(1, 4):
		var model := Models.build_ship(module)
		add_child(model)
		_ships.append(model)


func _add_camera(viewport: SubViewport) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 256.0
	camera.position = Vector3(0, 340, 0)
	camera.rotation.x = -PI / 2
	camera.far = 410.0
	viewport.add_child(camera)
	camera.make_current()


func _add_backdrop(viewport: SubViewport, material: Material) -> void:
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(192, 256)
	backdrop.mesh = plane
	backdrop.position.y = -12.0
	backdrop.material_override = material
	viewport.add_child(backdrop)


func start_frame(star_frame: float) -> void:
	# Le fond décale verticalement les étoiles de 5 pixels
	# logiques en 10 images, y compris en démo et pendant l'amarrage.
	_backdrop_material.set_shader_parameter(&"vertical_scroll", fposmod(star_frame, 512.0) / 512.0)
	_ship_mask = 0
	_enemy_count = 0


func finish_frame() -> void:
	for index in range(_ships.size()):
		if not (_ship_mask & (1 << index)):
			_ships[index].hide()
	for index in range(_enemy_count, _enemies.size()):
		_enemies[index].hide()
	render_target_update_mode = SubViewport.UPDATE_ONCE


func ship(point: Vector2, module: int, bank: float, thrust: bool, frame: float) -> void:
	var model := _ships[module - 1]
	_ship_mask |= 1 << (module - 1)
	_place(model, point)
	model.rotation.z = deg_to_rad(bank)
	var exhaust := model.get_node(^"Exhaust") as Node3D
	exhaust.visible = thrust
	exhaust.scale.z = 0.87 + 0.13 * sin(frame * 2.39)


func enemy(point: Vector2, kind: int, variant: int, heading: Vector2, frame: float, growth := 1.0, diving := false, slot := 0) -> void:
	var style := Vector2i(kind, variant)
	if _enemy_style != style:
		for item in _enemies:
			item.hide()
			item.queue_free()
		_enemies.clear()
		_enemy_count = 0
		_enemy_style = style
	if _enemy_count == _enemies.size():
		var new_model := Models.build_enemy(kind, variant) if _enemies.is_empty() else _enemies[0].duplicate() as Node3D
		add_child(new_model)
		_enemies.append(new_model)
	var model := _enemies[_enemy_count]
	_enemy_count += 1
	_place(model, point)
	model.scale = Vector3.ONE * growth
	if kind == Presentation.EnemyKind.METEOR:
		var spin := frame * 0.036 + slot * 1.67
		model.rotation = Vector3(0.43 + sin(spin * 0.67) * 0.52, spin, 0.32 * cos(spin * 0.83))
		return
	var orientation := -atan2(heading.x, -heading.y) if heading != Vector2.ZERO else PI
	var pitch := 0.0
	if kind == Presentation.EnemyKind.RING:
		pitch = absf(sin(orientation)) * 0.87
		var half := model.get_node(^"Half") as Node3D
		half.rotation.y = PI * (slot & 1)
	elif kind == Presentation.EnemyKind.INTERCEPTOR:
		pitch = sin(orientation) * 0.6
	elif kind == Presentation.EnemyKind.ROW:
		orientation = 0.0
		var wake := model.get_node(^"Wake") as Node3D
		wake.visible = diving
		wake.scale.z = 0.85 + 0.15 * sin(frame * 1.9)
	model.rotation.x = pitch
	model.rotation.y = orientation
	var flies_level := kind == Presentation.EnemyKind.RING or kind == Presentation.EnemyKind.ROW
	model.rotation.z = 0.0 if flies_level else 0.13


func _place(model: Node3D, point: Vector2) -> void:
	model.position = Vector3((point.x - 112) * X_SCALE, 0, point.y - 128)
	model.show()
