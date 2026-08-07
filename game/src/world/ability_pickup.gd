## Место, где открывается способность (DESIGN.md §6).
##
## Момент получения — единственный, где игра прямо говорит, что изменилось
## в Кате. Поэтому подпись берётся из Abilities.HINT, а не пишется как
## «получен апгрейд».
class_name AbilityPickup
extends Area2D

signal unlocked(kind: Abilities.Kind)

const SIZE := Vector2(20.0, 20.0)

@export var kind: Abilities.Kind = Abilities.Kind.PARSELTONGUE

var _t := 0.0


func _ready() -> void:
	if Game.has_ability(kind):
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
	var color := Abilities.color(kind)
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)

	draw_circle(Vector2.ZERO, 14.0 + pulse * 3.0, Color(color, 0.15))
	draw_circle(Vector2.ZERO, 7.0, color)
	draw_arc(Vector2.ZERO, 12.0, _t, _t + PI, 16, Color(color, 0.8), 1.5)

	var font := ThemeDB.fallback_font
	var label := Abilities.title(kind)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-width * 0.5, -24.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if not Game.unlock(kind):
		return
	unlocked.emit(kind)
	queue_free()
