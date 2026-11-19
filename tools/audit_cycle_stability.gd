extends SceneTree

# Real simulation, presentation and audio across the ten wave families and
# cycle transitions. A bounded fixture advances eight logical steps per draw.
var view: Node2D
var steps := 0
var draws := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	view = preload("res://main.tscn").instantiate()
	root.add_child(view)
	view.set_process(false)
	view._focused = true
	AudioServer.set_bus_mute(0, true)
	for cycle in [2, 3, 4]:
		for number in range(1, 11):
			view._profile.audio_bank = "modern" if (cycle + number) % 2 else "original"
			view._audio.set_bank(view._profile.audio_bank)
			view._restart(false)
			var run = view._run
			run.cycle = cycle
			run.stage = 0 if number <= 4 else (1 if number <= 8 else 2)
			run.wave_number = number - [0, 2, 6][run.stage]
			run.attached = [1, 3, 7][run.stage]
			run._begin_combat(112, 255)
			print("CYCLE STRESS cycle=", cycle, " wave=", number, " bank=", view._profile.audio_bank)
			for batch in 120:
				for frame in 8:
					var move: int = view.Pilot.RIGHT if (steps / 90) % 2 else view.Pilot.LEFT
					var fire: int = view.Pilot.FIRE if steps % 8 == 0 else 0
					_step(move | fire)
				await _draw_frame()
		# Exercise the actual reset/entrance code leading to cycles 3, 4 and 5.
		view._restart(false)
		view._run.cycle = cycle
		view._run.stage = 2
		view._run.wave_number = 4
		view._run._begin_combat(112, 255)
		view._run.combat.outcome = view.ArcadeRun.CombatRound.Outcome.CLEARED
		_step(0)
		for frame in view.ArcadeRun.CYCLE_ENTRANCE_DONE:
			_step(0)
			if frame % 8 == 0:
				await _draw_frame()
		if view._run.cycle != cycle + 1 or view._run.phase != view.ArcadeRun.Phase.COMBAT:
			push_error("Cycle transition failed")
			quit(1)
			return
	view.free()
	await create_timer(0.1).timeout
	print("CYCLE STRESS OK cycles=2,3,4 transitions=3,4,5 steps=", steps, " rendered_frames=", draws)
	quit()

func _step(mask: int) -> void:
	view._simulation_tick += 1
	view._step_session(mask)
	steps += 1

func _draw_frame() -> void:
	view._focused = true
	view._visual_tick = float(view._simulation_tick)
	view._redraw()
	await process_frame
	draws += 1
