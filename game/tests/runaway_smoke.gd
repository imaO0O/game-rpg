## Проверка убегающего осколка.
##
## Он вмешивается в подбор, поэтому ломается двумя способами сразу:
## может не убегать вовсе, а может не даться никогда. Второе хуже —
## игрок останется без осколка и без объяснения.
##
## Запуск:
##   godot --headless --path game res://tests/runaway_smoke.tscn
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")
const TARGET_ID := "ryazan_03"

var _house: Node3D
var _memory: MemoryObject
var _start := Vector3.ZERO

var _phase := 0
var _timer := 0.0
var _attempts := 0
var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	Game.reset()
	_house = HOUSE.instantiate()
	add_child(_house)

	for child in _house.get_children():
		if child is MemoryObject and (child as MemoryObject).id == TARGET_ID:
			_memory = child
			break

	_check(_memory != null, "убегающий осколок есть в доме")
	if _memory == null:
		_finish()
		return

	_check(_memory.escape_check.is_valid(), "осколку назначена проверка на побег")
	_start = _memory.global_position


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_first_try()
		1: _phase_check_moved()
		2: _phase_exhaust()
		3: _phase_finally_taken()
		4: _finish()


func _phase_first_try() -> void:
	if _timer < 0.3:
		return

	var taken: bool = _memory.interact()
	_attempts += 1

	_check(not taken, "с первого раза осколок не даётся")
	_check(not Game.has_shard(TARGET_ID), "и в состояние не записывается")
	_next(1)


## Убежал — значит сдвинулся с места. Осколок, который «убегает»,
## оставаясь на месте, выглядит поломкой, а не шуткой.
func _phase_check_moved() -> void:
	if _timer < 0.8:
		return

	var moved := _memory.global_position.distance_to(_start)
	_check(moved > 0.5, "осколок действительно улетел (на %.1f м)" % moved)
	_next(2)


## Убегает конечное число раз. Бесконечный побег — худший исход:
## игрок не поймёт, что осколок вообще можно взять.
func _phase_exhaust() -> void:
	if _timer < 0.4:
		return

	if _attempts >= 6:
		_check(false, "осколок сдался за разумное число попыток")
		_next(4)
		return

	var taken: bool = _memory.interact()
	_attempts += 1

	if taken:
		_check(true, "осколок дался с %d-й попытки" % _attempts)
		_next(3)
		return

	_timer = 0.0


func _phase_finally_taken() -> void:
	if _timer < 0.2:
		return
	_check(Game.has_shard(TARGET_ID), "взятый осколок записан в состояние")
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
