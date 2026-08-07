## Дымовой тест движения. Гоняет полигон без окна и проверяет,
## что ядро из DESIGN.md §5 действительно работает.
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

var _player: Player
var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0

var _speed_at_full_momentum := 0.0


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
		4: _finish()


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
	_speed_at_full_momentum = absf(_player.velocity.x)

	_check(_player.momentum > 0.95, "разгон набран за %.0f с (momentum=%.2f)" % [RUN, _player.momentum])
	_check(
		_speed_at_full_momentum > cfg.top_speed * 0.9,
		"скорость подошла к пределу (%.0f из %.0f)" % [_speed_at_full_momentum, cfg.top_speed]
	)
	_check(
		_speed_at_full_momentum > cfg.base_speed * 1.5,
		"разгон реально быстрее базовой скорости"
	)
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
	_next(4)


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("ПРОЙДЕНО: %d проверок" % _checks)
		get_tree().quit(0)
		return

	print("ПРОВАЛЕНО: %d из %d" % [_failures.size(), _checks])
	for f in _failures:
		print("  ✗ ", f)
	get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", label)
	else:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_timer = 0.0
