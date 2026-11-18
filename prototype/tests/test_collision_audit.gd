extends SceneTree

const Wave = preload("res://combat_wave.gd")
const Round = preload("res://combat_round.gd")
const Pilot = preload("res://pilot.gd")
const Docking = preload("res://docking.gd")
const Geometry = preload("res://collision_geometry.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_static_module_grid()
	_projectile_boundaries()
	_hidden_and_dead()
	_target_order()
	_real_crossings()
	_wraps_and_respawns()
	_single_credit()
	_sweep_properties()
	_docking_grid()
	print("COLLISION AUDIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _wave() -> Wave:
	var wave := Wave.new(3)
	var enemy := Wave.Enemy.new()
	enemy.position = Vector2i(112,100)
	wave.enemies.assign([enemy])
	return wave

func _static_module_grid() -> void:
	var wave := _wave()
	var enemy := wave.enemies[0]
	var values := PackedByteArray()
	for mask in range(1,8):
		var reached := 0
		for offset in [0,16]:
			for ship_x in [14,112,200]:
				for y in range(168,249):
					for dx in range(-40,41):
						enemy.position = Vector2i(ship_x+dx,y)
						var module := wave.hit_module(ship_x,mask,offset)
						values.append(module)
						if module > 0:
							reached |= 1 << (module-1)
						_expect(module == 0 or bool(mask & (1 << (module-1))), "Une coque absente ne peut être touchée")
		_expect(reached == mask,"Chaque module présent peut être touché, masque %d" % mask)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(values)
	_expect(digest.finish().hex_encode() == "123ffacc97604f15ab363ab56472f513e65fb3459bc6f4e14a38c98092fab068",
		"Les 275562 contacts fixes conservent les limites validées avant correction")
	print("OK 275562 positions : 7 assemblages, offsets 0/16, centre et butées")

func _projectile_boundaries() -> void:
	var wave := _wave()
	var enemy := wave.enemies[0]
	for dx in range(-2,18):
		for dy in range(-2,14):
			enemy.alive = true
			var shot := enemy.position - Vector2i(17,4) + Vector2i(dx,dy)
			var hit := wave.hit_by(shot)
			_expect((hit != null) == (dx >= 0 and dx < 16 and dy >= 0 and dy < 12), "Limite exacte du tir, sans erreur d'un pixel")
	# Aucune immunité artificielle lorsque l'ennemi est visible en haut.
	enemy.alive = true
	enemy.position = Vector2i(112,7)
	_expect(wave.hit_by(Vector2i(95,3)) == enemy,"Une cible visible reste touchable au bord supérieur")

func _hidden_and_dead() -> void:
	for phase in [Wave.Flight.FALL_EXIT,Wave.Flight.ROW_EXIT]:
		var wave := _wave()
		var enemy := wave.enemies[0]
		enemy.phase = phase
		_expect(wave.hit_by(Vector2i(95,96)) == null,"Pas d'impact sur une sortie masquée")
		enemy.position = Vector2i(112,200)
		_expect(wave.hit_module(112,7) == 0 and not wave.hits_ship(112,2),"Une sortie masquée ne détruit pas un module")
	var dead := _wave()
	dead.enemies[0].alive = false
	_expect(dead.hit_by(Vector2i(95,96)) == null,"Une coque ennemie détruite ne reçoit pas un deuxième impact")

func _target_order() -> void:
	for reversed in [false,true]:
		var wave := Wave.new(3,3)
		var upper := Wave.Enemy.new()
		upper.position = Vector2i(112,100)
		var lower := Wave.Enemy.new()
		lower.position = Vector2i(112,108)
		wave.enemies.assign([lower,upper] if reversed else [upper,lower])
		_expect(wave.hit_by(Vector2i(95,104)) == lower and upper.alive,"Un tir rencontre la coque du bas, indépendamment de l'ordre des objets")
	var ring := Wave.new(1,3)
	var left := Wave.Enemy.new()
	left.position = Vector2i(112,100)
	var right := Wave.Enemy.new()
	right.position = left.position
	ring.enemies.assign([left,right])
	_expect(ring.hit_by(Vector2i(95,96)) == left and right.alive and ring.remaining == 1,
		"Les deux demi-coques superposées restent deux cibles indépendantes")

func _real_crossings() -> void:
	var round := Round.new(3)
	var enemy := Wave.Enemy.new()
	enemy.position = Vector2i(110,192)
	enemy.velocity = Vector2i(4,-4)
	round.wave.enemies.assign([enemy])
	round.wave._wave_clock = 33
	round.step(0)
	_expect(round.lost_module == 1,"Contact en diagonale entre deux frames : module I touché")
	round = Round.new(3)
	enemy = Wave.Enemy.new()
	enemy.position = Vector2i(113,100)
	enemy.velocity = Vector2i(-4,4)
	round.wave.enemies.assign([enemy])
	round.wave._wave_clock = 33
	round.pilot.shot_active = true
	round.pilot.shot_position = Vector2i(95,103)
	round.step(0)
	_expect(not enemy.alive,"Croisement tir/ennemi pris en compte malgré deux extrémités hors de la zone")
	# Un vrai frôlement reste un raté.
	_expect(is_inf(Geometry.sweep_time(Vector2(-1,-2),Vector2(17,-1),Rect2(0,0,16,12))),"Pas d'impact lorsque le trajet reste juste hors de la zone")

func _wraps_and_respawns() -> void:
	var wave := _wave()
	var enemy := wave.enemies[0]
	enemy.position = Vector2i(2,100)
	var previous := {enemy:Vector2i(250,100)}
	_expect(wave.hit_by(Vector2i(95,96),Vector2(95,100),previous) == null,"Le retour 250 → 2 ne balaie pas l'écran")
	enemy.position = Vector2i(112,2)
	previous[enemy] = Vector2i(112,250)
	_expect(wave.hit_module(112,7,0,112,previous) == 0,"Le retour vertical 250 → 2 n'explose pas les modules traversés fictivement")
	enemy.position = Vector2i(113,100)
	_expect(wave.hit_by(Vector2i(96,95),Vector2(96,110),{}) == null,"Une apparition ne reçoit pas une collision située avant son existence")

func _single_credit() -> void:
	var round := Round.new(3,1,112,3)
	var first := Wave.Enemy.new()
	first.position = Vector2i(112,100)
	first.velocity = Vector2i.ZERO
	var second := Wave.Enemy.new()
	second.position = first.position
	second.velocity = Vector2i.ZERO
	round.wave.enemies.assign([first,second])
	round.wave._wave_clock = 100
	round.pilot.shot_active = true
	round.pilot.shot_position = Vector2i(95,100)
	round.pilot.second_shot_active = true
	round.pilot.second_shot_position = Vector2i(95,100)
	round.step(0)
	for frame in Round.SCORE_DELAY + 4:
		round.step(0)
	_expect(round.score == 60 and round.wave.remaining == 0 and round.wave.credited_remaining == 0,
		"Deux tirs simultanés : deux ennemis crédités une seule fois, sans cible négative")

func _sweep_properties() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4071980
	var bounds := Rect2(0,0,16,12)
	for index in 10000:
		var from := Vector2(rng.randi_range(-25,35),rng.randi_range(-25,35))
		var to := Vector2(rng.randi_range(-25,35),rng.randi_range(-25,35))
		var time := Geometry.sweep_time(from,to,bounds)
		var reverse := Geometry.sweep_time(to,from,bounds)
		_expect(is_inf(time) == is_inf(reverse),"La détection ne dépend pas du sens de parcours d'un segment")
		var shift := Vector2(37,-19)
		var moved := Geometry.sweep_time(from+shift,to+shift,Rect2(shift,bounds.size))
		_expect((is_inf(time) and is_inf(moved)) or is_equal_approx(time,moved),"Invariance par translation")
		if is_inf(time):
			for sample in range(0,33):
				_expect(not bounds.has_point(from.lerp(to,sample/32.0)),"Aucun contact échantillonné ne doit être manqué")
	print("OK 10000 segments déterministes : frôlements, sens inverse et translations")

func _docking_grid() -> void:
	for configuration in [[1,2],[2,3],[3,3],[1,3]]:
		var captures := 0
		var crashes := 0
		for y in range(-30,21):
			for x in range(-40,41):
				var module := 2 if configuration[0] == 2 else 1
				var dock := Docking.new(module,112,false,configuration[0],configuration[1])
				dock.position = Docking.TARGET + Vector2i(x,y)
				dock._resolve_contact()
				var stage := dock.stage
				var bonus := dock.bonus
				if stage == Docking.Stage.SUCCESS:
					captures += 1
				elif stage == Docking.Stage.COLLISION:
					crashes += 1
				if stage != Docking.Stage.APPROACH:
					dock.step(Pilot.FIRE|Pilot.LEFT)
					_expect(dock.stage == stage and dock.bonus == bonus,"L'issue d'un contact ne change pas au pas suivant")
		_expect(captures == 36,"Amarrage %s : fenêtre de réussite inchangée, y compris ses bords" % str(configuration))
		_expect(crashes == (272 if configuration == [1,2] else 832),"Amarrage %s : volume de collision inchangé" % str(configuration))
	print("OK 16524 positions d'amarrage : 4 combinaisons, priorité collision et stabilité des résultats")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		if failures <= 12:
			printerr("FAIL: " + message)
