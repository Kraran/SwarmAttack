extends ColorRect

const Scroll = preload("res://space_scroll.gdshader")
const TILE_EDGE := 2048
# Vitesse des trois plans en pixels par image à 60 Hz, la référence d'origine.
# Le défilement suit le temps écoulé : même vitesse à 60, 120 ou 144 Hz.
const PIXELS_PER_FRAME := Vector3i(1, 2, 3)
const REFERENCE_HZ := 60.0
const STAR_COUNTS := Vector3i(740, 470, 170)
# Rayons des étoiles par plan, en pixels, avec la part de chaque taille :
# le plan lointain reste fin, le plus proche compte quelques grosses étoiles.
const STAR_SIZES := [
	[[0.6, 0.4], [1.0, 0.6]],
	[[1.0, 0.4], [1.5, 0.6]],
	[[1.5, 0.5], [2.0, 0.35], [2.8, 0.15]],
]
# Parallaxe horizontale : décalage maximal de chaque plan quand le vaisseau
# atteint un bord, et vitesse à laquelle le décor rattrape sa position.
const DRIFT_PIXELS := Vector3(14.0, 30.0, 52.0)
const DRIFT_RATE := 3.0
# Part de chaque couleur : bleu, blanc, jaune, rouge orangé.
const HUE_SHARES := [0.22, 0.33, 0.27, 0.18]

var _offsets := Vector3i.ZERO
var _position := Vector3.ZERO
var _drift := Vector3.ZERO
var _drift_pixels := Vector3i.ZERO
var _scroll_material := ShaderMaterial.new()


func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_material.shader = Scroll
	_scroll_material.set_shader_parameter(&"star_map", _build_star_map())
	material = _scroll_material


func advance(seconds: float) -> void:
	_position += Vector3(PIXELS_PER_FRAME) * REFERENCE_HZ * seconds
	_position = Vector3(fposmod(_position.x, TILE_EDGE), fposmod(_position.y, TILE_EDGE), fposmod(_position.z, TILE_EDGE))
	# Positions entières : les étoiles restent nettes, sans demi-pixel.
	var offsets := Vector3i(_position.floor())
	if offsets != _offsets:
		_offsets = offsets
		_scroll_material.set_shader_parameter(&"scroll_pixels", _offsets)


# target va de -1 (vaisseau à gauche) à 1 (à droite) ; les étoiles glissent
# alors en sens inverse, davantage pour les plans proches.
func steer(target: float, seconds: float) -> void:
	var goal := DRIFT_PIXELS * clampf(target, -1.0, 1.0)
	_drift += (goal - _drift) * (1.0 - exp(-DRIFT_RATE * seconds))
	var pixels := Vector3i(_drift.round())
	if pixels != _drift_pixels:
		_drift_pixels = pixels
		_scroll_material.set_shader_parameter(&"drift_pixels", _drift_pixels)


func offsets() -> Vector3i:
	return _offsets


func drift() -> Vector3i:
	return _drift_pixels


func _build_star_map() -> ImageTexture:
	# Les canaux rouge, vert et bleu stockent chacun un plan indépendant.
	# Deux bits donnent la couleur de l'étoile et six son intensité.
	var pixels := PackedByteArray()
	pixels.resize(TILE_EDGE * TILE_EDGE * 3)
	var random := RandomNumberGenerator.new()
	random.seed = 104729
	for layer in range(3):
		for index in range(STAR_COUNTS[layer]):
			var center := Vector2i(random.randi_range(0, TILE_EDGE - 1), random.randi_range(0, TILE_EDGE - 1))
			var hue := _pick_hue(random.randf()) << 6
			var level := random.randi_range(10, 27) + layer * 16
			var radius := _pick_radius(STAR_SIZES[layer], random.randf())
			if radius >= 2.0:
				level = mini(63, level + 6)
			_stamp_star(pixels, center, radius, layer, hue, level)
	var image := Image.create_from_data(TILE_EDGE, TILE_EDGE, false, Image.FORMAT_RGB8, pixels)
	return ImageTexture.create_from_image(image)


func _pick_hue(roll: float) -> int:
	for index in HUE_SHARES.size():
		roll -= HUE_SHARES[index]
		if roll < 0.0:
			return index
	return HUE_SHARES.size() - 1


func _pick_radius(sizes: Array, roll: float) -> float:
	for size: Array in sizes:
		roll -= size[1]
		if roll < 0.0:
			return size[0]
	return sizes[-1][0]


# Un disque plein dont le bord s'adoucit sur un pixel.
func _stamp_star(pixels: PackedByteArray, center: Vector2i, radius: float, layer: int, hue: int, level: int) -> void:
	var reach := ceili(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var falloff := clampf(radius + 0.5 - Vector2(x, y).length(), 0.0, 1.0)
			var value := int(level * falloff + 0.5)
			if value > 0:
				_stamp(pixels, center + Vector2i(x, y), layer, hue, value)


func _stamp(pixels: PackedByteArray, point: Vector2i, layer: int, hue: int, level: int) -> void:
	var wrapped := Vector2i(posmod(point.x, TILE_EDGE), posmod(point.y, TILE_EDGE))
	var offset := (wrapped.y * TILE_EDGE + wrapped.x) * 3 + layer
	if level > (pixels[offset] & 63):
		pixels[offset] = hue | level
