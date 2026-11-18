extends RefCounted

const CombatWave = preload("res://combat_wave.gd")

# Familles visuelles des vagues. Les banques 1 et 2 partagent des
# trajectoires à entrée large mais ont des silhouettes différentes.
enum EnemyKind { RING, INTERCEPTOR, CLAW, METEOR, ROW }
const WAVES_PER_CYCLE := 10
const METEOR_DIAMETERS := [4.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 16.0]
const RING_DIAMETERS := [3.0, 4.0, 6.0, 10.0, 12.0, 14.0, 16.0, 16.0]
const CAPSULE_SCALES := [0.28, 0.38, 0.49, 0.59, 0.70, 0.81, 0.92, 1.0]


static func cycle_wave(wave_number: int, completed_docks: int) -> int:
	return wave_number + [0, 2, 6][completed_docks]


static func enemy_kind(wave: int) -> EnemyKind:
	if wave <= 2:
		return EnemyKind.RING
	if wave <= 4:
		return EnemyKind.CLAW
	if wave <= 6:
		return EnemyKind.INTERCEPTOR
	if wave <= 8:
		return EnemyKind.METEOR
	return EnemyKind.ROW


static func meteor_scale(opening_left: int) -> float:
	# 0x6f vers 0x68, deux pas de chute par taille (pr7, 14164–14196).
	var tier := clampi((16 - opening_left) >> 1, 0, 7)
	return METEOR_DIAMETERS[tier] / METEOR_DIAMETERS[-1]


static func ring_scale(opening_left: int) -> float:
	# Tailles relatives des demi-sprites 0x2f à 0x28 (pr12a, 571–604).
	var tier := clampi((16 - opening_left) >> 1, 0, 7)
	return RING_DIAMETERS[tier] / RING_DIAMETERS[-1]


static func ring_axis(heading: Vector2, opening_left: int) -> Vector2:
	# Les deux sprites de la paire gardent la même orientation pendant
	# le grossissement d'entrée, indépendamment de la direction de vol.
	return Vector2.DOWN if opening_left > 0 or heading.is_zero_approx() else heading.normalized()


static func capsule_scale(opening_left: int) -> float:
	var tier := clampi((16 - opening_left) >> 1, 0, 7)
	return CAPSULE_SCALES[tier]


static func interceptor_reveal(enemy: CombatWave.Enemy) -> float:
	# Les sprites 0x2f à 0x28 précèdent la coque pleine (pr5b, vague 0x07).
	if enemy.phase == CombatWave.Flight.ENTRY_CURVE:
		return float(CombatWave.WIDE_ENTRY_TURNS - enemy.turns_left) / (CombatWave.WIDE_ENTRY_TURNS - 1)
	if enemy.phase == CombatWave.Flight.RETURNING and enemy.return_wait > 0:
		return 1.0 - float(enemy.return_wait) / CombatWave.WIDE_RETURN_WAIT
	return 1.0


static func docking_module_origin(module: int, target_y: float, x := 112) -> Vector2:
	return Vector2(x, target_y + (0 if module == 3 else 8))


static func docked_module_origin(module: int, target: int, target_y: int, x := 112) -> Vector2:
	if target == 2:
		return Vector2(x, target_y if module == 1 else target_y + 8)
	return Vector2(x, target_y + (module - 3) * 8)
