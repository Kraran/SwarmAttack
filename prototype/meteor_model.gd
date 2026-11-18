extends RefCounted

const Stone = preload("res://meteor.gdshader")
const LONGITUDES := 24
const LATITUDES := 14
# Normales radialement orientées et rayons angulaires des cratères.
const CRATERS := [
	Vector4(-0.29, 0.93, -0.22, 0.42),
	Vector4(0.73, 0.57, 0.37, 0.31),
	Vector4(-0.69, -0.18, 0.70, 0.38),
	Vector4(0.37, -0.86, 0.36, 0.42),
	Vector4(0.12, 0.16, -0.98, 0.28),
]


static func build(variant: int) -> MeshInstance3D:
	var phase := 0.65 + variant * 2.7
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	for latitude in range(LATITUDES + 1):
		var polar := PI * latitude / LATITUDES
		for longitude in range(LONGITUDES):
			var meridian := TAU * longitude / LONGITUDES
			var radial := Vector3(sin(polar) * cos(meridian), cos(polar), sin(polar) * sin(meridian))
			var point := _shell(radial, phase)
			var reference := Vector3.RIGHT if absf(radial.y) > 0.94 else Vector3.UP
			var tangent := reference.cross(radial).normalized()
			var across := radial.cross(tangent)
			positions.append(point)
			var east := _shell((radial + 0.024 * tangent).normalized(), phase) - point
			var north := _shell((radial + 0.024 * across).normalized(), phase) - point
			normals.append(east.cross(north).normalized())

	var indices := PackedInt32Array()
	for latitude in range(LATITUDES):
		var row := latitude * LONGITUDES
		for longitude in range(LONGITUDES):
			var a := row + longitude
			var b := row + (longitude + 1) % LONGITUDES
			var c := a + LONGITUDES
			var d := b + LONGITUDES
			if latitude > 0:
				indices.append_array([a, c, b])
			if latitude + 1 < LATITUDES:
				indices.append_array([b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = Stone
	material.set_shader_parameter(&"minerals", Color("#9271ad") if variant == 0 else Color("#989954"))
	material.set_shader_parameter(&"veins", Color("#86c573") if variant == 0 else Color("#7f9bd2"))
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = material
	return model


static func _shell(direction: Vector3, phase: float) -> Vector3:
	# Grandes cassures asymétriques et relief plus fin sur la surface.
	var deformation := 1.0 + sin(direction.dot(Vector3(3.5, 4.4, 2.8)) + phase) * 0.14
	deformation += cos(direction.dot(Vector3(-6.1, 2.2, 5.2)) - phase) * 0.09
	deformation += sin(direction.dot(Vector3(8.7, 5.4, -7.8)) + 0.2 * phase) * 0.038
	for crater: Vector4 in CRATERS:
		var center := Vector3(crater.x, crater.y, crater.z)
		var distance := direction.distance_to(center) / crater.w
		var bowl := 1.0 - smoothstep(0.3, 0.94, distance)
		var raised_rim := smoothstep(0.65, 0.95, distance) * (1.0 - smoothstep(0.97, 1.28, distance))
		deformation += raised_rim * 0.038 - bowl * 0.21
	return direction * Vector3(6.15, 5.05, 7.2) * deformation
