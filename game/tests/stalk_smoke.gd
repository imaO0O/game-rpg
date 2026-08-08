## Проверка Сталк-режима (DESIGN.md §6).
##
## Способность обещает ровно одно: скрытые стены перестают держать.
## Проверяется физически — игрок разбегается в стену и либо упирается
## в неё, либо проходит насквозь. Флаг «стена проявлена» сам по себе
## ничего не доказывает: важно, пускает она или нет.
##
## Запуск:
##   godot --headless --path game res://tests/stalk_smoke.tscn
extends Node

const HOUSE := preload("res://src/levels/night/house.tscn")

## Скрытая стена в доме стоит на x = 18 тайлов, на перекрытии второго этажа.
const WALL_X := 18.0 * 16.0
const START := Vector2(13.0 * 16.0, 20.0 * 16.0)
const RUN_TIME := 1.6

var _room: Room
var _player: Player
var _wall: HiddenWall

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0
var _blocked_x := 0.0


func _ready() -> void:
	Game.reset()
	_room = HOUSE.instantiate()
	add_child(_room)
	_player = _room.player

	for child in _room.get_children():
		if child is HiddenWall:
			_wall = child
			break

	_check(_wall != null, "в доме есть скрытая стена")
	if _wall != null:
		_check(_wall.is_in_group(HiddenWall.GROUP), "стена слушает Сталк-режим")


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_run_without()
		1: _phase_check_blocked()
		2: _phase_run_with()
		3: _phase_check_passed()
		4: _finish()


func _phase_run_without() -> void:
	if _wall == null:
		_next(4)
		return

	if _timer < 0.1:
		_player.respawn_at(START)
		return

	Input.action_press("move_right")
	if _timer < RUN_TIME:
		return
	_next(1)


func _phase_check_blocked() -> void:
	_blocked_x = _player.global_position.x
	Input.action_release("move_right")

	_check(not _wall.is_revealed(), "без способности стена не проявлена")
	_check(
		_blocked_x < WALL_X,
		"без Сталка стена держит (игрок встал на x=%.0f, стена на %.0f)" % [_blocked_x, WALL_X]
	)

	Game.unlock(Abilities.Kind.STALK)
	_player.respawn_at(START)
	_next(2)


func _phase_run_with() -> void:
	# Сталк работает на удержание — держим всё время забега.
	Input.action_press("stalk")

	if _timer < 0.1:
		return

	Input.action_press("move_right")
	if _timer < RUN_TIME:
		return
	_next(3)


func _phase_check_passed() -> void:
	var passed_x := _player.global_position.x

	_check(_player.stalk_active, "Сталк-режим включился")
	_check(_wall.is_revealed(), "стена проявилась")
	_check(
		passed_x > WALL_X + 16.0,
		"со Сталком игрок прошёл сквозь стену (x=%.0f против %.0f без него)" % [
			passed_x, _blocked_x
		]
	)

	Input.action_release("move_right")
	Input.action_release("stalk")
	_next(4)


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
