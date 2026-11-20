extends SceneTree

const Training = preload("res://training_session.gd")
const Combat = preload("res://combat_round.gd")
const Run = preload("res://arcade_run.gd")
const Docking = preload("res://docking.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for cycle in [1, 2]:
		for number in range(1, 11):
			var session := Training.new(Training.Kind.WAVE, number, cycle)
			var stage := 0 if number <= 4 else (1 if number <= 8 else 2)
			_expect(session.practice and session.current.cycle == cycle and session.current.stage == stage
				and session.current.wave_number == number - [0, 2, 6][stage]
				and session.current.attached == [1, 3, 7][stage], "Configuration vague %d / cycle %d" % [number, cycle])
			session.current.combat.outcome = Combat.Outcome.CLEARED
			session.step(0)
			for frame in Training.RESULT_DELAY:
				session.step(0)
			_expect(session.completed and session.success and session.current.phase == Run.Phase.COMBAT
				and session.current.stage == stage and not session.finished, "Fin isolée de la vague")
	for target in [1, 2]:
		for outcome in [Docking.Stage.SUCCESS, Docking.Stage.COLLISION, Docking.Stage.TIMED_OUT]:
			var session := Training.new(Training.Kind.DOCKING, target, 2)
			_expect(session.current.attached == (1 if target == 1 else 3)
				and session.current.docking.is_i_and_ii() == (target == 2), "Modules de l’amarrage")
			session.current.docking.stage = outcome
			for frame in Training.RESULT_DELAY + 1:
				session.step(0)
			_expect(session.completed and session.success == (outcome == Docking.Stage.SUCCESS)
				and session.current.phase == Run.Phase.DOCKING, "Issue de l’amarrage isolé")
	var failed := Training.new(Training.Kind.WAVE, 7)
	failed.current.combat.outcome = Combat.Outcome.MODULE_LOST
	for frame in Training.RESULT_DELAY + 1:
		failed.step(0)
	_expect(failed.completed and not failed.success, "Échec après perte du module")
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	var scores = view._profile.scores.duplicate()
	_key(view, KEY_F2)
	_expect(view._training.opened and view._attract_active, "F2 ouvre le sélecteur")
	view._training.kind = Training.Kind.WAVE
	view._training.target = 10
	view._training.difficulty = 1
	view._training.choice = 3
	_key(view, KEY_ENTER)
	_expect(view._session is Training and view._run.stage == 2 and view._run.cycle == 2, "Démarrage du choix vétéran")
	view._run.combat.outcome = Combat.Outcome.CLEARED
	for frame in Training.RESULT_DELAY + 1:
		view._advance_frame(view.Pilot.FRAME_USEC, 0)
	_expect(view._training.result_open and view._profile.scores == scores and view._scores.entry == null, "Bilan hors classement")
	_key(view, KEY_R)
	_expect(not view._training.result_open and view._run.combat.outcome == Combat.Outcome.PLAYING
		and view._run.stage == 2 and view._run.cycle == 2, "Relance du même exercice")
	view._return_to_title()
	view._restart(false)
	var run_before = view._run
	_key(view, KEY_F2)
	_key(view, KEY_ESCAPE)
	_expect(view._pause.active and view._run == run_before and not view._training.opened, "Annuler conserve la partie en pause")
	var b_button := InputEventJoypadButton.new()
	b_button.button_index = JOY_BUTTON_B
	b_button.pressed = true
	view._input(b_button)
	_expect(view._pause.asking == view._pause.HOME and view._run == run_before and not view._attract_active,
		"B dans la pause demande confirmation au lieu de revenir à l'accueil")
	view._input(b_button)
	_expect(view._pause.asking == -1 and view._pause.active and view._run == run_before, "B annule et garde la partie")
	view._pause.choice = view._pause.HOME
	_key(view, KEY_ENTER)
	_key(view, KEY_LEFT)
	_key(view, KEY_ENTER)
	_expect(view._attract_active, "Oui revient à l'accueil")
	view._restart(false)
	run_before = view._run
	_key(view, KEY_ESCAPE)
	view._options.set_open(true)
	view._options.choice = view.OptionsMenu.TRAINING
	_key(view, KEY_ENTER)
	_expect(view._training.opened and not view._options.opened, "Options ouvre le sélecteur d'entraînement")
	_key(view, KEY_ESCAPE)
	_expect(view._options.opened and view._options.choice == view.OptionsMenu.TRAINING
		and view._pause.active and view._run == run_before, "Retour exact vers Options sans perdre la partie en pause")
	if failures == 0:
		print("TRAINING OK: 10 vagues, 2 cycles, 2 amarrages, issues, relance, navigation et scores isolés.")
	quit(1 if failures else 0)

func _key(view: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	view._input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
