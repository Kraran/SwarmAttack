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
var _visuals := PackedByteArray()


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
	return DemoData.ROWS[_row]


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


func demo_clock() -> String:
	# BCD : secondes, puis dixièmes comptés de 10 à 1 (0x3010 s'affiche 30:0).
	var clock := demo_value(Column.CLOCK)
	var tenths := clock & 0xFF
	return "%02x:%d" % [clock >> 8, ((tenths >> 4) * 10 + (tenths & 0x0F)) % 10]


func demo_objects(lookback := 0) -> PackedByteArray:
	if screen() != Screen.DEMO:
		return PackedByteArray()
	if _visuals.is_empty():
		_visuals = Marshalls.base64_to_raw(VisualData.DEFLATE).decompress(VisualData.SIZE, FileAccess.COMPRESSION_DEFLATE)
	var index := maxi(0, demo_frame() - lookback) * VisualData.STRIDE
	return _visuals.slice(index, index + VisualData.STRIDE)


func _sync_row() -> void:
	if screen() != Screen.DEMO:
		_row = 0
		return
	var target := demo_frame()
	if _row < DemoData.ROWS.size() and DemoData.ROWS[_row][Column.LOOP] > target:
		_row = 0
	while _row + 1 < DemoData.ROWS.size() and DemoData.ROWS[_row + 1][Column.LOOP] <= target:
		_row += 1
