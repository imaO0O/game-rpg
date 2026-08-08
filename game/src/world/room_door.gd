## Переход между комнатами.
##
## Куда именно встанет игрок в следующей комнате, решает не она, а дверь:
## так соседние комнаты не обязаны знать друг о друге ничего, кроме имени
## точки входа.
##
## Два режима. По краям комнаты переход срабатывает сам — там игрок и так
## собирался выйти. Посреди комнаты дверь обязана требовать нажатия, иначе
## она перехватывает всех, кто просто пробегал мимо.
class_name RoomDoor
extends Area2D

@export var target_scene := ""
## Имя точки входа в той комнате.
@export var target_spawn := "start"
## Требовать нажатия E. Обязательно для дверей на пути движения.
@export var require_interact := false
## Подпись для подсказки, если дверь требует нажатия.
@export var label := "войти"
@export var size := Vector2(20.0, 48.0)

var _used := false
## Дверь не срабатывает сразу после загрузки комнаты: игрок, появившийся
## рядом с ней, иначе тут же провалился бы обратно — и комнаты закольцевались бы.
var _armed := false
var _player: Player = null


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
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not require_interact or _player == null or _used or not _armed:
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_go()


func _draw() -> void:
	# Проём: тёмный прямоугольник со светлой рамкой. Читается как выход,
	# не притворяясь ничем другим.
	var rect := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	draw_rect(rect, Color(Palette.BACKGROUND, 0.9))
	draw_rect(rect, Color(Palette.SILVER_DIM, 0.7), false, 1.0)

	if not require_interact or _player == null:
		return

	var font := ThemeDB.fallback_font
	var text := "E — %s" % label
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-width * 0.5, -size.y - 8.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.SILVER)


func _go() -> void:
	_used = true
	Game.pending_spawn = target_spawn
	# Смену сцены откладываем: физика сейчас в середине шага.
	get_tree().change_scene_to_file.call_deferred(target_scene)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	_player = body
	queue_redraw()

	if require_interact or _used or not _armed:
		return
	_go()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		queue_redraw()
