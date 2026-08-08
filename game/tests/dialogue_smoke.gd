## Дымовой тест диалогов.
##
## Главный риск здесь — забрать у игрока управление и не вернуть.
## Поэтому проверяется весь цикл: вход в зону, блокировка, конец
## разговора, разблокировка, отметка «уже говорили».
##
## Запуск:
##   godot --headless --path game res://tests/dialogue_smoke.tscn
extends Node

const TESTBED := preload("res://src/levels/testbed.tscn")
## Координата автостартовой точки диалога на полигоне.
const TRIGGER_X := 145.0 * 16.0

var _level: Node2D
var _player: Player
var _trigger: DialogueTrigger

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0
var _started := false
var _finished := false


func _ready() -> void:
	_level = TESTBED.instantiate()
	add_child(_level)
	_player = _level.get_node("Player")

	for node in _level.get_children():
		if node is DialogueTrigger and (node as DialogueTrigger).auto_start:
			_trigger = node
			break


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_approach()
		1: _phase_locked()
		2: _phase_released()
		3: _finish()


func _phase_approach() -> void:
	_check(_trigger != null, "автостартовая точка диалога есть на полигоне")
	if _trigger == null:
		_next(3)
		return

	_check(not Dialogue.exists(_trigger.timeline_name), "настоящих реплик пока нет — работает заглушка")

	_trigger.started.connect(func(_t: String) -> void: _started = true)
	_trigger.finished.connect(func(_t: String) -> void: _finished = true)

	_player.respawn_at(Vector2(TRIGGER_X, 320.0))
	_next(1)


func _phase_locked() -> void:
	# Пара кадров, чтобы зона заметила игрока и разговор начался.
	if _timer < 0.2:
		return

	_check(_started, "разговор начался сам при входе в зону")
	_check(_player.input_locked, "на время разговора управление отключено")
	_next(2)


func _phase_released() -> void:
	# Заглушка держит паузу ~1.2 с.
	if _timer < 2.0:
		return

	_check(_finished, "разговор закончился")
	_check(not _player.input_locked, "управление вернулось после разговора")
	_check(Game.has_flag("dialogue_testbed_intro"), "разговор отмечен как состоявшийся")
	_check(not is_instance_valid(_trigger), "одноразовая точка убрана из мира")
	_next(3)


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
