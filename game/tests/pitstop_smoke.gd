## Проверка Пит-стопа — быстрого перемещения между кофейнями (DESIGN.md §6).
##
## Способность целиком состоит из меню и телепорта, поэтому ломается тихо:
## меню не откроется, или откроется без способности, или предложит поехать
## туда, где игрок и так стоит.
##
## Запуск:
##   godot --headless --path game res://tests/pitstop_smoke.tscn
extends Node

const DEPOT := preload("res://src/levels/moscow/depot.tscn")

var _room: Room
var _player: Player
var _shop: CoffeeShop

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0
var _target := Vector2.ZERO


func _ready() -> void:
	# Меню ставит игру на паузу — тест обязан продолжать работать.
	process_mode = Node.PROCESS_MODE_ALWAYS

	Game.reset()
	_room = DEPOT.instantiate()
	add_child(_room)
	_player = _room.player

	for child in _room.get_children():
		if child is CoffeeShop:
			_shop = child
			break

	_check(_shop != null, "в депо есть кофейня")


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_approach()
		1: _phase_without_ability()
		2: _phase_with_one_stop()
		3: _phase_with_two_stops()
		4: _phase_travel()
		5: _finish()


## Ставим игрока к кофейне и даём зоне его заметить: без этого нажатие
## уходит в пустоту, потому что кофейня ещё не знает, что кто-то рядом.
func _phase_approach() -> void:
	if _shop == null:
		_next(5)
		return

	if _timer < 0.5:
		_player.global_position = _shop.global_position
		_player.caffeine.current = 20.0
		return

	_press_interact()
	_next(1)


## Без способности кофейня остаётся просто точкой сохранения.
func _phase_without_ability() -> void:
	if _timer < 0.3:
		return

	_check(is_equal_approx(_player.caffeine.current, 100.0), "кофейня заправила бак")
	_check(Game.checkpoint_id == _shop.id, "кофейня стала точкой возврата")
	_check(Game.has_stop(_shop.id), "кофейня попала в сеть")
	_check(_menu() == null, "без Пит-стопа меню не открывается")

	# Способность есть, но ехать некуда — меню всё равно не нужно.
	Game.unlock(Abilities.Kind.PIT_STOP)
	_press_interact()
	_next(2)


func _phase_with_one_stop() -> void:
	if _timer < 0.3:
		return

	_check(_menu() == null, "с одной кофейней в сети меню не открывается")

	# Появилась вторая кофейня — вот теперь есть выбор.
	_target = Vector2(2000.0, 200.0)
	Game.register_stop("ryazan_yard", {
		"id": "ryazan_yard",
		"city": "Рязань",
		"drink": "капучино на овсяном",
		"x": _target.x,
		"y": _target.y,
	})
	_press_interact()
	_next(3)


func _phase_with_two_stops() -> void:
	if _timer < 0.3:
		return

	_check(_menu() != null, "меню открылось, когда есть куда ехать")
	_check(get_tree().paused, "игра встала на паузу на время выбора")

	if _menu() == null:
		_next(5)
		return

	# Подтверждаем выбор ровно так, как это сделал бы игрок.
	_send_action("ui_accept")
	_next(4)


func _phase_travel() -> void:
	if _timer < 0.3:
		return

	_check(not get_tree().paused, "пауза снята после выбора")

	# По вертикали сверять точно нельзя: после телепорта игрок падает
	# и встаёт на ближайшую опору — это правильное поведение.
	_check(
		absf(_player.global_position.x - _target.x) < 4.0,
		"игрок переехал в выбранную кофейню (x=%.0f, ожидалось %.0f)" % [
			_player.global_position.x, _target.x
		]
	)
	_next(5)


func _menu() -> Node:
	for child in _shop.get_children():
		if child is CanvasLayer:
			return child
	return null


func _press_interact() -> void:
	_send_action("interact")


## Input.action_press не порождает событие, а меню и кофейня слушают
## именно события — поэтому шлём настоящий InputEventAction.
func _send_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _finish() -> void:
	get_tree().paused = false
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
