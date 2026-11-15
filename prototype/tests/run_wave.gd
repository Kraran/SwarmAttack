extends SceneTree
const CombatWave = preload("res://combat_wave.gd")
# Entrée JSON : liste de segments {wave, mask, steps:[[ship_x, [kills]], ...]}
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var data = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	for seg in data:
		var w := CombatWave.new(int(seg["wave"]), int(seg["mask"]), -1, int(seg["stage"]))
		if seg.has("patterns"):
			w.load_patterns(seg["patterns"])
			w.max_divers = int(seg["max_divers"])
		var clock_frame := 1000
		# 31 pas avant l'apparition, puis un pas par image de boucle.
		for i in range(31):
			clock_frame += 1
			w.advance(clock_frame, int(seg["steps"][0][0]))
		var lines := PackedStringArray()
		var credits: Array[int] = []
		if seg.has("credits"):
			for c in seg["credits"]:
				credits.append(int(c))
		var step_index := 0
		for step in seg["steps"]:
			step_index += 1
			for k in step[1]:
				var e = w.enemies[int(k)] if w.enemies.size() > int(k) else null
				if e != null and e.alive:
					w.kill(int(k))
					if not seg.has("credits"):
						credits.append(step_index + 10)
			clock_frame += 1
			w.advance(clock_frame, int(step[0]))
			while not credits.is_empty() and credits[0] <= step_index:
				credits.pop_front()
				w.credit_kill()
			var s := PackedStringArray()
			for e in w.enemies:
				s.append("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [e.position.x, e.position.y, int(e.alive), e.phase, e.heading, e.turns_left, e.turn, e.straight_steps, e.diagonal_steps, e.steps_left, e.cadence, e.cadence_left, e.velocity.x, e.velocity.y, e.acceleration])
			lines.append(" ".join(s))
		out.store_line("SEG %d" % lines.size())
		for l in lines:
			out.store_line(l)
	out.close()
	quit(0)
