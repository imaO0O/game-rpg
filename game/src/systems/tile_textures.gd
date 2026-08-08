## Нарезка тайлсета на отдельные текстуры.
##
## Готовый тайлсет — один атлас, а геометрия уровня рисуется полигонами
## произвольного размера. Polygon2D умеет тайлить текстуру, но только
## целиком, поэтому нужные тайлы вырезаются в самостоятельные текстуры
## один раз при первом обращении.
##
## Источник: Sunny Land Луиса Зуно (@ansimuz), лицензия CC0 —
## public domain, коммерческое использование разрешено.
class_name TileTextures
extends RefCounted

const SUNNY := preload("res://assets/sunnyland/tileset.png")
const TILE := 16

## Координаты в тайлах внутри атласа.
##
## Тайлсет уложен с отступами: полезные тайлы стоят через один, шаг 32 px.
## Поэтому все координаты здесь нечётные — чётные ячейки пустые.
const GROUND_TOP := Vector2i(1, 1)
const GROUND_BODY := Vector2i(1, 3)
## Камень подземелья — для интерьеров и подвалов.
const STONE_TOP := Vector2i(15, 1)
const STONE_BODY := Vector2i(15, 3)
## Кирпич — для городских стен.
const BRICK_TOP := Vector2i(19, 13)
const BRICK_BODY := Vector2i(19, 15)

static var _cache: Dictionary = {}


## Вырезает тайл по координатам в тайлах. Результат кэшируется:
## комната строит десятки блоков, а текстур нужно всего несколько.
static func tile(cell: Vector2i, atlas: Texture2D = SUNNY) -> ImageTexture:
	var key := "%s:%d:%d" % [atlas.resource_path, cell.x, cell.y]
	if _cache.has(key):
		return _cache[key]

	var source := atlas.get_image()
	var region := Rect2i(cell.x * TILE, cell.y * TILE, TILE, TILE)

	# Выход за границы атласа даёт пустую текстуру — лучше заметить сразу.
	if not Rect2i(Vector2i.ZERO, source.get_size()).encloses(region):
		push_warning("Тайл %s вне атласа %s" % [cell, atlas.resource_path])
		return null

	var texture := ImageTexture.create_from_image(source.get_region(region))
	_cache[key] = texture
	return texture


## Набор текстур под материал комнаты.
static func material_set(kind: String) -> Dictionary:
	match kind:
		"stone":
			return {"top": tile(STONE_TOP), "body": tile(STONE_BODY)}
		"brick":
			return {"top": tile(BRICK_TOP), "body": tile(BRICK_BODY)}
		_:
			return {"top": tile(GROUND_TOP), "body": tile(GROUND_BODY)}
