extends SceneTree

const Attract = preload("res://attract.gd")
const ArcadeRun = preload("res://arcade_run.gd")
const Docking = preload("res://docking.gd")

var failures := 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _initialize() -> void:
	_check_cycle()
	_check_title_lines()
	_check_demo_events()
	_check_demo_volleys()
	_check_demo_matches_game_constants()
	if failures:
		printerr("%d échecs" % failures)
		quit(1)
	else:
		print("ATTRACT OK")
		quit(0)


func _at(frame: int) -> Attract:
	var attract := Attract.new()
	while attract.frame < frame:
		attract.step()
	return attract


func _demo_at(loop: int) -> Attract:
	return _at(Attract.TITLE_TEXT_FRAMES + Attract.SCORE_TABLE_FRAMES + loop)


func _check_cycle() -> void:
	# pr10e : texte 745 images de boucle, tableau 123, démo 8526.
	var attract := Attract.new()
	_expect(attract.cycle_length() == 745 + 123 + 8526, "Cycle de 9394 images de boucle, obtenu %d" % attract.cycle_length())
	_expect(attract.screen() == Attract.Screen.TITLE_TEXT, "Le cycle commence par le texte")
	_expect(_at(744).screen() == Attract.Screen.TITLE_TEXT, "Image 744 : texte")
	_expect(_at(745).screen() == Attract.Screen.SCORE_TABLE, "Image 745 : tableau des scores")
	_expect(_at(867).screen() == Attract.Screen.SCORE_TABLE, "Image 867 : tableau des scores")
	_expect(_at(868).screen() == Attract.Screen.DEMO, "Image 868 : démo")
	var wrap := _at(attract.cycle_length() - 1)
	_expect(wrap.screen() == Attract.Screen.DEMO, "Dernière image : démo")
	wrap.step()
	_expect(wrap.frame == 0 and wrap.screen() == Attract.Screen.TITLE_TEXT, "Après la démo, retour au texte")
	print("OK cycle d'attraction : texte 745, scores 123, démo 8526, puis retour au texte")


func _check_title_lines() -> void:
	var attract := _at(20)
	_expect(attract.title_line_progress(0) == 0.0, "Image 20 : aucune ligne")
	attract = _at(151)
	_expect(attract.title_line_progress(0) == 1.0, "Image 151 : première ligne complète")
	_expect(attract.title_line_progress(1) == 0.0, "Image 151 : « ESCADRONS EN APPROCHE » pas encore")
	attract = _at(661)
	for index in range(5):
		_expect(attract.title_line_progress(index) == 1.0, "Image 661 : ligne %d complète" % index)
	print("OK texte de présentation : lignes à 21–151, 181–251, 501–601, 641 et 661")


func _check_demo_events() -> void:
	# Entrée du module I (y = 120 à la boucle 281, 200 à 377), puis intro
	# d'amarrage I → II (0x809b = 2) sans vague de combat.
	var entry := _demo_at(377)
	_expect(entry.demo_value(Attract.Column.Y) == 200 and entry.demo_value(Attract.Column.STEP) == 2, "Boucle 377 : module I posé à y = 200, étape 2")
	_expect(entry.demo_attached() == 1, "Boucle 377 : module I seul")
	# Contact I → II (frame 2686) : chrono 10:7, puis écran bonus.
	var contact := _demo_at(1693)
	_expect(contact.demo_value(Attract.Column.FLAG) == 1, "Boucle 1693 : 0x8004 = 1")
	_expect(contact.demo_clock() == "10:7", "Chrono 10:7, obtenu %s" % contact.demo_clock())
	_expect(_demo_at(1694).demo_value(Attract.Column.SCREEN) == Attract.SCREEN_RESULT, "Boucle 1694 : écran bonus")
	var resume := _demo_at(1998)
	_expect(resume.demo_attached() == 3, "Boucle 1998 : reprise en I + II")
	_expect(resume.demo_value(Attract.Column.X) == 128 and resume.demo_value(Attract.Column.Y) == 232, "Reprise à 0x822b = 128, 0x822c = 232")
	# Amarrage I + II → III : temps écoulé (frame 5967), écran DOMMAGE.
	var timeout := _demo_at(4944)
	_expect(timeout.demo_value(Attract.Column.SCREEN) == Attract.SCREEN_TIMEOUT, "Boucle 4944 : écran d'expiration")
	_expect(timeout.demo_clock() == "00:0", "Chrono 00:0, obtenu %s" % timeout.demo_clock())
	var after := _demo_at(5127)
	_expect(after.demo_attached() == 3 and after.demo_value(Attract.Column.Y) == 216, "Boucle 5127 : I + II à 0x822c = 216")
	# Trois pertes : vies 3 → 2 → 1 → 0.
	_expect(_demo_at(5791).demo_value(Attract.Column.LIVES) == 3, "Boucle 5791 : 3 vies")
	_expect(_demo_at(5792).demo_value(Attract.Column.LIVES) == 2, "Boucle 5792 : 2 vies")
	_expect(_demo_at(7536).demo_value(Attract.Column.LIVES) == 1, "Boucle 7536 : 1 vie")
	_expect(_demo_at(8525).demo_value(Attract.Column.LIVES) == 1, "Boucle 8525 : encore 1 vie")
	_expect(_demo_at(5664).demo_attached() == 0, "Après la perte du I + II, aucun module actif pendant l'entrée")
	_expect(_demo_at(6169).demo_attached() == 1, "Le module I reprend après la perte du I + II")
	_expect(_demo_at(7913).demo_attached() == 4, "Le module III reprend après la perte du I")
	print("OK démo : entrée du I, amarrage I → II réussi (10:7), I + II → III expiré, trois pertes")


func _check_demo_volleys() -> void:
	# Une volée toutes les 64 images de boucle, seulement avec le I + II.
	var attract := _demo_at(0)
	var volleys: Array[int] = []
	for _index in range(Attract.DEMO_FRAMES - 1):
		attract.step()
		if attract.demo_volley():
			volleys.append(attract.demo_frame())
	_expect(volleys.size() == 25, "25 volées, obtenu %d" % volleys.size())
	_expect(volleys[0] == 2045 and volleys[18] == 3187, "Première série 2045–3187, obtenu %d–%d" % [volleys[0], volleys[18]])
	_expect(volleys[19] == 5174 and volleys[24] == 5494, "Seconde série 5174–5494, obtenu %d–%d" % [volleys[19], volleys[24]])
	# Exception : 54 images entre 2557 et 2611, la volée de 2611 partant à
	# l'image du changement de vague (0x809b 3 → 4).
	_expect(volleys[9] - volleys[8] == 54, "Écart de 54 images au changement de vague")
	for index in range(1, 25):
		if index != 9 and index != 19:
			_expect(volleys[index] - volleys[index - 1] == 64, "Écart de 64 images avant la volée %d, obtenu %d" % [index, volleys[index] - volleys[index - 1]])
	print("OK démo : 25 volées du I + II, au rythme de 64 images (54 au changement de vague)")


func _check_demo_matches_game_constants() -> void:
	# Les durées de la démo recoupent celles de la partie.
	_expect(1998 - 1693 == Docking.BONUS_HOLD, "Écran bonus de la démo : 305 images")
	_expect(5127 - 4944 == Docking.TIMEOUT_HOLD, "Écran d'expiration de la démo : 183 images")
	_expect(5792 - 5503 == ArcadeRun.COUNTER_DROP_FRAMES, "Perte du I + II : 289 images jusqu'à la baisse des vies")
	_expect(7536 - 7247 == ArcadeRun.COUNTER_DROP_FRAMES, "Perte du I : 289 images")
	var last := _demo_at(8209)
	_expect(last.demo_value(Attract.Column.FLAG) == 1, "Boucle 8209 : dernière perte")
	print("OK démo : bonus 305, expiration 183, pertes 289 comme en partie ; dernière perte 317 images jusqu'au texte")
