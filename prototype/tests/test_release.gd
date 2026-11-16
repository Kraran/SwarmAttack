extends SceneTree

const ArcadeRun = preload("res://arcade_run.gd")
const ArcadeSession = preload("res://arcade_session.gd")
const ArcadeProfile = preload("res://arcade_profile.gd")
const Attract = preload("res://attract.gd")
const Docking = preload("res://docking.gd")
const Presentation = preload("res://flight_presentation.gd")
const CombatRound = preload("res://combat_round.gd")
const CombatWave = preload("res://combat_wave.gd")

# Une partie du démarrage au cycle 2. Chaque octet code gauche, droite et tir.
const FULL_CYCLE_FRAMES := 10432
const FULL_CYCLE_INPUTS := (
	"eJztWoty7CAIRUbz/598o4AgosnutrftTE5mmt1EEQ7H5zbDS8iL5wcipgRAf897vRDr4/MJvZkAkEZk87mZTVBL1WbpodRh" +
	"A6f55G0sgemQenhU8+pIbQYjD6vvvoGiDpJzxtJYQh09CyZYuVoSsiG6ETWRNx3HTCWyfW4tagd2diuxkhCs+TpQPAEX5Rkn" +
	"XWSWqy+gTLR0grjeSQS+3RJe5x7NdcAcsDaBKseBPl+BNNDyVHrmOO6LbMQRr1A01bZw4U4i/ifAoGkt3r41C9j7yWhPRE6U" +
	"kSXmiknf+glpEPsuL7M02iXfY9aoc2GgZuVeYrrytWzfsvi0gx1XHcy5GtLDmHPUazWuF0oOoUa78cNoUOtywSyO7FLEr09v" +
	"MtHKHhuvlQ0ayHXgmj2cBrJoGC4ylpjn1V9U+S1Thb0BsgIgcu1OB8lXFxGC5HaN0ShHXQZBOyKzLFQsNLkTCfFlxUG0r2O1" +
	"sl0IUu2EtWwEIvJbyD2Zt6tMKPKh+qcZV/vDzNHuo/jlqaMxA3TadJVA5AK7zMTWzzkNo3tMOPSEZ+Ityl5vyMFok7NSdlm1" +
	"+SI3sz4h3k1QkYqcBFLvB+D4ymLN6qyQmu7N9Ra6Ennw4C6OHZqmv/BeG8wn7P1VbLrujwNRNwGf4pU2fT3vg6/zVeJ5wGgj" +
	"P68h6IFTwvAOSMXQ7jnMPkCodJ4ZoO5aZOPUJlaSAtAurRakLYhsGMRc5mUkt9GVMbS2W47LuyaqZiRWb7wCiyxt4axbRtet" +
	"2B3u/xTBgwfvIpgKF9oeuxkV9Tofe4yUMX1u3EL6ll0X7d9lL0Bdeahhai169jp27coXZcbQFzOkqyW7CzdUaDkdHH34FMva" +
	"p/3QpcdQ0+h0E25nfIsV3FSYTnsa5dSIOX5cQm0s+ACxs2dJ9bGMYmCJmAwObMPg07B53SGPXwbzRi5TkxdSjYNOWaZu+gsa" +
	"m1CRhgOHzkALX3IzZMma36cOg7ky8Bmmvi/zKOrqgiovJdvtUROFxxplRVr3nh9Lq0OcgJPEegQgHmOZo5xjngmK8jhTacM1" +
	"gN1pc31bvPmKdY8yrSxy2nIzRtTOv2E4xeieSiG+7q2OrA1bu/0YIKOnjcXGLBeT9izJHvwNbI8mZn2PCi9Jzvw+RbNEaxg5" +
	"RldIn0T9RcANlmaQ5SuMI9xHSSMa337OWzOmJr+brgcPKi4PNd/F9frk+1ED/CSGV2OJ6nkfojo/K4E/j8V4yoT374VH5vF3" +
	"JD5AbMUP+/NktEStY29haQU/efr8LzuQzjaR73hr43TNxzwHbsWr/5jRnAD77ySNmFJXzEbEbZbcEBCET8XmYw+c9jgBDFeY" +
	"joAf9Kvmt342efDg1+EftqAeHg=="
)

var _failures := 0


func _initialize() -> void:
	_test_full_cycle()
	_test_assembled_contact_edges()
	_test_jeutel_presentation()
	_test_ring_halves()
	_test_duo()
	_test_reserve()
	_test_profile()
	_test_attraction_objects()
	if _failures == 0:
		print("LIVRAISON OK · cycle complet, duo, réserve, profil, démo")
	quit(1 if _failures else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr(message)


func _test_full_cycle() -> void:
	var session := ArcadeSession.new()
	var run := session.current
	var inputs := Marshalls.base64_to_raw(FULL_CYCLE_INPUTS).decompress(FULL_CYCLE_FRAMES, FileAccess.COMPRESSION_DEFLATE)
	var successes := 0
	var was_success := false
	for mask in inputs:
		session.step(mask)
		var in_success := run.docking != null and run.docking.stage == Docking.Stage.SUCCESS
		if in_success and not was_success:
			successes += 1
		was_success = in_success
	_expect(successes == 2, "Le cycle complet doit réussir les deux amarrages.")
	_expect(run.cycle == 2 and run.phase == ArcadeRun.Phase.COMBAT, "Le cycle 2 doit être jouable.")
	_expect(run.frame == FULL_CYCLE_FRAMES and run.score() == 11340, "Le replay complet a divergé.")


func _test_assembled_contact_edges() -> void:
	var cases := {
		Vector2i(3, -4): Docking.Stage.SUCCESS,
		Vector2i(14, -4): Docking.Stage.SUCCESS,
		Vector2i(2, -4): Docking.Stage.APPROACH,
		Vector2i(15, -4): Docking.Stage.APPROACH,
		Vector2i(8, -3): Docking.Stage.COLLISION,
		Vector2i(-17, -3): Docking.Stage.COLLISION,
		Vector2i(34, 12): Docking.Stage.COLLISION,
		Vector2i(-18, -3): Docking.Stage.APPROACH,
		Vector2i(35, 12): Docking.Stage.APPROACH,
		Vector2i(34, 13): Docking.Stage.APPROACH,
	}
	for offset in cases:
		var dock := Docking.new(1, 112, false, 3)
		dock.position = Docking.TARGET + offset
		dock._resolve_contact()
		_expect(dock.stage == cases[offset], "Contact I + II → III incorrect à %s." % str(offset))


func _test_jeutel_presentation() -> void:
	var banks := [0, 0, 2, 2, 1, 1, 3, 3, 4, 4]
	var number := 0
	for stage in range(3):
		for wave in range(1 if stage == 0 else 3, 7 if stage == 1 else 5):
			number += 1
			_expect(Presentation.cycle_wave(wave, stage) == number, "Numérotation incorrecte après amarrage.")
			_expect(Presentation.enemy_kind(number) == banks[number - 1], "Mauvaise banque d’ennemis à la vague %d." % number)
	_expect(number == Presentation.WAVES_PER_CYCLE, "Le cycle contient dix vagues.")
	var last := 0.0
	for tier in range(8):
		var size := Presentation.meteor_scale(16 - 2 * tier)
		_expect(size > last and size == Presentation.meteor_scale(15 - 2 * tier), "Palier de taille du météore incorrect.")
		last = size
	_expect(Presentation.meteor_scale(16) == 0.25 and Presentation.meteor_scale(0) == 1.0, "Diamètres extrêmes incorrects.")
	last = 0.0
	for tier in range(8):
		var size := Presentation.capsule_scale(16 - 2 * tier)
		_expect(size > last and size == Presentation.capsule_scale(15 - 2 * tier), "Palier d'entrée de capsule incorrect.")
		last = size
	_expect(Presentation.capsule_scale(0) == 1.0, "Capsule hors échelle après l'entrée.")
	_expect(Presentation.docked_module_origin(1, 2, 216) == Vector2(112, 216), "Module I non aligné sur le II.")
	for module in range(1, 4):
		var expected := Vector2(112, 192 + 8 * module)
		_expect(Presentation.docked_module_origin(module, 3, 216) == expected, "Stack complet mal aligné.")


func _test_ring_halves() -> void:
	for wave_number in [1, 2]:
		var combat := CombatRound.new(wave_number)
		for tick in range(100):
			combat.step(0)
		var wave := combat.wave
		var first := wave.enemies[0]
		var partner := wave.enemies[1]
		_expect(first.position == partner.position, "Les deux moitiés doivent partager le pivot au départ.")
		_expect(combat._try_hit(first.position - Vector2i(17, 4)), "Le projectile doit toucher une moitié.")
		_expect(combat.impacted_enemy == first and not first.alive and partner.alive, "Un impact doit détruire une seule moitié.")
		_expect(wave.remaining == 7 and wave.credited_remaining == 8, "Chaque moitié est une cible indépendante.")
		for tick in range(14):
			combat.step(0)
		_expect(combat.score == 50 and partner.alive, "Une moitié détruite vaut 50 points.")

		wave = CombatWave.new(wave_number)
		var frame := 105
		for tick in range(1, frame + 1):
			wave.advance(tick, 112)
		for index in range(4):
			wave.kill(index)
		for index in range(3):
			wave.credit_kill()
		var left := wave.enemies[4]
		var right := wave.enemies[5]
		for tick in range(20):
			frame += 1
			wave.advance(frame, 112)
		_expect(wave.credited_remaining == 5 and left.position == right.position, "À cinq crédits restants, la paire reste assemblée.")
		wave.credit_kill()
		var separated := false
		for tick in range(120):
			frame += 1
			wave.advance(frame, 112)
			if left.position != right.position:
				separated = true
				break
		_expect(wave.credited_remaining == 4 and separated and left.alive and right.alive, "Sous cinq survivants, les deux moitiés s’écartent en piqué.")


func _test_duo() -> void:
	var session := ArcadeSession.new(2, 50000)
	var first := session.runs[0]
	var second := session.runs[1]
	first.combat.score = 400
	for tick in range(50000):
		if session.finished:
			break
		var previous := session.current
		var previous_lives := previous.lives
		var waiting := session.runs[1 - session.player]
		var waiting_frame := waiting.frame
		session.step(0)
		_expect(session.runs[0].score() == 400 and second.score() == 0, "Scores mélangés en duo.")
		if previous.lives != previous_lives and waiting.lives > 0:
			_expect(session.current != previous, "Pas de changement après la perte d’un module.")
			_expect(session.current.frame == waiting_frame, "Le joueur en attente a avancé.")
	_expect(session.finished and first.lives == 0 and second.lives == 0, "Fin de partie en duo incorrecte.")
	_expect(first.bonus_threshold == 50000 and second.bonus_threshold == 50000, "Seuil incorrect en duo.")


func _test_reserve() -> void:
	var session := ArcadeSession.new()
	var run := session.current
	run.combat.score = 29990
	session.step(0)
	_expect(not run.bonus_reserve, "Réserve créditée sous le seuil.")
	run.combat.score = 30000
	session.step(0)
	_expect(run.bonus_reserve and run.lives == 3, "Réserve non mise de côté au seuil.")
	for tick in range(50000):
		session.step(0)
		if run.cycle > 1 or session.finished:
			break
	_expect(run.lives == 3 and run.cycle == 2 and not run.bonus_reserve, "Réserve de trois modules incorrecte.")
	_expect(run.score() == 30000, "Score effacé par la réserve.")
	for tick in range(50000):
		session.step(0)
		if session.finished:
			break
	_expect(session.finished and run.cycle == 2 and not run.bonus_reserve, "La réserve s’est déclenchée deux fois.")
	run.cycle = 3
	_expect(run.max_divers() == 3, "Maximum Jeutel au cycle 3.")
	run.cycle = 17
	_expect(run.max_divers() == 1, "Le quartet de cycle du maximum Jeutel doit revenir à zéro.")


func _test_profile() -> void:
	var path := "user://test-release-%d.cfg" % OS.get_process_id()
	var profile := ArcadeProfile.new()
	_expect(profile.record(6100) and profile.record(7200) and not profile.record(10), "Insertion de scores incorrecte.")
	profile.muted = true
	profile.portrait = true
	profile.fullscreen = true
	profile.bonus_index = 1
	_expect(profile.write(path) == OK, "Échec à l’écriture du profil.")
	var reloaded := ArcadeProfile.new()
	reloaded.read(path)
	_expect(reloaded.scores == PackedInt32Array([7200, 6100, 5000, 5000, 5000]), "Scores mal rechargés.")
	_expect(reloaded.muted and reloaded.portrait and reloaded.fullscreen and reloaded.bonus_index == 1, "Réglages mal rechargés.")
	DirAccess.remove_absolute(path)


func _test_attraction_objects() -> void:
	var attract := Attract.new()
	attract.frame = Attract.TITLE_TEXT_FRAMES + Attract.SCORE_TABLE_FRAMES
	var varied := false
	var previous := attract.demo_objects()
	_expect(previous.size() == Attract.VISUAL_STRIDE, "Objets manquants au début de la démo.")
	for tick in range(1, Attract.DEMO_FRAMES):
		attract.step()
		var current := attract.demo_objects()
		_expect(current.size() == Attract.VISUAL_STRIDE, "Objets manquants pendant la démo.")
		if tick == 1693:
			_expect(current.slice(Attract.MODULE_OFFSET, Attract.MODULE_OFFSET + 6) == PackedByteArray([112, 216, 112, 224, 255, 0]), "Positions relevées après l’amarrage I → II en démo.")
		varied = varied or current != previous
		previous = current
	_expect(varied, "Objets immobiles pendant toute la démo.")
	attract.step()
	_expect(attract.demo_objects().is_empty(), "Les objets restent visibles après la démo.")
