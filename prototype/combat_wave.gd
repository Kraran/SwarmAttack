extends RefCounted

const SPAWN_FRAME := 32
const OPENING_LENGTH := 16
# The startup trace includes three board frames without a wave-clock increment.
const OPENING_CLOCK_HOLDS := [34, 118, 212]
const INITIAL_POSITIONS := [
	Vector2i(112, 96), Vector2i(120, 96), Vector2i(128, 96), Vector2i(120, 88)
]
const OPENING_STEPS := [Vector2i(-2, -2), Vector2i(0, -1), Vector2i(2, -2), Vector2i(0, -2)]

# Displacements for the 28 headings, in the board's 8-bit coordinate system.
const HEADINGS := [
	Vector2i(0, 3), Vector2i(-1, 4), Vector2i(-3, 5), Vector2i(-4, 4),
	Vector2i(-5, 3), Vector2i(-4, 1), Vector2i(-3, 0), Vector2i(-3, 0),
	Vector2i(-4, -1), Vector2i(-5, -3), Vector2i(-4, -4), Vector2i(-3, -5),
	Vector2i(-1, -4), Vector2i(0, -3), Vector2i(0, -3), Vector2i(1, -4),
	Vector2i(3, -5), Vector2i(4, -4), Vector2i(5, -3), Vector2i(4, -1),
	Vector2i(3, 0), Vector2i(3, 0), Vector2i(4, 1), Vector2i(5, 3),
	Vector2i(4, 4), Vector2i(3, 5), Vector2i(1, 4), Vector2i(0, 3)
]

enum Flight { OPENING, ENTRY_CURVE, FORMATION, DIVE, STRAIGHT_DIVE, RETURNING, CIRCLING, FALL_PAUSE, FALL, FALL_EXIT }

# Vagues 0x09 et 0x0a (pr7, 14132-14819) : huit objets lancés par paires, à
# position et vitesse fixes (octets +1, +2, +8, +9 de l'objet), dans l'ordre
# k3/k7, k2/k6, k1/k5, k0/k4. Une paire part au pas qui suit la résolution
# (sortie ou crédit) de la précédente : 0x823c passe à 6, 4, 2 aux images
# 14228, 14311, 14393, paires lancées à 14230, 14313, 14395.
const FALL_PAIRS := [[3, 7], [2, 6], [1, 5], [0, 4]]
const FALL_STARTS := [
	Vector2i(32, 48), Vector2i(176, 32), Vector2i(64, 32), Vector2i(144, 80),
	Vector2i(160, 96), Vector2i(80, 64), Vector2i(192, 112), Vector2i(80, 128)
]
const FALL_STEPS := [
	Vector2i(4, 6), Vector2i(-3, 6), Vector2i(3, 6), Vector2i(-4, 6),
	Vector2i(-3, 6), Vector2i(2, 4), Vector2i(-4, 5), Vector2i(4, 6)
]

class Enemy:
	var position: Vector2i
	var velocity: Vector2i
	var alive := true
	var phase := Flight.OPENING
	var opening_left := OPENING_LENGTH
	var heading := 1
	var turn := 1
	var turns_left := 0
	var steps_left := 0
	var straight_steps := 1
	var diagonal_steps := 1
	var acceleration := 0
	var reverse_turn := false
	var separate_at := 0
	var cadence := 1
	var cadence_left := 1
	var return_wait := 0
	# Courbe de retour (octet +0 = 0x22) : saut de virage comme les courbes
	# inversées, sans changement de sens, et pas +1 tous les 16 virages.
	var return_curve := false

	func display_position() -> Vector2:
		return Vector2(position.x - 8, position.y + 8)

var enemies: Array[Enemy] = []
# Vague d'objets en chute (0x809b = 0x09 et 0x0a, numéros de vague 5 et 6).
var falling := false
var _next_pair := 0
var remaining: int
var points_per_hit: int
var wide_entry: bool
var _alive_mask: int
# Étape du cycle (amarrages franchis) : choisit la variante d'entrée.
var stage := 0
var _wave_clock := 0
# Compteurs de motifs, rangés en RAM de 0x8242 (formation) à 0x8246 (piqués,
# quatre zones) puis 0x8247 (retour). Ils ne sont pas remis à zéro entre les
# vagues (pr7, pr11c) : ArcadeRun les transmet d'une vague à la suivante.
var _dive_patterns := [0, 0, 0, 0]
var _return_pattern := 0
var _formation_pattern := 0
# Plongeurs simultanés : 0x823e compte les ennemis en piqué (phase RAM 3) et
# 0x823d en fixe le maximum, 1 au cycle 1 et 2 au cycle 2 (pr11c, 0x809b = 0x11
# et suivants). Un ennemi en fin de formation part en piqué si la place est
# libre, sinon il enchaîne une courbe de formation.
var max_divers := 1
var divers := 0
# 0x823c : survivants, décrémenté au crédit des points.
var credited_remaining := 0


func _init(wave_number := 1, alive_mask := 255, points := -1, at_stage := 0) -> void:
	stage = at_stage
	falling = wave_number >= 5
	wide_entry = wave_number >= 3 and not falling
	points_per_hit = points if points > 0 else (30 if wide_entry else 50)
	_alive_mask = alive_mask
	remaining = 0
	for slot in range(8):
		if alive_mask & (1 << slot):
			remaining += 1
	credited_remaining = remaining


func patterns() -> Array:
	return [_formation_pattern] + _dive_patterns + [_return_pattern]


func load_patterns(values: Array) -> void:
	if values.size() != 6:
		return
	_formation_pattern = int(values[0])
	_dive_patterns = [int(values[1]), int(values[2]), int(values[3]), int(values[4])]
	_return_pattern = int(values[5])


# Crédit d'un ennemi abattu (CombatRound, SCORE_DELAY images après l'impact).
func credit_kill() -> void:
	credited_remaining -= 1


func kill(index: int) -> void:
	var enemy := enemies[index]
	if not enemy.alive:
		return
	enemy.alive = false
	remaining -= 1
	_alive_mask &= ~(1 << index)
	if wide_entry and enemy.phase == Flight.DIVE:
		divers -= 1
	if not wide_entry and not falling and not (index & 1):
		enemies[index + 1].separate_at = _wave_clock + 4


func survivors() -> int:
	return _alive_mask


func advance(frame: int, ship_x: int) -> void:
	if frame in OPENING_CLOCK_HOLDS:
		return
	_wave_clock += 1
	if falling:
		_advance_falling()
		return
	if _wave_clock == SPAWN_FRAME:
		for index in range(8):
			var enemy := Enemy.new()
			enemy.alive = bool(_alive_mask & (1 << index))
			if wide_entry:
				enemy.position = Vector2i(120, 128)
				enemy.phase = Flight.ENTRY_CURVE
				_start_entry(enemy, index)
			else:
				enemy.position = INITIAL_POSITIONS[index >> 1]
				enemy.velocity = OPENING_STEPS[index >> 1]
			enemies.append(enemy)
		return
	if enemies.is_empty() or remaining == 0:
		return
	if _wave_clock & 1:
		return
	for enemy in enemies:
		if enemy.alive:
			# Référence des piqués : 0x822b (x + 16). pr11c 20306 (x = 158, 0x822b =
			# 128 : zone proche) et pr7 11013 (x = 90, 0x822b = 130 : zone lointaine).
			_advance_enemy(enemy, ship_x + 16)


func hit_by(shot: Vector2i) -> Enemy:
	var bullet := shot + Vector2i(17, 4)
	if bullet.y < 12:
		return null
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not enemy.alive:
			continue
		var distance := bullet - enemy.position
		if distance.x >= 0 and distance.x < 16 and distance.y >= 0 and distance.y < 12:
			kill(index)
			return enemy
	return null


func hits_ship(ship_x: int, module := 1) -> bool:
	var top := -11 if module == 3 else -3
	return _hits_module_box(ship_x, module, top)


# Union des hitboxes des modules assemblés. Pour le vaisseau II + III, le module III
# contribue avec le même plafond que le II (dy >= -3), et non le plafond solo -11.
# Relevé pr3-hitbox, vaisseau immobile à x = 114 (0x822b = 130) : le sprite 7 à
# (141, 204) aux frames 8233–8234 (0x8004 = 0) est un raté ; à (140, 208) à 8235
# (0x8004 = 1) c'est un contact. La zone du module III seul est inchangée.
# I + II (pr6b-hitbox-i-ii) : après la réussite I + II, les boîtes I et II sont
# abaissées de 16 (y = 208 et 216, 0x822c = 232). Vaisseau immobile à x = 114 :
# l'ennemi à (123, 231) aux frames 11492–11493 (0x8004 = 0) est un raté ; à
# (120, 226) à 11494 (0x8004 = 1) c'est un contact, identifié visuellement sur
# le bas du module II (table d'objets 0x81e9–0x81ea). Après l'expiration
# I + II → III (pr7, 0x822c = 216), l'offset revient à 0 (y = 192 et 200).
func hits_attached(ship_x: int, attached: int, y_offset := 0) -> bool:
	return hit_module(ship_x, attached, y_offset) != 0


# Module touché, testé du III vers le I (0 si aucun contact). Relevé sur le
# I + II + III : ennemi à y = 193 ou 196 au contact (pr8c, pr9, pr10b), le
# module I est détruit (0x8140 = 0) ; à y = 209, 212 ou 218 (pr9b, pr10a,
# pr11a, pr11b), le module III l'est (0x814a = 0), alors que la boîte du II
# couvre aussi ces points. Un contact attribué au II n'a pas été relevé.
func hit_module(ship_x: int, attached: int, y_offset := 0) -> int:
	for module in range(3, 0, -1):
		if not (attached & (1 << (module - 1))):
			continue
		var top := -3 if attached == 6 and module == 3 else (-11 if module == 3 else -3)
		# pr9-tir-i-ii-iii, vaisseau I + II + III immobile à x = 110
		# (0x822b = 126, 0x822c = 216) : (116, 189) à 16925 est un raté,
		# (116, 193) à 16926 un contact sur le nez du module I. Le plafond
		# dy >= -3 du I, seul, compterait déjà 16925 ; on le resserre à -2.
		if attached == 7 and module == 1:
			top = -2
		if _hits_module_box(ship_x, module, top, y_offset if attached == 3 else 0):
			return module
	return 0


func _hits_module_box(ship_x: int, module: int, top: int, y_offset := 0) -> bool:
	var raw_position := Vector2i(ship_x + 8, 192) if module == 1 else Vector2i(ship_x, 192 + (module - 1) * 8)
	raw_position.y += y_offset
	const LEFT_LIMITS := [-9, -5, -10]
	const RIGHT_LIMITS := [11, 23, 28]
	for enemy in enemies:
		if not enemy.alive:
			continue
		var delta := enemy.position - raw_position
		if delta.x >= LEFT_LIMITS[module - 1] and delta.x <= RIGHT_LIMITS[module - 1] and delta.y >= top and delta.y <= 12:
			return true
	return false


func _advance_enemy(enemy: Enemy, ship: int) -> void:
	# Séparation du partenaire (vagues étroites, pr11c 18447-18451 et
	# 19739-19743) : au pas de la destruction il poursuit son mouvement ; au
	# pas suivant il passe en phase 3 avec la courbe (cap 1, sens selon
	# l'horloge, 30 virages, pas (1, 2)) ; au pas d'après il lance son piqué.
	if enemy.separate_at > 0 and _wave_clock >= enemy.separate_at:
		enemy.separate_at = 0
		_start_curve(enemy, 1, -1 if _wave_clock & 2 else 1, 30, 1, 2)
		enemy.phase = Flight.DIVE
		enemy.turns_left = 0
		return
	if enemy.phase == Flight.OPENING:
		_move(enemy)
		enemy.opening_left -= 1
		if enemy.opening_left == 0:
			enemy.phase = Flight.FORMATION
		return

	var phase := enemy.phase
	if phase == Flight.RETURNING and stage == 1:
		# Après le premier amarrage, l'ennemi sorti (phase RAM 4) reste un pas
		# sur place, réapparaît en ((x & 63) + 80, (y & 63) + 64) au pas
		# suivant, attend 16 pas immobile (octet +4 de l'objet, de 0x10 à 0),
		# passe en phase 1 au pas où le compteur s'annule, puis lance sa boucle.
		# Relevé sur 130 sorties (pr1-suite, pr2, pr3, pr5b, pr6, pr7, pr10c-d).
		if enemy.return_wait == 0:
			enemy.position = Vector2i((enemy.position.x & 63) + 80, (enemy.position.y & 63) + 64)
			enemy.return_wait = 16
			return
		enemy.return_wait -= 1
		if enemy.return_wait == 0:
			enemy.phase = Flight.CIRCLING
			enemy.turns_left = 0
		return
	if phase == Flight.STRAIGHT_DIVE:
		_move(enemy)
		_check_exit(enemy)
		return
	if enemy.turns_left == 0:
		match phase:
			Flight.FORMATION:
				if wide_entry:
					_start_wide_formation(enemy)
				else:
					_start_curve(enemy, 1, -1 if _wave_clock & 2 else 1, 30, 1, 2)
			Flight.DIVE:
				_start_dive(enemy, ship)
			Flight.RETURNING:
				enemy.position = Vector2i(120, 80)
				_return_pattern ^= 2
				if _return_pattern:
					_start_curve(enemy, 1, -enemy.turn, 47, 1, 1)
				else:
					_start_curve(enemy, 15, -enemy.turn, 31, 1, 1)
				# pr11c 0x14 (k6 20319-20403, k7 20333-20459) : virages 26 et 18
				# sautés, pas (1, 1) -> (2, 2) à 32 puis 16 virages restants.
				enemy.return_curve = true
			Flight.CIRCLING:
				# Octets +11 à +15 relevés à l'entrée en boucle (phase RAM 1) :
				# cap 15, 9 virages, sens conservé et pas (3, 3) avant le premier
				# amarrage (0x14, 0x15, démo) ; sens +1 et pas (1, 1) après (0x07, 0x08).
				if stage == 1:
					_start_curve(enemy, 15, 1, 9, 1, 1)
				else:
					_start_curve(enemy, 15, enemy.turn, 9, 3, 3)
	else:
		_step_curve(enemy)

	if (phase == Flight.ENTRY_CURVE or phase == Flight.RETURNING) and enemy.turns_left == 0:
		enemy.phase = Flight.CIRCLING
	if phase == Flight.CIRCLING and enemy.turns_left == 0:
		enemy.phase = Flight.FORMATION
	if phase != Flight.RETURNING and _check_exit(enemy):
		return
	# Moins de 5 survivants : piqué. Le compte est 0x823c, décrémenté au crédit
	# des points et non à l'impact (pr11c : crédits 18679 et 19994, passages
	# en phase 3 aux pas suivants 18681 et 19996).
	if not wide_entry and phase == Flight.FORMATION and credited_remaining < 5:
		enemy.phase = Flight.DIVE
		enemy.turns_left = 0


func _advance_falling() -> void:
	if _wave_clock == SPAWN_FRAME:
		for index in range(8):
			var enemy := Enemy.new()
			enemy.alive = false
			enemies.append(enemy)
	if enemies.is_empty() or remaining == 0 or _wave_clock & 1:
		return
	# Paire suivante quand les précédentes sont résolues (0x823c).
	var spawned: Array[int] = []
	if _next_pair < FALL_PAIRS.size():
		var later := 0
		for pair in range(_next_pair, FALL_PAIRS.size()):
			for index in FALL_PAIRS[pair]:
				if _alive_mask & (1 << index):
					later += 1
		if credited_remaining <= later:
			for index in FALL_PAIRS[_next_pair]:
				if _alive_mask & (1 << index):
					var enemy := enemies[index]
					enemy.alive = true
					enemy.position = FALL_STARTS[index]
					enemy.velocity = FALL_STEPS[index]
					enemy.phase = Flight.OPENING
					enemy.opening_left = OPENING_LENGTH
					spawned.append(index)
			_next_pair += 1
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not enemy.alive or index in spawned:
			continue
		match enemy.phase:
			Flight.OPENING:
				# 16 pas comptés par l'octet +4, puis phase 1 (pr7 k0, 14395-14427).
				_fall_move(enemy)
				enemy.opening_left -= 1
				if enemy.opening_left == 0 and enemy.phase == Flight.OPENING:
					enemy.phase = Flight.FALL_PAUSE
			Flight.FALL_PAUSE:
				# Phase 2 sans déplacement (14429).
				enemy.phase = Flight.FALL
			Flight.FALL:
				_fall_move(enemy)
			Flight.FALL_EXIT:
				# Retiré au pas suivant la sortie, 0x823c décrémenté sans points
				# (k7 : y = 0 à 14210, 0x823c de 8 à 7 à 14212).
				enemy.alive = false
				remaining -= 1
				credited_remaining -= 1
				_alive_mask &= ~(1 << index)


# Sortie par le bas : y dépasse 255, l'objet est posé à y = 0 (phase RAM 4).
func _fall_move(enemy: Enemy) -> void:
	var next := enemy.position + enemy.velocity
	if next.y >= 256:
		enemy.position = Vector2i(next.x & 255, 0)
		enemy.phase = Flight.FALL_EXIT
		return
	enemy.position = Vector2i(next.x & 255, next.y)


func _start_entry(enemy: Enemy, index: int) -> void:
	var turn := -1 if index & 1 else 1
	var pair := index >> 1
	const LENGTHS := [Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 4)]
	var length: Vector2i = LENGTHS[pair]
	var cadence := 4 if pair == 0 else 2
	if stage == 1:
		# 0x809b = 0x07 et 0x08 (pr7, pr5c, pr6, pr1-suite…) : paires 3 et 4 en
		# (3, 3) et (4, 4), cadence 1 (octets +14, +15 et +6 de l'objet).
		const LENGTHS_AFTER_FIRST_DOCK := [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]
		const CADENCES_AFTER_FIRST_DOCK := [4, 2, 1, 1]
		length = LENGTHS_AFTER_FIRST_DOCK[pair]
		cadence = CADENCES_AFTER_FIRST_DOCK[pair]
	_start_curve(enemy, 8 if turn > 0 else 22, turn, 9, length.x, length.y, 0, false, cadence)


func _start_wide_formation(enemy: Enemy) -> void:
	# pr11c 0x14 (images 20302-20306) et pr7 0x07 (11009-11013) : l'ennemi
	# passe en phase 3 sans bouger, puis lance son piqué au pas suivant.
	if divers < max_divers:
		divers += 1
		enemy.phase = Flight.DIVE
		enemy.turns_left = 0
		return
	_formation_pattern = (_formation_pattern + 6) & 6
	const STEPS := [Vector2i(2, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 2)]
	var length: Vector2i = STEPS[_formation_pattern >> 1]
	var turn := enemy.turn
	var heading := 8 if turn < 0 or _formation_pattern == 0 else 22
	_start_curve(enemy, heading, turn, 29, length.x, length.y)


func _check_exit(enemy: Enemy) -> bool:
	if enemy.position.y >= 8 and (enemy.position.x < 244 or enemy.position.x >= 252):
		return false
	if wide_entry and enemy.phase == Flight.DIVE:
		divers -= 1
	enemy.phase = Flight.RETURNING
	enemy.turns_left = 0
	enemy.return_wait = 0
	return true


func _start_dive(enemy: Enemy, ship: int) -> void:
	var x := enemy.position.x
	var y := enemy.position.y
	var turn := -enemy.turn
	var heading := 22 if turn > 0 else 8
	if x < ship - 32 or x >= ship + 32:
		var pattern := _next_dive_pattern(0, 14)
		const DURATIONS := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(4, 2),
			Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 4), Vector2i(2, 6)]
		var pace: Vector2i = DURATIONS[pattern >> 1]
		var acceleration := 1 if (pattern & 4) == 0 else -1
		_start_curve(enemy, heading, turn, 15, pace.x, pace.y, acceleration)
		return
	var region := 1
	var mask := 14
	if y >= 96 and y < 160:
		region = 2 if y < 128 else 3
		mask = 2
	var pattern := _next_dive_pattern(region, mask)
	if region == 3:
		# 96 <= y < 160 découpé : la bande 128-159 donne 63 virages au pas
		# (4, 4) sans accélération, avec le saut de virage des courbes
		# inversées (pr7 11087, pr11b 29869, pr11c 20051 ; octet +0 = 0x03).
		_start_curve(enemy, heading, turn, 63, 4, 4, 0, true)
		return
	if pattern < 4:
		_start_curve(enemy, heading, turn, 31, 4, 4, -1)
	else:
		_start_curve(enemy, heading, turn, 127, pattern >> 2, 1, 0, true)


func _next_dive_pattern(region: int, mask: int) -> int:
	var value: int = (_dive_patterns[region] + 6) & mask
	_dive_patterns[region] = value
	return value


func _start_curve(
		enemy: Enemy, heading: int, turn: int, turns: int, straight: int, diagonal: int,
		acceleration := 0, reverse_turn := false, cadence := 1
) -> void:
	enemy.heading = heading
	enemy.turn = turn
	enemy.turns_left = turns
	enemy.straight_steps = straight
	enemy.diagonal_steps = diagonal
	enemy.acceleration = acceleration
	enemy.reverse_turn = reverse_turn
	enemy.return_curve = false
	enemy.cadence = cadence
	enemy.cadence_left = cadence
	_change_heading(enemy)
	_move(enemy)


func _step_curve(enemy: Enemy) -> void:
	enemy.cadence_left -= 1
	if enemy.cadence_left > 0:
		return
	enemy.cadence_left = enemy.cadence
	enemy.steps_left -= 1
	if enemy.steps_left == 0:
		enemy.turns_left -= 1
		if enemy.turns_left == 0:
			return
		if (enemy.reverse_turn or enemy.return_curve) and (enemy.turns_left & 7) == 2:
			enemy.turns_left -= 1
		enemy.heading = posmod(enemy.heading + enemy.turn - 1, HEADINGS.size()) + 1
		if enemy.reverse_turn and (enemy.turns_left & 15) == 0:
			enemy.turn = -enemy.turn
		if enemy.return_curve and (enemy.turns_left & 15) == 0:
			enemy.straight_steps += 1
			enemy.diagonal_steps += 1
		if (enemy.turns_left & 7) == 0:
			enemy.straight_steps = maxi(1, enemy.straight_steps + enemy.acceleration)
			enemy.diagonal_steps = maxi(1, enemy.diagonal_steps + enemy.acceleration)
		_change_heading(enemy)
	_move(enemy)


func _change_heading(enemy: Enemy) -> void:
	enemy.velocity = HEADINGS[enemy.heading - 1]
	var straight := enemy.heading < 4 or (enemy.heading >= 11 and enemy.heading < 18) or enemy.heading >= 25
	enemy.steps_left = enemy.straight_steps if straight else enemy.diagonal_steps


func _move(enemy: Enemy) -> void:
	var next := enemy.position + enemy.velocity
	enemy.position = Vector2i(next.x & 255, next.y & 255)
