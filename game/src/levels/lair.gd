## Логово Тёмного Лорда (DESIGN.md §9).
##
## То, ради чего всё и делалось. Ни задач, ни врагов, ни таймеров —
## карта с флажками посещённого, стена фотографий, кофе-машина,
## спящая змея. Просто ходить и смотреть.
extends Node2D

const TILE := 16.0
const FLOOR_Y := 224.0
const SPAWN := Vector2(64.0, FLOOR_Y)

## Комната: пол на y = 14, потолок на y = 3.
const BLOCKS := [
	Rect2i(0, 14, 44, 3),
	Rect2i(0, 2, 44, 1),
	Rect2i(-1, 2, 1, 13),
	Rect2i(44, 2, 1, 13),
]

## Стена с экспонатами.
const WALL_Y := 8
const WALL_START_X := 4
const WALL_STEP := 3

## Карта России на правой стене.
const MAP_RECT := Rect2(30.0 * TILE, 4.0 * TILE, 12.0 * TILE, 6.0 * TILE)

@onready var _player: Player = $Player
@onready var _camera: GameCamera = $Camera
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BACKGROUND)

	_build_geometry()
	_build_exhibits()

	_camera.target = _player
	_camera.global_position = _player.global_position
	_hud.player = _player

	_player.respawn_at(SPAWN)


func _process(_delta: float) -> void:
	# В Логове падать некуда, но перезапуск с R удобен при отладке.
	if Input.is_action_just_pressed("debug_restart"):
		_player.respawn_at(SPAWN)
	queue_redraw()


# --- Экспонаты ---------------------------------------------------------

func _build_exhibits() -> void:
	var ids := ShardRegistry.all().keys()
	ids.sort()

	for i in ids.size():
		var id: String = ids[i]
		var exhibit := Exhibit.new()
		exhibit.shard_id = id
		exhibit.collected = Game.has_shard(id)
		exhibit.position = Vector2(
			(WALL_START_X + i * WALL_STEP) * TILE,
			WALL_Y * TILE
		)
		add_child(exhibit)


# --- Обстановка --------------------------------------------------------

func _draw() -> void:
	_draw_interior()
	_draw_map()
	_draw_coffee_machine()
	_draw_snake()
	_draw_summary()


## Заливка комнаты. Без неё интерьер сливается с пустотой за стенами
## и Логово не читается как помещение.
func _draw_interior() -> void:
	var interior := Rect2(0.0, 3.0 * TILE, 44.0 * TILE, 11.0 * TILE)
	draw_rect(interior, Color("0f261c"))

	# Плинтус — линия, по которой глаз считывает пол.
	draw_rect(Rect2(0.0, FLOOR_Y - 2.0, 44.0 * TILE, 2.0), Palette.EDGE)


## Карта с флажками: по одному за каждую открытую кофейню.
func _draw_map() -> void:
	draw_rect(MAP_RECT, Color(Palette.BLOCK, 0.8))
	draw_rect(MAP_RECT, Color(Palette.SILVER_DIM, 0.6), false, 1.0)

	var font := ThemeDB.fallback_font
	draw_string(font, MAP_RECT.position + Vector2(4.0, -4.0), "маршрут",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.SILVER_DIM)

	var i := 0
	for id: String in Game.stops:
		var stop: Dictionary = Game.stops[id]
		# Флажки раскладываются по сетке — настоящие координаты городов
		# появятся вместе с настоящей картой.
		var pos := MAP_RECT.position + Vector2(
			20.0 + (i % 3) * 52.0,
			22.0 + float(i / 3) * 30.0
		)
		draw_line(pos, pos + Vector2(0.0, -10.0), Palette.SILVER, 1.0)
		draw_colored_polygon(
			PackedVector2Array([
				pos + Vector2(0.0, -10.0),
				pos + Vector2(8.0, -7.0),
				pos + Vector2(0.0, -4.0),
			]),
			Palette.FERRARI
		)
		draw_string(font, pos + Vector2(-6.0, 8.0), String(stop.get("city", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Palette.SILVER_DIM)
		i += 1


func _draw_coffee_machine() -> void:
	var base := Vector2(24.0 * TILE, FLOOR_Y)
	draw_rect(Rect2(base.x - 10.0, base.y - 28.0, 20.0, 28.0), Palette.COFFEE)
	draw_rect(Rect2(base.x - 6.0, base.y - 22.0, 12.0, 8.0), Palette.BACKGROUND)

	var font := ThemeDB.fallback_font
	draw_string(font, base + Vector2(-18.0, -34.0), "кофе-машина",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Palette.SILVER_DIM)


## Змея спит. Она заслужила.
func _draw_snake() -> void:
	var base := Vector2(38.0 * TILE, FLOOR_Y)
	var color := Abilities.color(Abilities.Kind.PARSELTONGUE)
	var points := PackedVector2Array()
	for i in 24:
		var t := float(i) / 23.0
		points.append(base + Vector2(-24.0 + t * 48.0, -4.0 + sin(t * PI * 3.0) * 3.0))
	draw_polyline(points, color, 3.0)
	draw_circle(base + Vector2(24.0, -4.0), 3.0, color)


func _draw_summary() -> void:
	var font := ThemeDB.fallback_font
	var found := Game.shard_count()
	var total := ShardRegistry.total()
	var text := "найдено %d из %d" % [found, total]
	draw_string(font, Vector2(WALL_START_X * TILE, (WALL_Y - 3) * TILE), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.SILVER)


# --- Геометрия ---------------------------------------------------------

func _build_geometry() -> void:
	var body := StaticBody2D.new()
	body.name = "Geometry"
	add_child(body)

	for block: Rect2i in BLOCKS:
		var rect := Rect2(Vector2(block.position) * TILE, Vector2(block.size) * TILE)

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
		body.add_child(fill)
