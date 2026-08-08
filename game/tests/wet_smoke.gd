## Проверка гейта Мокрой резины в петербургских каналах (DESIGN.md §6).
##
## Гейт здесь не стена, а следствие механики: длинный мокрый участок гасит
## разгон, и к разрыву за ним игрок подходит слишком медленно. Проверять
## это можно только физически — пробежать воду и прыгнуть.
##
## Запуск:
##   godot --headless --path game res://tests/wet_smoke.tscn
extends Node

const CANALS := preload("res://src/levels/spb/canals.tscn")

## Координаты из canals.gd.
const GAP_START := 46.0 * 16.0
const GAP_TILES := 7
const FAR_EDGE := float(46 + GAP_TILES) * 16.0
const FLOOR_Y := 20.0 * 16.0
const START := Vector2(5.0 * 16.0, FLOOR_Y)
const JUMP_AT := GAP_START - 14.0
const TIMEOUT := 10.0

var _room: Room
var _player: Player

var _phase := 0
var _timer := 0.0
var _with_tyres := false
var _crossed_without := false
var _crossed_with := false

var _failures: PackedStringArray = []
var _checks := 0
var _jump_from := 0.0
var _max_x := 0.0
var _momentum_at_edge := 0.0


func _ready() -> void:
	Game.reset()
	_room = CANALS.instantiate()
	add_child(_room)
	_player = _room.player


func _physics_process(delta: float) -> void:
	_timer += delta

	if _player.global_position.y <= FLOOR_Y + 2.0:
		_max_x = maxf(_max_x, _player.global_position.x)

	match _phase:
		0: _phase_run_up()
		1: _phase_airborne()
		2: _phase_settle()
		3: _phase_switch()
		4: _finish()


func _phase_run_up() -> void:
	Input.action_press("move_right")

	if _timer > TIMEOUT:
		_check(false, "разбег дошёл до разрыва")
		_next(3)
		return

	if _player.global_position.x < JUMP_AT:
		return

	_momentum_at_edge = _player.momentum
	if _with_tyres:
		_check(
			_momentum_at_edge > 0.5,
			"с Мокрой резиной разгон по воде набирается (momentum=%.2f)" % _momentum_at_edge
		)
	else:
		_check(
			_momentum_at_edge < 0.2,
			"без Мокрой резины вода гасит разгон (momentum=%.2f)" % _momentum_at_edge
		)

	_jump_from = _player.global_position.x
	_max_x = _jump_from
	Input.action_press("jump")
	_next(1)


func _phase_airborne() -> void:
	if _timer < 0.42:
		return
	Input.action_release("jump")
	_next(2)


func _phase_settle() -> void:
	var x := _player.global_position.x

	if x > FAR_EDGE and _player.is_on_floor():
		_record(true)
		return

	if x < GAP_START - 300.0:
		_record(false)
		return

	if _timer > TIMEOUT:
		_record(false)


func _record(crossed: bool) -> void:
	var reach := _max_x - _jump_from
	print("    прыжок с воды %s: дальность %.0f px (%.1f тайла), разрыв %d тайлов" % [
		"со сцеплением" if _with_tyres else "без сцепления",
		reach,
		reach / 16.0,
		GAP_TILES,
	])

	if _with_tyres:
		_crossed_with = crossed
	else:
		_crossed_without = crossed
	_next(3)


func _phase_switch() -> void:
	Input.action_release("move_right")
	Input.action_release("jump")

	if _with_tyres:
		_check(not _crossed_without, "без Мокрой резины разрыв за водой не берётся")
		_check(_crossed_with, "с Мокрой резиной разрыв берётся")
		_next(4)
		return

	_with_tyres = true
	Game.unlock(Abilities.Kind.WET_TYRES)
	_player.respawn_at(START)
	_next(0)


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
