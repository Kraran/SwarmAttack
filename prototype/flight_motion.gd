extends RefCounted

const ArcadeRun = preload("res://arcade_run.gd")
const Attract = preload("res://attract.gd")
const CombatWave = preload("res://combat_wave.gd")
const Docking = preload("res://docking.gd")
const Pilot = preload("res://pilot.gd")
const Presentation = preload("res://flight_presentation.gd")


class Track:
	const MAX_STEP_SQUARED := 24.0 * 24.0

	var valid := false
	var target := Vector2.ZERO
	var _origin := Vector2.ZERO
	var _from_angle := 0.0
	var _to_angle := 0.0
	var _start_tick := 0
	var _duration := 1

	func sample(value: Vector2, tick: int, period: int, heading := Vector2.ZERO) -> void:
		var angle := heading.angle() if not heading.is_zero_approx() else _to_angle
		if not valid or value.distance_squared_to(target) > MAX_STEP_SQUARED:
			_origin = value
			_from_angle = angle
		elif value == target and is_equal_approx(angle, _to_angle):
			return
		else:
			_origin = _origin.lerp(target, _fraction(tick))
			_from_angle = lerp_angle(_from_angle, _to_angle, _fraction(tick))
		valid = true
		target = value
		_to_angle = angle
		_start_tick = tick
		_duration = period

	func point(value: Vector2, tick: float) -> Vector2:
		return _origin.lerp(target, _fraction(tick)) if valid and value == target else value

	func heading(value: Vector2, fallback: Vector2, tick: float) -> Vector2:
		if not valid or value != target:
			return fallback
		return Vector2.from_angle(lerp_angle(_from_angle, _to_angle, _fraction(tick)))

	func _fraction(tick: float) -> float:
		return clampf((tick - _start_tick) / _duration, 0.0, 1.0)


var ship := Track.new()
var bank := Track.new()
var dock_target := Track.new()
var enemies: Array[Track] = []
var demo_modules: Array[Track] = []
var previous_shots: Array[Vector2i] = []
var shot_tick := -1

var _run: ArcadeRun
var _wave: CombatWave
var _dock: Docking
var _phase := -1
var _demo_style := -1
var _demo_screen := -1
var _dock_x := Track.new()
var _dock_y := Track.new()


func _init() -> void:
	for index in range(8):
		enemies.append(Track.new())
	for index in range(3):
		demo_modules.append(Track.new())


func reset() -> void:
	_run = null
	_wave = null
	_dock = null
	_phase = -1
	_demo_style = -1
	_demo_screen = -1
	ship.valid = false
	_dock_x.valid = false
	_dock_y.valid = false
	dock_target.valid = false
	bank.valid = false
	previous_shots.clear()
	shot_tick = -1
	_clear_tracks(enemies)
	_clear_tracks(demo_modules)


func capture_live(run: ArcadeRun, tick: int, bank_angle: float, shots_before: Array[Vector2i]) -> void:
	var same_run := _run == run
	var same_phase := same_run and _phase == run.phase and _dock == run.docking
	var same_wave := same_phase and _wave == run.combat.wave
	if not same_phase:
		ship.valid = false
		_dock_x.valid = false
		_dock_y.valid = false
		dock_target.valid = false
		bank.valid = false
	if not same_wave:
		_clear_tracks(enemies)
	_run = run
	_phase = run.phase
	_wave = run.combat.wave
	_dock = run.docking
	var automatic_flight := run.phase in [ArcadeRun.Phase.LAUNCH, ArcadeRun.Phase.REPLACEMENT, ArcadeRun.Phase.CYCLE_END]
	var docking_timed_out := run.phase == ArcadeRun.Phase.DOCKING and _dock.stage == Docking.Stage.TIMED_OUT
	bank.sample(Vector2(0.0 if automatic_flight or docking_timed_out else bank_angle, 0), tick, 3)

	var pilot := run.combat.pilot
	match run.phase:
		ArcadeRun.Phase.COMBAT:
			ship.sample(Vector2(pilot.ship_x, pilot.assembly_y_offset), tick, 1)
			_capture_enemies(_wave, tick)
		ArcadeRun.Phase.DOCKING:
			var position := _dock.display_position()
			var intervals := _dock.movement_intervals()
			_dock_x.sample(Vector2(position.x, 0), tick, intervals.x)
			_dock_y.sample(Vector2(0, position.y), tick, intervals.y)
			dock_target.sample(Vector2(0, _dock.target_y), tick, Docking.BOARD_FRAMES_PER_CONTROL)
		ArcadeRun.Phase.CYCLE_END:
			ship.sample(Vector2(pilot.ship_x, pilot.assembly_y_offset - run.cycle_end_rise()), tick, 1)

	if same_wave and run.phase == ArcadeRun.Phase.COMBAT:
		previous_shots = shots_before
	else:
		previous_shots.clear()
	shot_tick = tick


func _capture_enemies(wave: CombatWave, tick: int) -> void:
	for index in range(wave.enemies.size()):
		var enemy := wave.enemies[index]
		if not enemy.has_visible_pose():
			enemies[index].valid = false
			continue
		var heading := Vector2(enemy.velocity)
		if not wave.rows and not wave.falling and not wave.wide_entry:
			heading = Presentation.ring_axis(heading, enemy.opening_left if enemy.phase == CombatWave.Flight.OPENING else 0)
		var period := 1 if wave.rows else 2
		if enemy.phase in [CombatWave.Flight.ENTRY_CURVE, CombatWave.Flight.FORMATION, CombatWave.Flight.DIVE,
				CombatWave.Flight.CIRCLING, CombatWave.Flight.RETURNING, CombatWave.Flight.ROW_ZIGZAG]:
			period *= enemy.cadence
		enemies[index].sample(enemy.display_position(), tick, period, heading)


func capture_demo(attract: Attract, tick: int) -> void:
	var record := attract.demo_objects()
	if record.is_empty():
		_demo_style = -1
		_demo_screen = -1
		_clear_tracks(demo_modules)
		_clear_tracks(enemies)
		return
	var style := record[Attract.STYLE_OFFSET]
	if style != _demo_style:
		_clear_tracks(enemies)
		_demo_style = style
	var period := 1 if style >> 1 == Presentation.EnemyKind.ROW else 2
	var screen := attract.demo_value(Attract.Column.SCREEN)
	if screen != _demo_screen:
		_clear_tracks(demo_modules)
		_demo_screen = screen
	var step := attract.demo_value(Attract.Column.STEP)
	var module_period := Docking.BOARD_FRAMES_PER_CONTROL if step in [2, 5] else 1
	for index in range(enemies.size()):
		var offset := 2 * index
		var track := enemies[index]
		_sample_demo_point(track, record, offset, tick, period)
	for index in range(demo_modules.size()):
		_sample_demo_point(demo_modules[index], record, Attract.MODULE_OFFSET + 2 * index, tick, module_period)


func _sample_demo_point(track: Track, record: PackedByteArray, offset: int, tick: int, period: int) -> void:
	if record[offset] == 255:
		track.valid = false
		return
	var point := Vector2(record[offset], record[offset + 1])
	var direction := point - track.target if track.valid else Vector2.DOWN
	track.sample(point, tick, period, direction)


func _clear_tracks(tracks: Array[Track]) -> void:
	for track in tracks:
		track.valid = false


func projectile(point: Vector2i, tick: float) -> Vector2:
	if point + Vector2i(0, Pilot.SHOT_STEP) not in previous_shots:
		return Vector2(point)
	return Vector2(point) + Vector2(0, Pilot.SHOT_STEP * clampf(1.0 - (tick - shot_tick), 0.0, 1.0))


func docking_ship(point: Vector2, tick: float) -> Vector2:
	return Vector2(_dock_x.point(Vector2(point.x, 0), tick).x, _dock_y.point(Vector2(0, point.y), tick).y)
