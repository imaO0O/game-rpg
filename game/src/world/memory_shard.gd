## Осколок памяти (DESIGN.md §11).
##
## Награда за исследование — не апгрейд, а настоящее воспоминание.
## Здесь только id и подпись: сам контент (фото, голосовое) лежит
## в private/ и в репозиторий не попадает.
class_name MemoryShard
extends Area2D

signal collected(shard: MemoryShard)

const SIZE := Vector2(12.0, 12.0)
const COLOR := Color("e8d9a0")
const GLOW := Color("e8d9a0", 0.22)

## Уникальный идентификатор — по нему осколок помнят между запусками.
@export var id := ""
## Короткая подпись. Реальный медиафайл подставляется из private/.
@export var caption := ""

var _t := 0.0


func _ready() -> void:
	if id.is_empty():
		push_warning("Осколок без id — он не сохранится между запусками")

	# Уже собранные не появляются заново при перезаходе в комнату.
	if Game.has_shard(id):
		queue_free()
		return

	var rect := RectangleShape2D.new()
	rect.size = SIZE

	var shape := CollisionShape2D.new()
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Покачивание рисованием, а не позицией: позиция остаётся честной
	# точкой подбора, независимо от анимации.
	var bob := sin(_t * 3.0) * 2.0
	var pts := PackedVector2Array([
		Vector2(0.0, -7.0 + bob),
		Vector2(6.0, bob),
		Vector2(0.0, 7.0 + bob),
		Vector2(-6.0, bob),
	])
	draw_circle(Vector2(0.0, bob), 12.0, GLOW)
	draw_colored_polygon(pts, COLOR)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if not Game.collect_shard(id):
		return
	collected.emit(self)
	queue_free()
