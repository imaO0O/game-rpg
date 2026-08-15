## Проверка финала.
##
## Единственная сцена, где что-то происходит само, поэтому ломается
## громче всех: не запустится — игрок упрётся в пустую комнату,
## запустится дважды — Зейд начнёт разговор заново поверх себя.
##
## Запуск:
##   godot --headless --path game res://tests/finale_smoke.tscn
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")

var _house: Node3D
var _player: CharacterBody3D
var _finale: Finale
var _memory: MemoryObject

var _starts := 0
var _finishes := 0

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	Game.reset()
	# Реплики вдесятеро быстрее: проверяется последовательность,
	# а не терпение. Ставится до сборки дома — финал читает это
	# значение при первой же реплике.
	Finale.speed_scale = 0.1

	_house = HOUSE.instantiate()
	add_child(_house)

	_player = _house.get_node_or_null("Player")
	for child in _house.get_children():
		if child is Finale:
			_finale = child
			break

	_check(_finale != null, "финал есть в доме")
	_check(_player != null, "игрок есть в сцене")

	if _finale == null or _player == null:
		_finish()
		return

	for child in _finale.get_children():
		if child is MemoryObject:
			_memory = child
			break

	_check(_memory != null, "у Зейда есть последний осколок")
	_check(
		_memory != null and ShardRegistry.all().has(_memory.id),
		"последний осколок есть в каталоге"
	)

	_finale.started.connect(func() -> void: _starts += 1)
	_finale.finished.connect(func() -> void: _finishes += 1)


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_before()
		1: _phase_enter()
		2: _phase_during()
		3: _phase_after()
		4: _finish()


func _phase_before() -> void:
	if _timer < 0.3:
		return
	_check(_starts == 0, "до входа сцена молчит")
	_check(not _finale.is_done(), "финал не считается пройденным заранее")

	_player.global_position = _finale.global_position
	_next(1)


func _phase_enter() -> void:
	if _timer < 0.4:
		return
	_check(_starts == 1, "сцена началась при входе (запусков: %d)" % _starts)
	_check(Game.has_flag("finale"), "финал отмечен флагом")

	# Пробуем взять осколок посреди разговора.
	_check(not _memory.interact(), "во время разговора осколок не даётся")
	_check(not Game.has_shard(_memory.id), "и в состояние не попадает")

	# Повторный вход не должен начинать разговор заново.
	_player.global_position = _finale.global_position + Vector3(0.0, 0.0, 6.0)
	_player.global_position = _finale.global_position
	_next(2)


func _phase_during() -> void:
	if _timer < 0.5:
		return
	_check(_starts == 1, "повторный вход не начинает сцену заново")
	_next(3)


## Ждём конца реплик и проверяем, что осколок наконец даётся.
func _phase_after() -> void:
	if _finishes == 0 and _timer < 4.0:
		return

	_check(_finishes == 1, "сцена дошла до конца (завершений: %d)" % _finishes)
	_check(_finale.is_done(), "финал отмечен как пройденный")
	_check(_memory.interact(), "после разговора осколок даётся")
	_check(Game.has_shard(_memory.id), "последний осколок записан в состояние")
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
