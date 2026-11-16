extends RefCounted

const Pilot = preload("res://pilot.gd")
const CombatWave = preload("res://combat_wave.gd")
const IMPACT_FRAMES := 12
# Délai entre l'impact (première image de l'explosion, 0x80ef) et le crédit
# (baisse de 0x823c et du score), en images de boucle. Il croît avec le
# nombre d'ennemis restants (charge de la carte) : 150 impacts relevés sur
# pr1 à pr12, valeur la plus fréquente par type de vague et par 0x823c au
# moment de l'impact (114 impacts sur 150 exacts, les autres à ±1 ou ±2).
# Valeur par défaut (objets en chute, non relevés) : 10.
const SCORE_DELAY := 10
const NARROW_SCORE_DELAYS := [9, 9, 9, 9, 9, 10, 10, 10, 10]
const WIDE_SCORE_DELAYS := [9, 9, 9, 9, 10, 10, 10, 10, 10]
const ROW_SCORE_DELAYS := [10, 10, 10, 11, 11, 12, 12, 12, 13]

enum Outcome { PLAYING, MODULE_LOST, CLEARED }

var pilot: Pilot
var wave: CombatWave
var score := 0
var outcome := Outcome.PLAYING
var impact_position := Vector2.ZERO
var impact_age := IMPACT_FRAMES
var impacted_enemy: CombatWave.Enemy
var lost_module := 0
var _elapsed_frames := 0
var _pending_points: Array[int] = []


func _init(
		wave_number := 1, module := 1, start_x := Pilot.START_X, alive_mask := 255, attached := 0,
		points := -1, stage := 0, max_divers := 1, patterns: Array = []
) -> void:
	pilot = Pilot.new(module, start_x, attached)
	wave = CombatWave.new(wave_number, alive_mask, points, stage)
	wave.max_divers = max_divers
	wave.load_patterns(patterns)


func step(input_mask: int) -> void:
	_elapsed_frames += 1
	impact_age = mini(impact_age + 1, IMPACT_FRAMES)
	var credits := 0
	for index in range(_pending_points.size() - 1, -1, -1):
		if _pending_points[index] <= _elapsed_frames:
			_pending_points.remove_at(index)
			score += wave.points_per_hit
			credits += 1
	if outcome != Outcome.PLAYING:
		return
	# Fin de vague : le moteur de tir s'arrête (0x8226 à 0 vers 6185)
	# sans vider les créneaux logiciels. Les projectiles restent figés.
	if wave.remaining == 0:
		if _pending_points.is_empty():
			outcome = Outcome.CLEARED
		return
	var next_frame := pilot.frame + 1
	pilot.step(input_mask, next_frame not in CombatWave.OPENING_CLOCK_HOLDS)
	wave.advance(pilot.frame, pilot.ship_x)
	# 0x823c baisse à l'image du crédit, après le déplacement des ennemis :
	# la règle des moins de 5 survivants joue au pas suivant (pr11c 18679-18681).
	for i in range(credits):
		wave.credit_kill()
	var shots := pilot.active_shots()
	var hits: Array[int] = []
	for index in range(shots.size() - 1, -1, -1):
		if _try_hit(shots[index]):
			hits.append(index)
	# La volée qui termine la vague n'est pas désactivée : pr1 fige
	# 0x8161–0x8168 (drapeau 0x8163 encore à 1, x = 0x40/0x50, y = 0xa7).
	if wave.remaining > 0:
		for index in hits:
			pilot.deactivate_shot(index)
	if wave.remaining == 0:
		if _pending_points.is_empty():
			outcome = Outcome.CLEARED
	elif wave.hits_attached(pilot.ship_x, pilot.attached, pilot.assembly_y_offset):
		outcome = Outcome.MODULE_LOST
		lost_module = wave.hit_module(pilot.ship_x, pilot.attached, pilot.assembly_y_offset)
		pilot.clear_shots()
		impact_position = Vector2(pilot.ship_x, pilot.ship_y() + 6)
		impacted_enemy = null
		impact_age = 0


func score_delay() -> int:
	var remaining := clampi(wave.credited_remaining, 0, 8)
	if wave.falling:
		return SCORE_DELAY
	if wave.rows:
		return ROW_SCORE_DELAYS[remaining]
	if wave.wide_entry:
		return WIDE_SCORE_DELAYS[remaining]
	return NARROW_SCORE_DELAYS[remaining]


func _try_hit(position: Vector2i) -> bool:
	var hit := wave.hit_by(position)
	if hit == null:
		return false
	_pending_points.append(_elapsed_frames + score_delay())
	impacted_enemy = hit
	impact_position = hit.display_position()
	impact_age = 0
	return true
