## Переход между комнатами.
##
## Куда именно встанет игрок в следующей комнате, решает не она, а дверь:
## так соседние комнаты не обязаны знать друг о друге ничего, кроме имени
## точки входа.
class_name RoomDoor
extends Area2D

@export var target_scene := ""
## Имя точки входа в той комнате.
@export var target_spawn := "start"
@export var size := Vector2(20.0, 48.0)

var _used := false
## Дверь не срабатывает сразу после загрузки комнаты: игрок, появившийся
## рядом с ней, иначе тут же провалился бы обратно — и комнаты закольцевались бы.
var _armed := false


func _ready() -> void:
	if target_scene.is_empty():
		push_warning("Дверь никуда не ведёт")

	get_tree().create_timer(0.35).timeout.connect(func() -> void: _armed = true)

	var rect := RectangleShape2D.new()
	rect.size = size

	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# Проём: тёмный прямоугольник со светлой рамкой. Читается как выход,
	# не притворяясь ничем другим.
	var rect := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	draw_rect(rect, Color(Palette.BACKGROUND, 0.9))
	draw_rect(rect, Color(Palette.SILVER_DIM, 0.7), false, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if _used or not _armed or not body is Player:
		return
	_used = true

	Game.pending_spawn = target_spawn
	# Смену сцены откладываем: физика сейчас в середине шага.
	get_tree().change_scene_to_file.call_deferred(target_scene)
