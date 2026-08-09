## Проверка скримеров (CONCEPT_3D.md).
##
## Скример ломается тихо: не сработает — игрок ничего не заметит,
## сработает дважды — превратится в раздражитель. Поэтому проверяется
## и то, и другое, плюс обязательная разрядка после испуга.
##
## Запуск:
##   godot --headless --path game res://tests/scare_smoke.tscn
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")

var _house: Node3D
var _player: CharacterBody3D
var _scare: Scare

var _strikes := 0
var _resolves := 0

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	Game.reset()
	_house = HOUSE.instantiate()
	add_child(_house)

	_player = _house.get_node_or_null("Player")
	_check(_player != null, "игрок есть в сцене")
	_check(_player != null and _player.is_in_group("player"), "игрок в группе player")

	for child in _house.get_children():
		if child is Scare:
			_scare = child
			break

	_check(_scare != null, "скример стоит в доме")
	if _scare == null:
		_finish()
		return

	_scare.struck.connect(func() -> void: _strikes += 1)
	_scare.resolved.connect(func() -> void: _resolves += 1)


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_walk_in()
		1: _phase_check_strike()
		2: _phase_check_resolve()
		3: _phase_check_once()
		4: _finish()


## Заводим игрока в триггер.
func _phase_walk_in() -> void:
	if _timer < 0.3:
		return
	_check(_strikes == 0, "до входа в триггер скример молчит")
	_player.global_position = _scare.global_position
	_next(1)


func _phase_check_strike() -> void:
	if _timer < 0.3:
		return
	_check(_strikes == 1, "скример сработал при входе (срабатываний: %d)" % _strikes)
	_check(_resolves == 0, "разрядка не наступает сразу — сначала испуг")
	_check(Game.has_flag("scare_pitstop"), "скример отметился флагом")
	_next(2)


## Разрядка обязательна: без неё это обычный хоррор, а не мемный.
func _phase_check_resolve() -> void:
	if _timer < _scare.strike_time + 0.4:
		return
	_check(_resolves == 1, "испуг разрешился шуткой (разрядок: %d)" % _resolves)
	_next(3)


## Повторный вход не должен ничего запускать.
func _phase_check_once() -> void:
	if _timer < 0.2:
		return
	_player.global_position = _scare.global_position + Vector3(0.0, 0.0, 4.0)
	_player.global_position = _scare.global_position
	_check(_strikes == 1, "повторный вход скример не запускает")
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
