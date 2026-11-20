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
	# The ten-entry table gets a longer reading time; demo timing is relative.
	var attract := Attract.new()
	_expect(attract.cycle_length() == 745 + 480 + 8526, "Durée du cycle d’attraction, obtenu %d" % attract.cycle_length())
	_expect(attract.screen() == Attract.Screen.TITLE_TEXT, "Le cycle commence par le texte")
	_expect(_at(744).screen() == Attract.Screen.TITLE_TEXT, "Image 744 : texte")
	_expect(_at(745).screen() == Attract.Screen.SCORE_TABLE, "Image 745 : tableau des scores")
	_expect(_at(1224).screen() == Attract.Screen.SCORE_TABLE, "Dernière image du tableau des scores")
	_expect(_at(1225).screen() == Attract.Screen.DEMO, "Début de la démo après le tableau")
	var wrap := _at(attract.cycle_length() - 1)
	_expect(wrap.screen() == Attract.Screen.DEMO, "Dernière image : démo")
	wrap.step()
	_expect(wrap.frame == 0 and wrap.screen() == Attract.Screen.TITLE_TEXT, "Après la démo, retour au texte")
	print("OK cycle d’attraction : texte 745, scores 480, démo 8526, puis retour au texte")


func _check_title_lines() -> void:
	var attract := _at(20)
	_expect(attract.title_line_progress(0) == 0.0, "Image 20 : aucune ligne")
	attract = _at(151)
	_expect(attract.title_line_progress(0) == 1.0, "Image 151 : première ligne complète")
	_expect(attract.title_line_progress(1) == 0.0, "Image 151 : le titre est encore hors champ")
	attract = _at(181)
	_expect(attract.title_line_progress(1) == 0.0, "Le titre commence hors champ à droite")
	_expect(attract.title_line_progress(1, 0.5) > 0.0, "Le titre défile entre deux pas")
	_expect(is_equal_approx(_at(216).title_line_progress(1), 0.5), "Image 216 : titre à mi-course")
	_expect(_at(251).title_line_progress(1) == 1.0, "Image 251 : titre centré")
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
	# Amarrage I + II → III retouché : approche au-dessus du III, puis contact.
	var approach := _demo_at(Attract.SECOND_DOCKING_CONTACT - 1)
	_expect(approach.demo_value(Attract.Column.MODULE_III) == 2 and approach.demo_value(Attract.Column.STEP) == 5, "Approche du III, chrono en marche")
	for loop in range(Attract.SECOND_DOCKING_PATH, Attract.SECOND_DOCKING_CONTACT, 7):
		var objects := _demo_at(loop).demo_objects()
		var module_i := Vector2(objects[Attract.MODULE_OFFSET], objects[Attract.MODULE_OFFSET + 1])
		_expect(module_i.y + 8 <= Attract.DOCKED_Y + 8 and absf(module_i.x - Attract.DOCKED_X) <= 6, "Boucle %d : le I + II reste au-dessus du III" % loop)
	var contact_iii := _demo_at(Attract.SECOND_DOCKING_CONTACT)
	_expect(contact_iii.demo_value(Attract.Column.SCREEN) == Attract.SCREEN_RESULT and contact_iii.demo_attached() == 7, "Contact I + II → III : écran bonus, trois modules")
	var bonus := contact_iii.demo_bonus()
	_expect(bonus.y == 300 and bonus.x > 0 and bonus.x % 300 == 0, "Bonus du second amarrage au multiplicateur 300, obtenu %s" % bonus)
	var after := _demo_at(5127)
	_expect(after.demo_attached() == 7 and after.demo_value(Attract.Column.Y) == 216, "Boucle 5127 : I + II + III à 0x822c = 216")
	_expect(after.demo_value(Attract.Column.STEP) == 6, "Boucle 5127 : reprise du combat")
	var loss := _demo_at(Attract.SECOND_DOCKING_LOSS)
	_expect(loss.demo_value(Attract.Column.MODULE_II) == 0 and loss.demo_value(Attract.Column.MODULE_III) == 3, "Perte du II : le III repasse en réserve")
	# Explosions : ennemis abattus et trois modules perdus.
	var ships := 0
	var enemies := 0
	var demo := _demo_at(0)
	for _index in range(Attract.DEMO_FRAMES - 1):
		demo.step()
		for burst in demo.demo_bursts():
			if burst[3] == 0.0:
				if burst[0]:
					ships += 1
				else:
					enemies += 1
	_expect(ships == 3, "Trois explosions de modules, obtenu %d" % ships)
	_expect(enemies >= 20, "Ennemis abattus visibles, obtenu %d" % enemies)
	# Trois pertes : vies 3 → 2 → 1 → 0.
	_expect(_demo_at(5791).demo_value(Attract.Column.LIVES) == 3, "Boucle 5791 : 3 vies")
	_expect(_demo_at(5792).demo_value(Attract.Column.LIVES) == 2, "Boucle 5792 : 2 vies")
	_expect(_demo_at(7536).demo_value(Attract.Column.LIVES) == 1, "Boucle 7536 : 1 vie")
	_expect(_demo_at(8525).demo_value(Attract.Column.LIVES) == 1, "Boucle 8525 : encore 1 vie")
	_expect(_demo_at(5664).demo_attached() == 0, "Après la perte du I + II, aucun module actif pendant l'entrée")
	_expect(_demo_at(6169).demo_attached() == 1, "Le module I reprend après la perte du I + II")
	_expect(_demo_at(7913).demo_attached() == 4, "Le module III reprend après la perte du I")
	print("OK démo : entrée du I, amarrage I → II réussi (10:7), I + II → III réussi, explosions, trois pertes")


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
	_expect(Attract.SECOND_DOCKING_RESUME - Attract.SECOND_DOCKING_CONTACT == Docking.BONUS_HOLD, "Second écran bonus de la démo : 305 images")
	_expect(5792 - 5503 == ArcadeRun.COUNTER_DROP_FRAMES, "Perte du I + II : 289 images jusqu'à la baisse des vies")
	_expect(7536 - 7247 == ArcadeRun.COUNTER_DROP_FRAMES, "Perte du I : 289 images")
	var last := _demo_at(8209)
	_expect(last.demo_value(Attract.Column.FLAG) == 1, "Boucle 8209 : dernière perte")
	print("OK démo : bonus 305 (deux fois), pertes 289 comme en partie ; dernière perte 317 images jusqu'au texte")
