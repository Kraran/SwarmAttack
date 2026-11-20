extends SceneTree

const Profile = preload("res://arcade_profile.gd")
const Pilot = preload("res://pilot.gd")
const Run = preload("res://arcade_run.gd")
const Docking = preload("res://docking.gd")
var view: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = Profile.new()
	_end_game([0])
	_expect(view._scores.results_open and view._scores.entry == null and view._scores.rows[0].rank == 0,
		"Toute partie normale affiche son bilan")
	_key(KEY_ENTER)
	_expect(view._scores.results_page == 1, "Accès au classement depuis le bilan")
	_key(KEY_ESCAPE)
	_expect(view._scores.results_page == 0 and view._scores.results_open, "Retour du classement vers le bilan")
	_key(KEY_ESCAPE)
	_expect(not view._scores.results_open and view._attract_active, "Retour du bilan vers l’accueil")
	_end_game([9000])
	_initials("ABC")
	_key(KEY_ENTER)
	_expect(view._scores.rows[0].score == 9000 and view._scores.rows[0].rank == 1 and view._scores.rows[0].initials == "ABC",
		"Score et rang réellement enregistrés dans le bilan")
	_end_game([14000,14000])
	_initials("ONE")
	_key(KEY_ENTER)
	_initials("TWO")
	_key(KEY_ENTER)
	_expect(view._scores.results_open and view._scores.rows.size() == 2
		and view._scores.rows[0].rank == 1 and view._scores.rows[1].rank == 2, "Deux nouveaux scores à égalité gardent leurs rangs")
	_expect(view._hud_layer.state[3] == 14000 and view._hud_layer.state[4] == 14000,
		"Les scores finaux restent affichés dans le HUD")
	_expect(view._scores.rows[0].cycle == 2 and view._scores.rows[1].cycle == 3
		and view._scores.rows[0].docks == 3 and view._scores.rows[1].docks == 4, "Bilan individuel en duo")
	_pad(JOY_BUTTON_A)
	_expect(view._scores.results_page == 1, "La manette ouvre le classement")
	_pad(JOY_BUTTON_B)
	_expect(view._scores.results_page == 0, "La manette revient au bilan")
	_stick(0.9)
	_expect(view._scores.result_choice == 1, "Le stick bas sélectionne Accueil")
	_stick(0.95)
	_expect(view._scores.result_choice == 1, "Le stick maintenu ne répète pas")
	_stick(0.0)
	_stick(-0.9)
	_expect(view._scores.result_choice == 0, "Le stick haut revient au classement")
	_stick(0.0)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_A)
	_expect(not view._scores.results_open, "La manette sélectionne Accueil puis valide")
	view._profile.difficulty = 1
	_end_game([18000],false,true)
	_initials("VET")
	_key(KEY_ENTER)
	_expect(view._score_mode() == 1 and view._profile.scores_for(1)[0] == 18000
		and view._profile.scores_for(0)[0] == 14000, "Le bilan et le record correspondent à la difficulté jouée")
	_key(KEY_ESCAPE)
	view._profile.scores = PackedInt32Array([9000,8000,7000,6000,5000,4000,3000,2000,1800,1000])
	view._profile.initials = PackedStringArray(["OLD","OLD","OLD","OLD","OLD","OLD","OLD","OLD","OLD","OLD"])
	_end_game([1500,1200])
	_key(KEY_ENTER)
	_expect(view._scores.entry == null and view._scores.results_open and view._scores.rows[0].rank == 10
		and view._scores.rows[1].rank == 0, "Le joueur évincé du top 10 conserve son bilan sans rang enregistré")
	_end_game([10000])
	_key(KEY_ESCAPE)
	_expect(view._scores.results_open and view._scores.rows[0].rank == 0 and view._profile.scores[0] == 9000,
		"Passer les initiales affiche le bilan sans inventer de rang")
	var profile_scores: PackedInt32Array = view._profile.scores.duplicate()
	_end_game([99999],true)
	_expect(not view._scores.results_open and view._scores.entry == null and view._profile.scores == profile_scores,
		"L’entraînement ne produit pas de résultat classé")
	_docking_statistics()
	if failures == 0:
		print("RESULTS OK: solo, duo, rangs, égalités, difficulté, bilan hors classement, navigation et amarrages.")
	quit(1 if failures else 0)

func _docking_statistics() -> void:
	for stage in [Docking.Stage.SUCCESS,Docking.Stage.TIMED_OUT,Docking.Stage.COLLISION]:
		var run := Run.new()
		run.practice_docking()
		run.docking.stage = stage
		run._resume_from_docking(0)
		_expect(run.successful_dockings == int(stage == Docking.Stage.SUCCESS), "Seuls les amarrages réussis sont comptés")
		if stage == Docking.Stage.SUCCESS:
			run.practice_docking()
			run.docking.stage = stage
			run._resume_from_docking(0)
			_expect(run.successful_dockings == 2, "Les succès se cumulent dans la partie")

func _end_game(scores: Array[int], practice := false, change_next_mode := false) -> void:
	view._restart(practice,scores.size())
	for index in scores.size():
		var run: Run = view._session.runs[index]
		run.combat.score = scores[index]
		run.cycle = 2+index
		run.successful_dockings = 3+index
	if change_next_mode:
		view._profile.difficulty = 0
	view._session.finished = true
	view._advance_frame(Pilot.FRAME_USEC,0)

func _initials(value: String) -> void:
	for character in value:
		var event := InputEventKey.new()
		event.keycode = character.unicode_at(0)
		event.unicode = character.unicode_at(0)
		event.pressed = true
		view._input(event)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)

func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	view._input(event)

func _stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	view._input(event)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

