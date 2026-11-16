extends SceneTree


func _initialize() -> void:
	var output := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	if output == null:
		printerr(error_string(FileAccess.get_open_error()))
		quit(1)
		return
	output.store_line("Godot Engine " + Engine.get_version_info()["string"])
	output.store_line(Engine.get_license_text())
	for component in Engine.get_copyright_info():
		output.store_line(component["name"])
		for part in component["parts"]:
			output.store_line("\t" + "\n\t".join(part["copyright"]))
			output.store_line("\t" + part["license"])
		output.store_line("")
	var licenses := Engine.get_license_info()
	for name in licenses:
		output.store_line(name)
		output.store_line(licenses[name])
	output.close()
	quit()
