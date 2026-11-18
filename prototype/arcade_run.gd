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
# Le cycle d'attraction (attract.gd) reprend ensuite au texte de présentation.
const GAME_OVER_CLEAR := 31
const GAME_OVER_MESSAGE := 30
# Le message de partie supplémentaire reste visible avant l'entrée du porteur.
const RESERVE_MESSAGE_FRAMES := 31
# Valeur d'un ennemi abattu selon l'étape du cycle (0x809b), relevée sur les sondes :
# vagues 1-2 à 50 et 3-4 à 30 avant le premier amarrage (cycle 2 de pr11c, 0x12 à 0x15,
# identique au cycle 1) ; 60 après le premier amarrage (pr7, 0x809b = 7 et 8) ;
# 100 après le second (pr7, pr8b, pr9, pr9b, pr11a à pr11d, 0x809b = 0x0c et 0x0d).
const POINTS_NARROW := 50
const POINTS_WIDE := 30
const POINTS_AFTER_FIRST_DOCK := 60
const POINTS_AFTER_SECOND_DOCK := 100
# 0x809b = 0x09 et 0x0a (pr7) : objets en chute à 200 points (score 3940 → 4140
# à 14258, 4540 → 4740 à 14743).
const POINTS_FALLING := 200
# Après le premier amarrage, quatre vagues avant le second : 0x07 et 0x08 à
# entrée large (vagues 3 et 4), puis 0x09 et 0x0a d'objets en chute (5 et 6).
const LAST_WAVE_AFTER_FIRST_DOCK := 6
# Fin de cycle, relevée sur pr11c (images de boucle depuis le crédit du dernier
# ennemi de la vague 0x0d, 17603) : 0x809b passe à 0x0e (+1), écran 0x80 puis 0xC0
# (+2 à +31), vaisseau immobile ; à +33 il monte d'une unité par image (0x822c de
# 216 à 57 à +191), « PLUS LOIN » affiché pendant la montée (vu de 17650 à 17790 sur
# les PNG, absent à 17640 et 17800) ; à +191 les trois modules repassent en réserve
# (0x8140, 0x8145, 0x814a = 3), écran vide jusqu'à l'entrée du module I (0x809b =
# 0x11 à +313), puis combat en vague 1 (0x809b = 0x12) à +689 avec 8 ennemis,
# vies et score inchangés, sans bonus.
const CYCLE_RISE_START := 33
const CYCLE_RISE_HEIGHT := 159
const CYCLE_MESSAGE_FROM := 47
const CYCLE_RESET := 191
# L'entrée standard (ENTRANCE_FRAMES = 378) démarre à +311 pour retrouver le combat
# à +689. Sur pr11c, le module apparaît à y = 120 à +474 et redescend à +610, soit
# 2 et 1 images plus tard que l'entrée standard. Écart non modélisé.
const CYCLE_ENTRANCE_START := 311
const CYCLE_ENTRANCE_DONE := CYCLE_ENTRANCE_START + ENTRANCE_FRAMES

enum Phase { COMBAT, REPLACEMENT, DOCKING, GAME_OVER, CYCLE_END, LAUNCH }

var phase := Phase.COMBAT
var wave_number := 1
# Cycle de jeu (0x809b : 0x01-0x0e pour le premier, 0x11 et suivants pour le second).
var cycle := 1
# Amarrages franchis dans le cycle : 0 avant le premier, 1 après, 2 après le second.
var stage := 0
var cycle_end_elapsed := 0
# Masque des modules assemblés : bit 0 = I, bit 1 = II, bit 2 = III.
var attached := 1
var lives := STARTING_LIVES
var bonus_threshold := 30000
var bonus_reserve := false
var _bonus_used := false
var _reserve_message_left := 0
var turn_ended := false
var combat: CombatRound
var docking: Docking
var frame := 0
var successful_dockings := 0
var _previous_score := 0
var _replacement_left := 0
var _counter_dropped := false
var _game_over_elapsed := 0
var _docking_life_taken := false
var _entrance_alive_mask := -1
# Modules exclus du porteur après leur destruction, y compris aux cycles suivants.
var _lost_modules := 0
# Compteurs de motifs 0x8242-0x8247, conservés d'une vague à l'autre et à
# travers l'amarrage et la fin de cycle (pr7, pr8, pr8b, pr11c). Ils sont remis
# à zéro à l'entrée du module qui suit une perte de vie (0x809b = 0x01 ou 0x11 :
# pr1-suite 5504 et 8379, pr10a-d, pr11a-d), pas après une collision
# d'amarrage. Nuls en début de partie (pr12a-b : RAM effacée à 106, 0x809b =
# 0x01 à 151) et au début de la démo (pr1-suite 10246, pr12b 27726).
var _patterns: Array = [0, 0, 0, 0, 0, 0]
var _reset_patterns := false


func _init(starting_cycle := 1) -> void:
	cycle = starting_cycle
	combat = CombatRound.new()
	combat.wave.max_divers = max_divers()


func front_module() -> int:
	for module in range(1, 4):
		if attached & (1 << (module - 1)):
			return module
	return 1


func available_modules() -> int:
	return 7 & ~_lost_modules


func docking_target() -> int:
	# Le prochain partenaire est une coque intacte, jamais un module détruit.
	for module in range(front_module() + 1, 4):
		var mask := 1 << (module - 1)
		if available_modules() & mask and not (attached & mask):
			return module
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
	return replacement_elapsed() - COUNTER_DROP_FRAMES


func replacement_elapsed() -> int:
	return COUNTER_DROP_FRAMES + ENTRANCE_FRAMES - _replacement_left


func begin_launch() -> void:
	phase = Phase.LAUNCH


func entrance_modules() -> int:
	if phase == Phase.LAUNCH:
		return 7
	if entrance_elapsed() < 0:
		return 0
	if combat.lost_module == 2 and available_modules() == 5 and not is_cycle_entrance():
		# Après la perte du II, seul le I se redéploie. Le III reste en réserve.
		return attached
	var lower_modules := 7 & ~((1 << front_module()) - 1)
	return attached | (lower_modules & available_modules())


func entrance_module_y(module: int, elapsed: float, released_module := 1) -> float:
	if elapsed < ENTRANCE_HIDDEN:
		return Pilot.FIELD_SIZE.y
	var separation := ENTRANCE_HIDDEN + ENTRANCE_RISE - 1
	var offset := (module - 1) * 8
	if elapsed <= separation:
		return ENTRANCE_START_Y - (elapsed - ENTRANCE_HIDDEN) + offset
	if module != released_module:
		return ENTRANCE_MID_Y + offset + elapsed - separation
	var descent_start := separation + ENTRANCE_PAUSE
	return clampf(ENTRANCE_MID_Y + elapsed - descent_start, ENTRANCE_MID_Y, ENTRANCE_REST_Y) + offset


# Montée du vaisseau en fin de cycle (0x822c diminue d'une unité par image).
func cycle_end_rise() -> int:
	if phase != Phase.CYCLE_END:
		return 0
	return clampi(cycle_end_elapsed - CYCLE_RISE_START + 1, 0, CYCLE_RISE_HEIGHT)


func is_cycle_entrance() -> bool:
	return phase == Phase.REPLACEMENT and _entrance_alive_mask >= 0


func reserve_shows_message() -> bool:
	return phase == Phase.REPLACEMENT and _reserve_message_left > 0


func cycle_end_shows_ship() -> bool:
	return phase == Phase.CYCLE_END and cycle_end_elapsed < CYCLE_RESET


func cycle_end_shows_message() -> bool:
	return phase == Phase.CYCLE_END and cycle_end_elapsed >= CYCLE_MESSAGE_FROM and cycle_end_elapsed < CYCLE_RESET


func points_per_hit(wave := wave_number, at_stage := stage) -> int:
	if wave >= 5:
		return POINTS_FALLING
	if at_stage >= 2:
		return POINTS_AFTER_SECOND_DOCK
	if at_stage == 1:
		return POINTS_AFTER_FIRST_DOCK
	return POINTS_NARROW if wave < 3 else POINTS_WIDE


func game_over_shows_message() -> bool:
	return phase == Phase.GAME_OVER and _game_over_elapsed >= GAME_OVER_CLEAR


# pr1-suite : 31 + 30 images après la baisse à 0, puis le texte d'attraction.
func game_over_finished() -> bool:
	return phase == Phase.GAME_OVER and _game_over_elapsed >= GAME_OVER_CLEAR + GAME_OVER_MESSAGE


func practice_docking() -> void:
	phase = Phase.DOCKING
	attached = 1
	docking = Docking.new(1, Pilot.START_X, false)
	_docking_life_taken = false


func step(input_mask: int, stop_after_exercise := false) -> void:
	turn_ended = false
	frame += 1
	match phase:
		Phase.LAUNCH:
			if frame >= ENTRANCE_FRAMES:
				phase = Phase.COMBAT
				if input_mask & Pilot.FIRE:
					combat.pilot.absorb_held_fire()
		Phase.COMBAT:
			combat.step(input_mask)
			if combat.outcome == CombatRound.Outcome.MODULE_LOST:
				var lost := combat.lost_module if combat.lost_module > 0 else front_module()
				combat.lost_module = lost
				_lost_modules |= 1 << (lost - 1)
				phase = Phase.REPLACEMENT
				_replacement_left = COUNTER_DROP_FRAMES + ENTRANCE_FRAMES
				_counter_dropped = false
			elif combat.outcome == CombatRound.Outcome.CLEARED:
				if not stop_after_exercise:
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
				_lost_modules |= attached
				# pr1-collision, frame 7452 : le drapeau 0x8163 passe de 1 à 0.
				combat.pilot.clear_shots()
			if docking.is_ready_to_resume() and not stop_after_exercise:
				_resume_from_docking(input_mask)
		Phase.GAME_OVER:
			_game_over_elapsed += 1
		Phase.CYCLE_END:
			combat.step(0)
			_advance_cycle_end()
	if not _bonus_used and score() >= bonus_threshold:
		bonus_reserve = true


# Le nombre de plongeurs varie avec le numéro du cycle.
func max_divers() -> int:
	return ((cycle - 1) & 0x0F) + 1


func last_wave() -> int:
	return LAST_WAVE_AFTER_FIRST_DOCK if stage == 1 else WAVES_BEFORE_DOCK


func _advance_from_clear() -> void:
	if wave_number < last_wave():
		wave_number += 1
		_begin_combat(combat.pilot.ship_x, 255)
	elif stage >= 2:
		# pr11c : après les deux vagues qui suivent le second amarrage, fin de
		# cycle puis nouveau cycle (relevé avec le vaisseau I + II + III).
		phase = Phase.CYCLE_END
		cycle_end_elapsed = 0
	elif docking_target() != 0:
		phase = Phase.DOCKING
		# pr7 : l'assemblage I + II s'approche du III depuis 0x822c = 232.
		docking = Docking.new(front_module(), combat.pilot.ship_x, true, attached, docking_target())
		_docking_life_taken = false
	else:
		# Sans partenaire, la vague suivante commence directement (module III
		# seul au cinquième cycle du longplay).
		stage += 1
		wave_number = WAVE_AFTER_DOCK
		_begin_combat(combat.pilot.ship_x, 255)


func _advance_cycle_end() -> void:
	cycle_end_elapsed += 1
	if cycle_end_elapsed == CYCLE_RESET:
		# Le premier module intact prend la main. À 9:12 et à 10:37 dans le
		# longplay, le III remonte seul après la destruction des I et II.
		var available := available_modules()
		for module in range(3):
			var mask := 1 << module
			if available & mask:
				attached = mask
				break
		combat.pilot.clear_shots()
	if cycle_end_elapsed == CYCLE_ENTRANCE_START:
		cycle += 1
		stage = 0
		wave_number = 1
		phase = Phase.REPLACEMENT
		_replacement_left = ENTRANCE_FRAMES
		_counter_dropped = true
		_entrance_alive_mask = 255


func _advance_replacement() -> void:
	if reserve_shows_message():
		_reserve_message_left -= 1
		return
	_replacement_left -= 1
	var elapsed := replacement_elapsed()
	if not _counter_dropped and elapsed >= COUNTER_DROP_FRAMES:
		lives -= 1
		turn_ended = true
		_counter_dropped = true
		_reset_patterns = true
		attached = _next_attached_after_loss()
		if lives <= 0 and not _consume_reserve():
			return
	if _replacement_left == 0:
		var alive := combat.wave.survivors() if _entrance_alive_mask < 0 else _entrance_alive_mask
		_entrance_alive_mask = -1
		_begin_combat(Pilot.START_X, alive)


func _next_attached_after_loss() -> int:
	# Les survivants de l'assemblage passent avant les modules de réserve.
	# Une perte ne doit jamais recréer le module qui vient d'être détruit.
	var available := available_modules()
	var survivors := attached & available
	var following := available & ~((1 << combat.lost_module) - 1)
	for candidates in [survivors, following, available]:
		for module in range(3):
			var mask := 1 << module
			if candidates & mask:
				return mask
	return 0


func _resume_from_docking(input_mask: int) -> void:
	var dock_stage := docking.stage
	var resume_x := Pilot.START_X
	# Créneaux encore actifs : la routine de reprise ne les efface pas
	# (succès et expiration). La collision les a déjà vidés à l'explosion.
	var leftover: Array[Vector2i] = []
	if dock_stage != Docking.Stage.COLLISION:
		leftover = combat.pilot.active_shots()
	# Première image visible : deux pas après un bonus (7723, y registre 96),
	# un seul après une expiration (8125, y registre 92). Les valeurs logiques
	# correspondent à 251 − registre, soit 155 et 159 depuis un gel à 163.
	var resume_ticks := 2 if dock_stage == Docking.Stage.SUCCESS else 1
	if dock_stage == Docking.Stage.SUCCESS:
		successful_dockings += 1
		# pr5c : contact à 10599, écran « BRAVO !! » / bonus 17 × 100 = 1700
		# pendant 305 images (10599–10903), crédit et reprise à 10904 :
		# I + II à x = 112 (0x822b = 128, 0x822c = 232), vies = 3, pas de
		# tir figé, vague à entrée large vers 10935. Un maintien du tir
		# commencé pendant l'approche et poursuivi à la reprise ne tire pas.
		# pr8c : contact à 16357, bonus 05 × 300 = 1500 pendant 305 images
		# (16357–16661), crédit et reprise à 16662 : I + II + III à x = 112
		# (0x822b = 128, 0x822c = 216), vies = 3, butée gauche x = 14.
		attached |= 1 << (docking.target_module - 1)
		_lost_modules &= ~attached
		resume_x = Docking.TARGET.x
	elif dock_stage == Docking.Stage.COLLISION:
		# II → III : le module cible poursuit seul, déjà aligné à x = 112.
		# I + II → III (pr8, 16139) : le module III seul reprend à x = 112
		# (0x822b = 128, 0x822c = 232), vies 1, sans bonus.
		attached = 1 << (docking.target_module - 1)
		resume_x = Docking.TARGET.x
	else:
		# Temps écoulé : le module en approche poursuit, recentré à x = 112.
		# II → III : 0x822b passe de 31 à 128 à la frame 8125 (pr1-timeout).
		# I + II : 0x822b passe de 96 à 128 à la frame 11526 (pr5b), vies inchangées.
		# I + II → III (pr7, 16775) : le I + II continue (0x814a = 3), vies 3,
		# sans bonus, 0x822b = 128, 0x822c = 216 (modules à y = 192 et 200).
		resume_x = Pilot.START_X
	var i_ii_timeout_altitude := dock_stage == Docking.Stage.TIMED_OUT and attached == 3
	_previous_score += combat.score + docking.credited_bonus()
	combat.score = 0
	docking = null
	if lives <= 0:
		if _consume_reserve():
			phase = Phase.REPLACEMENT
			_replacement_left = ENTRANCE_FRAMES
			_counter_dropped = true
		return
	wave_number = WAVE_AFTER_DOCK
	# pr7 (expiration), pr8b (collision), pr8c (réussite) : l'étape suivante
	# (0x809b = 7 ou 0x0c) suit l'amarrage quelle qu'en soit l'issue.
	stage += 1
	# pr7 + pr9b : le dernier tir du I + II avant l'intro (14721) est le
	# groupe 0 ; à la reprise en I + II + III, le premier appui (16840,
	# projectiles à 16841) forme le groupe 1 assemblé. L'index survit à
	# l'amarrage. Un module sans groupes laisse l'index à 0, ce qui
	# retrouve le groupe 0 mesuré après II → III.
	var next_group := combat.pilot._next_group
	_begin_combat(resume_x, 255)
	combat.pilot._next_group = next_group
	if i_ii_timeout_altitude:
		combat.pilot.assembly_y_offset = 0
	if input_mask & Pilot.FIRE:
		combat.pilot.absorb_held_fire()
	if not leftover.is_empty():
		combat.pilot.restore_shots(leftover)
		for _tick in range(resume_ticks):
			combat.pilot.advance_shots_only()


func _consume_reserve() -> bool:
	if not bonus_reserve:
		lives = 0
		phase = Phase.GAME_OVER
		_game_over_elapsed = 0
		return false
	bonus_reserve = false
	_bonus_used = true
	_reserve_message_left = RESERVE_MESSAGE_FRAMES
	lives = STARTING_LIVES
	attached = 1
	_lost_modules = 0
	cycle += 1
	stage = 0
	wave_number = 1
	_reset_patterns = true
	_entrance_alive_mask = 255
	return true


func _begin_combat(ship_x: int, alive_mask: int) -> void:
	_previous_score += combat.score
	if not combat.wave.enemies.is_empty():
		_patterns = combat.wave.patterns()
	if _reset_patterns:
		_patterns = [0, 0, 0, 0, 0, 0]
		_reset_patterns = false
	combat = CombatRound.new(
		wave_number, front_module(), ship_x, alive_mask, attached, points_per_hit(),
		stage, max_divers(), _patterns
	)
	phase = Phase.COMBAT
