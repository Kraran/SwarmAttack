extends "res://arcade_session.gd"

const Docking = preload("res://docking.gd")
const Pilot = preload("res://pilot.gd")
const Combat = preload("res://combat_round.gd")
enum Kind { WAVE, DOCKING }
const RESULT_DELAY := 30

var kind: Kind
var target: int
var completed := false
var pending := false
var success := false
var _result_frames := 0


func _init(exercise := Kind.DOCKING, number := 1, cycle := 1, bonus_threshold := 30000) -> void:
	super(1, bonus_threshold, false, cycle)
	practice = true
	kind = exercise
	target = clampi(number, 1, 10 if kind == Kind.WAVE else 2)
	var run := current
	if kind == Kind.WAVE:
		run.stage = 0 if target <= 4 else (1 if target <= 8 else 2)
		run.wave_number = target - [0, 2, 6][run.stage]
		run.attached = [1, 3, 7][run.stage]
		run._begin_combat(Pilot.START_X, 255)
	else:
		run.stage = target - 1
		run.attached = 1 if target == 1 else 3
		run.wave_number = run.last_wave()
		run.phase = ArcadeRun.Phase.DOCKING
		run.docking = Docking.new(1, Pilot.START_X, false, run.attached)


func step(input_mask: int) -> void:
	if completed:
		return
	current.step(0 if pending else input_mask, true)
	if pending:
		_result_frames += 1
		completed = _result_frames >= RESULT_DELAY
		return
	if kind == Kind.WAVE:
		if current.combat.outcome == Combat.Outcome.PLAYING:
			return
		success = current.combat.outcome == Combat.Outcome.CLEARED
	else:
		if current.docking.stage in [Docking.Stage.INTRO, Docking.Stage.APPROACH]:
			return
		success = current.docking.stage == Docking.Stage.SUCCESS
	pending = true
