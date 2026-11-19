extends RefCounted

const CollisionGeometry = preload("res://collision_geometry.gd")

const SPAWN_FRAME := 32
const OPENING_LENGTH := 16
const WIDE_ENTRY_TURNS := 9
const WIDE_RETURN_WAIT := 16
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

enum Flight {
	OPENING, ENTRY_CURVE, FORMATION, DIVE, STRAIGHT_DIVE, RETURNING, CIRCLING, FALL_PAUSE, FALL, FALL_EXIT,
	ROW_PAUSE, ROW_ZIGZAG, ROW_DIVE, ROW_EXIT
}

# Vagues en rangée 0x0c et 0x0d (après le second amarrage ; pr7, pr8*, pr9*,
# pr10a-b, pr11*). Apparition à l'horloge 32 en y = 0, vitesse d'ouverture
# verticale propre à chaque objet (octet +8), 16 pas comptés par l'octet +4.
# Tous les objets avancent à chaque image de boucle.
const ROW_X := [32, 56, 80, 104, 136, 160, 184, 208]
const ROW_OPENING_VY := [2, 3, 2, 3, 3, 2, 3, 2]
const ROW_DIVE_STEP := Vector2i(0, 4)

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

	func has_visible_pose() -> bool:
		# Lors de la sortie, le compteur vertical peut déjà être revenu à 0
		# alors que l'objet occupe encore son créneau de vol.
		return alive and phase != Flight.FALL_EXIT and phase != Flight.ROW_EXIT

var enemies: Array[Enemy] = []
# Vague d'objets en chute (0x809b = 0x09 et 0x0a, numéros de vague 5 et 6).
var falling := false
var _next_pair := 0
# Vague en rangée (0x809b = 0x0c et 0x0d, numéros de vague 3 et 4 de l'étape 2).
var rows := false
var remaining: int
var points_per_hit: int
var wide_entry: bool
var _alive_mask: int
var _resumed := false
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
# Événements de vol : apparition et réapparition, sans modifier la simulation.
var flight_sound_serial := 0
var flight_sound_source: Enemy


func _init(wave_number := 1, alive_mask := 255, points := -1, at_stage := 0) -> void:
	stage = at_stage
	falling = wave_number >= 5
	rows = at_stage >= 2 and wave_number >= 3 and not falling
	wide_entry = wave_number >= 3 and not falling and not rows
	points_per_hit = points if points > 0 else (30 if wide_entry else 50)
	_alive_mask = alive_mask
	_resumed = alive_mask != 255
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


# Crédit d'un ennemi abattu (CombatRound, score_delay() images après l'impact).
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
	if rows and enemy.phase == Flight.ROW_DIVE:
		# L'impact est traité après le déplacement des huit objets : 0x823e
		# baisse à l'image où l'objet touché fait son dernier pas, et le
		# plongeur suivant part à l'image d'après (pr11c : k7 à 16956, k3
		# plonge à 16957 ; k1 à 17417, k2 plonge à 17418).
		divers -= 1
	if not wide_entry and not falling and not rows and not (index & 1):
		enemies[index + 1].separate_at = _wave_clock + 4


func survivors() -> int:
	return _alive_mask


func advance(_frame: int, ship_x: int) -> void:
	# Chaque pas logique compte ; les arrêts matériels de la borne sont exclus.
	_wave_clock += 1
	if falling:
		_advance_falling()
		return
	if rows:
		_advance_rows(ship_x + 16)
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
			if enemy.alive:
				flight_sound_source = enemy
				flight_sound_serial += 1
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


func hit_by(shot: Vector2i, previous_shot := Vector2.INF, previous_enemies: Dictionary = {}) -> Enemy:
	var selected := -1
	var first_time := INF
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not enemy.has_visible_pose():
			continue
		var from := Vector2(shot) if previous_shot == Vector2.INF else previous_shot
		var before := Vector2(previous_enemies.get(enemy, enemy.position))
		if not previous_enemies.has(enemy):
			# Une apparition n'a aucune trajectoire de collision antérieure.
			from = Vector2(shot)
		if not CollisionGeometry.continuous(before, Vector2(enemy.position)):
			before = Vector2(enemy.position)
			from = Vector2(shot)
		var start := from + Vector2(17, 4) - before
		var end := Vector2(shot + Vector2i(17, 4) - enemy.position)
		var time := CollisionGeometry.sweep_time(start, end, Rect2(0, 0, 16, 12))
		if is_inf(time):
			continue
		# Dans une superposition, le tir montant rencontre la cible du bas.
		if selected < 0 or time < first_time - CollisionGeometry.EPSILON or (
				absf(time - first_time) <= CollisionGeometry.EPSILON and enemy.position.y > enemies[selected].position.y):
			selected = index
			first_time = time
	if selected < 0:
		return null
	var hit := enemies[selected]
	kill(selected)
	return hit


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


# Conserver l'union des hitboxes, puis attribuer le contact à la coque
# la plus proche. La priorité systématique au III rendait le II intouchable
# dans le trio, sa boîte étant entièrement recouverte par celle du III.
func hit_module(ship_x: int, attached: int, y_offset := 0, previous_ship_x := -1, previous_enemies: Dictionary = {}) -> int:
	var hit := 0
	var nearest := INF
	var first_time := INF
	for module in range(3, 0, -1):
		if not (attached & (1 << (module - 1))):
			continue
		var offset := y_offset if attached == 3 else 0
		var bounds := module_contact_rect(0, module, attached, y_offset)
		for enemy in enemies:
			if not enemy.has_visible_pose():
				continue
			var before := Vector2(previous_enemies.get(enemy, enemy.position))
			var old_ship := ship_x if previous_ship_x < 0 else previous_ship_x
			if not CollisionGeometry.continuous(before, Vector2(enemy.position)) or absi(ship_x - old_ship) > CollisionGeometry.MAX_CONTINUOUS_STEP:
				before = Vector2(enemy.position)
				old_ship = ship_x
			var time := CollisionGeometry.sweep_time(before - Vector2(old_ship, 0),
				Vector2(enemy.position) - Vector2(ship_x, 0), Rect2(bounds))
			if is_inf(time):
				continue
			var contact_y := lerpf(before.y, enemy.position.y, time) + 8
			var distance := absf(contact_y - (200 + (module - 1) * 8 + offset))
			if time < first_time - CollisionGeometry.EPSILON or (absf(time - first_time) <= CollisionGeometry.EPSILON and distance < nearest):
				first_time = time
				nearest = distance
				hit = module
	return hit


static func module_contact_rect(ship_x: int, module: int, attached: int, y_offset := 0) -> Rect2i:
	var top := -3 if attached == 6 and module == 3 else (-11 if module == 3 else -3)
	if attached == 7 and module == 1:
		top = -2
	return _module_box(ship_x, module, top, y_offset if attached == 3 else 0)


static func shot_contact_rect(position: Vector2i) -> Rect2i:
	return Rect2i(position - Vector2i(17, 4), Vector2i(16, 12))


func _hits_module_box(ship_x: int, module: int, top: int, y_offset := 0) -> bool:
	var bounds := _module_box(ship_x, module, top, y_offset)
	for enemy in enemies:
		if enemy.has_visible_pose() and bounds.has_point(enemy.position):
			return true
	return false


static func _module_box(ship_x: int, module: int, top: int, y_offset: int) -> Rect2i:
	var raw_position := Vector2i(ship_x + 8, 192) if module == 1 else Vector2i(ship_x, 192 + (module - 1) * 8)
	raw_position.y += y_offset
	const LEFT_LIMITS := [-9, -5, -10]
	const RIGHT_LIMITS := [11, 23, 28]
	return Rect2i(raw_position + Vector2i(LEFT_LIMITS[module - 1], top),
		Vector2i(RIGHT_LIMITS[module - 1] - LEFT_LIMITS[module - 1] + 1, 13 - top))


func _advance_enemy(enemy: Enemy, ship: int) -> void:
	# Séparation du partenaire (vagues étroites, pr11c 18447-18451 et
	# 19739-19743) : au pas de la destruction il poursuit son mouvement ; au
	# pas suivant il passe en phase 3 avec la courbe (cap 1, sens selon
	# l'horloge, 30 virages, pas (1, 2)) ; au pas d'après il lance son piqué.
	if enemy.separate_at > 0 and _wave_clock >= enemy.separate_at:
		enemy.separate_at = 0
		_start_curve(enemy, 1, -1 if _wave_clock & 2 else 1, 30, 1, 2)
		# Au cycle 1 (0x823d = 1), le partenaire garde cette courbe en
		# formation (phase 2) tant que 0x823c vaut au moins 5 : pr12a 0x02
		# (598, 721, 902) et 0x03 (2648, 2672), y compris depuis l'ouverture.
		# Sous 5 (pr12a 3076, 3356) et au cycle 2 (0x823d = 2, pr11c 0x12 et
		# 0x13, même à 8 survivants), il passe en phase 3 et plonge au pas
		# suivant.
		if max_divers >= 2 or credited_remaining < 5:
			enemy.phase = Flight.DIVE
			enemy.turns_left = 0
		else:
			enemy.phase = Flight.FORMATION
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
			flight_sound_source = enemy
			flight_sound_serial += 1
			enemy.position = Vector2i((enemy.position.x & 63) + 80, (enemy.position.y & 63) + 64)
			enemy.return_wait = WIDE_RETURN_WAIT
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
				flight_sound_source = enemy
				flight_sound_serial += 1
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


func _advance_rows(ship: int) -> void:
	if _wave_clock == SPAWN_FRAME:
		for index in range(8):
			var enemy := Enemy.new()
			enemy.alive = bool(_alive_mask & (1 << index))
			enemy.position = Vector2i(ROW_X[index], 0)
			enemy.velocity = Vector2i(0, ROW_OPENING_VY[index])
			enemy.turn = 0
			enemies.append(enemy)
			if enemy.alive:
				flight_sound_source = enemy
				flight_sound_serial += 1
		return
	if enemies.is_empty():
		return
	for enemy in enemies:
		if not enemy.alive:
			continue
		match enemy.phase:
			Flight.OPENING:
				# 16 pas verticaux, phase 1 au dernier (pr11d k0 : y = 32 à 16710).
				_move(enemy)
				enemy.opening_left -= 1
				if enemy.opening_left == 0:
					enemy.phase = Flight.ROW_PAUSE
			Flight.ROW_PAUSE:
				# Phase 2 sans déplacement (16711), zigzag au pas suivant.
				enemy.phase = Flight.ROW_ZIGZAG
				enemy.turns_left = 0
			Flight.ROW_ZIGZAG:
				# Zigzags de 8 virages à la cadence 2, pas (2, 2), octet +0 = 0x60 :
				# caps 4 à 11 au sens +1, puis 26 à 19 au sens -1, en alternance.
				# Une courbe achevée (virages à 0, sans déplacement) ou une
				# réapparition enchaîne la courbe de sens opposé au pas suivant.
				if enemy.turns_left == 0:
					enemy.turn = -1 if enemy.turn > 0 else 1
					_start_curve(enemy, 4 if enemy.turn > 0 else 26, enemy.turn, 8, 2, 2, 0, false, 2)
				else:
					_step_curve(enemy)
				# Le premier objet en phase 2, dans l'ordre k0 à k7, plonge quand
				# 0x823e est sous 0x823d, après son pas normal et sans test de
				# sortie (pr11d k1 : piqué à y = 7, 17569).
				if divers < max_divers:
					divers += 1
					enemy.phase = Flight.ROW_DIVE
					if _formation_pattern != 0:
						# 0x8242 passe à 0 au premier piqué de la vague (horloge 50).
						_formation_pattern = 0
				else:
					_row_exit(enemy)
			Flight.ROW_DIVE:
				# Piqué vertical à +4 par image de boucle jusqu'à la sortie par le bas.
				enemy.velocity = ROW_DIVE_STEP
				_move(enemy)
				if _row_exit(enemy):
					divers -= 1
			Flight.ROW_EXIT:
				flight_sound_source = enemy
				flight_sound_serial += 1
				# Réapparition au pas suivant la sortie, y inchangé, en
				# x = 0x822b + (0x8227 & 63) - 32 (302 réapparitions sur pr7, pr8*,
				# pr9*, pr10a-b et pr11a-d, toutes conformes).
				enemy.position.x = (ship + (_wave_clock & 63) - 32) & 255
				enemy.phase = Flight.ROW_ZIGZAG
				enemy.turns_left = 0


func _row_exit(enemy: Enemy) -> bool:
	if enemy.position.y >= 8 and (enemy.position.x < 244 or enemy.position.x >= 252):
		return false
	enemy.phase = Flight.ROW_EXIT
	return true


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
					flight_sound_source = enemy
					flight_sound_serial += 1
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
	enemy.cadence = cadence
	_start_curve(enemy, 8 if turn > 0 else 22, turn, WIDE_ENTRY_TURNS, length.x, length.y, 0, false, cadence)


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
	# Vague large du cycle 1 (0x823d = 1) reprise après une perte de vie, avant le
	# premier amarrage : la cadence d'entrée (+6) n'est jamais remplacée, ni à la
	# boucle ni aux courbes suivantes (pr1-suite et pr13a, 0x05 reprise à 5882,
	# paires 1 à 3 en cadence 2 jusqu'à la fin de la vague). Partout ailleurs, la
	# boucle passe à 1, y compris en 0x14 reprise au cycle 2 (pr11c 21246).
	# Indépendant de la position du vaisseau : pr14a, vaisseau immobile à x = 108
	# pendant la reprise, garde aussi la cadence 2 (442 pas concordants). 0x04
	# reprise n'a pas été relevée ; elle suit la même règle par extension.
	if _resumed and wide_entry and stage == 0 and max_divers == 1:
		cadence = enemy.cadence
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
