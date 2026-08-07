## Дымовой тест состояния прохождения.
##
## Главное, что здесь проверяется: сохранение переживает перезапуск.
## Если это сломается, игрок потеряет собранное — худший из возможных багов
## для игры, которая целиком про собирание.
##
## Запуск:
##   godot --headless --path game res://tests/state_smoke.tscn
extends Node

var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	_test_abilities()
	_test_shards()
	_test_flags()
	_test_stops()
	_test_save_load()
	_finish()


func _test_abilities() -> void:
	Game.reset()
	_check(not Game.has_ability(Abilities.Kind.SLIPSTREAM), "способностей на старте нет")
	_check(Game.unlock(Abilities.Kind.SLIPSTREAM), "способность открылась")
	_check(Game.has_ability(Abilities.Kind.SLIPSTREAM), "способность запомнилась")
	_check(not Game.unlock(Abilities.Kind.SLIPSTREAM), "повторное открытие не засчитывается")


func _test_shards() -> void:
	Game.reset()
	_check(Game.collect_shard("ryazan_01"), "осколок засчитан")
	_check(not Game.collect_shard("ryazan_01"), "тот же осколок повторно не засчитан")
	_check(Game.shard_count() == 1, "счётчик осколков не задваивается")


func _test_flags() -> void:
	Game.reset()
	_check(Game.set_flag("door_test"), "флаг поднят")
	_check(not Game.set_flag("door_test"), "повторный подъём флага не засчитан")
	_check(Game.has_flag("door_test"), "флаг читается")


func _test_stops() -> void:
	Game.reset()
	Game.register_stop("ryazan", {"id": "ryazan", "city": "Рязань"})
	Game.register_stop("sochi", {"id": "sochi", "city": "Сочи"})
	_check(Game.has_stop("ryazan"), "кофейня зарегистрирована")
	_check(Game.other_stops("ryazan").size() == 1, "текущая кофейня не предлагается для перемещения")


func _test_save_load() -> void:
	Game.reset()
	Game.unlock(Abilities.Kind.PARSELTONGUE)
	Game.unlock(Abilities.Kind.STALK)
	Game.collect_shard("ryazan_01")
	Game.collect_shard("sochi_04")
	Game.set_flag("door_prologue")
	Game.register_stop("ryazan", {"id": "ryazan", "city": "Рязань", "drink": "раф"})
	Game.set_checkpoint("ryazan", "res://src/levels/testbed.tscn", Vector2(128.0, 320.0))

	_check(Game.save_game(), "сохранение записалось")

	Game.reset()
	_check(not Game.has_ability(Abilities.Kind.PARSELTONGUE), "сброс действительно чистит состояние")

	_check(Game.load_game(), "сохранение прочиталось")
	_check(Game.has_ability(Abilities.Kind.PARSELTONGUE), "Змееуст пережил перезапуск")
	_check(Game.has_ability(Abilities.Kind.STALK), "Сталк пережил перезапуск")
	_check(Game.shard_count() == 2, "оба осколка на месте")
	_check(Game.has_shard("sochi_04"), "конкретный осколок на месте")
	_check(Game.has_flag("door_prologue"), "открытая дверь осталась открытой")
	_check(Game.has_stop("ryazan"), "кофейня осталась в сети")
	_check(Game.checkpoint_id == "ryazan", "точка сохранения на месте")
	_check(
		Game.checkpoint_position.is_equal_approx(Vector2(128.0, 320.0)),
		"координаты точки сохранения не поехали"
	)


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
