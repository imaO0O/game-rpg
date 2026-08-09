## Всё, с чем игрок может что-то сделать по нажатию.
##
## Общий предок для осколков, кофемашины, дверей и записок. Луч взгляда
## ищет именно его, поэтому добавить новый вид взаимодействия — значит
## написать наследника, а не трогать контроллер игрока.
class_name Interactable
extends Node3D

## Слой физики, по которому луч ищет цели. Обычная геометрия на нём
## не висит: иначе предмет на столе было бы не взять из-за самого стола.
const LAYER := 4

@export var prompt_text := "взять"

var _looked_at := false


## Строит область-мишень заданного радиуса. Вызывается наследником:
## одним нужна сфера у пола, другим — на уровне глаз.
func build_target(radius: float, offset := Vector3.ZERO) -> Area3D:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	shape.position = offset
	area.add_child(shape)
	area.collision_layer = LAYER
	area.collision_mask = 0
	add_child(area)
	return area


## Подпись для подсказки. Может меняться по состоянию — например,
## кофемашина сначала предлагает сварить, потом отдохнуть.
func prompt() -> String:
	return prompt_text


## Наведён ли на объект взгляд. Наследник может подсвечиваться.
func set_looked_at(value: bool) -> void:
	_looked_at = value


func is_looked_at() -> bool:
	return _looked_at


## Собственно действие. Возвращает false, если ничего не произошло —
## тогда подсказка не сбрасывается и игрок может нажать ещё раз.
func interact() -> bool:
	return false
