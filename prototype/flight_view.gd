extends SubViewport

const Models = preload("res://flight_models.gd")
const Presentation = preload("res://flight_presentation.gd")
const X_SCALE := 192.0 / 224.0
const ENEMY_POOL_SIZE := 8

var _ships: Array[Node3D] = []
var _enemy_pools: Dictionary[Vector2i, Array] = {}
var _enemies: Array[Node3D] = []
var _enemy_count := 0
var _enemy_style := Vector2i(-1, -1)
var _ship_mask := 0


func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	# Le champ occupe 756 × 1008 pixels dans la composition Full HD.
	size = Vector2i(756, 1008)
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_add_camera(self)

	for module in range(1, 4):
		var model := Models.build_ship(module)
		add_child(model)
		_ships.append(model)

	# Préparer les maillages et partager leurs ressources entre instances
	# avant l'affichage, pour éviter leur création au changement de vague.
	for wave in range(1, Presentation.WAVES_PER_CYCLE + 1):
		var style := Vector2i(Presentation.enemy_kind(wave), (wave - 1) % 2)
		var template := Models.build_enemy(style.x, style.y)
		var pool: Array[Node3D] = [template]
		for index in range(1, ENEMY_POOL_SIZE):
			pool.append(template.duplicate() as Node3D)
		for enemy in pool:
			enemy.hide()
			add_child(enemy)
		_enemy_pools[style] = pool


func _add_camera(viewport: SubViewport) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 256.0
	camera.position = Vector3(0, 340, 0)
	camera.rotation.x = -PI / 2
	camera.far = 410.0
	viewport.add_child(camera)
	camera.make_current()


func start_frame() -> void:
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
	if thrust:
		exhaust.scale.z = 0.86 + 0.14 * sin(frame * 0.26)
		var plume := exhaust.get_child(0) as MeshInstance3D
		(plume.material_override as ShaderMaterial).set_shader_parameter(&"frame", fposmod(frame, 12000.0))


func enemy(point: Vector2, kind: int, variant: int, heading: Vector2, frame: float, growth := 1.0, diving := false, slot := 0) -> void:
	var style := Vector2i(kind, variant)
	if _enemy_style != style:
		for item in _enemies:
			item.hide()
		_enemies = _enemy_pools[style]
		_enemy_count = 0
		_enemy_style = style
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
		if diving:
			var plume := wake.get_child(0) as MeshInstance3D
			(plume.material_override as ShaderMaterial).set_shader_parameter(&"frame", fposmod(frame, 12000.0))
	model.rotation.x = pitch
	model.rotation.y = orientation
	var flies_level := kind == Presentation.EnemyKind.RING or kind == Presentation.EnemyKind.ROW
	model.rotation.z = 0.0 if flies_level else 0.13


func _place(model: Node3D, point: Vector2) -> void:
	model.position = Vector3((point.x - 112) * X_SCALE, 0, point.y - 128)
	model.show()
