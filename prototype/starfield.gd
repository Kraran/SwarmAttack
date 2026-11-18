extends ColorRect

const Scroll = preload("res://space_scroll.gdshader")
const TILE_EDGE := 2048
const PIXELS_PER_FRAME := Vector3i(1, 2, 3)
const STAR_COUNTS := Vector3i(740, 470, 170)

var _offsets := Vector3i.ZERO
var _scroll_material := ShaderMaterial.new()


func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_material.shader = Scroll
	_scroll_material.set_shader_parameter(&"star_map", _build_star_map())
	material = _scroll_material


func advance() -> void:
	_offsets = (_offsets + PIXELS_PER_FRAME) % TILE_EDGE
	_scroll_material.set_shader_parameter(&"scroll_pixels", _offsets)


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
			var hue := random.randi_range(0, 3) << 6
			var level := random.randi_range(10, 27) + layer * 16
			if layer > 0:
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					_stamp(pixels, center + direction, layer, hue, level / (4 if layer == 1 else 3))
			_stamp(pixels, center, layer, hue, level)
	var image := Image.create_from_data(TILE_EDGE, TILE_EDGE, false, Image.FORMAT_RGB8, pixels)
	return ImageTexture.create_from_image(image)


func _stamp(pixels: PackedByteArray, point: Vector2i, layer: int, hue: int, level: int) -> void:
	var wrapped := Vector2i(posmod(point.x, TILE_EDGE), posmod(point.y, TILE_EDGE))
	var offset := (wrapped.y * TILE_EDGE + wrapped.x) * 3 + layer
	if level > (pixels[offset] & 63):
		pixels[offset] = hue | level
