extends SceneTree

# Les manettes PlayStation et Nintendo affichent leurs propres symboles.
const Controls = preload("res://arcade_controls.gd")
const UiSkin = preload("res://ui/skin.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Controls.family_for_name("PS4 Controller") == "playstation", "DualShock 4 reconnue")
	_expect(Controls.family_for_name("Sony Interactive Entertainment Wireless Controller") == "playstation", "Nom Sony reconnu")
	_expect(Controls.family_for_name("DualSense Wireless Controller") == "playstation5"
		and Controls.family_for_name("PS5 Controller") == "playstation5", "DualSense reconnue")
	_expect(Controls.family_for_name("Nintendo Switch Pro Controller") == "nintendo", "Manette Switch reconnue")
	_expect(Controls.family_for_name("Xbox Series Controller") == "xbox" and Controls.family_for_name("") == "xbox",
		"Xbox et manettes inconnues gardent les lettres Xbox")
	var skin = UiSkin.create("orbital")
	_expect(skin.pad_label("LB") == "LB" and skin.pad_label("Start") == "Start", "Libellés Xbox")
	skin.pad_family = "playstation"
	_expect(skin.pad_label("LB") == "L1" and skin.pad_label("RB") == "R1" and skin.pad_label("Start") == "Options"
		and skin.pad_label("Back") == "Share", "Libellés DualShock 4")
	skin.pad_family = "playstation5"
	_expect(skin.pad_label("Back") == "Create", "Libellé DualSense")
	skin.pad_family = "nintendo"
	_expect(skin.pad_label("Start") == "+" and skin.pad_label("LB") == "L", "Libellés Nintendo")
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = view.ArcadeProfile.new()
	view._profile.language = "fr"
	await process_frame
	view._set_pad_family("playstation5")
	_expect(view._skin.pad_family == "playstation5", "La vue transmet la famille au thème")
	_expect(view._pad_text("A") == "×" and view._pad_text("Y") == "Triangle", "Textes PlayStation dans les phrases")
	view._profile.skin = "arcade"
	view._apply_skin()
	_expect(view._skin.pad_family == "playstation5", "La famille survit au changement de thème")
	view._set_pad_family("nintendo")
	_expect(view._pad_text("A") == "B", "Nintendo : le bouton du bas s'écrit B")
	view._set_pad_family("xbox")
	_expect(view._pad_text("A") == "A" and view._pad_text("Start") == "Start", "Retour aux libellés Xbox")
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("PLAYSTATION OK")
		quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
