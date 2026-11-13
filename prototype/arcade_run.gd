extends RefCounted

const Pilot = preload("res://pilot.gd")
const CombatRound = preload("res://combat_round.gd")
const Docking = preload("res://docking.gd")
const WAVES_BEFORE_DOCK := 4
const REPLACEMENT_FRAMES := 120

enum Phase { COMBAT, REPLACEMENT, DOCKING, GAME_OVER, NO_PARTNER }

var phase := Phase.COMBAT
var wave_number := 1
var module := 1
var combat := CombatRound.new()
var docking: Docking
var frame := 0
var _previous_score := 0
var _replacement_left := 0


func score() -> int:
	var points := _previous_score + combat.score
	if docking != null:
		points += docking.credited_bonus()
	return points


func practice_docking() -> void:
	phase = Phase.DOCKING
	docking = Docking.new(1, Pilot.START_X, false)


func step(input_mask: int) -> void:
	frame += 1
	match phase:
		Phase.COMBAT:
			combat.step(input_mask)
			if combat.outcome == CombatRound.Outcome.MODULE_LOST:
				phase = Phase.REPLACEMENT
				_replacement_left = REPLACEMENT_FRAMES
			elif combat.outcome == CombatRound.Outcome.CLEARED:
				_advance_from_clear()
		Phase.REPLACEMENT:
			combat.step(0)
			_replacement_left -= 1
			if _replacement_left == 0:
				if module == 3:
					phase = Phase.GAME_OVER
				else:
					module += 1
					_begin_combat(Pilot.START_X, combat.wave.survivors())
		Phase.DOCKING:
			docking.step(input_mask)


func _advance_from_clear() -> void:
	if wave_number < WAVES_BEFORE_DOCK:
		wave_number += 1
		_begin_combat(combat.pilot.ship_x, 255)
	elif module == 3:
		phase = Phase.NO_PARTNER
	else:
		phase = Phase.DOCKING
		docking = Docking.new(module, combat.pilot.ship_x)


func _begin_combat(ship_x: int, alive_mask: int) -> void:
	_previous_score += combat.score
	combat = CombatRound.new(wave_number, module, ship_x, alive_mask)
	phase = Phase.COMBAT
