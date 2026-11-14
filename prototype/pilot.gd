extends RefCounted

const LEFT := 1
const RIGHT := 2
const FIRE := 4
const FRAME_USEC := 16_500
const FIELD_SIZE := Vector2i(224, 256)
const START_X := 112
const MIN_X := 14
const MAX_X := 200
# Vaisseau II + III : butées confirmées sur pr3-hitbox, tenues avec la commande
# enfoncée et 0x8004 = 0. Gauche : MIN_X, 0x822b = 30 aux frames 7974–8019.
# Droite : MAX_X, 0x822b = 216 aux frames 7810–7879.
const SHIP_Y := 200
const MOVE_STEP := 2
const SHOT_START_Y := 183
const SHOT_STEP := 4
const SHOT_LENGTH := 4
# Vaisseau II + III, relevé sur pr1-suite au rythme de 0x8005.
# Groupe 0 : paire à y = 212 (registre 0x27), écart 12. Groupe 1 : paire à y = 195
# (registre 0x38), écart 8. L'abscisse logique vaut le registre de projectile moins 17.
const ASSEMBLED_START_Y := [212, 195]
const ASSEMBLED_SPREADS := [12, 8]
# Vaisseau I + II, relevé sur pr6-tir-i-ii au rythme de 0x8005, vaisseau à
# 0x822b = 130 (x = 114). Groupe 0 : paire à y = 211 (registre matériel 40),
# écart 8. Groupe 1 : un projectile central à y = 199 (registre 52).
const I_II_PAIR_START_Y := 211
const I_II_SINGLE_START_Y := 199
const I_II_PAIR_SPREAD := 8

var frame := 0
var ship_x := START_X
var module: int
var attached: int
var shot_active := false
var shot_position := Vector2i.ZERO
var second_shot_active := false
var second_shot_position := Vector2i.ZERO
var _fire_held := false
# Deux groupes de deux projectiles pour le vaisseau assemblé.
var _group_active: Array[bool] = [false, false, false, false]
var _group_position: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
var _next_group := 0
# pr6b : après la réussite I + II, le combat se joue 16 pixels plus bas
# (0x822c = 232, modules à y = 208 et 216). Après l'expiration I + II → III
# (pr7, reprise 16775), 0x822c = 216 et les modules reviennent à 192 et 200.
var assembly_y_offset := 0


func _init(module_number := 1, start_x := START_X, attached_modules := 0) -> void:
	module = module_number
	ship_x = start_x
	attached = attached_modules if attached_modules != 0 else 1 << (module_number - 1)
	if is_i_and_ii():
		assembly_y_offset = 16


func has_module(number: int) -> bool:
	return bool(attached & (1 << (number - 1)))


# pr5c : un maintien commencé pendant l'amarrage I + II et poursuivi à la
# reprise ne déclenche pas de volée. Un nouvel front d'appui est nécessaire.
func absorb_held_fire() -> void:
	_fire_held = true


func is_assembled() -> bool:
	return has_module(2) and has_module(3)


func is_i_and_ii() -> bool:
	return has_module(1) and has_module(2) and not has_module(3)


func uses_fire_groups() -> bool:
	return is_assembled() or is_i_and_ii()


func module_y(number: int) -> int:
	return SHIP_Y + (number - 1) * 8


func ship_y() -> int:
	return module_y(module)


func clear_shots() -> void:
	shot_active = false
	second_shot_active = false
	for index in range(_group_active.size()):
		_group_active[index] = false


# Reprend des projectiles figés dans les créneaux logiciels 0x8161–0x8168.
# Après amarrage réussi, le vaisseau assemblé les replace dans le groupe 1
# (même paire que le module II, écart 8, registres 0x40/0x50 sur pr1).
func restore_shots(shots: Array[Vector2i]) -> void:
	clear_shots()
	if shots.is_empty():
		return
	if is_assembled():
		var base := 2
		for index in range(mini(shots.size(), 2)):
			_group_position[base + index] = shots[index]
			_group_active[base + index] = true
	else:
		shot_position = shots[0]
		shot_active = true
		if shots.size() > 1:
			second_shot_position = shots[1]
			second_shot_active = true


func advance_shots_only() -> void:
	_advance_assembled_shots()
	if shot_active:
		shot_position.y -= SHOT_STEP
		shot_active = shot_position.y >= 0
	if second_shot_active:
		second_shot_position.y -= SHOT_STEP
		second_shot_active = second_shot_position.y >= 0


func active_shots() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if uses_fire_groups():
		for index in range(_group_active.size()):
			if _group_active[index]:
				result.append(_group_position[index])
		return result
	if shot_active:
		result.append(shot_position)
	if second_shot_active:
		result.append(second_shot_position)
	return result


func deactivate_shot(index: int) -> void:
	var current := 0
	if uses_fire_groups():
		for slot in range(_group_active.size()):
			if not _group_active[slot]:
				continue
			if current == index:
				_group_active[slot] = false
				return
			current += 1
		return
	if shot_active:
		if current == index:
			shot_active = false
			return
		current += 1
	if second_shot_active and current == index:
		second_shot_active = false


func step(input_mask: int, accept_input := true) -> void:
	frame += 1
	var group_busy := [_group_is_busy(0), _group_is_busy(1)]
	var slot_was_busy := shot_active or second_shot_active
	_advance_assembled_shots()
	if shot_active:
		shot_position.y -= SHOT_STEP
		shot_active = shot_position.y >= 0
	if second_shot_active:
		second_shot_position.y -= SHOT_STEP
		second_shot_active = second_shot_position.y >= 0
	if not accept_input:
		return
	if input_mask & LEFT:
		ship_x = maxi(MIN_X, ship_x - MOVE_STEP)
	elif input_mask & RIGHT:
		ship_x = mini(MAX_X, ship_x + MOVE_STEP)

	var fire := bool(input_mask & FIRE)
	# Relevé pr2-held-fire : un maintien commencé pendant le vol d'un groupe
	# et poursuivi après sa disparition ne déclenche pas de volée différée.
	# Un nouvel front d'appui est nécessaire, comme pour le module I (fire_busy).
	if fire and not _fire_held:
		if uses_fire_groups():
			if not group_busy[_next_group]:
				if is_assembled():
					_fire_assembled_group(_next_group)
				else:
					_fire_i_ii_group(_next_group)
				_next_group = 1 - _next_group
		elif not slot_was_busy:
			var spread := 4 * module if module > 1 else 0
			const START_HEIGHTS := [SHOT_START_Y, 195, 204]
			shot_position = Vector2i(ship_x - 1 - spread, START_HEIGHTS[module - 1])
			shot_active = true
			if spread:
				second_shot_position = Vector2i(ship_x - 1 + spread, shot_position.y)
				second_shot_active = true
	_fire_held = fire


func _group_is_busy(group: int) -> bool:
	var base := group * 2
	return _group_active[base] or _group_active[base + 1]


func _advance_assembled_shots() -> void:
	for index in range(_group_active.size()):
		if not _group_active[index]:
			continue
		_group_position[index].y -= SHOT_STEP
		_group_active[index] = _group_position[index].y >= 0


func _fire_i_ii_group(group: int) -> void:
	if group == 0:
		_group_position[0] = Vector2i(ship_x - 1 - I_II_PAIR_SPREAD, I_II_PAIR_START_Y)
		_group_position[1] = Vector2i(ship_x - 1 + I_II_PAIR_SPREAD, I_II_PAIR_START_Y)
		_group_active[0] = true
		_group_active[1] = true
	else:
		_group_position[2] = Vector2i(ship_x - 1, I_II_SINGLE_START_Y)
		_group_active[2] = true


func _fire_assembled_group(group: int) -> void:
	var spread: int = ASSEMBLED_SPREADS[group]
	var height: int = ASSEMBLED_START_Y[group]
	var base := group * 2
	_group_position[base] = Vector2i(ship_x - 1 - spread, height)
	_group_position[base + 1] = Vector2i(ship_x - 1 + spread, height)
	_group_active[base] = true
	_group_active[base + 1] = true
