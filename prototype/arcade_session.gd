extends RefCounted

const ArcadeRun = preload("res://arcade_run.gd")

var runs: Array[ArcadeRun] = []
var player := 0
var practice := false
var finished := false
var current: ArcadeRun:
	get:
		return runs[player]


func _init(players := 1, bonus_threshold := 30000, practice_mode := false, starting_cycle := 1) -> void:
	practice = practice_mode
	for index in range(players):
		var run := ArcadeRun.new(1 if practice else starting_cycle)
		run.bonus_threshold = bonus_threshold
		runs.append(run)
	if practice:
		current.practice_docking()


func step(input_mask: int) -> void:
	if finished:
		return
	current.step(input_mask)
	if runs.size() == 2 and (current.turn_ended or current.game_over_finished()):
		var other := 1 - player
		if runs[other].lives > 0:
			player = other
	if current.game_over_finished():
		finished = true
