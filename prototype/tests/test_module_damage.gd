extends SceneTree

const Run = preload("res://arcade_run.gd")
const Round = preload("res://combat_round.gd")
const Wave = preload("res://combat_wave.gd")
var failures := 0

func _initialize() -> void:
	for scenario in [[3,1,2],[3,2,1],[5,1,4],[5,3,1],[6,2,4],[6,3,2],[7,1,2],[7,2,1],[7,3,1]]:
		_check_loss(scenario[0], scenario[1], scenario[2])
	_check_successive_losses()
	_check_contact_position()
	if failures == 0:
		print("MODULE DAMAGE OK: chaque impact, survivants, relais, pertes successives et explosion localisée.")
	quit(1 if failures else 0)

func _assembled(mask: int) -> Run:
	var run := Run.new()
	run.attached = mask
	run.stage = 2 if mask == 7 else 1
	run.wave_number = 3
	run._begin_combat(112, 255)
	return run

func _check_loss(mask: int, lost: int, next: int) -> void:
	var run := _assembled(mask)
	run.combat.outcome = Round.Outcome.MODULE_LOST
	run.combat.lost_module = lost
	run.step(0)
	_expect(run.available_modules() == (7 & ~(1 << (lost - 1))), "Seul le module %d du masque %d est perdu" % [lost, mask])
	for frame in Run.COUNTER_DROP_FRAMES:
		run.step(0)
	_expect(run.attached == next, "Masque %d, impact %d : relais %d, obtenu %d" % [mask,lost,next,run.attached])
	_expect(run.available_modules() == (7 & ~(1 << (lost - 1))), "Le module détruit ne ressuscite pas au relais")
	_expect(run.lives == 2 and not (run.entrance_modules() & (1 << (lost - 1))), "Une seule vie et aucune réapparition du module détruit")
	while run.phase == Run.Phase.REPLACEMENT:
		run.step(0)
	_expect(run.combat.pilot.attached == next and run.combat.wave.points_per_hit == run.points_per_hit(), "Reprise avec le survivant, même vague et barème")

func _check_successive_losses() -> void:
	var run := _assembled(7)
	for lost in [2,1,3]:
		run.combat.outcome = Round.Outcome.MODULE_LOST
		run.combat.lost_module = lost
		run.step(0)
		for frame in Run.COUNTER_DROP_FRAMES + Run.ENTRANCE_FRAMES:
			if run.phase != Run.Phase.REPLACEMENT:
				break
			run.step(0)
	_expect(run.lives == 0 and run.available_modules() == 0 and run.phase == Run.Phase.GAME_OVER,
		"II puis I puis III : fin de partie sans recréer un module perdu")

func _check_contact_position() -> void:
	for contact in [[7,Vector2i(116,193),1],[7,Vector2i(135,200),2],[7,Vector2i(116,218),3],
			[3,Vector2i(116,206),1],[3,Vector2i(116,225),2],
			[6,Vector2i(116,200),2],[6,Vector2i(116,218),3]]:
		var run := _assembled(contact[0])
		var enemy := Wave.Enemy.new()
		enemy.position = contact[1]
		enemy.velocity = Vector2i.ZERO
		run.combat.wave.enemies.assign([enemy])
		run.combat.wave._wave_clock = 100
		run.step(0)
		_expect(run.combat.lost_module == contact[2], "Contact réel : module attendu %d" % contact[2])
		var pilot := run.combat.pilot
		_expect(run.combat.impact_position == Vector2(pilot.ship_x, pilot.module_y(contact[2]) + pilot.assembly_y_offset + 6),
			"Explosion centrée sur le module réellement touché")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
