## Проверка камер наблюдения.
##
## Главное, что здесь ловится: одновременно рисоваться должна ровно
## одна камера. Полдюжины включённых видов роняют кадры, и заметить
## это на глаз можно только когда игра уже тормозит.
##
## Запуск:
##   godot --headless --path game res://tests/camera_smoke.tscn
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")

var _house: Node3D
var _monitor: CameraMonitor
var _cameras: Array[SecurityCamera] = []

var _phase := 0
var _timer := 0.0
var _failures: PackedStringArray = []
var _checks := 0
var _first_label := ""
var _switches := 0


func _ready() -> void:
	Game.reset()
	_house = HOUSE.instantiate()
	add_child(_house)

	for child in _house.get_children():
		if child is SecurityCamera:
			_cameras.append(child)

	_monitor = _find_monitor(_house)

	_check(_cameras.size() >= 3, "камеры развешаны по дому (найдено: %d)" % _cameras.size())
	_check(_monitor != null, "монитор стоит в комнате Зейда")

	if _monitor == null or _cameras.is_empty():
		_finish()
		return

	for camera in _cameras:
		_check(not camera.label.is_empty(), "камера подписана местом, а не номером")
		break

	_monitor.switched.connect(func(_c: SecurityCamera) -> void: _switches += 1)


func _physics_process(delta: float) -> void:
	_timer += delta

	match _phase:
		0: _phase_initial()
		1: _phase_switch()
		2: _phase_cycle()
		3: _finish()


func _phase_initial() -> void:
	if _timer < 0.3:
		return

	_check(_monitor.camera_count() == _cameras.size(), "монитор нашёл все камеры")
	_check(_monitor.current_camera() != null, "монитор сразу показывает первую камеру")
	_check(_active_count() == 1, "рисуется ровно одна камера (активных: %d)" % _active_count())

	_first_label = _monitor.current_camera().label
	_next(1)


func _phase_switch() -> void:
	if _timer < 0.2:
		return

	_check(_monitor.interact(), "монитор переключился")
	_check(
		_monitor.current_camera().label != _first_label,
		"после переключения показывается другая камера"
	)
	_check(_active_count() == 1, "включённой осталась одна (активных: %d)" % _active_count())
	_next(2)


## Полный круг должен вернуть к первой камере, а не упереться в конец.
func _phase_cycle() -> void:
	if _timer < 0.2:
		return

	for i in _cameras.size() - 1:
		_monitor.interact()

	_check(
		_monitor.current_camera().label == _first_label,
		"обход по кругу вернулся к первой камере"
	)
	_check(_switches >= _cameras.size(), "каждое переключение отмечено сигналом")
	_check(_active_count() == 1, "после круга активна одна камера")
	_next(3)


func _active_count() -> int:
	var count := 0
	for camera in _cameras:
		if camera.is_active():
			count += 1
	return count


func _find_monitor(node: Node) -> CameraMonitor:
	if node is CameraMonitor:
		return node
	for child in node.get_children():
		var found := _find_monitor(child)
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
