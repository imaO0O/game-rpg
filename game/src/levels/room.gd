## Базовый класс комнаты.
##
## Комната описывается декларативно в `_define()` наследника: блоки в тайлах,
## точки входа, объекты. Всё остальное — игрок, камера, HUD, границы кадра,
## расстановка по точке входа — делается здесь один раз для всех комнат.
##
## Почему не TileMap: пока нет тайлсета, а описание в коде правится быстрее
## и переживает отсутствие арта. Когда арт появится, поменяется только
## `_build_geometry()` — интерфейс комнаты останется тем же.
class_name Room
extends Node2D

const TILE := 16.0

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const HUD_SCENE := preload("res://src/ui/hud.tscn")

## Идентификатор комнаты. Используется в флагах и отладке.
@export var room_id := ""
## Название для игрока — показывается при входе.
@export var room_title := ""

var player: Player
var camera: GameCamera
var hud: CanvasLayer

## Геометрия в тайлах.
var _blocks: Array[Rect2i] = []
## Именованные точки входа: имя -> позиция в пикселях.
var _spawns: Dictionary = {}
## Границы комнаты в тайлах — по ним ставятся лимиты камеры.
var _bounds := Rect2i(0, 0, 40, 24)
## Куда падать нельзя: ниже этой отметки — возврат на точку входа.
var _kill_y := 0.0

var _entered_from := ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BACKGROUND)

	_define()

	_build_geometry()
	_spawn_player()
	_setup_camera()
	_setup_hud()

	_place_player()
	_announce()


## Переопределяется наследником: здесь описывается комната.
func _define() -> void:
	push_warning("Комната %s ничего не описала" % room_id)


func _process(_delta: float) -> void:
	if player == null:
		return
	if Input.is_action_just_pressed("debug_restart") or player.global_position.y > _kill_y:
		player.respawn_at(_spawn_point(_entered_from))


# --- Описание комнаты: помощники для наследников ------------------------

## Блок геометрии в тайлах.
func block(x: int, y: int, w: int, h: int) -> void:
	_blocks.append(Rect2i(x, y, w, h))


## Границы комнаты в тайлах. Задают лимиты камеры и высоту падения.
func bounds(x: int, y: int, w: int, h: int) -> void:
	_bounds = Rect2i(x, y, w, h)
	_kill_y = float(y + h) * TILE + 160.0


## Именованная точка входа. `name` совпадает с тем, что указывает дверь.
func spawn(name: String, x: int, y: int) -> void:
	_spawns[name] = Vector2(x * TILE, y * TILE)


func shard(x: int, y: int, id: String, caption := "") -> void:
	var node := MemoryShard.new()
	node.id = id
	node.caption = caption
	node.position = Vector2(x * TILE, y * TILE - 12.0)
	add_child(node)


func coffee(x: int, y: int, id: String, city: String, drink: String) -> void:
	var node := CoffeeShop.new()
	node.id = id
	node.city = city
	node.drink = drink
	node.position = Vector2(x * TILE, y * TILE)
	add_child(node)


func ability(x: int, y: int, kind: Abilities.Kind) -> void:
	var node := AbilityPickup.new()
	node.kind = kind
	node.position = Vector2(x * TILE, y * TILE - 16.0)
	add_child(node)


func snake_door(x: int, y: int, id: String, height := 80.0) -> void:
	var node := SnakeDoor.new()
	node.id = id
	node.size = Vector2(14.0, height)
	node.position = Vector2(x * TILE, y * TILE)
	add_child(node)


func hidden_wall(x: int, y: int, height := 80.0) -> void:
	var node := HiddenWall.new()
	node.size = Vector2(16.0, height)
	node.position = Vector2(x * TILE, y * TILE)
	add_child(node)


func water(x: int, y: int, tiles_wide: int, height := 40.0) -> void:
	var node := WaterZone.new()
	node.size = Vector2(tiles_wide * TILE, height)
	node.position = Vector2(x * TILE, y * TILE)
	add_child(node)


func dialogue(x: int, y: int, timeline: String, label: String, auto := false) -> void:
	var node := DialogueTrigger.new()
	node.timeline_name = timeline
	node.label = label
	node.auto_start = auto
	node.position = Vector2(x * TILE, y * TILE)
	add_child(node)


## Дверь в другую комнату. `to_spawn` — имя точки входа в той комнате.
func door(x: int, y: int, to_scene: String, to_spawn: String, height := 48.0) -> void:
	var node := RoomDoor.new()
	node.target_scene = to_scene
	node.target_spawn = to_spawn
	node.size = Vector2(20.0, height)
	node.position = Vector2(x * TILE, y * TILE)
	add_child(node)


# --- Сборка ------------------------------------------------------------

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.z_index = 10
	add_child(player)


func _setup_camera() -> void:
	camera = GameCamera.new()
	camera.target = player
	add_child(camera)

	# Кадр не должен вылезать за комнату — иначе половину экрана
	# занимает пустота за стенами.
	camera.limit_left = int(_bounds.position.x * TILE)
	camera.limit_top = int(_bounds.position.y * TILE)
	camera.limit_right = int(_bounds.end.x * TILE)
	camera.limit_bottom = int(_bounds.end.y * TILE)


func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.player = player


## Игрок встаёт туда, откуда вошёл. Если пришёл не из двери — в "start".
func _place_player() -> void:
	_entered_from = Game.pending_spawn if not Game.pending_spawn.is_empty() else "start"
	Game.pending_spawn = ""

	var point := _spawn_point(_entered_from)
	player.respawn_at(point)
	camera.global_position = point


## Габариты комнаты в пикселях. Нужно инструменту снимков, чтобы
## показать планировку целиком.
func world_bounds() -> Rect2:
	return Rect2(Vector2(_bounds.position) * TILE, Vector2(_bounds.size) * TILE)


## Есть ли в комнате такая точка входа. Нужно проверке целостности области.
func has_spawn(name: String) -> bool:
	return _spawns.has(name)


func spawn_names() -> Array:
	return _spawns.keys()


func _spawn_point(name: String) -> Vector2:
	if _spawns.has(name):
		return _spawns[name]
	if _spawns.has("start"):
		return _spawns["start"]
	push_warning("В комнате %s нет точки входа «%s»" % [room_id, name])
	return Vector2(_bounds.position) * TILE + Vector2(64.0, 64.0)


func _announce() -> void:
	if room_title.is_empty() or hud == null:
		return
	# Название показываем только при первом входе — потом это шум.
	if not Game.set_flag("seen_%s" % room_id):
		return
	hud.show_toast(room_title, Palette.SILVER)


func _build_geometry() -> void:
	var body := StaticBody2D.new()
	body.name = "Geometry"
	add_child(body)

	for b: Rect2i in _blocks:
		var rect := Rect2(Vector2(b.position) * TILE, Vector2(b.size) * TILE)

		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		body.add_child(collision)

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
		body.add_child(fill)
