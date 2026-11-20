extends RefCounted

# Cycle d'attraction relevé sur pr10e-attract (scénario attract, 20 000 images,
# sonde 8000-83ff depuis 0). Deux cycles complets, identiques au rythme de
# 0x8005 : texte de présentation, tableau des scores, démo, puis retour au texte.
const DemoData = preload("res://attract_demo_data.gd")
const VisualData = preload("res://attract_visual_data.gd")
const Language = preload("res://arcade_language.gd")
const VISUAL_STRIDE := VisualData.STRIDE
const MODULE_OFFSET := VisualData.MODULE_OFFSET
const STYLE_OFFSET := VisualData.STYLE_OFFSET
const DIVING_OFFSET := VisualData.DIVING_OFFSET
const THRUST_OFFSET := VisualData.THRUST_OFFSET

# Texte de présentation : 0x801d = 0x20 puis 0x60 de 9619 à 10367, soit
# 748 images murales dont 3 figées (745 au rythme de 0x8005). Depuis la mise
# sous tension : 107 → 855, 748 images dont 4 figées.
const TITLE_TEXT_FRAMES := 745
# Keep the ten-entry table visible for about eight seconds.
# The reference board displayed five entries for 123 logic frames.
const SCORE_TABLE_FRAMES := 480
# Démo : de 0x8097 = 3 (978, 10490) au retour à 0 (9619, 19134) ; 8641 et 8644
# images murales, 8526 images de boucle dans les deux cycles.
const DEMO_FRAMES := DemoData.LENGTH

# Apparition des lignes du texte, en images depuis le début du texte. Lecture
# sur les PNG pris toutes les 10 images (précision ±10) : première image où la
# ligne est entamée, première image où elle est complète.
const TITLE_LINES := [
	["ALERTE ORBITALE", 21, 151],
	[Language.TITLE, 181, 251],
	["ASSEMBLEZ VOTRE VAISSEAU", 501, 601],
	["TENEZ LA LIGNE", 641, 641],
	["ESPACE POUR JOUER", 661, 661],
]

# Valeurs de 0x801d pendant la démo.
const SCREEN_PLAY := 0x00
const SCREEN_RESULT := 0x40
const SCREEN_TIMEOUT := 0x80
const SCREEN_TIMEOUT_TEXT := 0xC0

# Index des colonnes de DemoData.ROWS.
enum Column { LOOP, X, Y, LIVES, FLAG, SCREEN, STEP, CLOCK, MODULE_I, MODULE_II, MODULE_III, VOLLEY }

enum Screen { TITLE_TEXT, SCORE_TABLE, DEMO }

var frame := 0
var _row := 0
# Données de la démo, avec la retouche du second amarrage (voir _patch_second_docking).
static var _rows: Array = []
static var _visuals := PackedByteArray()
static var _events: Array = []

# Second amarrage de la démo. Sur la borne, le I + II manque le III, glisse
# à côté de lui puis le temps expire : à l'écran, le vaisseau traverse le
# module en attente. La démo montre plutôt un amarrage réussi : approche
# freinée au-dessus du III, contact, écran bonus de 305 images, puis reprise
# du combat avec I + II + III jusqu'à la perte du module II (boucle 5504),
# où le III repasse en réserve comme en partie.
const SECOND_DOCKING_PATH := 4240
const SECOND_DOCKING_CONTACT := 4822
const SECOND_DOCKING_RESUME := 5127
const SECOND_DOCKING_LOSS := 5504
const DOCKED_X := 112
const DOCKED_Y := 200
# Durée de vie des explosions, en images de boucle.
const ENEMY_BURST_FRAMES := 18
const SHIP_BURST_FRAMES := 36
enum Event { FRAME, SHIP, X, Y, STYLE }


func cycle_length() -> int:
	return TITLE_TEXT_FRAMES + SCORE_TABLE_FRAMES + DEMO_FRAMES


func step() -> void:
	frame += 1
	if frame >= cycle_length():
		frame = 0
	_sync_row()


func screen() -> Screen:
	if frame < TITLE_TEXT_FRAMES:
		return Screen.TITLE_TEXT
	if frame < TITLE_TEXT_FRAMES + SCORE_TABLE_FRAMES:
		return Screen.SCORE_TABLE
	return Screen.DEMO


func demo_frame() -> int:
	return frame - TITLE_TEXT_FRAMES - SCORE_TABLE_FRAMES


# Fraction visible d'une ligne du texte (0 à 1).
func title_line_progress(index: int, fraction := 0.0) -> float:
	if screen() != Screen.TITLE_TEXT:
		return 0.0
	var line: Array = TITLE_LINES[index]
	if frame < line[1]:
		return 0.0
	if frame >= line[2]:
		return 1.0
	return (float(frame - line[1]) + fraction) / float(line[2] - line[1])


# État relevé de la démo à l'image courante (dernière ligne de la table).
func demo_state() -> Array:
	if screen() != Screen.DEMO:
		return []
	return _rows[_row]


func demo_value(column: Column) -> int:
	var state := demo_state()
	return state[column] if not state.is_empty() else 0


func demo_volley() -> bool:
	var state := demo_state()
	return not state.is_empty() and state[Column.LOOP] == demo_frame() and state[Column.VOLLEY] == 1


# Modules actifs (état 1 dans 0x8140 / 0x8145 / 0x814a), en masque.
func demo_attached() -> int:
	var mask := 0
	for module in range(3):
		if demo_value(Column.MODULE_I + module) == 1:
			mask |= 1 << module
	return mask


# Bonus affiché par l'écran BRAVO : secondes restantes × multiplicateur.
func demo_bonus() -> Vector2i:
	var multiplier := 100 if demo_value(Column.STEP) == 2 else 300
	var seconds := demo_value(Column.CLOCK) >> 8
	return Vector2i(((seconds >> 4) * 10 + (seconds & 0x0F)) * multiplier, multiplier)


# Explosions visibles à l'image courante : [image, vaisseau, x, y, style, âge].
func demo_bursts(fraction := 0.0) -> Array:
	var bursts := []
	if screen() != Screen.DEMO:
		return bursts
	_load()
	var now := demo_frame()
	for event in _events:
		var age := float(now - event[Event.FRAME]) + fraction
		if age < 0.0:
			break
		var life := SHIP_BURST_FRAMES if event[Event.SHIP] else ENEMY_BURST_FRAMES
		if age < life:
			bursts.append([event[Event.SHIP], Vector2(event[Event.X], event[Event.Y]), event[Event.STYLE], age / life])
	return bursts


func demo_clock() -> String:
	# BCD : secondes, puis dixièmes comptés de 10 à 1 (0x3010 s'affiche 30:0).
	var clock := demo_value(Column.CLOCK)
	var tenths := clock & 0xFF
	return "%02x:%d" % [clock >> 8, ((tenths >> 4) * 10 + (tenths & 0x0F)) % 10]


func demo_objects(lookback := 0) -> PackedByteArray:
	if screen() != Screen.DEMO:
		return PackedByteArray()
	_load()
	var index := maxi(0, demo_frame() - lookback) * VisualData.STRIDE
	return _visuals.slice(index, index + VisualData.STRIDE)


func _sync_row() -> void:
	if screen() != Screen.DEMO:
		_row = 0
		return
	var target := demo_frame()
	_load()
	if _row < _rows.size() and _rows[_row][Column.LOOP] > target:
		_row = 0
	while _row + 1 < _rows.size() and _rows[_row + 1][Column.LOOP] <= target:
		_row += 1


static func _load() -> void:
	if not _rows.is_empty():
		return
	_rows = DemoData.ROWS.duplicate(true)
	_visuals = Marshalls.base64_to_raw(VisualData.DEFLATE).decompress(VisualData.SIZE, FileAccess.COMPRESSION_DEFLATE)
	_patch_second_docking()
	_find_bursts()


static func _row_at(loop: int) -> Array:
	var found: Array = _rows[0]
	for row in _rows:
		if row[Column.LOOP] > loop:
			break
		found = row
	return found


static func _set_module(frame: int, module: int, point: Vector2i) -> void:
	var at := frame * VISUAL_STRIDE + MODULE_OFFSET + (module - 1) * 2
	_visuals[at] = point.x
	_visuals[at + 1] = point.y


static func _patch_second_docking() -> void:
	var contact_clock: int = _row_at(SECOND_DOCKING_CONTACT)[Column.CLOCK]
	var replaced := []
	var span := float(SECOND_DOCKING_CONTACT - SECOND_DOCKING_PATH)
	var start := Vector2(_visuals[SECOND_DOCKING_PATH * VISUAL_STRIDE + MODULE_OFFSET],
		_visuals[SECOND_DOCKING_PATH * VISUAL_STRIDE + MODULE_OFFSET + 1])
	for frame in range(SECOND_DOCKING_PATH, SECOND_DOCKING_RESUME):
		var point := Vector2i(DOCKED_X, DOCKED_Y)
		if frame < SECOND_DOCKING_CONTACT:
			# Approche freinée : léger balancement, vitesse qui retombe au contact.
			var t := (frame - SECOND_DOCKING_PATH) / span
			point = Vector2i(roundi(DOCKED_X + (start.x - DOCKED_X) * (1.0 - t) * cos(2.5 * PI * t)),
				roundi(start.y + (DOCKED_Y - start.y) * (1.0 - pow(1.0 - t, 1.6))))
			var original: Array = _row_at(frame)
			replaced.append([frame, point.x + 16, point.y + 16, original[Column.LIVES], original[Column.FLAG],
				SCREEN_PLAY, 5, original[Column.CLOCK], 1, 1, 2, 0])
		elif frame == SECOND_DOCKING_CONTACT:
			replaced.append([frame, DOCKED_X + 16, DOCKED_Y + 16, 3, 1, SCREEN_RESULT, 5, contact_clock, 1, 1, 1, 0])
		_set_module(frame, 1, point)
		_set_module(frame, 2, point + Vector2i(0, 8))
		_set_module(frame, 3, Vector2i(DOCKED_X, DOCKED_Y + 16))
		_visuals[frame * VISUAL_STRIDE + THRUST_OFFSET] = 2 if frame < SECOND_DOCKING_CONTACT else 3
	# Après la reprise, le III reste sous le II jusqu'à la perte du II.
	for frame in range(SECOND_DOCKING_RESUME, SECOND_DOCKING_LOSS):
		var at := frame * VISUAL_STRIDE + MODULE_OFFSET
		if _visuals[at + 2] != 255:
			_set_module(frame, 3, Vector2i(_visuals[at + 2], _visuals[at + 3] + 8))
			if _visuals[frame * VISUAL_STRIDE + THRUST_OFFSET] == 2:
				_visuals[frame * VISUAL_STRIDE + THRUST_OFFSET] = 3
	var rows := []
	for row in _rows:
		var loop: int = row[Column.LOOP]
		if loop >= SECOND_DOCKING_PATH and loop < SECOND_DOCKING_RESUME:
			continue
		if loop >= SECOND_DOCKING_RESUME and loop < SECOND_DOCKING_LOSS:
			row[Column.MODULE_III] = 1
		if loop == SECOND_DOCKING_RESUME:
			rows.append_array(replaced)
		rows.append(row)
	_rows = rows


# Les explosions ne sont pas dans le relevé : un ennemi qui disparaît juste
# après le passage d'un tir a été abattu ; un module qui passe à 0 est perdu.
static func _find_bursts() -> void:
	_events = []
	var previous_states := [1, 1, 1]
	var row_index := 0
	for frame in range(1, DEMO_FRAMES):
		var before := (frame - 1) * VISUAL_STRIDE
		var now := frame * VISUAL_STRIDE
		for slot in range(0, 16, 2):
			if _visuals[before + slot] == 255 or _visuals[now + slot] != 255:
				continue
			var point := Vector2(_visuals[before + slot], _visuals[before + slot + 1])
			for shot in range(16, 26, 2):
				if _visuals[before + shot] != 255 and absf(_visuals[before + shot] - point.x) + absf(_visuals[before + shot + 1] - point.y) <= 16.0:
					_events.append([frame, false, point.x, point.y, _visuals[before + STYLE_OFFSET]])
					break
		while row_index + 1 < _rows.size() and _rows[row_index + 1][Column.LOOP] <= frame:
			row_index += 1
		for module in range(3):
			var state: int = _rows[row_index][Column.MODULE_I + module]
			var at := before + MODULE_OFFSET + module * 2
			if state == 0 and previous_states[module] == 1 and _visuals[at] != 255:
				_events.append([frame, true, _visuals[at], _visuals[at + 1] + 6, 255])
			previous_states[module] = state
