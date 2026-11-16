extends SceneTree

const FlightMotion = preload("res://flight_motion.gd")
const Pilot = preload("res://pilot.gd")
const ArcadeRun = preload("res://arcade_run.gd")
const CombatRound = preload("res://combat_round.gd")
const CombatWave = preload("res://combat_wave.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_track()
	_check_dock_axes()
	_check_falling_exit()
	var view := preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	_check_intermediate_frame(view)
	for practice in [false, true]:
		var expected := _state_at_refresh(view, 60, practice)
		for frequency in [30, 120, 144]:
			_expect(_state_at_refresh(view, frequency, practice) == expected,
				"État de simulation divergent à %d Hz (amarrage : %s)." % [frequency, practice])
	if _failures == 0:
		print("MOUVEMENTS OK · interpolation, amarrage, 16 sorties de météorites, vitesse identique à 30/60/120/144 Hz")
	quit(1 if _failures else 0)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		printerr(message)


func _check_track() -> void:
	var track := FlightMotion.Track.new()
	track.sample(Vector2(20, 50), 0, 2, Vector2.from_angle(deg_to_rad(175)))
	track.sample(Vector2(26, 54), 2, 2, Vector2.from_angle(deg_to_rad(-175)))
	_expect(track.point(Vector2(26, 54), 3) == Vector2(23, 52), "Position intermédiaire d’un ennemi.")
	_expect(track.heading(Vector2(26, 54), Vector2.ZERO, 3).is_equal_approx(Vector2.LEFT), "Rotation par le chemin court.")
	track.sample(Vector2(26, 54), 3, 2)
	_expect(track.point(Vector2(26, 54), 4) == Vector2(26, 54), "Un pas immobile ne doit pas relancer l’interpolation.")
	track.sample(Vector2(220, 54), 5, 2)
	_expect(track.point(Vector2(220, 54), 5) == Vector2(220, 54), "Un retour par le bord doit être instantané.")


func _check_dock_axes() -> void:
	var run := ArcadeRun.new()
	run.practice_docking()
	var motion := FlightMotion.new()
	var from := run.docking.display_position()
	motion.capture_live(run, 0, 0.0, [])
	run.docking.position += Vector2i(1, 1)
	run.docking._horizontal.wait = 0
	run.docking._vertical.wait = 2
	motion.capture_live(run, 1, 0.0, [])
	var current := run.docking.display_position()
	_expect(motion.docking_ship(current, 2).is_equal_approx(from + Vector2(0.25, 1.0 / 12.0)), "Les deux axes d’amarrage ont chacun leur cadence.")
	_expect(motion.docking_ship(current, 5).is_equal_approx(from + Vector2(1, 1.0 / 3.0)), "La progression verticale continue entre les crans.")


func _check_falling_exit() -> void:
	for number in [5, 6]:
		var run := ArcadeRun.new()
		run.combat = CombatRound.new(number, 1, 112, 255, 1, 200, 1)
		var wave := run.combat.wave
		var motion := FlightMotion.new()
		var finished := 0
		for tick in range(1, 450):
			wave.advance(tick, Pilot.START_X)
			motion.capture_live(run, tick, 0.0, [])
			for index in range(wave.enemies.size()):
				var meteor := wave.enemies[index]
				if meteor.alive and meteor.phase == CombatWave.Flight.FALL_EXIT:
					finished |= 1 << index
					_expect(meteor.position.y == 0 and not meteor.has_visible_pose(), "L’ordonnée RAM de sortie ne doit jamais devenir une pose visible.")
					_expect(not motion.enemies[index].valid, "La sortie d’une météorite doit invalider sa trajectoire d’affichage.")
		_expect(finished == 255 and wave.credited_remaining == 0, "Les huit sorties de cette vague doivent laisser la suivante se lancer.")


func _check_intermediate_frame(view: Node) -> void:
	view._restart(false)
	view._advance_frame(Pilot.FRAME_USEC, Pilot.RIGHT)
	var raw := Vector2(view._run.combat.pilot.ship_x, 0)
	_expect(raw.x == Pilot.START_X + Pilot.MOVE_STEP, "Déplacement logique du vaisseau.")
	view._advance_frame(Pilot.FRAME_USEC / 2, Pilot.RIGHT)
	var rendered: Vector2 = view._visual_point(view._motion.ship, raw)
	_expect(rendered.x == Pilot.START_X + Pilot.MOVE_STEP / 2.0, "Une image sans pas de jeu doit dessiner la position intermédiaire.")
	_expect(view._run.frame == 1, "L’interpolation ne doit pas avancer la simulation.")
	view._toggle_pause()
	_expect(view._visual_point(view._motion.ship, raw) == rendered, "La pause doit figer la pose intermédiaire.")
	view._toggle_pause()
	view._advance_frame(Pilot.FRAME_USEC / 2, Pilot.RIGHT)
	_expect(view._visual_point(view._motion.ship, Vector2(view._run.combat.pilot.ship_x, 0)) == raw,
		"La reprise doit poursuivre la pose au pas suivant.")


func _state_at_refresh(view: Node, frequency: int, practice: bool) -> Array:
	view._restart(practice)
	const DURATION_USEC := 600000
	var before := 0
	for index in range(1, ceili(DURATION_USEC * frequency / 1000000.0) + 1):
		var now := mini(DURATION_USEC, roundi(index * 1000000.0 / frequency))
		view._advance_frame(now - before, Pilot.RIGHT)
		before = now
	var run: ArcadeRun = view._run
	_expect(run.frame == DURATION_USEC / Pilot.FRAME_USEC, "Nombre de pas Jeutel en 0,6 s à %d Hz." % frequency)
	if practice:
		return [run.frame, run.docking.position, run.docking.remaining_tenths]
	return [run.frame, run.combat.pilot.ship_x, run.combat.wave.enemies[0].position, run.score()]
