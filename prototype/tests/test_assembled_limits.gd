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
	_check_i_ii_hitbox()
	_check_i_ii_iii_hitbox()
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


func _check_i_ii_hitbox() -> void:
	# pr6b-hitbox-i-ii, vaisseau I + II immobile à x = 114 (0x822b = 130,
	# 0x822c = 232). Coordonnées de la table d'objets (0x81e9, 0x81ea).
	var miss := _enemy_at(Vector2i(123, 231))
	_expect(not miss.hits_attached(114, 3, 16), "Frames 11492–11493 : (123, 231) ne touche pas le I + II")
	var hit := _enemy_at(Vector2i(120, 226))
	_expect(hit.hits_attached(114, 3, 16), "Frame 11494 : (120, 226) touche le I + II")
	# Sans le décalage de 16, le contact mesuré resterait hors des boîtes 192/200.
	_expect(not hit.hits_attached(114, 3, 0), "Sans offset, (120, 226) ne doit pas toucher les boîtes à y = 192/200")
	# pr7 : après l'expiration I + II → III, 0x822c = 216, offset 0.
	var low := _enemy_at(Vector2i(120, 210))
	_expect(low.hits_attached(114, 3, 0), "Après expiration, le I + II reprend les boîtes à y = 192/200")
	print("OK hitbox I + II : raté à (123, 231), contact à (120, 226), offset 16")


func _check_i_ii_iii_hitbox() -> void:
	# pr9-tir-i-ii-iii, I + II + III immobile à x = 110 (0x822b = 126,
	# 0x822c = 216). Table d'objets 0x81d5/0x81d6 (y, x). L'ennemi identifié
	# sur le nez du module I plonge de +4 par image, x = 116 constant.
	var miss := _enemy_at(Vector2i(116, 189))
	_expect(not miss.hits_attached(110, 7), "Frame 16925 : (116, 189) ne touche pas le I + II + III")
	var hit := _enemy_at(Vector2i(116, 193))
	_expect(hit.hits_attached(110, 7), "Frame 16926 : (116, 193) touche le nez du module I")
	# L'offset 16 ne s'applique qu'au I + II tant que 0x822c = 232.
	# II et III, trop bas, ne reçoivent pas ce contact.
	_expect(not hit.hits_attached(110, 6), "Le contact (116, 193) n'appartient pas au II + III")
	print("OK hitbox I + II + III : raté à (116, 189), contact à (116, 193), offset 0")
