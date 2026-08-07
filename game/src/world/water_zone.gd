## Вода — гейт Мокрой резины (DESIGN.md §6).
##
## Без способности здесь скользко, медленно и разгон не набирается:
## пройти можно, но линию не удержать. С Мокрой резиной вода
## перестаёт что-либо значить.
class_name WaterZone
extends Area2D

@export var size := Vector2(96.0, 48.0)

var _t := 0.0


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = size

	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	draw_rect(rect, Color(Palette.WATER, 0.45))

	# Рябь по поверхности — иначе зона читается как просто синий прямоугольник.
	var points := PackedVector2Array()
	var steps := int(size.x / 6.0)
	for i in steps + 1:
		var x := -size.x * 0.5 + i * 6.0
		var y := -size.y + sin(_t * 2.0 + i * 0.6) * 1.5
		points.append(Vector2(x, y))
	draw_polyline(points, Color(Palette.SILVER, 0.35), 1.0)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).enter_water()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		(body as Player).exit_water()
