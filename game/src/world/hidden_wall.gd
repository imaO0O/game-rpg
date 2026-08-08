## Скрытая стена — гейт Сталк-режима (DESIGN.md §6).
##
## Пока Сталк выключен, это неотличимая от остальных стена. В Сталк-режиме
## она проявляется и перестаёт держать. В отличие от змеиной двери, этот гейт
## намеренно НЕ сообщает о себе: он и есть секрет.
class_name HiddenWall
extends StaticBody2D

const GROUP := "stalk_hidden"

@export var size := Vector2(16.0, 48.0)

var _revealed := false

@onready var _shape := CollisionShape2D.new()


func _ready() -> void:
	add_to_group(GROUP)

	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(_shape)


## Проявлена ли стена сейчас. Нужно тестам: проверять приватную
## коллизию снаружи нельзя, а поведение проверять надо.
func is_revealed() -> bool:
	return _revealed


## Вызывается игроком через группу при переключении Сталк-режима.
func set_revealed(active: bool) -> void:
	if _revealed == active:
		return
	_revealed = active
	_shape.set_deferred("disabled", active)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size.x * 0.5, -size.y, size.x, size.y)

	if not _revealed:
		# Ровно то же, что рисует обычная геометрия уровня.
		draw_rect(rect, Palette.BLOCK)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Palette.EDGE)
		return

	var color := Abilities.color(Abilities.Kind.STALK)
	draw_rect(rect, Color(color, 0.18))
	draw_rect(rect, Color(color, 0.7), false, 1.0)
