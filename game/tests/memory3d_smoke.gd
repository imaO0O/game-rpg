## Проверка осколков памяти в трёхмерном доме.
##
## Собирание — то, ради чего игра существует, поэтому проверяется
## вся цепочка: осколок нашёлся взглядом, взялся, засчитался один раз
## и не появился заново.
##
## Запуск:
##   godot --headless --path game res://tests/memory3d_smoke.tscn
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")

var _house: Node3D
var _player: CharacterBody3D
var _interactor: Interactor
var _memory: MemoryObject

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0
var _taken_id := ""


func _ready() -> void:
	Game.reset()
	_house = HOUSE.instantiate()
	add_child(_house)

	_player = _house.get_node_or_null("Player")
	if _player == null:
		_check(false, "игрок есть в сцене")
		_finish()
		return

	for child in _player.get_children():
		if child is Interactor:
			_interactor = child

	var memories: Array[MemoryObject] = []
	for child in _house.get_children():
		if child is MemoryObject:
			memories.append(child)

	_check(_interactor != null, "у игрока есть узел взаимодействия")
	_check(not memories.is_empty(), "в доме есть осколки (найдено: %d)" % memories.size())

	if memories.is_empty() or _interactor == null:
		_finish()
		return

	_memory = memories[0]
	_check(ShardRegistry.all().has(_memory.id), "осколок есть в каталоге")
	_check(not _memory.caption().is_empty(), "у осколка есть подпись")

	_interactor.taken.connect(func(id: String) -> void: _taken_id = id)


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_look_away()
		1: _phase_look_at()
		2: _phase_take()
		3: _phase_check_once()
		4: _finish()


## Издалека осколок не должен считаться целью.
func _phase_look_away() -> void:
	if _timer < 0.3:
		return
	_check(_interactor.current() == null, "издалека осколок не в фокусе")
	_aim_at_memory()
	_next(1)


func _phase_look_at() -> void:
	if _timer < 0.3:
		return
	_check(
		_interactor.current() == _memory,
		"взгляд нашёл осколок вблизи"
	)
	_next(2)


func _phase_take() -> void:
	if _timer < 0.2:
		return

	var id := _memory.id
	var before := Game.shard_count()
	var ok: bool = _memory.take()

	_check(ok, "осколок взялся")
	_check(Game.shard_count() == before + 1, "счётчик вырос ровно на один")
	_check(Game.has_shard(id), "осколок записан в состояние")
	_next(3)


## Повторное взятие того же идентификатора не должно засчитываться:
## иначе счётчик собранного поедет при любом перезаходе в комнату.
func _phase_check_once() -> void:
	if _timer < 0.2:
		return

	var before := Game.shard_count()
	var again := MemoryObject.new()
	again.id = "ryazan_01"
	add_child(again)

	# Уже собранный осколок обязан исчезнуть сам.
	await get_tree().process_frame
	_check(not is_instance_valid(again) or again.is_queued_for_deletion(), "собранный осколок не появляется заново")
	_check(Game.shard_count() == before, "счётчик не вырос от повторного появления")
	_next(4)


func _aim_at_memory() -> void:
	var target := _memory.global_position + Vector3(0.0, 0.3, 0.0)
	_player.global_position = target + Vector3(0.0, 0.4, 0.9)

	var camera := _find_camera(_player)
	if camera != null:
		camera.look_at(target, Vector3.UP)


func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null


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
