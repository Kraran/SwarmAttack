extends RefCounted

const Pilot = preload("res://pilot.gd")
const CombatRound = preload("res://combat_round.gd")
const Docking = preload("res://docking.gd")
const WAVES_BEFORE_DOCK := 4
# Reprise après amarrage : entrée large identique aux vagues 3 et 4 (relevé aux frames 7753, 7950, 8157).
const WAVE_AFTER_DOCK := 3
# 0x8004 reste à 1 pendant 161 images, puis 127 images, puis une impulsion d'une image
# avant la baisse de 0x8097. Au rythme de 0x8005, le délai vaut 289 images
# (les 292 images murales observées sur la perte du module II tiennent à 3 frames figées).
const DEATH_FLAG_FRAMES := 161
const FRAMES_BEFORE_COUNTER_DROP := 127
const COUNTER_DROP_PULSE := 1
const COUNTER_DROP_FRAMES := DEATH_FLAG_FRAMES + FRAMES_BEFORE_COUNTER_DROP + COUNTER_DROP_PULSE
# Entrée du module suivant, au rythme de 0x8005, de la baisse du compteur à la reprise.
const ENTRANCE_HIDDEN := 25
const ENTRANCE_RISE := 136
const ENTRANCE_PAUSE := 137
const ENTRANCE_DESCENT := 80
const ENTRANCE_FRAMES := ENTRANCE_HIDDEN + ENTRANCE_RISE + ENTRANCE_PAUSE + ENTRANCE_DESCENT
const ENTRANCE_START_Y := 255
const ENTRANCE_MID_Y := 120
const ENTRANCE_REST_Y := 200
const STARTING_LIVES := 3
# Après la baisse à 0 : 31 images, puis 30 images de « JEU 1 TERMINE ».
# Les 869 images suivantes mènent à la démo (non reproduite).
const GAME_OVER_CLEAR := 31
const GAME_OVER_MESSAGE := 30

enum Phase { COMBAT, REPLACEMENT, DOCKING, GAME_OVER }

var phase := Phase.COMBAT
var wave_number := 1
# Masque des modules assemblés : bit 0 = I, bit 1 = II, bit 2 = III.
var attached := 1
var lives := STARTING_LIVES
var combat := CombatRound.new()
var docking: Docking
var frame := 0
var _previous_score := 0
var _replacement_left := 0
var _counter_dropped := false
var _game_over_elapsed := 0
var _docking_life_taken := false


func front_module() -> int:
	for module in range(1, 4):
		if attached & (1 << (module - 1)):
			return module
	return 1


func docking_target() -> int:
	if attached & 1 and not (attached & 2):
		return 2
	if attached & 2 and not (attached & 4):
		return 3
	return 0


func ship_label() -> String:
	var parts := PackedStringArray()
	const NAMES := ["I", "II", "III"]
	for module in range(1, 4):
		if attached & (1 << (module - 1)):
			parts.append(NAMES[module - 1])
	return " + ".join(parts)


func score() -> int:
	var points := _previous_score + combat.score
	if docking != null:
		points += docking.credited_bonus()
	return points


func entrance_elapsed() -> int:
	if not _counter_dropped or phase != Phase.REPLACEMENT:
		return -1
	return COUNTER_DROP_FRAMES + ENTRANCE_FRAMES - _replacement_left - COUNTER_DROP_FRAMES


func entrance_ship_y() -> int:
	var elapsed := entrance_elapsed()
	if elapsed < ENTRANCE_HIDDEN:
		return -1
	var rise := elapsed - ENTRANCE_HIDDEN
	if rise < ENTRANCE_RISE:
		return ENTRANCE_START_Y - rise
	var pause := rise - ENTRANCE_RISE
	if pause < ENTRANCE_PAUSE:
		return ENTRANCE_MID_Y
	var descent := pause - ENTRANCE_PAUSE
	return mini(ENTRANCE_REST_Y, ENTRANCE_MID_Y + 1 + descent)


func game_over_shows_message() -> bool:
	return phase == Phase.GAME_OVER and _game_over_elapsed >= GAME_OVER_CLEAR


func practice_docking() -> void:
	phase = Phase.DOCKING
	attached = 1
	docking = Docking.new(1, Pilot.START_X, false)
	_docking_life_taken = false


func step(input_mask: int) -> void:
	frame += 1
	match phase:
		Phase.COMBAT:
			combat.step(input_mask)
			if combat.outcome == CombatRound.Outcome.MODULE_LOST:
				phase = Phase.REPLACEMENT
				_replacement_left = COUNTER_DROP_FRAMES + ENTRANCE_FRAMES
				_counter_dropped = false
			elif combat.outcome == CombatRound.Outcome.CLEARED:
				_advance_from_clear()
		Phase.REPLACEMENT:
			combat.step(0)
			_advance_replacement()
		Phase.DOCKING:
			docking.step(input_mask)
			# Relevé : 0x8097 baisse dès l'explosion (frame 7452), pas après 161 + 127 images.
			if docking.stage == Docking.Stage.COLLISION and not _docking_life_taken:
				# pr8-amarrage-i-ii-iii-approche, frame 15673 : le I + II entre
				# en collision avec le III, 0x8097 passe de 3 à 1 dès l'explosion.
				lives -= 2 if attached == 3 else 1
				_docking_life_taken = true
				# pr1-collision, frame 7452 : le drapeau 0x8163 passe de 1 à 0.
				combat.pilot.clear_shots()
			if docking.is_ready_to_resume():
				_resume_from_docking(input_mask)
		Phase.GAME_OVER:
			_game_over_elapsed += 1


func _advance_from_clear() -> void:
	if wave_number < WAVES_BEFORE_DOCK:
		wave_number += 1
		_begin_combat(combat.pilot.ship_x, 255)
	elif docking_target() != 0:
		phase = Phase.DOCKING
		# pr7 : l'assemblage I + II s'approche du III depuis 0x822c = 232.
		docking = Docking.new(front_module(), combat.pilot.ship_x, true, attached)
		_docking_life_taken = false
	else:
		# Aucun partenaire restant : nouveau cycle des quatre vagues. PROVISOIRE.
		wave_number = 1
		_begin_combat(combat.pilot.ship_x, 255)


func _advance_replacement() -> void:
	_replacement_left -= 1
	var elapsed := COUNTER_DROP_FRAMES + ENTRANCE_FRAMES - _replacement_left
	if not _counter_dropped and elapsed >= COUNTER_DROP_FRAMES:
		lives -= 1
		_counter_dropped = true
		attached = _next_attached_after_loss()
		if lives <= 0:
			phase = Phase.GAME_OVER
			_game_over_elapsed = 0
			return
	if _replacement_left == 0:
		_begin_combat(Pilot.START_X, combat.wave.survivors())


func _next_attached_after_loss() -> int:
	if attached == 1:
		# Relevé : après la perte du module I, le module II prend le relais.
		return 2
	if attached == 6:
		# Relevé : après la destruction du vaisseau II + III, le module II seul repart.
		return 2
	if attached == 3:
		# pr5c : après la destruction du I + II à la butée droite (frame 12290,
		# vies 3 → 2 à 12579), le module I reprend l'entrée (0x822c vers 200,
		# sprite 0x78, visible à 12968).
		return 1
	if attached == 2:
		# La perte du module II seul, dans le relevé, ramène le compteur à 0 et termine
		# la partie. Une succession II → III avec des vies restantes reste provisoire.
		return 4
	if attached == 7:
		# pr8c : destruction du I + II + III à la butée gauche (16754), vies
		# 3 → 2 à 17073, puis entrée du II + III (modules à y = 200 et 216,
		# visibles à 17451).
		return 6
	# Vaisseau assemblé : ne garder que le module supérieur (mesuré pour II + III).
	return 1 << (front_module() - 1)


func _resume_from_docking(input_mask: int) -> void:
	var stage := docking.stage
	var resume_x := Pilot.START_X
	# Créneaux encore actifs : la routine de reprise ne les efface pas
	# (succès et expiration). La collision les a déjà vidés à l'explosion.
	var leftover: Array[Vector2i] = []
	if stage != Docking.Stage.COLLISION:
		leftover = combat.pilot.active_shots()
	# Première image visible : deux pas après un bonus (7723, y registre 96),
	# un seul après une expiration (8125, y registre 92). Les valeurs logiques
	# correspondent à 251 − registre, soit 155 et 159 depuis un gel à 163.
	var resume_ticks := 2 if stage == Docking.Stage.SUCCESS else 1
	if stage == Docking.Stage.SUCCESS:
		# pr5c : contact à 10599, écran « BRAVO !! » / bonus 17 × 100 = 1700
		# pendant 305 images (10599–10903), crédit et reprise à 10904 :
		# I + II à x = 112 (0x822b = 128, 0x822c = 232), vies = 3, pas de
		# tir figé, vague à entrée large vers 10935. Un maintien du tir
		# commencé pendant l'approche et poursuivi à la reprise ne tire pas.
		# pr8c : contact à 16357, bonus 05 × 300 = 1500 pendant 305 images
		# (16357–16661), crédit et reprise à 16662 : I + II + III à x = 112
		# (0x822b = 128, 0x822c = 216), vies = 3, butée gauche x = 14.
		attached |= 1 << (docking_target() - 1)
		resume_x = Docking.TARGET.x
	elif stage == Docking.Stage.COLLISION:
		# II → III : le module cible poursuit seul, déjà aligné à x = 112.
		# I + II → III (pr8, 16139) : le module III seul reprend à x = 112
		# (0x822b = 128, 0x822c = 232), vies 1, sans bonus.
		attached = 1 << (docking_target() - 1)
		resume_x = Docking.TARGET.x
	else:
		# Temps écoulé : le module en approche poursuit, recentré à x = 112.
		# II → III : 0x822b passe de 31 à 128 à la frame 8125 (pr1-timeout).
		# I + II : 0x822b passe de 96 à 128 à la frame 11526 (pr5b), vies inchangées.
		# I + II → III (pr7, 16775) : le I + II continue (0x814a = 3), vies 3,
		# sans bonus, 0x822b = 128, 0x822c = 216 (modules à y = 192 et 200).
		resume_x = Pilot.START_X
	var i_ii_timeout_altitude := stage == Docking.Stage.TIMED_OUT and attached == 3
	_previous_score += combat.score + docking.credited_bonus()
	combat.score = 0
	docking = null
	if lives <= 0:
		# Collision d'amarrage avec une seule vie restante : non relevée.
		phase = Phase.GAME_OVER
		_game_over_elapsed = 0
		return
	wave_number = WAVE_AFTER_DOCK
	_begin_combat(resume_x, 255)
	if i_ii_timeout_altitude:
		combat.pilot.assembly_y_offset = 0
	if input_mask & Pilot.FIRE:
		combat.pilot.absorb_held_fire()
	if not leftover.is_empty():
		combat.pilot.restore_shots(leftover)
		for _tick in range(resume_ticks):
			combat.pilot.advance_shots_only()


func _begin_combat(ship_x: int, alive_mask: int) -> void:
	_previous_score += combat.score
	combat = CombatRound.new(wave_number, front_module(), ship_x, alive_mask, attached)
	phase = Phase.COMBAT
