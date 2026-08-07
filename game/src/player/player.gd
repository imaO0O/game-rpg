## Контроллер игрока: momentum-платформер (DESIGN.md §5).
##
## Идея жанра: скорость не задаётся кнопкой, а *набирается*, пока держишь
## линию, и теряется на ошибке — разворот, удар в стену. DRS доступен только
## после того, как разгон набран и какое-то время не было столкновений.
class_name Player
extends CharacterBody2D

signal jumped
signal landed(impact: float)
signal drs_fired
signal momentum_lost(reason: String)

@export var config: MovementConfig

@onready var visual: Node2D = $Visual
@onready var caffeine: Caffeine = $Caffeine
@onready var dust: CPUParticles2D = $Dust

## Разгон, 0..1. Определяет текущую максимальную скорость.
var momentum := 0.0
## Куда смотрит персонаж: -1 или 1.
var facing := 1

var _coyote := 0.0
var _buffer := 0.0
## Секунд без касания стен — это и есть «прямая» для DRS.
var _clean_time := 0.0
var _drs_time := 0.0
var _drs_cooldown := 0.0
var _last_dir := 0.0
var _was_on_floor := true
var _was_on_wall := false
## Скорость падения на кадр до move_and_slide — после столкновения она уже 0.
var _prev_velocity_y := 0.0


func _ready() -> void:
	if config == null:
		config = MovementConfig.new()


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")

	_update_timers(delta)
	_update_momentum(delta, input_dir)
	_apply_gravity(delta)
	_apply_horizontal(delta, input_dir)
	_handle_jump()
	_handle_drs()

	_prev_velocity_y = velocity.y
	move_and_slide()

	_resolve_collisions()
	_update_squash(delta)


func _update_timers(delta: float) -> void:
	# Coyote time: прыжок ещё засчитывается некоторое время после схода с края.
	if is_on_floor():
		_coyote = config.coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)

	# Jump buffer: нажатие запоминается и срабатывает при приземлении.
	if Input.is_action_just_pressed("jump"):
		_buffer = config.jump_buffer
	else:
		_buffer = maxf(0.0, _buffer - delta)

	if is_on_wall():
		_clean_time = 0.0
	else:
		_clean_time += delta

	_drs_time = maxf(0.0, _drs_time - delta)
	_drs_cooldown = maxf(0.0, _drs_cooldown - delta)


func _update_momentum(delta: float, input_dir: float) -> void:
	if is_zero_approx(input_dir):
		momentum = maxf(0.0, momentum - config.momentum_decay * delta)
		_last_dir = 0.0
		return

	var dir := signf(input_dir)
	# Штраф за разворот начисляется один раз на смену направления,
	# а не каждый кадр, пока скорость меняет знак.
	if not is_zero_approx(_last_dir) and not is_equal_approx(dir, _last_dir):
		_break_momentum(config.momentum_turn_penalty, "разворот")
	_last_dir = dir

	momentum = minf(1.0, momentum + config.momentum_gain * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := config.gravity
	if _drs_time > 0.0:
		# Во время рывка почти невесомость — иначе DRS не читается как рывок.
		g *= config.drs_gravity_mult
	elif velocity.y > 0.0:
		# Падать быстрее, чем взлетать. Без этого прыжок ощущается вялым.
		g *= config.fall_gravity_mult
	velocity.y = minf(velocity.y + g * delta, config.max_fall_speed)


func _apply_horizontal(delta: float, input_dir: float) -> void:
	if _drs_time > 0.0:
		velocity.x = facing * config.drs_speed
		return

	if is_zero_approx(input_dir):
		var friction := config.ground_friction if is_on_floor() else config.air_friction
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	facing = int(signf(input_dir))

	var accel := config.ground_accel if is_on_floor() else config.air_accel
	# Разворот ускоряем отдельно, иначе смена направления ощущается ватной.
	if not is_zero_approx(velocity.x) and not is_equal_approx(signf(velocity.x), signf(input_dir)):
		accel *= config.turn_multiplier

	var max_speed := lerpf(config.base_speed, config.top_speed, momentum)
	velocity.x = move_toward(velocity.x, input_dir * max_speed, accel * delta)


func _handle_jump() -> void:
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = config.jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		visual.scale = config.squash_jump
		jumped.emit()

	# Переменная высота прыжка: отпустил раньше — прыгнул ниже.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= config.jump_cut


## Готов ли DRS. Публично — оверлей это показывает.
func can_use_drs() -> bool:
	return momentum >= config.drs_threshold \
		and _clean_time >= config.drs_clean_time \
		and _drs_cooldown <= 0.0 \
		and caffeine.can_spend(config.drs_cost)


func _handle_drs() -> void:
	if not Input.is_action_just_pressed("drs"):
		return
	if not can_use_drs():
		return
	if not caffeine.try_spend(config.drs_cost):
		return

	_drs_time = config.drs_duration
	_drs_cooldown = config.drs_duration + config.drs_cooldown
	velocity.x = facing * config.drs_speed
	drs_fired.emit()


func _resolve_collisions() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact := absf(_prev_velocity_y)
		if impact >= config.hard_landing_speed:
			var strength := clampf(impact / config.max_fall_speed, 0.0, 1.0)
			visual.scale = Vector2.ONE.lerp(config.squash_land, strength)
			dust.restart()
		landed.emit(impact)
	_was_on_floor = on_floor

	var on_wall := is_on_wall()
	if on_wall and not _was_on_wall:
		_break_momentum(config.momentum_wall_penalty, "стена")
	_was_on_wall = on_wall


func _update_squash(delta: float) -> void:
	# Экспоненциальное сглаживание — не зависит от частоты кадров.
	var t := 1.0 - exp(-config.squash_recover * delta)
	visual.scale = visual.scale.lerp(Vector2.ONE, t)


func _break_momentum(amount: float, reason: String) -> void:
	if momentum <= 0.0:
		return
	momentum = maxf(0.0, momentum - amount)
	momentum_lost.emit(reason)


## Текущий потолок скорости с учётом разгона.
func current_max_speed() -> float:
	return lerpf(config.base_speed, config.top_speed, momentum)


## Снимок состояния для отладочного оверлея.
func debug_state() -> Dictionary:
	return {
		"speed": velocity.x,
		"fall": velocity.y,
		"momentum": momentum,
		"max_speed": current_max_speed(),
		"coyote": _coyote,
		"buffer": _buffer,
		"clean": _clean_time,
		"drs": _drs_time,
		"drs_ready": can_use_drs(),
		"caffeine": caffeine.current,
		"on_floor": is_on_floor(),
	}


## Точка сохранения возвращает игрока в строй (DESIGN.md §10).
func respawn_at(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	momentum = 0.0
	_last_dir = 0.0
	_clean_time = 0.0
	_drs_time = 0.0
	visual.scale = Vector2.ONE
