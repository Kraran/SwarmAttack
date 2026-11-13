extends SceneTree

const ModuleOne = preload("res://pilot.gd")
const FirstWaveRound = preload("res://combat_round.gd")
const FIRST_PLAY_FRAME := 540
const COLUMNS := "frame,coin,start,left,right,fire,tile_scroll,sprite_ram,bullet_ram"

var _failures := 0


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.size() != 3:
		printerr("Arguments attendus : dossier MAME, trace déplacement + tir, trace expiration.")
		quit(2)
		return
	_compare_movement(paths[0].path_join("movement.csv"), 849, 11)
	_compare_movement(paths[0].path_join("opposed.csv"), 649, 1)
	_compare_shots(paths[0].path_join("fire.csv"), 814)
	_compare_shots(paths[0].path_join("fire_tap.csv"), 698)
	_compare_shots(paths[0].path_join("fire_busy.csv"), 699)
	_compare_shots(paths[1], 574)
	_compare_shots(paths[2], 609)
	_compare_opening(paths[0].path_join("idle.csv"))
	_compare_impacts(paths[1], 595, 1)
	_compare_impacts(paths[0].path_join("fire_tap.csv"), 798, 2)
	_check_ship_contact()
	quit(1 if _failures else 0)


func _read_rows(path: String, last_frame: int) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_line().strip_edges() != COLUMNS:
		_fail("Trace manquante ou en-tête invalide : %s" % path)
		return rows
	for index in range(last_frame + 1):
		var row := file.get_csv_line()
		if row.size() != 9 or not row[0].is_valid_int() or row[0].to_int() != index:
			_fail("%s : ligne invalide pour la frame %d" % [path, index])
			rows.clear()
			break
		rows.append(row)
	return rows


func _input_mask(row: PackedStringArray) -> int:
	return (
		row[3].to_int() * ModuleOne.LEFT
		| row[4].to_int() * ModuleOne.RIGHT
		| row[5].to_int() * ModuleOne.FIRE
	)


func _compare_movement(path: String, last_frame: int, observed_pauses: int) -> void:
	var rows := _read_rows(path, last_frame)
	if rows.is_empty():
		return
	var from_trace := ModuleOne.new()
	var continuous := ModuleOne.new()
	var previous_x := ModuleOne.START_X
	var pauses := 0
	var different := 0
	var max_error := 0
	for index in range(FIRST_PLAY_FRAME, last_frame + 1):
		var mask := _input_mask(rows[index - 1])
		var actual := rows[index][6].substr(100, 2).hex_to_int() - 8
		continuous.step(mask)
		if continuous.ship_x != actual:
			different += 1
			max_error = maxi(max_error, absi(continuous.ship_x - actual))
		from_trace.ship_x = previous_x
		from_trace.step(mask)
		if from_trace.ship_x != actual:
			if actual == previous_x:
				pauses += 1
			else:
				_fail("%s : déplacement à la frame %d, obtenu %d, attendu %d" % [
					path, index, from_trace.ship_x, actual
				])
		previous_x = actual
	if pauses != observed_pauses:
		_fail("%s : %d pauses constatées, %d attendues" % [path, pauses, observed_pauses])
	print("%s | %d pauses Jeutel | %d positions différentes sur %d | écart max %d px" % [
		path.get_file(), pauses, different, last_frame - FIRST_PLAY_FRAME + 1, max_error
	])


func _compare_shots(path: String, last_frame: int) -> void:
	var rows := _read_rows(path, last_frame)
	if rows.is_empty():
		return
	var simulation := ModuleOne.new()
	var failures_before := _failures
	for index in range(FIRST_PLAY_FRAME, last_frame + 1):
		simulation.step(_input_mask(rows[index - 1]))
		var registers := rows[index][8]
		var x := registers.substr(2, 2).hex_to_int()
		var y := registers.substr(6, 2).hex_to_int()
		if simulation.shot_active != (x != 0) or (
			x != 0 and simulation.shot_position != Vector2i(x - 17, 251 - y)
		):
			_fail("%s : état du projectile divergent à la frame %d" % [path, index])
	if _failures == failures_before:
		print("%s | %d frames identiques pour le projectile" % [
			path, last_frame - FIRST_PLAY_FRAME + 1
		])


func _compare_opening(path: String) -> void:
	var rows := _read_rows(path, 657)
	if rows.is_empty():
		return
	var round := FirstWaveRound.new()
	var failures_before := _failures
	for index in range(FIRST_PLAY_FRAME, rows.size()):
		round.step(0)
		if index < 571:
			if not round.wave.enemies.is_empty():
				_fail("Apparition anticipée à la frame %d" % index)
			continue
		var registers := rows[index][7]
		if round.wave.enemies.size() != 8:
			_fail("Huit cibles attendues à la frame %d" % index)
			break
		for slot in range(8):
			var expected := Vector2i(
				registers.substr(slot * 8, 2).hex_to_int(),
				registers.substr(slot * 8 + 6, 2).hex_to_int()
			)
			if round.wave.enemies[slot].position != expected:
				_fail("Trajectoire divergente à la frame %d pour la cible %d" % [index, slot])
	if _failures == failures_before:
		print("Formation | positions des 8 cibles identiques sur 87 frames")


func _compare_impacts(path: String, last_frame: int, expected_count: int) -> void:
	var rows := _read_rows(path, last_frame)
	if rows.is_empty():
		return
	var round := FirstWaveRound.new()
	var jeutel := {}
	var prototype := {}
	for index in range(FIRST_PLAY_FRAME, rows.size()):
		round.step(_input_mask(rows[index - 1]))
		var sprites := rows[index][7]
		for slot in range(round.wave.enemies.size()):
			if not jeutel.has(slot) and sprites.substr(slot * 8 + 4, 2) == "0c":
				jeutel[slot] = index
			if not prototype.has(slot) and not round.wave.enemies[slot].alive:
				prototype[slot] = index
	if jeutel.size() != expected_count or prototype.size() != expected_count:
		_fail("%s : %d impacts attendus, Jeutel %d, prototype %d" % [
			path, expected_count, jeutel.size(), prototype.size()
		])
		return
	for slot in jeutel:
		if not prototype.has(slot) or absi(prototype[slot] - jeutel[slot]) > 1:
			_fail("%s : impact différent pour la cible %d, Jeutel %s, prototype %s" % [
				path, slot, jeutel[slot], prototype.get(slot, "aucun")
			])
			continue
		print("Impact cible %d | Jeutel %d | prototype %d" % [slot, jeutel[slot], prototype[slot]])
	if round.score != expected_count * 50:
		_fail("%s : score %d, attendu %d" % [path, round.score, expected_count * 50])


func _check_ship_contact() -> void:
	for offset in [-10, -9, 11, 12]:
		var round := FirstWaveRound.new()
		for index in range(32):
			round.step(0)
		round.wave.enemies[0].position = Vector2i(120 + offset, 192)
		round.step(0)
		var expected: bool = offset in [-9, 11]
		if (round.outcome == FirstWaveRound.Outcome.MODULE_LOST) != expected:
			_fail("Collision vaisseau : résultat incorrect pour un décalage de %d" % offset)


func _fail(message: String) -> void:
	_failures += 1
	printerr(message)
