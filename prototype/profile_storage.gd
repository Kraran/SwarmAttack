extends RefCounted

# Publish immutable snapshots. Godot's Windows rename removes an existing
# destination before moving, so published snapshots are never overwritten.
const HEADER := "; SWARM ATTACK profile v1 "
const PREFIX := "profile-"
const KEEP_VERSIONS := 2

var recovered_backup := false
var unreadable_profile := false
var backup_failed := false


func load_profile(path: String) -> ConfigFile:
	recovered_backup = false
	unreadable_profile = false
	backup_failed = false
	var snapshots := _snapshots(path)
	var valid_versions := 0
	for snapshot in snapshots:
		valid_versions += int(snapshot.config != null)
	backup_failed = not snapshots.is_empty() and valid_versions < KEEP_VERSIONS
	var newest := 0
	for snapshot in snapshots:
		newest = maxi(newest, snapshot.generation)
		if snapshot.config != null:
			recovered_backup = snapshot.generation < newest
			return snapshot.config
	var legacy := _read_legacy(path)
	if legacy != null:
		recovered_backup = not snapshots.is_empty()
		return legacy
	unreadable_profile = not snapshots.is_empty() or FileAccess.file_exists(path)
	return null


func save_profile(config: ConfigFile, path: String) -> Error:
	var folder := path + ".saves"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path.get_base_dir())):
		return ERR_FILE_BAD_PATH
	var error := OK
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		error = DirAccess.make_dir_absolute(ProjectSettings.globalize_path(folder))
		if error != OK and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
			return error
	var snapshots := _snapshots(path)
	var generation: int = 1 if snapshots.is_empty() else snapshots[0].generation + 1
	# Seed the backup with the legacy profile before the first modern commit.
	if snapshots.is_empty():
		var legacy := _read_legacy(path)
		if legacy != null:
			error = _publish(legacy, folder, generation)
			if error != OK:
				return error
			generation += 1
	error = _publish(config, folder, generation)
	if error != OK:
		return error
	# A first-ever commit has no predecessor. Duplicate that committed version
	# so that a new profile also gets a recovery copy immediately.
	backup_failed = false
	var valid_versions := 0
	for snapshot in _snapshots(path):
		valid_versions += int(snapshot.config != null)
	if valid_versions == 1:
		backup_failed = _publish(config, folder, generation + 1) != OK
	recovered_backup = false
	unreadable_profile = false
	var retained := 0
	for snapshot in _snapshots(path):
		if snapshot.config == null:
			continue
		retained += 1
		if retained > KEEP_VERSIONS:
			# Pruning is optional after a successful commit.
			DirAccess.remove_absolute(ProjectSettings.globalize_path(snapshot.path))
	return OK


func _publish(config: ConfigFile, folder: String, generation: int) -> Error:
	var content := config.encode_to_text()
	var packet := "%s%d %s\n%s" % [HEADER, generation, content.sha256_text(), content]
	var nonce := "%d-%d-%d" % [OS.get_process_id(), get_instance_id(), Time.get_ticks_usec()]
	var final := folder.path_join("%s%020d-%s.cfg" % [PREFIX, generation, nonce])
	var temporary := final + ".tmp"
	var error := _write_temporary(temporary, packet)
	if error == OK and _read_snapshot(temporary).config == null:
		error = ERR_FILE_CORRUPT
	if error == OK:
		error = _publish_file(temporary, final)
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return error


func _write_temporary(path: String, content: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_buffer(content.to_utf8_buffer())
	file.flush()
	var error := file.get_error()
	file.close()
	if not stored:
		return ERR_FILE_CANT_WRITE
	return error


func _publish_file(temporary: String, final: String) -> Error:
	if FileAccess.file_exists(final):
		return ERR_ALREADY_EXISTS
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(final))


func _snapshots(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var folder := path + ".saves"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		return result
	for name in DirAccess.get_files_at(folder):
		if not name.begins_with(PREFIX) or not name.ends_with(".cfg"):
			continue
		var generation := name.trim_prefix(PREFIX).get_slice("-", 0)
		if not generation.is_valid_int() or generation.to_int() <= 0:
			continue
		var file_path := folder.path_join(name)
		var snapshot := _read_snapshot(file_path)
		snapshot.path = file_path
		# The file name also records the generation if its contents are damaged.
		snapshot.generation = generation.to_int()
		result.append(snapshot)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.path > b.path if a.generation == b.generation else a.generation > b.generation)
	return result


func _read_snapshot(path: String) -> Dictionary:
	var result := {"config": null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var packet := file.get_as_text()
	file.close()
	var newline := packet.find("\n")
	if newline < 0 or not packet.begins_with(HEADER):
		return result
	var fields := packet.substr(HEADER.length(), newline - HEADER.length()).split(" ")
	var payload := packet.substr(newline + 1)
	if fields.size() != 2 or not fields[0].is_valid_int() or fields[1] != payload.sha256_text():
		return result
	var config := ConfigFile.new()
	if config.parse(payload) == OK and _has_profile_data(config):
		result.config = config
	return result


func _read_legacy(path: String) -> ConfigFile:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text().trim_prefix(String.chr(0xFEFF)).strip_edges()
	file.close()
	if text.is_empty() or not (text.begins_with("[") or text.begins_with(";") or text.begins_with("#")):
		return null
	var config := ConfigFile.new()
	if config.parse(text) != OK or not _has_profile_data(config):
		return null
	return config


func _has_profile_data(config: ConfigFile) -> bool:
	for section in ["options", "records", "records_normal", "records_veterans", "controls"]:
		if config.has_section(section):
			return true
	return false
