extends SceneTree

const Pilot = preload("res://pilot.gd")
const CombatWave = preload("res://combat_wave.gd")

var failures := 0


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _initialize() -> void:
	_check_assembled_limits()
	_check_assembled_hitbox()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("ASSEMBLED LIMITS OK")
		quit(0)


func _assembled(start_x: int) -> Pilot:
	return Pilot.new(2, start_x, 6)


func _check_assembled_limits() -> void:
	var right := _assembled(196)
	for index in range(8):
		right.step(Pilot.RIGHT)
	_expect(right.ship_x == Pilot.MAX_X, "La butée droite du II + III est x = 200, obtenu %d" % right.ship_x)
	right.step(Pilot.RIGHT)
	_expect(right.ship_x == Pilot.MAX_X, "La butée droite tient tant que la droite reste enfoncée")
	var left := _assembled(18)
	for index in range(8):
		left.step(Pilot.LEFT)
	_expect(left.ship_x == Pilot.MIN_X, "La butée gauche du II + III est x = 14, obtenu %d" % left.ship_x)
	left.step(Pilot.LEFT)
	_expect(left.ship_x == Pilot.MIN_X, "La butée gauche tient tant que la gauche reste enfoncée")
	print("OK butées II + III : x = 14 et x = 200")


func _enemy_at(position: Vector2i) -> CombatWave:
	var wave := CombatWave.new(3)
	var enemy := CombatWave.Enemy.new()
	enemy.alive = true
	enemy.position = position
	wave.enemies.append(enemy)
	return wave


func _check_assembled_hitbox() -> void:
	# pr3-hitbox, vaisseau immobile à x = 114. Coordonnées brutes du sprite 7.
	var miss := _enemy_at(Vector2i(141, 204))
	_expect(not miss.hits_attached(114, 6), "Frames 8233–8234 : (141, 204) ne touche pas le II + III")
	var hit := _enemy_at(Vector2i(140, 208))
	_expect(hit.hits_attached(114, 6), "Frame 8235 : (140, 208) touche le II + III")
	# Le plafond solo du module III (dy >= -11) n'est pas celui de l'assemblage.
	var early := _enemy_at(Vector2i(141, 198))
	_expect(early.hits_ship(114, 3), "Le module III seul conserve son plafond à dy = -11")
	_expect(not early.hits_attached(114, 6), "L'assemblage ne reprend pas le plafond solo du III")
	print("OK hitbox II + III : raté à (141, 204), contact à (140, 208)")
