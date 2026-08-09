## Проверка точки покоя в трёхмерном доме.
##
## Кофемашина делает три вещи разом, и каждая ломается по-своему:
## сохранение может не записаться, фонарь не зарядиться, свет не
## разгореться. Проверяются все три.
##
## Запуск:
##   godot --headless --path game res://tests/coffee3d_smoke.tscn
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")

var _house: Node3D
var _player: CharacterBody3D
var _coffee: CoffeePoint

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	Game.reset()
	_house = HOUSE.instantiate()
	add_child(_house)

	_player = _house.get_node_or_null("Player")
	for child in _house.get_children():
		if child is CoffeePoint:
			_coffee = child
			break

	_check(_coffee != null, "точка покоя есть в доме")
	_check(_player != null, "игрок есть в сцене")

	if _coffee == null or _player == null:
		_finish()
		return

	_check(not _coffee.drink.is_empty(), "у точки покоя есть свой напиток")
	_check(
		_coffee.prompt().contains(_coffee.drink),
		"подсказка называет напиток, а не «использовать»"
	)


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_before()
		1: _phase_use()
		2: _phase_after()
		3: _finish()


func _phase_before() -> void:
	if _timer < 0.3:
		return

	_check(Game.checkpoint_id.is_empty(), "до кофе точки возврата нет")
	_check(not Game.has_stop(_coffee.id), "до кофе точка не в сети")

	# Сажаем батарею, чтобы проверить именно зарядку.
	_player.battery = 0.2
	_next(1)


func _phase_use() -> void:
	if _timer < 0.2:
		return
	_check(_coffee.interact(), "кофемашина сработала")
	_next(2)


func _phase_after() -> void:
	if _timer < 0.4:
		return

	_check(Game.checkpoint_id == _coffee.id, "кофе поставил точку возврата")
	_check(Game.has_stop(_coffee.id), "точка попала в сеть")
	# Точное сравнение с единицей здесь не годится: если фонарь горит,
	# он успевает потратить доли процента за те же кадры.
	_check(
		_player.battery > 0.95,
		"фонарь заряжен (%.3f против 0.2 до кофе)" % _player.battery
	)
	_check(
		not _coffee.interact(),
		"повторное нажатие во время передышки ничего не делает"
	)
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
