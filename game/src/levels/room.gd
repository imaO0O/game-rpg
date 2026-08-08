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
const SURFACE_SHADER := preload("res://src/shaders/surface.gdshader")
const ATMOSPHERE_SHADER := preload("res://src/shaders/atmosphere.gdshader")

## Идентификатор комнаты. Используется в флагах и отладке.
@export var room_id := ""
## Название для игрока — показывается при входе.
@export var room_title := ""

## Фон и цвет геометрии. Области отличаются в первую очередь ими.
var background := Palette.BACKGROUND
var block_color := Palette.BLOCK
var edge_color := Palette.EDGE
## Фактура поверхности. Крупность пятен и густота трещин отличают
## гранит Петербурга от штукатурки Рязани без отдельных текстур.
var grain_scale := 0.035
var crack_scale := 0.012
var crack_strength := 0.35

## Тип фона за геометрией. Слои силуэтов уезжают с разной скоростью
## и выцветают вдаль — без этого сцена читается как плоская.
var backdrop: Backdrop.Kind = Backdrop.Kind.CITY
## Готовые слои-картинки вместо процедурных силуэтов. Если задано,
## используется вместо `backdrop`.
var backdrop_layers: Array = []
## Плотность атмосферной дымки поверх кадра.
var haze := 0.12
## Плотность дождя. Ноль — сухо. Дождь висит на камере, поэтому идёт
## по всему кадру, а не в одной точке комнаты.
var rain_amount := 0
## Общий свет комнаты. Белый — без затемнения, тёмный — ночь.
## Именно он превращает одну и ту же геометрию в разные места.
var ambient := Color.WHITE
## Радиус свечения вокруг игрока. Нужен там, где темно настолько,
## что без него не видно, куда идёшь.
var player_light := 0.0
var player_light_color := Color(1.0, 0.94, 0.85)

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
	_define()

	# Цвет фона комната может переопределить: у Сочи он теплее, чем у Рязани.
	RenderingServer.set_default_clear_color(background)

	_setup_backdrop()
	_build_geometry()
	_setup_ambient()
	_spawn_player()
	_setup_camera()
	_setup_hud()
	_setup_atmosphere()

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


## Источник света: фонарь, лампа, витрина.
func lamp(x: int, y: int, color: Color, energy := 1.0, radius := 90.0) -> void:
	var light := Lighting.make_point(color, energy, radius)
	light.position = Vector2(x * TILE, y * TILE)
	add_child(light)


## Свет из окна, падающий вниз. Ставится на само окно.
func window(x: int, y: int, w: int, h: int, color: Color, energy := 0.9) -> void:
	decor(x, y, w, h, color)

	var light := Lighting.make_beam(color, energy, w * TILE * 3.0, h * TILE * 8.0)
	light.position = Vector2((float(x) + w * 0.5) * TILE, (y + h) * TILE)
	add_child(light)


## Декорация без коллизии: окна, море, разметка. Рисуется под геометрией.
func decor(x: int, y: int, w: int, h: int, color: Color) -> void:
	var rect := Rect2(Vector2(x, y) * TILE, Vector2(w, h) * TILE)

	var poly := Polygon2D.new()
	poly.color = color
	poly.z_index = -5
	poly.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	add_child(poly)


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


## Водная зона от тайла `x` вправо на `tiles_wide` — как block() и decor().
## Сама зона центрируется по своей позиции, поэтому сдвигаем на половину:
## иначе вода стоит не там, где нарисована, и гейт срабатывает не в том месте.
func water(x: int, y: int, tiles_wide: int, height := 40.0) -> void:
	var node := WaterZone.new()
	node.size = Vector2(tiles_wide * TILE, height)
	node.position = Vector2((float(x) + tiles_wide * 0.5) * TILE, y * TILE)
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


## Дверь посреди комнаты — только по нажатию. Автоматическая на пути
## движения перехватывала бы всех, кто просто пробегал мимо.
func door_here(x: int, y: int, to_scene: String, to_spawn: String, label: String, height := 48.0) -> void:
	var node := RoomDoor.new()
	node.target_scene = to_scene
	node.target_spawn = to_spawn
	node.require_interact = true
	node.label = label
	node.size = Vector2(20.0, height)
	node.position = Vector2(x * TILE, y * TILE)
	add_child(node)


# --- Сборка ------------------------------------------------------------

## Слои силуэтов за геометрией. Семя берём из имени комнаты: один и тот же
## двор всегда выглядит одинаково, а соседний — иначе.
func _setup_backdrop() -> void:
	var world := world_bounds()
	var view := Backdrop.new()
	add_child(view)

	if not backdrop_layers.is_empty():
		view.build_textured(backdrop_layers, maxf(world.size.x, 1600.0))
		return

	view.build(
		backdrop,
		# Темнее игровой геометрии: иначе фон читается как площадка,
		# по которой можно бежать.
		block_color.darkened(0.35),
		background,
		world.end.y - 4.0 * TILE,
		maxf(world.size.x, 1600.0),
		int(hash(room_id)) & 0xffff
	)


## Виньетка, зерно и дымка поверх всего. Отдельным слоем, чтобы
## не зависеть от того, что нарисовано под ним.
func _setup_atmosphere() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = ATMOSPHERE_SHADER
	mat.set_shader_parameter("haze_color", background.lightened(0.12))
	mat.set_shader_parameter("haze_strength", haze)

	var overlay := ColorRect.new()
	overlay.color = Color.WHITE
	overlay.material = mat
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var layer := CanvasLayer.new()
	# Выше игры, ниже интерфейса.
	layer.layer = 1
	layer.add_child(overlay)
	add_child(layer)


## Затемнение всей комнаты. Источники света работают только вместе с ним:
## без затемнения осветлять нечего.
func _setup_ambient() -> void:
	if ambient == Color.WHITE:
		return
	var modulate_node := CanvasModulate.new()
	modulate_node.color = ambient
	add_child(modulate_node)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.z_index = 10
	add_child(player)

	if player_light > 0.0:
		var light := Lighting.make_point(player_light_color, 0.9, player_light)
		light.position = Vector2(0.0, -10.0)
		player.add_child(light)


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

	if rain_amount > 0:
		_setup_rain()


## Дождь — ребёнок камеры: так он всегда в кадре и не требует
## засевать частицами всю комнату.
func _setup_rain() -> void:
	var drops := CPUParticles2D.new()
	drops.amount = rain_amount
	drops.lifetime = 1.2
	drops.preprocess = 1.2
	drops.local_coords = false
	drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drops.emission_rect_extents = Vector2(400.0, 8.0)
	drops.position = Vector2(0.0, -220.0)
	drops.direction = Vector2(-0.25, 1.0)
	drops.spread = 4.0
	drops.gravity = Vector2(0.0, 260.0)
	drops.initial_velocity_min = 320.0
	drops.initial_velocity_max = 420.0
	drops.scale_amount_min = 0.6
	drops.scale_amount_max = 1.4
	drops.color = Color(Palette.RAIN, 0.35)
	drops.z_index = 20
	camera.add_child(drops)


func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate()
	# Выше атмосферного слоя: виньетка не должна затемнять интерфейс.
	hud.layer = 2
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
		fill.color = Color.WHITE
		fill.polygon = PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		fill.material = _surface_material(rect)
		body.add_child(fill)


## Материал поверхности: фактура, трещины, освещённая кромка сверху
## и затемнение вглубь. Свой на блок — ему нужно знать, где его верх.
func _surface_material(rect: Rect2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE_SHADER
	mat.set_shader_parameter("base_color", block_color)
	mat.set_shader_parameter("edge_color", edge_color)
	mat.set_shader_parameter("vein_color", block_color.darkened(0.45))
	mat.set_shader_parameter("grain_scale", grain_scale)
	mat.set_shader_parameter("crack_scale", crack_scale)
	mat.set_shader_parameter("crack_strength", crack_strength)
	mat.set_shader_parameter("edge_width", 3.0)
	mat.set_shader_parameter("top_y", rect.position.y)
	mat.set_shader_parameter("height", rect.size.y)
	return mat
