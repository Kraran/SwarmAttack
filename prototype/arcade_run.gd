extends RefCounted

const Pilot = preload("res://pilot.gd")
const CombatRound = preload("res://combat_round.gd")
const Docking = preload("res://docking.gd")
const WAVES_BEFORE_DOCK := 4
# 0x8004 reste à 1 pendant 161 images, puis 127 images avant la baisse de 0x8097.
# Les écarts relevés entre la destruction et la baisse du compteur valent 289 ou 292.
const DEATH_FLAG_FRAMES := 161
const FRAMES_BEFORE_COUNTER_DROP := 127
const COUNTER_DROP_FRAMES := DEATH_FLAG_FRAMES + FRAMES_BEFORE_COUNTER_DROP
# Animation d'entrée (montée, palier, redescente) non relevée image par image.
const ENTRANCE_FRAMES := 0  # PROVISOIRE
const STARTING_LIVES := 3

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


func practice_docking() -> void:
	phase = Phase.DOCKING
	attached = 1
	docking = Docking.new(1, Pilot.START_X, false)


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
			if docking.is_ready_to_resume():
				_resume_from_docking()


func _advance_from_clear() -> void:
	if wave_number < WAVES_BEFORE_DOCK:
		wave_number += 1
		_begin_combat(combat.pilot.ship_x, 255)
	elif docking_target() != 0:
		phase = Phase.DOCKING
		# L'approche d'un assemblage I + II vers le module III n'est pas relevée :
		# on réutilise le modèle du module supérieur.
		docking = Docking.new(front_module(), combat.pilot.ship_x)
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
	if attached == 2:
		# Suite I → II étendue au cas II seul. PROVISOIRE.
		return 4
	# Vaisseau assemblé : ne garder que le module supérieur (mesuré pour II + III).
	return 1 << (front_module() - 1)


func _resume_from_docking() -> void:
	var stage := docking.stage
	var resume_x := Pilot.START_X
	if stage == Docking.Stage.SUCCESS:
		attached |= 1 << (docking_target() - 1)
		resume_x = Docking.TARGET.x
	elif stage == Docking.Stage.COLLISION:
		# Relevé pour II → III : le module cible poursuit seul.
		attached = 1 << (docking_target() - 1)
	else:
		# Temps écoulé : le module en approche poursuit seul. Position de reprise
		# non relevée : on conserve l'abscisse d'affichage. PROVISOIRE.
		resume_x = clampi(int(docking.display_position().x), Pilot.MIN_X, Pilot.MAX_X)
	_previous_score += combat.score + docking.credited_bonus()
	combat.score = 0
	docking = null
	# Composition des vagues après un amarrage non relevée : on reprend un cycle. PROVISOIRE.
	wave_number = 1
	_begin_combat(resume_x, 255)


func _begin_combat(ship_x: int, alive_mask: int) -> void:
	_previous_score += combat.score
	combat = CombatRound.new(wave_number, front_module(), ship_x, alive_mask, attached)
	phase = Phase.COMBAT
