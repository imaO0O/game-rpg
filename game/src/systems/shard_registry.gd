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
	"ryazan_01": {"caption": "Дом", "area": "Рязань"},
	"ryazan_02": {"caption": "Двор", "area": "Рязань"},
	"ryazan_03": {"caption": "Парк", "area": "Рязань"},
	"ryazan_04": {"caption": "За калиткой", "area": "Рязань"},
	"ryazan_05": {"caption": "Подвал", "area": "Рязань"},
	"sochi_01": {"caption": "Набережная", "area": "Сочи"},
	"sochi_02": {"caption": "За разрывом", "area": "Сочи"},
	"sochi_03": {"caption": "Медальная площадь", "area": "Сочи"},
	"sochi_04": {"caption": "Боксы", "area": "Сочи"},
	"moscow_01": {"caption": "Площадь трёх вокзалов", "area": "Москва"},
	"moscow_02": {"caption": "Крыши составов", "area": "Москва"},
	"moscow_03": {"caption": "Переход", "area": "Москва"},
	"moscow_04": {"caption": "За стеной перехода", "area": "Москва"},
	"moscow_05": {"caption": "Депо", "area": "Москва"},
	"night_01": {"caption": "Двор ночью", "area": "Рязань ночью"},
	"night_02": {"caption": "Первый этаж", "area": "Рязань ночью"},
	"night_03": {"caption": "За стеной в доме", "area": "Рязань ночью"},
	"night_04": {"caption": "Чердак", "area": "Рязань ночью"},
	"spb_01": {"caption": "Набережная", "area": "Петербург"},
	"spb_02": {"caption": "У воды", "area": "Петербург"},
	"spb_03": {"caption": "За разрывом", "area": "Петербург"},
	"spb_04": {"caption": "Крыши", "area": "Петербург"},
	"spb_05": {"caption": "Двор-колодец", "area": "Петербург"},
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
