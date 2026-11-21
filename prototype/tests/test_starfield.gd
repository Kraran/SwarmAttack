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
	var right := Starfield.new()
	var right_120 := Starfield.new()
	for i in 120:
		right.steer(1.0, 1.0 / 60.0)
	for i in 240:
		right_120.steer(1.0, 1.0 / 120.0)
	_expect(right.drift() == Vector3i(Starfield.DRIFT_PIXELS), "Vaisseau à droite : décalage maximal, obtenu %s" % right.drift())
	_expect(right_120.drift() == right.drift(), "La parallaxe suit le temps, pas la fréquence")
	var left := Starfield.new()
	left.steer(-1.0, 0.1)
	_expect(left.drift().z < 0 and left.drift().z > -int(Starfield.DRIFT_PIXELS.z), "Vaisseau à gauche : décalage progressif dans l'autre sens, obtenu %s" % left.drift())
	_expect(absi(left.drift().x) <= absi(left.drift().z), "Le plan proche bouge plus que le plan lointain")
	for i in 300:
		left.steer(0.0, 1.0 / 60.0)
	_expect(left.drift() == Vector3i.ZERO, "Sans vaisseau, le décor revient au centre")
	for item in [at_60, at_120, at_144, half, wrap, right, right_120, left]:
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
