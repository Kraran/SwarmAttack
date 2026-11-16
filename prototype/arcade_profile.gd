extends RefCounted

const SAVE_PATH := "user://arcade.cfg"
const BONUS_THRESHOLDS := [30000, 50000]
const SCORE_COUNT := 5

var scores := PackedInt32Array([5000, 5000, 5000, 5000, 5000])
var muted := false
var fullscreen := true
var portrait := false
var bonus_index := 0


func read(path := SAVE_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var stored: Variant = config.get_value("records", "scores", scores)
	if stored is PackedInt32Array and stored.size() == SCORE_COUNT:
		scores = stored
		scores.sort()
		scores.reverse()
	muted = config.get_value("options", "muted", false) == true
	fullscreen = config.get_value("options", "fullscreen", true) == true
	portrait = config.get_value("options", "portrait", false) == true
	bonus_index = 1 if config.get_value("options", "bonus_index", 0) == 1 else 0


func record(score: int) -> bool:
	for index in range(scores.size()):
		if score > scores[index]:
			scores.insert(index, score)
			scores.resize(SCORE_COUNT)
			return true
	return false


func write(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("records", "scores", scores)
	config.set_value("options", "muted", muted)
	config.set_value("options", "fullscreen", fullscreen)
	config.set_value("options", "portrait", portrait)
	config.set_value("options", "bonus_index", bonus_index)
	return config.save(path)
