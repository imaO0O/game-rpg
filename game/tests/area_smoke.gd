## Проверка целостности области.
##
## Ловит то, что глазами не видно и что ломается тихо: дверь ведёт в комнату,
## где нет такой точки входа, два осколка с одним id, комната без спавна.
## Игрок узнал бы об этом, провалившись сквозь пол в неизвестность.
##
## Запуск:
##   godot --headless --path game res://tests/area_smoke.tscn
extends Node

const ROOMS := [
	"res://src/levels/ryazan/home.tscn",
	"res://src/levels/ryazan/yard.tscn",
	"res://src/levels/ryazan/park.tscn",
	"res://src/levels/ryazan/cellar.tscn",
	"res://src/levels/transsib/train.tscn",
	"res://src/levels/sochi/promenade.tscn",
	"res://src/levels/sochi/straight.tscn",
	"res://src/levels/sochi/turn3.tscn",
	"res://src/levels/sochi/paddock.tscn",
]

var _failures: PackedStringArray = []
var _checks := 0
## id осколка -> где встретился, для поиска дубликатов.
var _shard_owners: Dictionary = {}


func _ready() -> void:
	Game.reset()

	for path: String in ROOMS:
		_check_room(path)

	_check_doors()
	_check_spawn_clearance()
	_check_spawn_placement()
	_finish()


func _check_room(path: String) -> void:
	var room := _load_room(path)
	if room == null:
		return

	var name := room.room_id

	_check(not name.is_empty(), "%s: комната назвала себя" % path.get_file())
	_check(room.player != null, "%s: игрок создан" % name)
	_check(room.camera != null, "%s: камера создана" % name)
	_check(room.hud != null, "%s: HUD создан" % name)
	_check(room.has_spawn("start"), "%s: есть точка входа start" % name)

	# Игрок обязан стоять на полу, а не висеть и не проваливаться.
	_check(
		room.player.global_position.y < room._kill_y,
		"%s: спавн не в пропасти" % name
	)

	for shard in _find_all(room, MemoryShard):
		var id: String = shard.id
		_check(not id.is_empty(), "%s: осколок с id" % name)
		if _shard_owners.has(id):
			_check(false, "осколок %s встречается дважды: %s и %s" % [id, _shard_owners[id], name])
		else:
			_shard_owners[id] = name
		_check(
			ShardRegistry.all().has(id),
			"осколок %s есть в каталоге" % id
		)

	room.free()


## Каждая дверь должна вести в существующую комнату, где есть
## названная точка входа. Опечатка здесь роняет игрока в пустоту.
func _check_doors() -> void:
	for path: String in ROOMS:
		var room := _load_room(path)
		if room == null:
			continue

		var doors := _find_all(room, RoomDoor)
		_check(not doors.is_empty(), "%s: из комнаты есть выход" % room.room_id)

		for d in doors:
			var target: String = d.target_scene
			var spawn_name: String = d.target_spawn

			if not ResourceLoader.exists(target):
				_check(false, "%s: дверь ведёт в несуществующую сцену %s" % [room.room_id, target])
				continue

			var other := _load_room(target)
			if other == null:
				continue

			_check(
				other.has_spawn(spawn_name),
				"%s -> %s: точка входа «%s» существует" % [room.room_id, other.room_id, spawn_name]
			)
			other.free()

		room.free()


## Точка входа не должна попадать в дверь. Иначе игрок появляется внутри
## перехода и мгновенно уходит обратно — комнаты закольцовываются намертво.
func _check_spawn_clearance() -> void:
	const MIN_GAP := 24.0

	for path: String in ROOMS:
		var room := _load_room(path)
		if room == null:
			continue

		for spawn_name: String in room.spawn_names():
			var point: Vector2 = room._spawn_point(spawn_name)

			for d in _find_all(room, RoomDoor):
				var door: RoomDoor = d
				var gap := absf(door.global_position.x - point.x)
				_check(
					gap >= MIN_GAP,
					"%s: точка входа «%s» не в двери (%.0f px до неё)" % [room.room_id, spawn_name, gap]
				)

		room.free()


## Механика входа: игрок встаёт туда, откуда пришёл, а не всегда в начало.
func _check_spawn_placement() -> void:
	var yard := _load_room("res://src/levels/ryazan/yard.tscn")
	if yard == null:
		return

	var west: Vector2 = yard.player.global_position
	yard.free()

	Game.pending_spawn = "east"
	var yard_east := _load_room("res://src/levels/ryazan/yard.tscn")
	if yard_east == null:
		return

	var east: Vector2 = yard_east.player.global_position
	yard_east.free()

	_check(not west.is_equal_approx(east), "вход с востока и с запада — разные точки")
	_check(east.x > west.x, "вход «east» действительно справа")
	_check(Game.pending_spawn.is_empty(), "точка входа сбрасывается после использования")


func _load_room(path: String) -> Room:
	if not ResourceLoader.exists(path):
		_check(false, "сцена %s существует" % path)
		return null

	var scene: PackedScene = load(path)
	var room := scene.instantiate() as Room
	if room == null:
		_check(false, "%s — это комната" % path)
		return null

	add_child(room)
	return room


func _find_all(node: Node, type: Variant) -> Array:
	var result := []
	for child in node.get_children():
		if is_instance_of(child, type):
			result.append(child)
	return result


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("ПРОЙДЕНО: %d проверок" % _checks)
		get_tree().quit(0)
		return

	print("ПРОВАЛЕНО: %d из %d" % [_failures.size(), _checks])
	for f in _failures:
		print("  x ", f)
	get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  + ", label)
	else:
		_failures.append(label)
