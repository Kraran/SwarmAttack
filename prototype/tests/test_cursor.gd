extends SceneTree

# Curseur masqué en jeu après 3 s sans mouvement de la souris.

const Profile = preload("res://arcade_profile.gd")
var view: Node2D
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	view._profile = Profile.new()
	var idle: int = Time.get_ticks_usec() - view.CURSOR_HIDE_USEC - 1
	view._last_mouse_motion_usec = idle
	view._update_cursor()
	_expect(not view._cursor_hidden, "Curseur visible à l’accueil")
	view._restart(false)
	view._last_mouse_motion_usec = Time.get_ticks_usec()
	view._update_cursor()
	_expect(not view._cursor_hidden, "Curseur visible juste après un mouvement")
	view._last_mouse_motion_usec = idle
	view._update_cursor()
	_expect(view._cursor_hidden, "Curseur masqué après 3 s sans mouvement")
	view._input(InputEventMouseMotion.new())
	_expect(not view._cursor_hidden, "Curseur affiché dès un mouvement")
	view._last_mouse_motion_usec = idle
	view._update_cursor()
	view._toggle_pause()
	view._update_cursor()
	_expect(not view._cursor_hidden, "Curseur visible en pause")
	view._toggle_pause()
	view._update_cursor()
	_expect(view._cursor_hidden, "Curseur masqué à la reprise")
	view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(not view._cursor_hidden, "Curseur visible hors focus")
	print("CURSOR OK" if failures == 0 else "CURSOR FAIL")
	quit(1 if failures else 0)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
