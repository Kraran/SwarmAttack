extends RefCounted

const Pilot = preload("res://pilot.gd")
const TARGET := Vector2i(112, 216)
const LIFT_WAIT := 48
const LIFT_HEIGHT := 76
const TARGET_ARRIVAL := 200
const BOARD_FRAMES_PER_CONTROL := 4
# Écran bonus relevé : 305 images entre le contact (frame 7417) et la reprise (7723).
const BONUS_HOLD := 305
# 7918 − 7452 : de l'explosion relevée à la reprise. À confirmer si l'explosion
# coïncide avec le début de l'étape COLLISION.
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
var position: Vector2i
var target_y := 256
var stage := Stage.INTRO
var bonus := 0
var remaining_tenths := 300
var _elapsed := 0
var _result_frames := 0
var _horizontal := Axis.new(128)
var _vertical := Axis.new(120)


func _init(approaching_module: int, ship_x: int, show_intro := true, attached_modules := 0) -> void:
	module = approaching_module
	attached = attached_modules if attached_modules != 0 else 1 << (approaching_module - 1)
	if is_i_and_ii():
		# pr7 : l'intro part de 0x822c = 232 (0x8143 = 208, 0x8148 = 216),
		# à l'abscisse courante (butée droite 0x822b = 216, x = 200).
		position = Vector2i(ship_x + 8, I_II_START_Y)
	else:
		position = Vector2i(ship_x + (8 if module == 1 else 0), 192 if module == 1 else 200)
	if not show_intro:
		position.y -= LIFT_HEIGHT
		_release()


func is_i_and_ii() -> bool:
	return bool(attached & 1) and bool(attached & 2) and not bool(attached & 4)


func display_position() -> Vector2:
	return Vector2(position.x - (8 if module == 1 else 0), position.y + 8)


func display_clock() -> String:
	if stage == Stage.INTRO:
		return "30:0"
	var seconds := maxi(0, (remaining_tenths - 1) / 10)
	return "%02d:%d" % [seconds, remaining_tenths % 10]


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
	var lift_end := LIFT_WAIT + LIFT_HEIGHT * BOARD_FRAMES_PER_CONTROL
	var arrival := I_II_III_POST_LIFT if is_i_and_ii() else TARGET_ARRIVAL
	if _elapsed <= lift_end:
		if _elapsed > LIFT_WAIT and _elapsed % BOARD_FRAMES_PER_CONTROL == 0:
			position.y -= 1
	else:
		target_y = maxi(TARGET.y, 256 - ((_elapsed - lift_end) >> 2))
		if _elapsed >= lift_end + arrival:
			_release()


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
	var thrust := 1 if input_mask & Pilot.FIRE else -1
	position.y = clampi(position.y + _vertical.step(thrust), 47 - bounds_offset, 240 - bounds_offset)
	_resolve_contact()


func _in_capture_area(offset: Vector2i) -> bool:
	# Le contact se teste sur la position calculée au cran, avant affichage.
	# pr5c (frame 10599) : 0x822b/0x822c restent à l'offset (14, -7) affiché
	# depuis 10596, mais l'attente verticale était à 0 : le cran porte le
	# module à (14, -6), et c'est là que 0x8004 passe à 1. Démo d'attraction
	# (pr10e, frame 2686) : affiché (6, -7), vitesses 171/64 et attentes 0,
	# le cran donne (5, -6), contact. Le cran précédent de pr5c, (13, -7),
	# reste sans contact. Seule la rangée y = -6 est mesurée pour le module I
	# (x = 5 et 14) ; le reste du rectangle reste provisoire.
	# I + II → III (pr8c, pr10a, pr10b) : contacts mesurés sur la rangée
	# y = -6 à x = 3, 8 et 14 ; ratés à (1, -6), (15, -6), (2, -5), (15, -5),
	# (7, -7) et (6, -8). (2, -6) n'a pas été visité. Les rangées y > -6,
	# jamais atteintes dans la zone x = 3–14, reprennent provisoirement le
	# rectangle du module I.
	var capture_area := Rect2i(3, -6, 12, 8) if module == 1 else Rect2i(-5, -14, 12, 16)
	return capture_area.has_point(offset)


func _resolve_contact() -> void:
	# pr8 / pr8b : collisions I + II → III aux offsets (31, -3) et (29, -3) ;
	# (32, -4) et (28, -4) restent sans contact. La zone de collision n'est
	# connue que par ces deux points.
	if is_i_and_ii():
		var offset := position - TARGET
		if offset in [Vector2i(31, -3), Vector2i(29, -3)]:
			stage = Stage.COLLISION
		elif _in_capture_area(offset):
			# Pendant l'écran bonus, 0x822c garde la position du contact
			# (218 sur pr8c, pr10a et pr10b) : on ne replace pas le vaisseau.
			# Bonus affichés : 05 × 300 = 1500 (pr8c, pr10b), 14 × 300 = 4200
			# (pr10a, score 4940 → 9140).
			bonus = ((remaining_tenths - 1) / 10) * 300
			stage = Stage.SUCCESS
		return
	var offset := position - TARGET
	var crash_area := Rect2i(-8, -3, 34, 8) if module == 1 else Rect2i(-25, -11, 52, 16)
	if crash_area.has_point(offset):
		stage = Stage.COLLISION
	elif _in_capture_area(offset):
		position = TARGET + (Vector2i(8, -8) if module == 1 else Vector2i(0, -16))
		bonus = ((remaining_tenths - 1) / 10) * module * 100
		stage = Stage.SUCCESS
