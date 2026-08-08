## Точка диалога в мире.
##
## Пинки говорит сама, когда есть что сказать, — а с людьми и предметами
## разговор начинает игрок. Отсюда два режима: по входу в зону и по нажатию.
class_name DialogueTrigger
extends Area2D

signal started(timeline_name: String)
signal finished(timeline_name: String)

@export var timeline_name := ""
## Заголовок для заглушки, пока настоящих реплик нет.
@export var label := "Пинки"
## Запускать сразу при входе в зону, а не по нажатию E.
@export var auto_start := false
## Сыграть один раз за прохождение.
@export var once := true
@export var size := Vector2(48.0, 48.0)

var _player: Player = null
var _running := false


func _ready() -> void:
	if timeline_name.is_empty():
		push_warning("Точка диалога без имени таймлайна")

	if once and Game.has_flag(_flag()):
		queue_free()
		return

	var rect := RectangleShape2D.new()
	rect.size = size

	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if auto_start or _running or _player == null:
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_run()


func _draw() -> void:
	if auto_start or _player == null or _running:
		return

	var font := ThemeDB.fallback_font
	var text := "E — %s" % label
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-width * 0.5, -size.y - 6.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.SILVER)


func _run() -> void:
	if _running:
		return
	_running = true
	queue_redraw()

	if _player != null:
		_player.input_locked = true

	started.emit(timeline_name)

	var played: bool = await Dialogue.play(timeline_name)
	if not played:
		await _show_placeholder()

	if _player != null:
		_player.input_locked = false

	if once:
		Game.set_flag(_flag())

	finished.emit(timeline_name)
	_running = false

	if once:
		queue_free()
	else:
		queue_redraw()


## Пока реплик нет — показываем, что здесь будет разговор, и идём дальше.
## Так каркас можно проходить целиком без личного контента.
func _show_placeholder() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.show_toast(label, Palette.SILVER, "здесь будет разговор: %s" % timeline_name)
	await get_tree().create_timer(1.2).timeout


func _flag() -> String:
	return "dialogue_%s" % timeline_name


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	_player = body
	queue_redraw()
	if auto_start:
		_run()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		queue_redraw()
