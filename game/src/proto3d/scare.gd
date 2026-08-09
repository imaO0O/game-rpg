## Скример: испуг с обязательной разрядкой (CONCEPT_3D.md).
##
## Правило жанра — пугает резко, разрешается смешно. Поэтому здесь
## всегда две фазы: `_strike()` бьёт по игроку светом и движением,
## `_resolve()` через секунду с небольшим объясняет, что это было.
## Без второй фазы получается обычный хоррор, а не мемный.
##
## Каждый скример срабатывает один раз за прохождение: флаг живёт
## в общем состоянии игры, поэтому переживает перезапуск.
class_name Scare
extends Area3D

signal struck
signal resolved

## Идентификатор для флага. Пустой — скример сработает снова после загрузки.
@export var id := ""
@export var trigger_size := Vector3(3.0, 2.4, 2.0)
## Сколько длится испуг до разрядки.
@export var strike_time := 1.3

var _armed := true
var _player: Node3D = null


func _ready() -> void:
	if not id.is_empty() and Game.has_flag(_flag()):
		_armed = false

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = trigger_size
	shape.shape = box
	add_child(shape)

	# Триггер реагирует только на игрока, а не на всё подряд.
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not _armed or not body.is_in_group("player"):
		return

	_armed = false
	_player = body
	if not id.is_empty():
		Game.set_flag(_flag())

	_strike()
	struck.emit()

	await get_tree().create_timer(strike_time).timeout

	_resolve()
	resolved.emit()


## Переопределяется наследником: собственно испуг.
func _strike() -> void:
	pass


## Переопределяется наследником: разрядка. Обязательна.
func _resolve() -> void:
	pass


func _flag() -> String:
	return "scare_%s" % id


## Помощник для наследников: погасить весь свет в доме и вернуть обратно.
func blackout(duration: float) -> void:
	var lights := _all_lights()
	var saved := {}
	for light: Light3D in lights:
		saved[light] = light.light_energy
		light.light_energy = 0.0

	await get_tree().create_timer(duration).timeout

	for light: Light3D in saved:
		if is_instance_valid(light):
			light.light_energy = saved[light]


func _all_lights() -> Array:
	var result := []
	for node in get_tree().get_nodes_in_group("house_light"):
		if node is Light3D:
			result.append(node)
	return result
