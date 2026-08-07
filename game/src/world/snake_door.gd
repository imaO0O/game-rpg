## Змеиная дверь — гейт Змееуста (DESIGN.md §6).
##
## Гейт обязан сам сообщать, что от игрока требуется: без способности
## дверь шипит и показывает змею, со способностью — предлагает поговорить.
## Догадываться игрок не должен.
class_name SnakeDoor
extends StaticBody2D

signal opened(door: SnakeDoor)

const ABILITY := Abilities.Kind.PARSELTONGUE

@export var id := ""
@export var size := Vector2(14.0, 48.0)

var _player: Player = null
var _open := false
var _t := 0.0

@onready var _shape := CollisionShape2D.new()


func _ready() -> void:
	if id.is_empty():
		push_warning("Дверь без id — не запомнит, что её открыли")

	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(_shape)

	var sensor := Area2D.new()
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = size + Vector2(48.0, 8.0)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0.0, -size.y * 0.5)
	sensor.add_child(sensor_shape)
	sensor.body_entered.connect(_on_body_entered)
	sensor.body_exited.connect(_on_body_exited)
	add_child(sensor)

	# Однажды открытая дверь открыта навсегда.
	if Game.has_flag(_flag()):
		_open_now(false)


func _process(delta: float) -> void:
	_t += delta
	if _player != null or _open:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _open or _player == null:
		return
	if not event.is_action_pressed("interact"):
		return
	if not Game.has_ability(ABILITY):
		return
	_open_now(true)
	get_viewport().set_input_as_handled()


func _open_now(announce: bool) -> void:
	_open = true
	_shape.set_deferred("disabled", true)
	Game.set_flag(_flag())
	queue_redraw()
	if announce:
		opened.emit(self)


func _draw() -> void:
	if _open:
		_draw_open()
		return

	var color := Abilities.color(ABILITY)
	draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), Palette.BLOCK)
	draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), color, false, 1.0)
	_draw_snake(color)

	if _player == null:
		return

	var has := Game.has_ability(ABILITY)
	_draw_label(
		"E — говорить со змеёй" if has else "заперто",
		color if has else Palette.SILVER_DIM
	)


## Открытая дверь остаётся в мире тонкой рамкой — так видно, что здесь был путь.
func _draw_open() -> void:
	var color := Color(Abilities.color(ABILITY), 0.25)
	draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), color, false, 1.0)


func _draw_snake(color: Color) -> void:
	var points := PackedVector2Array()
	var segments := 12
	for i in segments + 1:
		var t := float(i) / segments
		var y := -size.y * 0.2 - t * size.y * 0.6
		var x := sin(t * PI * 2.0 + _t * 1.5) * (size.x * 0.25)
		points.append(Vector2(x, y))
	draw_polyline(points, color, 2.0)


func _draw_label(text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-width * 0.5, -size.y - 12.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _flag() -> String:
	return "door_%s" % id


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		queue_redraw()
