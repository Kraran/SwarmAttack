extends SceneTree

const FlightMotion = preload("res://flight_motion.gd")
const Pilot = preload("res://pilot.gd")
const ArcadeRun = preload("res://arcade_run.gd")
const CombatRound = preload("res://combat_round.gd")
const CombatWave = preload("res://combat_wave.gd")
const FlightView = preload("res://flight_view.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_track()
	_check_dock_axes()
	_check_falling_exit()
	_check_capsule_exit()
	_check_exhaust_motion()
	var view := preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	_check_intermediate_frame(view)
	for phase in [ArcadeRun.Phase.LAUNCH, ArcadeRun.Phase.COMBAT, ArcadeRun.Phase.DOCKING]:
		var expected := _state_at_refresh(view, 60, phase)
		for frequency in [30, 120, 144]:
			_expect(_state_at_refresh(view, frequency, phase) == expected,
				"État de simulation divergent à %d Hz (phase %d)." % [frequency, phase])
	if _failures == 0:
		print("MOUVEMENTS OK · décollage, interpolation, amarrage, météo, vitesse identique à 30/60/120/144 Hz")
	quit(1 if _failures else 0)


func _check_exhaust_motion() -> void:
	var motion := FlightView.ExhaustMotion.new()
	_expect(motion.sample(Vector2(112,200),0) == 0.0,"Réacteur au repos lors de l'apparition")
	for frame in range(1,13):
		motion.sample(Vector2(112+frame*2,200),frame)
	_expect(motion.level > 0.9,"Le jet augmente progressivement pendant le déplacement")
	var moving := motion.level
	motion.sample(Vector2(136,200),12)
	_expect(motion.level == moving,"La pause fige aussi la poussée visuelle")
	motion.sample(Vector2(136,200),13)
	_expect(motion.level > 0.0 and motion.level < moving,"Le retour au repos est progressif")
	for frame in range(14,74):
		motion.sample(Vector2(136,200),frame)
	_expect(motion.level < 0.001,"À l'arrêt ou en butée, le jet retrouve sa taille normale")
	motion.sample(Vector2(138,200),74)
	motion.sample(Vector2(20,200),75)
	_expect(motion.level == 0.0,"Une téléportation n'est pas une poussée")
	motion.reset()
	_expect(motion.sample(Vector2(112,200),0) == 0.0,"Aucune poussée héritée d'un module masqué")
	var reference := _exhaust_at_refresh(60)
	for frequency in [30,120,144]:
		_expect(is_equal_approx(_exhaust_at_refresh(frequency),reference),"Poussée indépendante de la fréquence d'affichage à %d Hz" % frequency)


func _exhaust_at_refresh(frequency: int) -> float:
	var motion := FlightView.ExhaustMotion.new()
	motion.sample(Vector2(100,200),0)
	for index in range(1,frequency+1):
		var frame := index * 60.0 / frequency
		motion.sample(Vector2(100+frame,200),frame)
	for index in range(1,frequency+1):
		var frame := 60.0 + index * 12.0 / frequency
		motion.sample(Vector2(160,200),frame)
	return motion.level


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


func _check_capsule_exit() -> void:
	for number in [3, 4]:
		var run := ArcadeRun.new()
		run.combat = CombatRound.new(number, 1, Pilot.START_X, 255, 1, 100, 2)
		var wave := run.combat.wave
		var motion := FlightMotion.new()
		var saw_wrap := false
		for tick in range(1, 300):
			wave.advance(tick, Pilot.START_X)
			motion.capture_live(run, tick, 0.0, [])
			for index in range(wave.enemies.size()):
				var capsule := wave.enemies[index]
				if capsule.phase == CombatWave.Flight.ROW_EXIT and capsule.position.y < 8:
					saw_wrap = true
					_expect(not capsule.has_visible_pose() and not motion.enemies[index].valid,
						"La sortie basse d’une capsule ne doit jamais afficher son ancienne abscisse en haut du terrain.")
		_expect(saw_wrap, "La vague doit contenir une sortie basse de capsule.")


func _check_intermediate_frame(view: Node) -> void:
	view._restart(false)
	var run: ArcadeRun = view._run
	var separation := ArcadeRun.ENTRANCE_HIDDEN + ArcadeRun.ENTRANCE_RISE - 1
	_expect(run.phase == ArcadeRun.Phase.LAUNCH and run.entrance_module_y(1, 0) == Pilot.FIELD_SIZE.y,
		"Le vaisseau doit commencer hors champ.")
	_expect(run.entrance_module_y(1, separation) == 120 and run.entrance_module_y(2, separation) == 128
		and run.entrance_module_y(3, separation) == 136, "Les trois modules montent assemblés.")
	_expect(run.entrance_module_y(1, separation + 0.5) == 120 and run.entrance_module_y(2, separation + 0.5) == 128.5
		and run.entrance_module_y(3, separation + 0.5) == 136.5, "Les modules inférieurs se séparent progressivement.")
	var descent_start := separation + ArcadeRun.ENTRANCE_PAUSE
	_expect(run.entrance_module_y(2, descent_start) >= Pilot.FIELD_SIZE.y
		and run.entrance_module_y(1, descent_start + 0.5) == 120.5, "Le module I descend après la sortie des deux autres.")
	_advance_launch(view, Pilot.RIGHT | Pilot.FIRE)
	_expect(run.phase == ArcadeRun.Phase.COMBAT and run.combat.pilot.frame == 0 and run.attached == 1
		and run.combat.pilot.ship_x == Pilot.START_X and run.combat.wave.enemies.is_empty(),
		"Le décollage doit finir avec le module I centré et la première vague au début.")
	view._advance_frame(Pilot.FRAME_USEC, Pilot.RIGHT | Pilot.FIRE)
	_expect(run.combat.pilot.active_shots().is_empty(), "Un tir maintenu pendant le décollage ne doit pas partir à la reprise.")
	var raw := Vector2(view._run.combat.pilot.ship_x, 0)
	_expect(raw.x == Pilot.START_X + Pilot.MOVE_STEP, "Déplacement logique du vaisseau.")
	view._advance_frame(Pilot.FRAME_USEC / 2, Pilot.RIGHT)
	var rendered: Vector2 = view._visual_point(view._motion.ship, raw)
	_expect(rendered.x == Pilot.START_X + Pilot.MOVE_STEP / 2.0, "Une image sans pas de jeu doit dessiner la position intermédiaire.")
	_expect(run.frame == ArcadeRun.ENTRANCE_FRAMES + 1, "L’interpolation ne doit pas avancer la simulation.")
	view._toggle_pause()
	_expect(view._visual_point(view._motion.ship, raw) == rendered, "La pause doit figer la pose intermédiaire.")
	view._toggle_pause()
	view._advance_frame(Pilot.FRAME_USEC / 2, Pilot.RIGHT)
	_expect(view._visual_point(view._motion.ship, Vector2(view._run.combat.pilot.ship_x, 0)) == raw,
		"La reprise doit poursuivre la pose au pas suivant.")


func _advance_launch(view: Node, input := 0) -> void:
	for frame in range(ArcadeRun.ENTRANCE_FRAMES):
		view._advance_frame(Pilot.FRAME_USEC, input)


func _state_at_refresh(view: Node, frequency: int, phase: int) -> Array:
	view._restart(phase == ArcadeRun.Phase.DOCKING)
	if phase == ArcadeRun.Phase.COMBAT:
		_advance_launch(view)
	var initial_frame: int = view._run.frame
	const DURATION_USEC := 600000
	var before := 0
	for index in range(1, ceili(DURATION_USEC * frequency / 1000000.0) + 1):
		var now := mini(DURATION_USEC, roundi(index * 1000000.0 / frequency))
		view._advance_frame(now - before, Pilot.RIGHT)
		before = now
	var run: ArcadeRun = view._run
	_expect(run.frame - initial_frame == DURATION_USEC / Pilot.FRAME_USEC, "Nombre de pas de simulation en 0,6 s à %d Hz." % frequency)
	if phase == ArcadeRun.Phase.DOCKING:
		return [run.frame, run.docking.position, run.docking.remaining_tenths]
	if phase == ArcadeRun.Phase.LAUNCH:
		return [run.frame, run.entrance_module_y(1, run.frame), run.combat.pilot.frame]
	return [run.frame, run.combat.pilot.ship_x, run.combat.wave.enemies[0].position, run.score()]
