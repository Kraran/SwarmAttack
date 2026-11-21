extends SceneTree

const ArcadeRun = preload("res://arcade_run.gd")
const Pilot = preload("res://pilot.gd")
const ArcadeSession = preload("res://arcade_session.gd")
const ArcadeProfile = preload("res://arcade_profile.gd")
const Attract = preload("res://attract.gd")
const Docking = preload("res://docking.gd")
const Presentation = preload("res://flight_presentation.gd")
const CombatRound = preload("res://combat_round.gd")
const CombatWave = preload("res://combat_wave.gd")

# Une partie du démarrage au cycle 2. Chaque octet code gauche, droite et tir.
const FULL_CYCLE_FRAMES := 9250
const FULL_CYCLE_INPUTS := (
	"eJztWYuO7CAIVaP+/ydv5aGA+JhJbrK5W2Y7mW2V1wFEm8NHlP3bNaUUYwhJU02WnjsxPANDXNAzBrgg37IaJmeENniIaPfavAB34Ul/" +
	"ivcSa8DPZzKat9FrnTsV9AHqHmMONA9ktauAzDPthNTYR7VPZJntqs22KPh0vT0AJ7Efwn8BTtPXs9i5Bz4SIvD/C5cviQ1KbG1I+cb7" +
	"MwpaivQTcF1iWiErFkkzOxWZ909u39aoRcAauX6SUSjG++Dfw+07f4zey7HVwU8yT4ZMMpfKPHrIKV7ob3wJGFQRDl3zMKWXkyUHQpZ5" +
	"aNR/IW+RDJcAtLTnoDdBOhfkC/PZ0mEm/lr4XmsWhN9WVhhbEhXoTZrFpD2+8PnCpOdJCSTpQAYrBznW/BPMreYnufvZRsfu7UYymrgU" +
	"bVEwmFDpxO9tqRPBMmByiPVcVp8EOn5o91IKSSpmMg/Z44ajmhcQlDRLIm+W4EcTVJ9u8ey9mhQvHxtsWZoqOSrdHDSCuNx050zO0kKX" +
	"qK2aJPsR1O/jE5nNoA2j7UkqF5konUY+STq+N9VS1Enhg6it7zHzRGCrQBJFxtHDEFcIkKujR+kwoj13jHp7RhfNyQ4WFH2dC/On2PPJ" +
	"aYCcVYA9p1rVNtkJH6WnQVhTpggcza+mzSIpFvfexpjhmQ0a5sn5fId3AXU4LllgNBXrBg3hw6cKKasINeGBC7Igq/Wi14SfKXKXv9JM" +
	"ieo4QVOh2wpKmjlMILS7T/d2cRDmCy9oxOK5bZjcgHhJTtqEctUQg1zQQlitSqWvPW3pejQetUetO0pGi4myJ/uwN4oG/3n8fYn3dNfR" +
	"PQ9j/OvQrWnBnxVVTyRqu40jpwg5jdjI6QIN8IWhjllXjc5mUZWsXnrpmpZZc6J9oH9P38rHZNAG/U9jXvqOVtvzCn9BntSetsM59BF1" +
	"BuUQ18SA1t0xRwmdNaiw5oBkI21eS7j/VNOBLfZvQ+b+9PJpRf1OwJhz53MaW+RmNAS/8mi3+igsfF3Yt33rOB6RyhbYyU9CTnbljEaF" +
	"h+9B92bjGwInpy8OaydMqN/SfepqNltUgupAp+0i/+LOSvLxUONc4o1iFFvYY6y4djPfvutQOuJOiI8HLplHPrWosomjUyk2eLhEh/vC" +
	"JX0j4rokGZdYmNaaSw7W/MLnAXu7X/oD9MWhuqkf/5i+1QMiP7zN0+8kKlzk88D/BT7kCeOowBx/XgRBFS/JDZqm1HKJ3YezPkq5Mswh" +
	"eUYLy27Coz1xinqKe3yP53DsN9ZEb++Nrbv36NqUj94LvvTSr6AfTjQeSA=="
)

var _failures := 0


func _initialize() -> void:
	_test_full_cycle()
	_test_assembled_contact_edges()
	_test_wave_presentation()
	_test_ring_halves()
	_test_duo()
	_test_reserve()
	_test_difficulties()
	_test_profile()
	_test_separate_scores()
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
	_expect(run.successful_dockings == 2, "Le bilan conserve les deux amarrages du cycle complet.")
	_expect(run.cycle == 2 and run.phase == ArcadeRun.Phase.COMBAT, "Le cycle 2 doit être jouable.")
	_expect(run.frame == FULL_CYCLE_FRAMES and run.score() == 14340, "Le replay complet a divergé.")


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


func _test_wave_presentation() -> void:
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
	var interceptor := CombatWave.Enemy.new()
	interceptor.phase = CombatWave.Flight.ENTRY_CURVE
	var reveal := -1.0
	for turns in range(CombatWave.WIDE_ENTRY_TURNS, 0, -1):
		interceptor.turns_left = turns
		var next := Presentation.interceptor_reveal(interceptor)
		_expect(next > reveal, "Chaque palier révèle de nouveaux points de l’intercepteur.")
		reveal = next
	_expect(reveal == 1.0, "La coque est pleine au dernier palier de l’entrée.")
	interceptor.phase = CombatWave.Flight.RETURNING
	interceptor.return_wait = CombatWave.WIDE_RETURN_WAIT
	_expect(Presentation.interceptor_reveal(interceptor) == 0.0, "La coque se reforme au point de retour.")
	interceptor.return_wait = 1
	_expect(Presentation.interceptor_reveal(interceptor) < 1.0, "Le retour conserve son dernier palier de points.")
	interceptor.phase = CombatWave.Flight.CIRCLING
	_expect(Presentation.interceptor_reveal(interceptor) == 1.0, "La coque est pleine à la reprise de la boucle.")
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
	for tick in range(ArcadeRun.RESERVE_MESSAGE_FRAMES):
		_expect(run.reserve_shows_message() and run.entrance_elapsed() == 0 and not session.finished,
			"L’annonce de la réserve précède le retour des trois modules.")
		session.step(0)
	_expect(not run.reserve_shows_message() and run.entrance_modules() == 7,
		"Après l’annonce, le porteur complet entame son retour.")
	for tick in range(50000):
		session.step(0)
		if session.finished:
			break
	_expect(session.finished and run.cycle == 2 and not run.bonus_reserve, "La réserve s’est déclenchée deux fois.")
	run.cycle = 3
	_expect(run.max_divers() == 3, "Maximum de plongeurs au cycle 3.")
	run.cycle = 16
	_expect(run.max_divers() == 16, "Maximum de plongeurs au cycle 16.")
	for cycle in [17, 18, 32, 33, 100]:
		run.cycle = cycle
		_expect(run.max_divers() == 16, "Cycle %d : plafond de plongeurs gelé à 16 au lieu de revenir à 1." % cycle)
	# Passage réel du cycle 16 au cycle 17 : la vague reçoit toujours le plafond maximal.
	var late := ArcadeRun.new(16)
	_expect(late.combat.wave.max_divers == 16, "Le cycle 16 démarre avec 16 plongeurs simultanés.")
	late.cycle = 17
	late.wave_number = 1
	late._begin_combat(Pilot.START_X, 255)
	_expect(late.combat.wave.max_divers == 16, "La première vague du cycle 17 garde 16 plongeurs simultanés.")


func _test_difficulties() -> void:
	var profile := ArcadeProfile.new()
	_expect(profile.starting_cycle() == 1 and profile.bonus_threshold() == 30000, "Configuration normale par défaut.")
	profile.difficulty = ArcadeProfile.Difficulty.VETERANS
	var session := ArcadeSession.new(2, profile.bonus_threshold(), false, profile.starting_cycle())
	for run in session.runs:
		_expect(run.cycle == 2 and run.stage == 0 and run.wave_number == 1 and run.combat.wave.max_divers == 2,
			"Chaque joueur vétéran commence à la première vague du cycle 2 avec sa difficulté.")
		_expect(run.score() == 0 and run.lives == 3 and run.attached == 1, "État initial du mode Vétérans.")
		run.combat.score = 49999
		run.step(0)
		_expect(not run.bonus_reserve, "La réserve vétéran reste indisponible à 49 999 points.")
		run.combat.score = 50000
		run.step(0)
		_expect(run.bonus_reserve, "La réserve vétéran est acquise à 50 000 points.")


func _test_profile() -> void:
	var path := "user://test-release-%d.cfg" % OS.get_process_id()
	var profile := ArcadeProfile.new()
	var Language = ArcadeProfile.Language
	_expect(profile.language == Language.system_language() and Language.LANGUAGES.keys()[0] == "en",
		"Un nouveau profil démarre dans la langue du système ; l’anglais est proposé en premier.")
	_expect(Language.for_locale("fr_FR") == "fr" and Language.for_locale("fr_CA") == "fr" and Language.for_locale("de-AT") == "de",
		"Windows en français ou en allemand : le jeu démarre dans cette langue.")
	_expect(Language.for_locale("nb_NO") == "no" and Language.for_locale("nn") == "no" and Language.for_locale("ru_RU") == "ru",
		"Norvégien bokmål ou nynorsk et russe reconnus.")
	_expect(Language.for_locale("ja_JP") == "en" and Language.for_locale("") == "en",
		"Une langue non traduite démarre en anglais.")
	_expect(profile.scores.size() == 10 and profile.qualifies(10) and not profile.qualifies(0),
		"Dix places, dont cinq libres, au premier lancement.")
	_expect(profile.submit_score(6100, "ONE", path) == OK and profile.submit_score(7200, "TWO", path) == OK
		and profile.submit_score(7200, "TIE", path) == OK, "Insertion et égalité des scores.")
	_expect(profile.submit_score(8300, "A@Z", path) == ERR_INVALID_PARAMETER, "Initiales invalides rejetées.")
	_expect(profile.submit_score(8300, "BAD", path + "/invalid.cfg") != OK
		and profile.scores[0] == 7200 and profile.initials[0] == "TWO", "Un échec d’écriture laisse le classement intact.")
	profile.muted = true
	profile.portrait = true
	profile.fullscreen = true
	profile.difficulty = ArcadeProfile.Difficulty.VETERANS
	_expect(profile.write(path) == OK, "Échec à l’écriture du profil.")
	var reloaded := ArcadeProfile.new()
	reloaded.read(path)
	_expect(reloaded.scores_for(ArcadeProfile.Difficulty.NORMAL) == PackedInt32Array([7200, 7200, 6100, 5000, 5000, 5000, 5000, 5000, 0, 0])
		and reloaded.initials_for(ArcadeProfile.Difficulty.NORMAL).slice(0, 3) == PackedStringArray(["TWO", "TIE", "ONE"]), "Scores ou initiales mal rechargés.")
	_expect(reloaded.muted and reloaded.portrait and reloaded.fullscreen
		and reloaded.difficulty == ArcadeProfile.Difficulty.VETERANS, "Réglages mal rechargés.")
	for language in ArcadeProfile.Language.LANGUAGES:
		profile.language = language
		_expect(profile.write(path) == OK, "Écriture du profil dans la langue %s." % language)
		reloaded.read(path)
		_expect(reloaded.language == language and reloaded.scores == profile.scores and reloaded.initials == profile.initials
			and reloaded.difficulty == profile.difficulty, "Langue ou données du profil perdues à la relecture.")
	var legacy := ConfigFile.new()
	var legacy_path := path + ".legacy"
	legacy.set_value("options", "bonus_index", 1)
	legacy.set_value("records", "scores", PackedInt32Array([3400, 5000, 2200, 4300, 7200]))
	_expect(legacy.save(legacy_path) == OK, "Écriture du profil précédent.")
	reloaded.read(legacy_path)
	_expect(reloaded.difficulty == ArcadeProfile.Difficulty.NORMAL
		and reloaded.scores == PackedInt32Array([7200, 5000, 4300, 3400, 2200, 0, 0, 0, 0, 0]),
		"Le profil précédent conserve ses scores et démarre en Normal.")
	_expect(reloaded.initials == PackedStringArray(["---", "---", "---", "---", "---", "---", "---", "---", "---", "---"]),
		"Les anciens scores ne reçoivent pas d’initiales arbitraires.")
	for score in range(11, 16):
		_expect(reloaded.submit_score(score, "NEW", legacy_path) == OK, "Les cinq nouvelles places sont utilisables.")
	_expect(not reloaded.qualifies(11) and not reloaded.qualifies(10) and reloaded.qualifies(12),
		"La qualification exige de battre le dixième score.")
	_expect(reloaded.language == "fr", "Le profil précédent conserve le français par défaut.")
	legacy.set_value("options", "language", "invalid")
	_expect(legacy.save(legacy_path + ".invalid") == OK, "Écriture du profil avec une langue inconnue.")
	reloaded.read(legacy_path + ".invalid")
	_expect(reloaded.language == Language.system_language(), "Une langue inconnue revient à la langue du système.")
	DirAccess.remove_absolute(path)


func _test_separate_scores() -> void:
	var path := "user://test-separate-records-%d.cfg" % OS.get_process_id()
	var profile := ArcadeProfile.new()
	_expect(profile.submit_score(9000, "NOR", path) == OK, "Score Normal enregistré.")
	profile.difficulty = ArcadeProfile.Difficulty.VETERANS
	_expect(profile.scores == PackedInt32Array(ArcadeProfile.DEFAULT_SCORES), "Vétérans possède son classement indépendant.")
	_expect(profile.submit_score(7000, "VET", path) == OK, "Score Vétérans enregistré.")
	_expect(profile.scores_for(0)[0] == 9000 and profile.initials_for(0)[0] == "NOR"
		and profile.scores[0] == 7000 and profile.initials[0] == "VET", "Les scores et initiales sont séparés.")
	_expect(profile.submit_score(10000, "ERR", path + "/invalid.cfg", 0) != OK
		and profile.scores_for(0)[0] == 9000 and profile.scores_for(1)[0] == 7000, "Échec d’écriture sans perte dans les deux classements.")
	var loaded := ArcadeProfile.new()
	loaded.read(path)
	for mode in [0, 1]:
		_expect(loaded.scores_for(mode) == profile.scores_for(mode)
			and loaded.initials_for(mode) == profile.initials_for(mode), "Relecture des deux classements.")
	# Shared scores cannot be attributed retrospectively to a difficulty.
	var legacy := ConfigFile.new()
	var legacy_path := path + ".legacy"
	legacy.set_value("records", "scores", PackedInt32Array([8000, 7500, 5000, 5000, 5000]))
	legacy.set_value("records", "initials", PackedStringArray(["OLD", "ABC", "---", "---", "---"]))
	legacy.set_value("options", "difficulty", 1)
	_expect(legacy.save(legacy_path) == OK, "Écriture d’un ancien profil partagé.")
	loaded.read(legacy_path)
	_expect(loaded.difficulty == 1 and loaded.scores_for(0)[0] == 8000
		and loaded.initials_for(0)[0] == "OLD" and loaded.scores_for(1) == PackedInt32Array(ArcadeProfile.DEFAULT_SCORES),
		"Migration des scores partagés vers Normal et création du classement Vétérans.")
	_expect(loaded.write(legacy_path) == OK, "Sauvegarde après migration.")
	loaded.read(legacy_path)
	_expect(loaded.scores_for(0)[0] == 8000 and loaded.scores_for(1)[0] == 5000, "Migration stable après relecture.")
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
