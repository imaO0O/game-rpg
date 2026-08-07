## Дымовой тест движения и способностей. Гоняет полигон без окна
## и проверяет, что ядро из DESIGN.md §5–6 действительно работает.
##
## Запуск:
##   godot --headless --path game res://tests/movement_smoke.tscn
## Код возврата 1 — что-то сломалось.
extends Node

const TESTBED := preload("res://src/levels/testbed.tscn")

## Сколько ждать в каждой фазе, секунд.
const SETTLE := 0.4
const RUN := 3.0
const TURN := 0.4
const WATER := 1.2

var _player: Player
var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0

var _momentum_in_water := 0.0


func _ready() -> void:
	var level := TESTBED.instantiate()
	add_child(level)
	_player = level.get_node("Player")


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_settle()
		1: _phase_run()
		2: _phase_turn()
		3: _phase_jump()
		4: _phase_slipstream()
		5: _phase_land_before_water()
		6: _phase_water_without_ability()
		7: _phase_water_with_ability()
		8: _finish()


## Игрок должен спокойно стоять на полу, а не проваливаться и не висеть.
func _phase_settle() -> void:
	if _timer < SETTLE:
		return
	_check(_player.is_on_floor(), "игрок стоит на полу после спавна")
	_check(is_zero_approx(_player.momentum), "разгон на старте нулевой")
	_check(not _player.can_use_drs(), "DRS без разгона недоступен")
	_next(1)
	Input.action_press("move_right")


## За несколько секунд бега разгон должен дойти до предела,
## скорость — подойти к top_speed, а DRS — открыться.
func _phase_run() -> void:
	if _timer < RUN:
		return
	var cfg := _player.config
	var speed := absf(_player.velocity.x)

	_check(_player.momentum > 0.95, "разгон набран за %.0f с (momentum=%.2f)" % [RUN, _player.momentum])
	_check(
		speed > cfg.top_speed * 0.9,
		"скорость подошла к пределу (%.0f из %.0f)" % [speed, cfg.top_speed]
	)
	_check(speed > cfg.base_speed * 1.5, "разгон реально быстрее базовой скорости")
	_check(_player.can_use_drs(), "DRS открылся на прямой")
	_next(2)

	# Резкий разворот — момент, на котором разгон обязан просесть.
	Input.action_release("move_right")
	Input.action_press("move_left")


func _phase_turn() -> void:
	if _timer < TURN:
		return
	_check(_player.momentum < 0.95, "разворот сбил разгон (momentum=%.2f)" % _player.momentum)
	_check(not _player.can_use_drs(), "после разворота DRS закрылся")
	_next(3)

	Input.action_release("move_left")
	Input.action_press("jump")


func _phase_jump() -> void:
	# Одного кадра хватает: прыжок применяется сразу через буфер.
	if _timer < 0.05:
		return
	_check(_player.velocity.y < 0.0, "прыжок поднимает игрока (vy=%.0f)" % _player.velocity.y)
	Input.action_release("jump")

	# Слипстрим без способности не должен работать даже в воздухе.
	_check(not _player.can_slipstream(), "слипстрим закрыт, пока способность не открыта")

	Game.unlock(Abilities.Kind.SLIPSTREAM)
	_check(_player.can_slipstream(), "слипстрим открылся вместе со способностью")

	_next(4)
	Input.action_press("drs")


func _phase_slipstream() -> void:
	if _timer < 0.05:
		return
	Input.action_release("drs")

	_check(
		absf(_player.velocity.x) > _player.config.slipstream_speed * 0.9,
		"слипстрим разогнал в воздухе (vx=%.0f)" % _player.velocity.x
	)
	_check(not _player.can_slipstream(), "второй рывок в том же прыжке недоступен")
	_next(5)


## Ждём земли: водные проверки имеют смысл только на опоре.
func _phase_land_before_water() -> void:
	if not _player.is_on_floor():
		return

	_player.enter_water()
	_player.momentum = 0.0
	_check(_player.in_water(), "игрок в воде")
	_check(not Game.has_ability(Abilities.Kind.WET_TYRES), "Мокрой резины пока нет")

	_next(6)
	Input.action_press("move_right")


func _phase_water_without_ability() -> void:
	if _timer < WATER:
		return
	_momentum_in_water = _player.momentum

	_check(
		is_zero_approx(_momentum_in_water),
		"без Мокрой резины разгон в воде не набирается (momentum=%.2f)" % _momentum_in_water
	)
	_check(
		absf(_player.velocity.x) < _player.config.base_speed,
		"без Мокрой резины в воде медленнее обычного (vx=%.0f)" % _player.velocity.x
	)

	Game.unlock(Abilities.Kind.WET_TYRES)
	_next(7)


func _phase_water_with_ability() -> void:
	if _timer < WATER:
		return
	_check(
		_player.momentum > _momentum_in_water,
		"с Мокрой резиной разгон в воде пошёл (momentum=%.2f)" % _player.momentum
	)
	_check(
		absf(_player.velocity.x) > _player.config.base_speed,
		"с Мокрой резиной в воде скорость восстановилась (vx=%.0f)" % _player.velocity.x
	)

	Input.action_release("move_right")
	_next(8)


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("ПРОЙДЕНО: %d проверок" % _checks)
		get_tree().quit(0)
		return

	print("ПРОВАЛЕНО: %d из %d" % [_failures.size(), _checks])
	for f in _failures:
		print("  x ", f)
	get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  + ", label)
	else:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_timer = 0.0
