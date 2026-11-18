extends SceneTree

const Profile = preload("res://arcade_profile.gd")
const Storage = preload("res://profile_storage.gd")
const Controls = preload("res://arcade_controls.gd")
var failures := 0

class FailingStorage extends Storage:
	var failure := ""
	var publishes := 0

	func _write_temporary(path: String, content: String) -> Error:
		if failure == "partial":
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file == null:
				return FileAccess.get_open_error()
			file.store_string(content.left(content.length()/2))
			file.close()
			return ERR_FILE_CANT_WRITE
		return super._write_temporary(path,content)

	func _publish_file(temporary: String, final: String) -> Error:
		publishes += 1
		if failure == "publish" or failure == "backup" and publishes == 2:
			return ERR_FILE_CANT_WRITE
		return super._publish_file(temporary,final)


func _initialize() -> void:
	_test_recovery()
	_test_failures()
	_test_legacy()
	_test_concurrent()
	if failures == 0:
		print("STORAGE OK: checksum, backup recovery, legacy migration, partial writes, failed commit, retry and concurrency.")
	quit(1 if failures else 0)


func _test_recovery() -> void:
	var path := _path("recovery")
	var profile := Profile.new()
	_expect(profile.submit_score(6100,"ONE",path) == OK, "Premier score enregistré")
	var storage := Storage.new()
	var versions := storage._snapshots(path)
	_expect(versions.size() == 2, "Deux copies dès la première sauvegarde")
	profile.volume = 60
	Controls.assign_key(profile.key_bindings,&"fire",KEY_Z)
	_expect(profile.submit_score(7200,"TWO",path,1) == OK, "Deuxième difficulté enregistrée")
	versions = storage._snapshots(path)
	_expect(versions.size() == 2, "Deux dernières versions retenues")
	var good := FileAccess.get_file_as_string(versions[0].path)
	_write(versions[0].path,good.left(good.length()/2))
	var restored := Profile.new()
	restored.read(path)
	_expect(restored.recovered_backup and restored.scores_for(0)[0] == 6100 and restored.scores_for(1)[0] == 5000,
		"Une sauvegarde tronquée recharge la version précédente complète")
	_expect(restored.volume == 100 and restored.key_bindings == Controls.DEFAULT_KEYS, "Réglages cohérents avec le classement récupéré")
	_expect(restored.submit_score(8000,"NEW",path) == OK, "Nouvelle sauvegarde après récupération")
	var reloaded := Profile.new()
	reloaded.read(path)
	_expect(not reloaded.recovered_backup and reloaded.scores_for(0)[0] == 8000, "Récupération suivie d’une sauvegarde stable")
	versions = storage._snapshots(path)
	var latest: String = versions[0].path
	var text := FileAccess.get_file_as_string(latest)
	_write(latest,text.replace("muted=false","muted=true"))
	reloaded.read(path)
	_expect(reloaded.recovered_backup and not reloaded.muted and reloaded.scores_for(0)[0] == 6100,
		"Une altération syntaxiquement valide est détectée par le checksum")
	_write((path+".saves").path_join("profile-99999999999999999999-interrupted.cfg.tmp"),"partial")
	reloaded.read(path)
	_expect(reloaded.recovered_backup and reloaded.scores_for(0)[0] == 6100, "Un temporaire interrompu est ignoré")
	_cleanup(path)


func _test_failures() -> void:
	var path := _path("failure")
	var profile := Profile.new()
	_expect(profile.submit_score(6000,"OLD",path) == OK, "État initial enregistré")
	var broken := FailingStorage.new()
	profile._storage = broken
	for failure in ["partial","publish"]:
		broken.failure = failure
		_expect(profile.submit_score(20000,"BAD",path) != OK and profile.scores[0] == 6000 and profile.initials[0] == "OLD",
			"Échec sans insertion en mémoire "+failure)
		var read := Profile.new()
		read.read(path)
		_expect(read.scores[0] == 6000 and read.initials[0] == "OLD", "La dernière version reste intacte "+failure)
		_expect(_temporary_count(path) == 0, "Nettoyage du temporaire "+failure)
	broken.failure = ""
	_expect(profile.submit_score(9000,"YES",path) == OK, "Une nouvelle tentative réussit sans doublon")
	var latest := Profile.new()
	latest.read(path)
	_expect(latest.scores[0] == 9000 and latest.scores[1] == 6000, "Ordre conservé après nouvelle tentative")
	var invalid := path + "/invalid.cfg"
	_expect(profile.write(invalid) != OK, "Un parent inexistant est signalé")
	_cleanup(path)
	var first := _path("backup-failure")
	var one := Profile.new()
	var fail_backup := FailingStorage.new()
	fail_backup.failure = "backup"
	one._storage = fail_backup
	_expect(one.submit_score(7000,"ONE",first) == OK and one.backup_failed, "La première version publiée reste un succès si sa copie secondaire échoue")
	var read := Profile.new()
	read.read(first)
	_expect(read.scores[0] == 7000, "Le score publié avant l’échec secondaire est relu")
	fail_backup.failure = ""
	_expect(one.write(first) == OK and not one.backup_failed, "La tentative suivante rétablit la copie de secours")
	_cleanup(first)


func _test_legacy() -> void:
	var path := _path("legacy")
	var legacy := ConfigFile.new()
	legacy.set_value("records","scores",PackedInt32Array([9000,8000,7000,6000,5000]))
	legacy.set_value("records","initials",PackedStringArray(["OLD","ABC","DEF","GHI","JKL"]))
	legacy.set_value("options","language","fr")
	legacy.set_value("options","muted",true)
	_expect(legacy.save(path) == OK, "Profil historique créé")
	var original := FileAccess.get_file_as_string(path)
	var profile := Profile.new()
	profile.read(path)
	_expect(profile.scores[0] == 9000 and profile.initials[0] == "OLD" and profile.muted, "Ancien profil relu")
	profile.volume = 40
	_expect(profile.write(path) == OK and FileAccess.get_file_as_string(path) == original, "Migration sans altérer le fichier historique")
	var storage := Storage.new()
	var versions := storage._snapshots(path)
	_write(versions[0].path,"corrupted")
	var recovered := Profile.new()
	recovered.read(path)
	_expect(recovered.recovered_backup and recovered.volume == 100 and recovered.scores[0] == 9000,
		"L’ancienne version sert aussi de secours après migration")
	for snapshot in storage._snapshots(path):
		_write(snapshot.path,"corrupted")
	recovered.read(path)
	_expect(recovered.recovered_backup and recovered.scores[0] == 9000, "Le profil historique reste une dernière récupération")
	_cleanup(path)
	var absent := _path("all-corrupt")
	_expect(profile.write(absent) == OK, "Profil moderne créé")
	for snapshot in storage._snapshots(absent):
		_write(snapshot.path,"corrupted")
	var defaults := Profile.new()
	defaults.read(absent)
	_expect(defaults.unreadable_profile and defaults.scores == PackedInt32Array(Profile.DEFAULT_SCORES),
		"Des fichiers tous illisibles sont signalés")
	_cleanup(absent)


func _test_concurrent() -> void:
	var path := _path("concurrent")
	var seed := Profile.new()
	_expect(seed.write(path) == OK, "Profil initial concurrent")
	var threads: Array[Thread] = []
	for index in 3:
		var thread := Thread.new()
		var value := index
		_expect(thread.start(func() -> Error:
			var profile := Profile.new()
			profile.volume = 20+value*10
			profile.language = ["fr","en","de"][value]
			return profile.submit_score(10000+value,"THR",path)
		) == OK, "Écriture concurrente lancée")
		threads.append(thread)
	for thread in threads:
		_expect(thread.wait_to_finish() == OK, "Écriture concurrente terminée")
	var loaded := Profile.new()
	loaded.read(path)
	var value: int = loaded.scores[0]-10000
	_expect(value in [0,1,2] and loaded.volume == 20+value*10 and loaded.language == ["fr","en","de"][value],
		"La lecture concurrente reçoit une version entière")
	_expect(not loaded.unreadable_profile and _temporary_count(path) == 0, "Journal concurrent valide")
	_cleanup(path)


func _path(label: String) -> String:
	return "user://test-storage-%d-%s.cfg" % [OS.get_process_id(),label]


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	_expect(file != null, "Fichier de test ouvert")
	if file != null:
		file.store_string(content)
		file.close()


func _temporary_count(path: String) -> int:
	var count := 0
	for name in DirAccess.get_files_at(path+".saves"):
		count += int(name.ends_with(".tmp"))
	return count


func _cleanup(path: String) -> void:
	var folder := path+".saves"
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

