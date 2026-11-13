extends SceneTree

# Compare l'approche d'amarrage du module II avec les relevés Jeutel.
# Chaque dossier contient trace.csv (entrées et sprites) et dock-registers.csv
# (RAM 0x8222-0x8232, objet 0x8140-0x814e, compteur de boucle 0x8005).

const Pilot = preload("res://pilot.gd")
const Docking = preload("res://docking.gd")
const FIRST_PROBE_FRAME := 6700

var _failures := 0


func _initialize() -> void:
	var folders := OS.get_cmdline_user_args()
	if folders.size() != 2:
		printerr("Arguments attendus : dossier du relevé réussi, dossier du relevé bouton maintenu.")
		quit(2)
		return
	_compare(folders[0], Docking.Stage.SUCCESS, 2600)
	_compare(folders[1], Docking.Stage.APPROACH, 0)
	quit(1 if _failures else 0)


func _byte(hex: String, index: int) -> int:
	return hex.substr(index * 2, 2).hex_to_int()


func _read(path: String, first_frame: int, columns: int) -> Dictionary:
	var rows := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Relevé manquant : %s" % path)
		return rows
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == columns and row[0].is_valid_int() and row[0].to_int() >= first_frame:
			rows[row[0].to_int()] = row
	return rows


func _compare(folder: String, expected_stage: int, expected_bonus: int) -> void:
	var probe := _read(folder.path_join("dock-registers.csv"), FIRST_PROBE_FRAME, 4)
	var trace := _read(folder.path_join("trace.csv"), FIRST_PROBE_FRAME, 9)
	if probe.is_empty() or trace.is_empty():
		return
	var last_frame: int = probe.keys().max()

	# Le prototype commence l'approche quand les deux attentes initiales de la
	# carte sont écoulées. Son premier pas est le tick de contrôle suivant.
	var start := -1
	for frame in range(FIRST_PROBE_FRAME + 1, last_frame + 1):
		var registers: String = probe[frame][1]
		var ticked: bool = probe[frame][3] != probe[frame - 1][3]
		if start < 0:
			if ticked and _byte(probe[frame][3], 0) % 4 == 0 and _byte(probe[frame - 1][1], 2) == 0 and _byte(probe[frame - 1][1], 3) == 0:
				start = frame
			else:
				continue
		if start == frame:
			break
	if start < 0:
		_fail("%s : début de l'approche introuvable" % folder)
		return

	var sprites: String = trace[start - 1][7]
	var dock := Docking.new(2, _byte(sprites, 4), false)
	if dock.position != Vector2i(_byte(sprites, 4), _byte(sprites, 7)):
		_fail("%s : position de départ %s, Jeutel %d,%d" % [
			folder, dock.position, _byte(sprites, 4), _byte(sprites, 7)
		])

	var position_errors := 0
	var velocity_errors := 0
	var clock_errors := 0
	var first_error := -1
	var end_frame := -1
	var compared := 0
	for frame in range(start, last_frame + 1):
		if probe[frame][3] == probe[frame - 1][3]:
			continue
		# Comme en combat, la carte applique les commandes de la frame précédente.
		var held: PackedStringArray = trace[frame - 1]
		dock.step(
			held[3].to_int() * Pilot.LEFT | held[4].to_int() * Pilot.RIGHT | held[5].to_int() * Pilot.FIRE
		)
		var row: PackedStringArray = trace[frame]
		var registers: String = probe[frame][1]
		if _byte(registers, 16) != 0:
			end_frame = frame
			break
		if dock.stage != Docking.Stage.APPROACH:
			end_frame = frame
			break
		compared += 1
		sprites = row[7]
		var wrong := false
		if dock.position != Vector2i(_byte(sprites, 4), _byte(sprites, 7)):
			position_errors += 1
			wrong = true
		if dock._horizontal.velocity != _byte(registers, 0) or dock._vertical.velocity != _byte(registers, 1):
			velocity_errors += 1
			wrong = true
		# Les dixièmes sont en BCD et vont de 10 à 1 sur la carte.
		var clock := "%02x:%d" % [_byte(registers, 14), _byte(registers, 15) & 15]
		if dock.display_clock() != clock:
			clock_errors += 1
			wrong = true
		if wrong and first_error < 0:
			first_error = frame
			printerr("%s : premier écart à la frame %d | prototype %s v %d,%d chrono %s | Jeutel %d,%d v %d,%d chrono %s" % [
				folder.get_file(), frame, dock.position, dock._horizontal.velocity, dock._vertical.velocity,
				dock.display_clock(), _byte(sprites, 4), _byte(sprites, 7), _byte(registers, 0),
				_byte(registers, 1), clock
			])

	print("%s | départ frame %d | %d frames comparées | écarts position %d, vitesse %d, chrono %d" % [
		folder.get_file(), start, compared, position_errors, velocity_errors, clock_errors
	])
	if position_errors or velocity_errors or clock_errors:
		_fail("%s : l'approche diverge de Jeutel" % folder.get_file())

	var jeutel_done: bool = end_frame >= 0 and _byte(probe[end_frame][1], 16) != 0
	if expected_stage == Docking.Stage.SUCCESS:
		if not jeutel_done or dock.stage != Docking.Stage.SUCCESS:
			_fail("%s : amarrage attendu à la même frame, prototype %s, Jeutel %s (frame %d)" % [
				folder.get_file(), Docking.Stage.keys()[dock.stage], "terminé" if jeutel_done else "en cours", end_frame
			])
		elif dock.bonus != expected_bonus:
			_fail("%s : bonus %d, attendu %d" % [folder.get_file(), dock.bonus, expected_bonus])
		else:
			print("%s | amarrage à la frame %d | bonus %d" % [folder.get_file(), end_frame, dock.bonus])
	elif end_frame >= 0:
		_fail("%s : fin inattendue à la frame %d (%s)" % [
			folder.get_file(), end_frame, Docking.Stage.keys()[dock.stage]
		])


func _fail(message: String) -> void:
	_failures += 1
	printerr(message)
