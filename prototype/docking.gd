extends RefCounted

const Pilot = preload("res://pilot.gd")
const TARGET := Vector2i(112, 216)
const LIFT_WAIT := 48
const LIFT_HEIGHT := 76
const TARGET_ARRIVAL := 200
const BOARD_FRAMES_PER_CONTROL := 4
const LIFT_END := LIFT_WAIT + LIFT_HEIGHT * BOARD_FRAMES_PER_CONTROL
const START_CLOCK_TENTHS := 310
const APPROACH_CLOCK_TENTHS := 300
# Écran bonus relevé : 305 images entre le contact (frame 7417) et la reprise (7723).
const BONUS_HOLD := 305
# Relevé pr1-collision : impact à 7452, texte visible à 7614, reprise à 7918.
const COLLISION_MESSAGE_FROM := 162
const COLLISION_HOLD := 466
# 8125 − 7942 : du chrono à 00:0 jusqu'à la reprise avec le module en approche.
const TIMEOUT_HOLD := 183
# pr7 : après la montée I + II → III (chrono à 15173, 0x822c = 156), le premier
# cran 30:09 tombe à 15325, soit 152 images au rythme de 0x8005. pr5c I + II
# donne le même écart en 0x8005 (le 168 mural de 9904 à 10072 inclut 16 figées).
const I_II_III_POST_LIFT := 152
# Altitude de combat du I + II après la réussite I + II (0x822c = 232) : la
# position logique d'approche vaut 0x822c − 8, comme le module I.
const I_II_START_Y := 224

enum Stage { INTRO, APPROACH, SUCCESS, COLLISION, TIMED_OUT }

class Axis:
	var velocity: int
	var wait := 0

	func _init(initial_velocity: int) -> void:
		velocity = initial_velocity

	func step(acceleration: int) -> int:
		velocity = clampi(velocity + acceleration, 64, 192)
		if wait > 0:
			wait -= 1
			return 0
		var speed := velocity if velocity < 128 else 256 - velocity
		wait = (speed - 64) >> 5
		return 1 if velocity < 128 else -1

var module: int
var attached: int
var target_module: int
var position: Vector2i
var target_y := 256
var stage := Stage.INTRO
var bonus := 0
var remaining_tenths := APPROACH_CLOCK_TENTHS
var thrusting := false
var _elapsed := 0
var _result_frames := 0
var _horizontal := Axis.new(128)
var _vertical := Axis.new(120)


func _init(approaching_module: int, ship_x: int, show_intro := true, attached_modules := 0, target := 0) -> void:
	module = approaching_module
	attached = attached_modules if attached_modules != 0 else 1 << (approaching_module - 1)
	target_module = target if target in [2, 3] else (3 if is_i_and_ii() or module == 2 else 2)
	if is_i_and_ii():
		# pr7 : l'intro part de 0x822c = 232 (0x8143 = 208, 0x8148 = 216),
		# à l'abscisse courante (butée droite 0x822b = 216, x = 200).
		position = Vector2i(ship_x + 8, I_II_START_Y)
	else:
		position = Vector2i(ship_x + (8 if module == 1 else 0), 192 if module == 1 else 200)
		if is_i_to_iii():
			position.y += 16
	if not show_intro:
		position.y -= LIFT_HEIGHT
		_release()


func is_i_and_ii() -> bool:
	return bool(attached & 1) and bool(attached & 2) and not bool(attached & 4)


func is_i_to_iii() -> bool:
	return attached == 1 and target_module == 3


func display_position() -> Vector2:
	return Vector2(position.x - (8 if module == 1 else 0), position.y + 8 - (16 if is_i_to_iii() else 0))


func movement_intervals() -> Vector2i:
	if stage == Stage.APPROACH:
		return Vector2i(_horizontal.wait + 1, _vertical.wait + 1) * BOARD_FRAMES_PER_CONTROL
	return Vector2i.ONE * BOARD_FRAMES_PER_CONTROL


func display_clock_tenths() -> int:
	var tenths := remaining_tenths
	if stage == Stage.INTRO:
		# Le chrono compte de 30:0 à 30:1 avant la prise des commandes.
		var frames_left := _intro_duration() - _elapsed
		tenths = mini(START_CLOCK_TENTHS, APPROACH_CLOCK_TENTHS + ceili(float(frames_left) / BOARD_FRAMES_PER_CONTROL))
	return tenths


func display_clock() -> String:
	var tenths := display_clock_tenths()
	var seconds := maxi(0, (tenths - 1) / 10)
	return "%02d:%d" % [seconds, tenths % 10]


func briefing_visible() -> bool:
	# Le 30:0 apparaît à la fin de la montée du vaisseau, avant celle de la cible.
	return stage == Stage.INTRO and _elapsed < LIFT_END


func lifting() -> bool:
	return stage == Stage.INTRO and _elapsed > LIFT_WAIT and _elapsed <= LIFT_END


func timeout_shows_message() -> bool:
	# Le chronomètre affiche 00:0 une image avant le message de résultat.
	return stage == Stage.TIMED_OUT and _result_frames > 0


func collision_shows_message() -> bool:
	return stage == Stage.COLLISION and _result_frames >= COLLISION_MESSAGE_FROM


func credited_bonus() -> int:
	return bonus if _result_frames >= BONUS_HOLD else 0


func result_hold() -> int:
	match stage:
		Stage.SUCCESS:
			return BONUS_HOLD
		Stage.COLLISION:
			return COLLISION_HOLD
		Stage.TIMED_OUT:
			return TIMEOUT_HOLD
		_:
			return 0


func is_ready_to_resume() -> bool:
	var hold := result_hold()
	return hold > 0 and _result_frames >= hold


func step(input_mask: int) -> void:
	if stage == Stage.INTRO:
		_advance_intro()
	elif stage == Stage.APPROACH:
		var phase := _elapsed % BOARD_FRAMES_PER_CONTROL
		if phase == 0:
			_advance_approach(input_mask)
		elif phase == 1:
			# The board counts the clock down on the frame after each control tick.
			remaining_tenths -= 1
		_elapsed += 1
	else:
		_result_frames += 1


func _advance_intro() -> void:
	_elapsed += 1
	if _elapsed <= LIFT_END:
		if _elapsed > LIFT_WAIT and _elapsed % BOARD_FRAMES_PER_CONTROL == 0:
			position.y -= 1
	else:
		target_y = maxi(TARGET.y, 256 - ((_elapsed - LIFT_END) >> 2))
		if _elapsed >= _intro_duration():
			_release()


func _intro_duration() -> int:
	var arrival := I_II_III_POST_LIFT if is_i_and_ii() or is_i_to_iii() else TARGET_ARRIVAL
	return LIFT_END + arrival


func _release() -> void:
	stage = Stage.APPROACH
	target_y = TARGET.y
	_elapsed = 0


func _advance_approach(input_mask: int) -> void:
	if remaining_tenths <= 1:
		remaining_tenths = 0
		stage = Stage.TIMED_OUT
		return
	var steer := 0
	if input_mask & Pilot.LEFT:
		steer = 1
	elif input_mask & Pilot.RIGHT:
		steer = -1
	var bounds_offset := 8 if module == 1 or is_i_and_ii() else 16
	position.x = clampi(position.x + _horizontal.step(steer), 31 - bounds_offset, 216 - bounds_offset)
	thrusting = bool(input_mask & Pilot.FIRE)
	var thrust := 1 if thrusting else -1
	position.y = clampi(position.y + _vertical.step(thrust), 47 - bounds_offset, 240 - bounds_offset)
	_resolve_contact()


func _in_capture_area(offset: Vector2i) -> bool:
	return capture_rect().has_point(offset)


func capture_rect() -> Rect2i:
	# Les trois séquences utilisent le même test de capture
	# après le test de collision $2540. Les bornes basses en RAM sont
	# strictes et les hautes inclusives. Pour I + II, le registre logique
	# pointe un cran de 8 pixels après le module II sur les deux axes.
	if is_i_and_ii() or is_i_to_iii():
		return Rect2i(3, -6, 12, 16)
	return Rect2i(3, -6, 12, 8) if module == 1 else Rect2i(-5, -14, 12, 16)


func collision_rect() -> Rect2i:
	if is_i_and_ii() or is_i_to_iii():
		return Rect2i(-17, -3, 52, 16)
	return Rect2i(-8, -3, 34, 8) if module == 1 else Rect2i(-25, -11, 52, 16)


func _resolve_contact() -> void:
	var offset := position - TARGET
	if is_i_and_ii() or is_i_to_iii():
		# Même paire II et III que pour le module II seul, après translation
		# depuis le module II vers la position logique de l'assemblage.
		if collision_rect().has_point(offset):
			stage = Stage.COLLISION
		elif _in_capture_area(offset):
			# Pendant l'écran bonus, 0x822c garde la position du contact
			# (218 sur pr8c, pr10a et pr10b) : on ne replace pas le vaisseau.
			# Bonus affichés : 05 × 300 = 1500 (pr8c, pr10b), 14 × 300 = 4200
			# (pr10a, score 4940 → 9140).
			bonus = ((remaining_tenths - 1) / 10) * (100 if is_i_to_iii() else 300)
			if is_i_to_iii():
				position = TARGET + Vector2i(8, -8)
			stage = Stage.SUCCESS
		return
	if collision_rect().has_point(offset):
		stage = Stage.COLLISION
	elif _in_capture_area(offset):
		position = TARGET + (Vector2i(8, -8) if module == 1 else Vector2i(0, -16))
		bonus = ((remaining_tenths - 1) / 10) * module * 100
		stage = Stage.SUCCESS
