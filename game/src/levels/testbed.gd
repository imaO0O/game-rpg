## Полигон для подбора ощущения движения. Не уровень игры — стенд.
##
## Геометрия задаётся списком прямоугольников в тайлах, а не рисуется руками:
## так её быстрее править под конкретный вопрос («хватает ли coyote time
## на пропасть в 4 тайла?»).
extends Node2D

const TILE := 16.0
## Ниже этой отметки — падение засчитано, возврат на старт.
const KILL_Y := 560.0

const SPAWN := Vector2(48.0, 320.0)

const COLOR_BACKGROUND := Color("0e1f17")
const COLOR_BLOCK := Color("1e3a2c")
const COLOR_EDGE := Color("2f5c46")

## Геометрия в тайлах: x, y, ширина, высота. Пол на y = 20.
const BLOCKS := [
	# --- границы ---
	Rect2i(-1, 0, 1, 26),
	Rect2i(130, 0, 1, 26),

	# --- длинная прямая: разгон до top_speed и накопление «чистого» времени ---
	Rect2i(0, 20, 72, 6),

	# --- пропасти 3 / 4 / 5 тайлов: проверка coyote time и высоты прыжка ---
	Rect2i(75, 20, 8, 6),
	Rect2i(87, 20, 8, 6),
	Rect2i(100, 20, 30, 6),

	# --- лестница платформ: точность прыжка на скорости ---
	Rect2i(18, 16, 4, 1),
	Rect2i(25, 13, 4, 1),
	Rect2i(32, 10, 4, 1),
	Rect2i(39, 7, 6, 1),

	# --- низкий потолок: бежать можно, прыгать нельзя ---
	Rect2i(50, 17, 16, 1),

	# --- выступ на прямой: сбивает разгон, если не перепрыгнуть ---
	Rect2i(107, 18, 1, 2),

	# --- тупик в конце: штраф momentum за удар в стену ---
	Rect2i(127, 13, 2, 7),
]

@onready var _player: Player = $Player
@onready var _camera: GameCamera = $Camera
@onready var _overlay: CanvasLayer = $DebugOverlay


func _ready() -> void:
	RenderingServer.set_default_clear_color(COLOR_BACKGROUND)

	_build_geometry()

	_camera.target = _player
	_camera.global_position = _player.global_position
	_overlay.player = _player

	_player.landed.connect(_on_player_landed)
	_player.respawn_at(SPAWN)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_restart") or _player.global_position.y > KILL_Y:
		_player.respawn_at(SPAWN)


func _on_player_landed(impact: float) -> void:
	# Трясём только на действительно жёстких приземлениях.
	if impact < _player.config.hard_landing_speed:
		return
	var strength := clampf(impact / _player.config.max_fall_speed, 0.0, 1.0)
	_camera.shake(strength)


func _build_geometry() -> void:
	var body := StaticBody2D.new()
	body.name = "Geometry"
	add_child(body)

	for block: Rect2i in BLOCKS:
		var rect := Rect2(
			Vector2(block.position) * TILE,
			Vector2(block.size) * TILE
		)
		body.add_child(_make_collision(rect))
		body.add_child(_make_visual(rect))


func _make_collision(rect: Rect2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = rect.size

	var node := CollisionShape2D.new()
	node.shape = shape
	node.position = rect.get_center()
	return node


func _make_visual(rect: Rect2) -> Node2D:
	var fill := Polygon2D.new()
	fill.color = COLOR_BLOCK
	fill.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])

	# Светлая кромка сверху — без неё блоки сливаются в кашу.
	var edge := Polygon2D.new()
	edge.color = COLOR_EDGE
	edge.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y + 2.0),
		Vector2(rect.position.x, rect.position.y + 2.0),
	])
	fill.add_child(edge)
	return fill
