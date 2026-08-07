## Полигон. Не уровень игры — стенд, где каждая система проверяется руками.
##
## Геометрия задаётся списком прямоугольников в тайлах, а не рисуется руками:
## так её быстрее править под конкретный вопрос («хватает ли coyote time
## на пропасть в 4 тайла?»).
##
## Состояние прохождения при запуске полигона намеренно чистое: все осколки
## и способности на месте при каждом перезапуске.
extends Node2D

const TILE := 16.0
## Ниже этой отметки — падение засчитано, возврат на старт.
const KILL_Y := 560.0
const FLOOR_Y := 320.0

const SPAWN := Vector2(48.0, FLOOR_Y)

## Геометрия в тайлах: x, y, ширина, высота. Пол на y = 20.
const BLOCKS := [
	# --- границы ---
	Rect2i(-1, 0, 1, 26),
	Rect2i(190, 0, 1, 26),

	# --- длинная прямая: разгон до предела и накопление «чистого» времени ---
	Rect2i(0, 20, 72, 6),

	# --- пропасти 3 / 4 / 5 тайлов: coyote time, высота прыжка, слипстрим ---
	Rect2i(75, 20, 8, 6),
	Rect2i(87, 20, 8, 6),
	Rect2i(100, 20, 30, 6),

	# --- секция способностей ---
	Rect2i(132, 20, 58, 6),

	# --- лестница платформ: точность прыжка на скорости ---
	Rect2i(18, 16, 4, 1),
	Rect2i(25, 13, 4, 1),
	Rect2i(32, 10, 4, 1),
	Rect2i(39, 7, 6, 1),

	# --- низкий потолок: бежать можно, прыгать нельзя ---
	Rect2i(50, 17, 16, 1),

	# --- выступ на прямой: сбивает разгон, если не перепрыгнуть ---
	Rect2i(107, 18, 1, 2),

	# --- массив над змеиной дверью: гейт нельзя просто перепрыгнуть ---
	Rect2i(159, 0, 3, 15),

	# --- массив над карманом: единственный вход — через скрытую стену ---
	Rect2i(174, 0, 16, 15),
]

@onready var _player: Player = $Player
@onready var _camera: GameCamera = $Camera
@onready var _overlay: CanvasLayer = $DebugOverlay
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BACKGROUND)

	# Полигон всегда начинается с чистого листа, иначе собранное
	# в прошлом запуске просто не появится.
	Game.reset()

	_build_geometry()
	_populate()

	_camera.target = _player
	_camera.global_position = _player.global_position
	_overlay.player = _player
	_hud.player = _player

	_player.landed.connect(_on_player_landed)
	_player.respawn_at(SPAWN)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_restart") or _player.global_position.y > KILL_Y:
		_player.respawn_at(_respawn_point())


## После кофейни падение возвращает к ней, а не в начало полигона.
func _respawn_point() -> Vector2:
	if Game.checkpoint_id.is_empty():
		return SPAWN
	return Game.checkpoint_position


func _on_player_landed(impact: float) -> void:
	# Трясём только на действительно жёстких приземлениях.
	if impact < _player.config.hard_landing_speed:
		return
	var strength := clampf(impact / _player.config.max_fall_speed, 0.0, 1.0)
	_camera.shake(strength)


# --- Наполнение --------------------------------------------------------

func _populate() -> void:
	_add_coffee_shop(6, "testbed", "Полигон", "двойной эспрессо")

	# Слипстрим — на верхней платформе, куда без него ещё можно долезть.
	_add_ability(41, 7, Abilities.Kind.SLIPSTREAM)
	# Остальные разложены по ходу, чтобы гейты можно было проверять подряд.
	_add_ability(104, 20, Abilities.Kind.PARSELTONGUE)
	_add_ability(126, 20, Abilities.Kind.WET_TYRES)
	_add_ability(152, 20, Abilities.Kind.STALK)

	# Осколки: два на виду, один в кармане за скрытой стеной.
	_add_shard(35, 9, "testbed_ladder", "На лестнице")
	_add_shard(91, 18, "testbed_gap", "Над пропастью")
	_add_shard(182, 20, "testbed_secret", "В кармане за стеной")

	# Вода: без Мокрой резины разгон здесь не держится.
	_add_water(138, 20, 14)

	# Змеиная дверь перегораживает проход к дальней части.
	_add_snake_door(160, "testbed_door")

	# Скрытая стена — вход в карман с осколком.
	_add_hidden_wall(175)


func _add_coffee_shop(tile_x: int, id: String, city: String, drink: String) -> void:
	var shop := CoffeeShop.new()
	shop.id = id
	shop.city = city
	shop.drink = drink
	shop.position = Vector2(tile_x * TILE, FLOOR_Y)
	add_child(shop)


func _add_ability(tile_x: int, tile_y: int, kind: Abilities.Kind) -> void:
	var pickup := AbilityPickup.new()
	pickup.kind = kind
	pickup.position = Vector2(tile_x * TILE, tile_y * TILE - 16.0)
	add_child(pickup)


func _add_shard(tile_x: int, tile_y: int, id: String, caption: String) -> void:
	var shard := MemoryShard.new()
	shard.id = id
	shard.caption = caption
	shard.position = Vector2(tile_x * TILE, tile_y * TILE - 12.0)
	add_child(shard)


func _add_water(tile_x: int, tile_y: int, tiles_wide: int) -> void:
	var water := WaterZone.new()
	water.size = Vector2(tiles_wide * TILE, 40.0)
	water.position = Vector2(tile_x * TILE, tile_y * TILE)
	add_child(water)


func _add_snake_door(tile_x: int, id: String) -> void:
	var door := SnakeDoor.new()
	door.id = id
	# До самого массива сверху: гейт должен гейтить, а не предлагать обход.
	door.size = Vector2(14.0, 80.0)
	door.position = Vector2(tile_x * TILE, FLOOR_Y)
	add_child(door)


func _add_hidden_wall(tile_x: int) -> void:
	var wall := HiddenWall.new()
	wall.size = Vector2(16.0, 80.0)
	wall.position = Vector2(tile_x * TILE, FLOOR_Y)
	add_child(wall)


# --- Геометрия ---------------------------------------------------------

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
	fill.color = Palette.BLOCK
	fill.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])

	# Светлая кромка сверху — без неё блоки сливаются в кашу.
	var edge := Polygon2D.new()
	edge.color = Palette.EDGE
	edge.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y + 2.0),
		Vector2(rect.position.x, rect.position.y + 2.0),
	])
	fill.add_child(edge)
	return fill
