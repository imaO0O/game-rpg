## Каталог осколков памяти.
##
## Разделение намеренное: код знает только идентификаторы, а что именно
## за ними стоит — подпись, фотография, голосовое — живёт в private/
## и в репозиторий не попадает (DESIGN.md §13).
##
## Файл private/shards.json:
##   { "ryazan_01": { "caption": "...", "area": "Рязань" }, ... }
class_name ShardRegistry
extends RefCounted

const PRIVATE_PATH := "res://private/shards.json"

## Заглушки для полигона — чтобы каркас работал до появления настоящего контента.
const FALLBACK := {
	"testbed_ladder": {"caption": "На лестнице", "area": "Полигон"},
	"testbed_gap": {"caption": "Над пропастью", "area": "Полигон"},
	"testbed_secret": {"caption": "В кармане за стеной", "area": "Полигон"},
}

static var _cache: Dictionary = {}
static var _loaded := false


static func entry(id: String) -> Dictionary:
	_ensure_loaded()
	return _cache.get(id, {"caption": id, "area": ""})


static func caption(id: String) -> String:
	return entry(id).get("caption", id)


static func area(id: String) -> String:
	return entry(id).get("area", "")


## Все известные осколки — нужно, чтобы Логово знало, сколько их всего.
static func all() -> Dictionary:
	_ensure_loaded()
	return _cache


static func total() -> int:
	return all().size()


## Перечитать каталог — на случай, если private/ подложили при запущенной игре.
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_cache = FALLBACK.duplicate(true)

	if not FileAccess.file_exists(PRIVATE_PATH):
		return

	var file := FileAccess.open(PRIVATE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Каталог осколков есть, но не читается: %s" % PRIVATE_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Каталог осколков повреждён: ожидался объект JSON")
		return

	# Настоящий каталог дополняет и перекрывает заглушки.
	for id: Variant in parsed:
		_cache[String(id)] = parsed[id]
