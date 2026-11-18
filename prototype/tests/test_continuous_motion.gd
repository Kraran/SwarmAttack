extends SceneTree
const Round = preload("res://combat_round.gd")
const Wave = preload("res://combat_wave.gd")
const Pilot = preload("res://pilot.gd")
var failures := 0

func _initialize() -> void:
	for frame in [34,118,212]:
		var round := Round.new()
		round.pilot.frame = frame - 1
		round.pilot.ship_x = 100
		round.wave._wave_clock = frame - 1
		round.step(Pilot.RIGHT | Pilot.FIRE)
		_expect(round.pilot.ship_x == 102 and not round.pilot.active_shots().is_empty(),
			"Déplacement et tir acceptés à l'ancienne frame figée %d" % frame)
		_expect(round.wave._wave_clock == frame, "Horloge continue à la frame %d" % frame)
	for configuration in [[1,0],[3,0],[3,1],[5,1],[3,2]]:
		var wave := Wave.new(configuration[0],255,-1,configuration[1])
		var shifted := Wave.new(configuration[0],255,-1,configuration[1])
		for tick in range(1,241):
			wave.advance(tick,112)
			shifted.advance(1000+tick,112)
		_expect(wave._wave_clock == 240 and wave.enemies.size() == shifted.enemies.size(),
			"Chaque pas logique avance la vague, indépendamment de son numéro de frame")
		for index in mini(wave.enemies.size(),shifted.enemies.size()):
			_expect(wave.enemies[index].position == shifted.enemies[index].position,
				"Trajectoire identique sans les trois arrêts artificiels")
	var ending := Round.new(1,1,100,1)
	var enemy := Wave.Enemy.new()
	enemy.position = Vector2i(112,96)
	enemy.velocity = Vector2i.ZERO
	var partner := Wave.Enemy.new()
	partner.alive = false
	ending.wave.enemies.assign([enemy,partner])
	ending.wave._wave_clock = 100
	ending.pilot.shot_position = Vector2i(95,96)
	ending.pilot.shot_active = true
	ending.step(0)
	_expect(ending.wave.remaining == 0 and ending.pilot.active_shots().is_empty(), "Dernier impact : les tirs sont supprimés")
	for tick in Round.SCORE_DELAY:
		var before := ending.pilot.ship_x
		ending.step(Pilot.RIGHT | Pilot.FIRE)
		_expect(ending.pilot.ship_x == before + Pilot.MOVE_STEP and ending.pilot.active_shots().is_empty(),
			"Le vaisseau continue à bouger pendant le crédit final, sans tirer")
	_expect(ending.score == 50 and ending.wave.credited_remaining == 0 and ending.outcome == Round.Outcome.CLEARED,
		"Le dernier ennemi est crédité exactement une fois, puis la vague se termine")
	if failures == 0:
		print("CONTINUOUS MOTION OK: commandes, cinq familles, horloge et déplacement en fin de vague.")
	quit(1 if failures else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 12:
			printerr("FAIL: " + message)
