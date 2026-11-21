extends SceneTree

# Le défilement du fond étoilé ne dépend pas de la fréquence d'affichage.
const Starfield = preload("res://starfield.gd")
var failures := 0

func _initialize() -> void:
	var at_60 := Starfield.new()
	var at_120 := Starfield.new()
	var at_144 := Starfield.new()
	for i in 60:
		at_60.advance(1.0 / 60.0)
	for i in 120:
		at_120.advance(1.0 / 120.0)
	for i in 144:
		at_144.advance(1.0 / 144.0)
	var expected := Starfield.PIXELS_PER_FRAME * 60
	_expect(at_60.offsets() == expected, "60 Hz : une seconde = 60 images de référence, obtenu %s" % at_60.offsets())
	_expect(_close(at_120.offsets(), expected), "120 Hz : même vitesse qu'à 60 Hz, obtenu %s" % at_120.offsets())
	_expect(_close(at_144.offsets(), expected), "144 Hz : même vitesse qu'à 60 Hz, obtenu %s" % at_144.offsets())
	var half := Starfield.new()
	half.advance(1.0 / 120.0)
	_expect(half.offsets() == Vector3i(0, 1, 1), "Une image à 120 Hz avance d'un demi-pas, arrondi au pixel")
	var wrap := Starfield.new()
	wrap.advance(Starfield.TILE_EDGE / 60.0)
	_expect(wrap.offsets().x == 0, "Le défilement boucle sur la tuile")
	for item in [at_60, at_120, at_144, half, wrap]:
		item.free()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("STARFIELD OK")
		quit(0)

func _close(value: Vector3i, expected: Vector3i) -> bool:
	return absi(value.x - expected.x) <= 1 and absi(value.y - expected.y) <= 1 and absi(value.z - expected.z) <= 1

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
