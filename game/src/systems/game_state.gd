## Состояние прохождения. Автозагрузка под именем Game.
##
## Здесь всё, что переживает перезапуск: открытые способности, собранные
## осколки, точка сохранения и сеть кофеен для быстрого перемещения.
## Сам файл сохранения — обычный JSON, чтобы его можно было починить руками.
extends Node

signal ability_unlocked(kind: Abilities.Kind)
signal shard_collected(id: String, total: int)
signal checkpoint_reached(id: String)
signal game_saved
signal game_loaded

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Открытые способности: Abilities.Kind -> true.
var abilities: Dictionary = {}
## Собранные осколки памяти: id -> true.
var shards: Dictionary = {}
## Открытые кофейни: id -> {title, city, drink, scene, x, y}.
var stops: Dictionary = {}
## Разовые события мира: открытые двери, сыгранные сцены и прочее.
var flags: Dictionary = {}

var checkpoint_id := ""
var checkpoint_scene := ""
var checkpoint_position := Vector2.ZERO

var playtime := 0.0

## Куда встать в следующей комнате. Живёт только между сменами сцен
## и потому не сохраняется.
var pending_spawn := ""


func _process(delta: float) -> void:
	playtime += delta


# --- Способности -------------------------------------------------------

func has_ability(kind: Abilities.Kind) -> bool:
	return abilities.get(kind, false)


## Возвращает false, если способность уже была открыта.
func unlock(kind: Abilities.Kind) -> bool:
	if has_ability(kind):
		return false
	abilities[kind] = true
	ability_unlocked.emit(kind)
	return true


# --- Осколки памяти ----------------------------------------------------

func has_shard(id: String) -> bool:
	return shards.get(id, false)


## Возвращает false, если осколок уже был собран — так подбор
## не засчитывается дважды при перезаходе в комнату.
func collect_shard(id: String) -> bool:
	if has_shard(id):
		return false
	shards[id] = true
	shard_collected.emit(id, shards.size())
	return true


func shard_count() -> int:
	return shards.size()


# --- Флаги мира --------------------------------------------------------

func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


## Возвращает false, если флаг уже был поднят.
func set_flag(flag: String) -> bool:
	if has_flag(flag):
		return false
	flags[flag] = true
	return true


# --- Кофейни -----------------------------------------------------------

func register_stop(id: String, data: Dictionary) -> void:
	stops[id] = data


func has_stop(id: String) -> bool:
	return stops.has(id)


## Кофейни, доступные для быстрого перемещения, кроме текущей.
func other_stops(current_id: String) -> Array:
	var result := []
	for id: String in stops:
		if id != current_id:
			result.append(stops[id])
	return result


func set_checkpoint(id: String, scene: String, position: Vector2) -> void:
	checkpoint_id = id
	checkpoint_scene = scene
	checkpoint_position = position
	checkpoint_reached.emit(id)


# --- Сохранение --------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось открыть файл сохранения: %s" % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(_to_dict(), "\t"))
	file.close()
	game_saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось прочитать сохранение: %s" % FileAccess.get_open_error())
		return false

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Сохранение повреждено: ожидался объект JSON")
		return false

	_from_dict(parsed)
	game_loaded.emit()
	return true


## Начать заново. Файл сохранения не трогаем — только состояние в памяти.
func reset() -> void:
	abilities.clear()
	shards.clear()
	stops.clear()
	flags.clear()
	checkpoint_id = ""
	checkpoint_scene = ""
	checkpoint_position = Vector2.ZERO
	playtime = 0.0


func _to_dict() -> Dictionary:
	# Ключи-enum в JSON становятся строками, поэтому храним списком int.
	var ability_list: Array[int] = []
	for kind: int in abilities:
		if abilities[kind]:
			ability_list.append(kind)

	return {
		"version": SAVE_VERSION,
		"abilities": ability_list,
		"shards": shards.keys(),
		"flags": flags.keys(),
		"stops": stops,
		"checkpoint": {
			"id": checkpoint_id,
			"scene": checkpoint_scene,
			"x": checkpoint_position.x,
			"y": checkpoint_position.y,
		},
		"playtime": playtime,
	}


func _from_dict(data: Dictionary) -> void:
	reset()

	for kind: Variant in data.get("abilities", []):
		abilities[int(kind)] = true

	for id: Variant in data.get("shards", []):
		shards[String(id)] = true

	for flag: Variant in data.get("flags", []):
		flags[String(flag)] = true

	var saved_stops: Variant = data.get("stops", {})
	if typeof(saved_stops) == TYPE_DICTIONARY:
		stops = saved_stops

	var cp: Variant = data.get("checkpoint", {})
	if typeof(cp) == TYPE_DICTIONARY:
		checkpoint_id = String(cp.get("id", ""))
		checkpoint_scene = String(cp.get("scene", ""))
		checkpoint_position = Vector2(
			float(cp.get("x", 0.0)),
			float(cp.get("y", 0.0))
		)

	playtime = float(data.get("playtime", 0.0))
