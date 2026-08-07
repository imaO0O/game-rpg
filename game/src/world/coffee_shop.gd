## Кофейня — точка сохранения (DESIGN.md §10).
##
## Делает четыре вещи разом: полный бак кофеина, сохранение, точка
## возврата после падения и узел сети быстрого перемещения.
## В каждом городе свой напиток — настоящий, тот, что она там пила.
class_name CoffeeShop
extends Area2D

signal used(shop: CoffeeShop)

const SIZE := Vector2(28.0, 36.0)
const COLOR_IDLE := Color("6b5540")
const COLOR_ACTIVE := Color("c8a06a")

@export var id := ""
@export var city := ""
## Название напитка. Мелочь, ради которой всё и делается.
@export var drink := ""

var _player: Player = null
var _t := 0.0


func _ready() -> void:
	if id.is_empty():
		push_warning("Кофейня без id — не попадёт в сеть быстрого перемещения")

	var rect := RectangleShape2D.new()
	rect.size = SIZE

	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = Vector2(0.0, -SIZE.y * 0.5)
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_t += delta
	if _player != null:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return
	if not event.is_action_pressed("interact"):
		return
	_use()
	get_viewport().set_input_as_handled()


func _use() -> void:
	_player.caffeine.refill()

	Game.set_checkpoint(id, scene_file_path, global_position)
	Game.register_stop(id, {
		"id": id,
		"city": city,
		"drink": drink,
		"scene": get_tree().current_scene.scene_file_path,
		"x": global_position.x,
		"y": global_position.y,
	})
	Game.save_game()

	used.emit(self)


func _draw() -> void:
	var active := _player != null
	var color := COLOR_ACTIVE if active else COLOR_IDLE

	# Стойка.
	draw_rect(Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y), color)

	# Пар — единственная анимация, по которой кофейню видно издалека.
	for i in 3:
		var phase := _t * 1.6 + i * 0.7
		var x := sin(phase) * 3.0 + (i - 1) * 6.0
		var y := -SIZE.y - 6.0 - fposmod(phase * 6.0, 14.0)
		var alpha := 1.0 - fposmod(phase * 6.0, 14.0) / 14.0
		draw_circle(Vector2(x, y), 2.0, Color(COLOR_ACTIVE, alpha * 0.6))

	if not active:
		return

	var font := ThemeDB.fallback_font
	var label := "E — %s" % (drink if not drink.is_empty() else "отдохнуть")
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-width * 0.5, -SIZE.y - 24.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_ACTIVE)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		queue_redraw()
