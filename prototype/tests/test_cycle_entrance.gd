extends SceneTree

# Au début d'un nouveau cycle, le premier module intact entre seul, et le
# panneau annonce ce module-là (pas toujours le module I).
const ArcadeRun = preload("res://arcade_run.gd")
const Profile = preload("res://arcade_profile.gd")
const NAMES := ["I", "II", "III"]
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._profile = Profile.new()
	view._profile.language = "fr"
	view._attract_active = false
	# Chaque combinaison de modules perdus, sauf la perte des trois.
	for lost in range(7):
		var run := ArcadeRun.new()
		run._lost_modules = lost
		run.attached = run.available_modules()
		run.stage = 2
		run.phase = ArcadeRun.Phase.CYCLE_END
		run.cycle_end_elapsed = 0
		for i in ArcadeRun.CYCLE_ENTRANCE_START + 5:
			run.step(0)
			if run.phase != ArcadeRun.Phase.CYCLE_END:
				break
		var first := 0
		while not (run.available_modules() & (1 << first)):
			first += 1
		var label: String = NAMES[first]
		_expect(run.is_cycle_entrance(), "Pertes %d : entrée de nouveau cycle" % lost)
		_expect(run.attached == 1 << first and run.front_module() == first + 1, "Pertes %d : le module %s entre seul" % [lost, label])
		view._session.runs.assign([run])
		view._session.player = 0
		var status: String = view._status_lines()[0]
		_expect(status == "Cycle 2 · entrée du module %s" % label, "Pertes %d : le panneau annonce le module %s, obtenu « %s »" % [lost, label, status])
		var hud: Vector2i = view._hud_modules(false)
		_expect(hud.y == 1 << first, "Pertes %d : le HUD allume le module %s" % [lost, label])
	view._profile.language = "en"
	var run := ArcadeRun.new()
	run._lost_modules = 3
	run.attached = 4
	run.phase = ArcadeRun.Phase.CYCLE_END
	for i in ArcadeRun.CYCLE_ENTRANCE_START + 5:
		run.step(0)
	view._session.runs.assign([run])
	_expect(view._status_lines()[0] == "Cycle 2 · Module III entering", "Traduction anglaise avec le module III")
	view.free()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("CYCLE ENTRANCE OK")
		quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
