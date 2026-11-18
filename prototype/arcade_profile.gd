extends RefCounted

const Language = preload("res://arcade_language.gd")
const Controls = preload("res://arcade_controls.gd")
const Storage = preload("res://profile_storage.gd")
const SAVE_PATH := "user://arcade.cfg"
const BONUS_THRESHOLDS := [30000, 50000]
const DIFFICULTY_LABELS := ["Normal", "Vétérans"]
const SCORE_COUNT := 10
const INITIALS_ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const UNKNOWN_INITIALS := "---"

enum Difficulty { NORMAL, VETERANS }

const DEFAULT_SCORES := [5000, 5000, 5000, 5000, 5000, 0, 0, 0, 0, 0]
const RECORD_SECTIONS := ["records_normal", "records_veterans"]
var _scores: Array[PackedInt32Array] = []
var _initials: Array[PackedStringArray] = []
var scores: PackedInt32Array:
	get:
		return scores_for(difficulty)
	set(value):
		_scores[difficulty] = value
var initials: PackedStringArray:
	get:
		return initials_for(difficulty)
	set(value):
		_initials[difficulty] = value
var muted := false
var volume := 100
var audio_bank := "original"
var key_bindings := Controls.DEFAULT_KEYS.duplicate(true)
var button_bindings := Controls.DEFAULT_BUTTONS.duplicate()
var fullscreen := true
var portrait := false
var difficulty := Difficulty.NORMAL
var language := Language.DEFAULT_LANGUAGE
var _storage := Storage.new()
var recovered_backup: bool:
	get:
		return _storage.recovered_backup
var unreadable_profile: bool:
	get:
		return _storage.unreadable_profile
var backup_failed: bool:
	get:
		return _storage.backup_failed


func _init() -> void:
	_reset_scores()


func _reset_scores() -> void:
	_scores.clear()
	_initials.clear()
	for mode in RECORD_SECTIONS.size():
		_scores.append(PackedInt32Array(DEFAULT_SCORES))
		var names := PackedStringArray()
		names.resize(SCORE_COUNT)
		names.fill(UNKNOWN_INITIALS)
		_initials.append(names)


func scores_for(mode: int) -> PackedInt32Array:
	return _scores[mode]


func initials_for(mode: int) -> PackedStringArray:
	return _initials[mode]


func read(path := SAVE_PATH) -> void:
	var config := _storage.load_profile(path)
	if config == null:
		return
	_reset_scores()
	for mode in RECORD_SECTIONS.size():
		var section: String = RECORD_SECTIONS[mode]
		# The former shared table has no per-score difficulty metadata.
		if mode == Difficulty.NORMAL and not config.has_section(section):
			section = "records"
		var stored: Variant = config.get_value(section, "scores", PackedInt32Array())
		if stored is PackedInt32Array and stored.size() in [5, SCORE_COUNT]:
			_read_scores(stored, config.get_value(section, "initials", PackedStringArray()), mode)
	muted = config.get_value("options", "muted", false) == true
	var stored_volume: Variant = config.get_value("options", "volume", 100)
	volume = clampi(stored_volume, 0, 100) if stored_volume is int else 100
	var stored_bank: Variant = config.get_value("options", "audio_bank", "original")
	audio_bank = stored_bank if stored_bank in ["original", "modern"] else "original"
	key_bindings = Controls.read_keys(config.get_value("controls", "keys", {}))
	button_bindings = Controls.read_buttons(config.get_value("controls", "buttons", {}))
	fullscreen = config.get_value("options", "fullscreen", true) == true
	portrait = config.get_value("options", "portrait", false) == true
	difficulty = Difficulty.VETERANS if config.get_value("options", "difficulty", 0) == 1 else Difficulty.NORMAL
	# Profiles from before language selection used French.
	var stored_language: Variant = config.get_value("options", "language", "fr")
	language = stored_language if stored_language is String and Language.LANGUAGES.has(stored_language) else Language.DEFAULT_LANGUAGE


func starting_cycle() -> int:
	return 2 if difficulty == Difficulty.VETERANS else 1


func bonus_threshold() -> int:
	return BONUS_THRESHOLDS[difficulty]


func _read_scores(stored: PackedInt32Array, names: Variant, mode: int) -> void:
	var table := scores_for(mode)
	var table_names := initials_for(mode)
	var order: Array[int] = []
	for index in stored.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool:
		return a < b if stored[a] == stored[b] else stored[a] > stored[b])
	table.fill(0)
	table_names.fill(UNKNOWN_INITIALS)
	var has_names: bool = names is PackedStringArray and names.size() == stored.size()
	for rank in order.size():
		var index := order[rank]
		table[rank] = maxi(0, stored[index])
		if table[rank] > 0 and has_names and valid_initials(names[index]):
			table_names[rank] = names[index]
	_scores[mode] = table
	_initials[mode] = table_names


static func valid_initials(name: String) -> bool:
	if name.length() != 3:
		return false
	for index in name.length():
		if not INITIALS_ALPHABET.contains(name[index]):
			return false
	return true


func qualifies(score: int, mode := -1) -> bool:
	return insertion_rank(score, mode) > 0


func insertion_rank(score: int, mode := -1) -> int:
	var table := scores_for(difficulty if mode < 0 else mode)
	for index in table.size():
		if score > table[index]:
			return index + 1
	return 0


func submit_score(score: int, name: String, path := SAVE_PATH, mode := -1) -> Error:
	var target := difficulty if mode < 0 else mode
	if not valid_initials(name):
		return ERR_INVALID_PARAMETER
	if not qualifies(score, target):
		return ERR_UNAVAILABLE
	var table := scores_for(target).duplicate()
	var names := initials_for(target).duplicate()
	for index in range(table.size()):
		if score <= table[index]:
			continue
		var previous_scores := scores_for(target)
		var previous_initials := initials_for(target)
		table.insert(index, score)
		names.insert(index, name)
		table.resize(SCORE_COUNT)
		names.resize(SCORE_COUNT)
		_scores[target] = table
		_initials[target] = names
		var error := write(path)
		if error != OK:
			_scores[target] = previous_scores
			_initials[target] = previous_initials
		return error
	return ERR_UNAVAILABLE


func write(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	for mode in RECORD_SECTIONS.size():
		config.set_value(RECORD_SECTIONS[mode], "scores", scores_for(mode))
		config.set_value(RECORD_SECTIONS[mode], "initials", initials_for(mode))
	config.set_value("options", "muted", muted)
	config.set_value("options", "volume", volume)
	config.set_value("options", "audio_bank", audio_bank)
	config.set_value("controls", "keys", key_bindings)
	config.set_value("controls", "buttons", button_bindings)
	config.set_value("options", "fullscreen", fullscreen)
	config.set_value("options", "portrait", portrait)
	config.set_value("options", "difficulty", difficulty)
	config.set_value("options", "language", language)
	return _storage.save_profile(config, path)
