## Экспонат в Логове — собранный осколок, повешенный на стену.
##
## Здесь он уже не награда, а просто вещь, на которую можно посмотреть.
## Подпись показывается, когда подходишь: читать всю стену разом не нужно.
class_name Exhibit
extends Area2D

const SIZE := Vector2(28.0, 22.0)

@export var shard_id := ""
## Ненайденные висят пустыми рамками: видно, что что-то пропущено,
## но не видно что именно.
@export var collected := true

var _player_near := false


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE.x + 16.0, 48.0)

	var shape := CollisionShape2D.new()
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _draw() -> void:
	var rect := Rect2(-SIZE.x * 0.5, -SIZE.y * 0.5, SIZE.x, SIZE.y)
	var color := Palette.SHARD if collected else Palette.SILVER_DIM

	# Рамка, а внутри — место под настоящее фото.
	draw_rect(rect, Color(color, 0.15 if collected else 0.05))
	draw_rect(rect, Color(color, 0.9 if _player_near else 0.4), false, 1.0)

	if not collected:
		_draw_label("?", Color(color, 0.5))
		return

	if _player_near:
		_draw_label(ShardRegistry.caption(shard_id), color)


func _draw_label(text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(font, Vector2(-width * 0.5, -SIZE.y * 0.5 - 8.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_near = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_near = false
		queue_redraw()
