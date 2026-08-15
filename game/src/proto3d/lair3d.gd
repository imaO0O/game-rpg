## Логово Тёмного Лорда в трёх измерениях (CONCEPT_3D.md).
##
## То, ради чего всё и делалось. Ни скримеров, ни задач, ни таймеров —
## стена с найденным, карта с флажками, кофе-машина, спящая змея.
## Просто ходить и смотреть.
##
## Открывается после финала. До него дверь есть, но за ней темнота:
## Логово собирается из того, что игрок нашёл, и показывать его
## заранее — значит показать пустые рамки вместо смысла.
extends Node3D

const ROOM := Vector3(9.0, 2.6, 7.0)
const WALL := 0.15

## Экспонаты вешаются в ряд на дальней стене.
const SHELF_Y := 1.55
const SHELF_START_X := -3.4
const SHELF_STEP := 0.85

var _wall_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _frame_material: StandardMaterial3D
var _missing_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_room()
	_build_exhibits()
	_build_map()
	_build_snake()
	_build_lights()


func _build_materials() -> void:
	_floor_material = StandardMaterial3D.new()
	_floor_material.albedo_color = Color(0.16, 0.13, 0.11)
	_floor_material.roughness = 0.8

	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = Color(0.13, 0.18, 0.15)
	_wall_material.roughness = 0.9

	# Найденное — тёплое и светлое.
	_frame_material = StandardMaterial3D.new()
	_frame_material.albedo_color = Color(0.82, 0.76, 0.62)
	_frame_material.roughness = 0.45

	# Ненайденное — пустая рамка. Видно, что чего-то не хватает,
	# но не видно, чего именно.
	_missing_material = StandardMaterial3D.new()
	_missing_material.albedo_color = Color(0.18, 0.19, 0.19)
	_missing_material.roughness = 0.95


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.24, 0.22)
	# Светлее, чем в доме: здесь ничего не прячется.
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.7

	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)


func _build_room() -> void:
	var half := ROOM * 0.5

	_slab(Vector3(0, -WALL * 0.5, 0), Vector3(ROOM.x, WALL, ROOM.z), _floor_material)
	_slab(Vector3(0, ROOM.y + WALL * 0.5, 0), Vector3(ROOM.x, WALL, ROOM.z), _wall_material)
	_slab(Vector3(-half.x, half.y, 0), Vector3(WALL, ROOM.y, ROOM.z), _wall_material)
	_slab(Vector3(half.x, half.y, 0), Vector3(WALL, ROOM.y, ROOM.z), _wall_material)
	_slab(Vector3(0, half.y, -half.z), Vector3(ROOM.x, ROOM.y, WALL), _wall_material)
	_slab(Vector3(0, half.y, half.z), Vector3(ROOM.x, ROOM.y, WALL), _wall_material)


## Стена с найденным. Порядок фиксированный, поэтому пробелы в ряду
## всегда на одних и тех же местах — по ним видно, что пропущено.
func _build_exhibits() -> void:
	var ids := ShardRegistry.all().keys()
	ids.sort()

	for i in ids.size():
		var id: String = ids[i]
		var found := Game.has_shard(id)

		var x := SHELF_START_X + (i % 9) * SHELF_STEP
		var y := SHELF_Y - float(i / 9) * 0.62
		var pos := Vector3(x, y, -ROOM.z * 0.5 + 0.2)

		var frame := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.42, 0.03)
		frame.mesh = box
		frame.position = pos
		frame.material_override = _frame_material if found else _missing_material
		add_child(frame)

		if not found:
			continue

		# Найденное подсвечено собственным огоньком: стена должна
		# светиться тем сильнее, чем больше собрано.
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.88, 0.68)
		glow.light_energy = 0.22
		glow.omni_range = 1.1
		glow.omni_attenuation = 2.4
		glow.shadow_enabled = false
		glow.position = pos + Vector3(0.0, 0.0, 0.35)
		add_child(glow)

		var label := Label3D.new()
		label.text = ShardRegistry.caption(id)
		label.font_size = 42
		label.pixel_size = 0.0016
		label.modulate = Color(0.85, 0.82, 0.74)
		label.position = pos + Vector3(0.0, -0.3, 0.05)
		add_child(label)


## Карта с флажками: по одному за каждый город, где она была.
func _build_map() -> void:
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.6, 1.6, 0.04)
	board.mesh = box
	board.position = Vector3(ROOM.x * 0.5 - 0.25, 1.5, 0.0)
	board.rotation.y = -PI * 0.5

	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.5, 0.48, 0.42)
	paper.roughness = 0.95
	board.material_override = paper
	add_child(board)

	var cities := ShardRegistry.areas()
	for i in cities.size():
		var flag := MeshInstance3D.new()
		var pin := BoxMesh.new()
		pin.size = Vector3(0.02, 0.02, 0.14)
		flag.mesh = pin
		flag.position = Vector3(
			ROOM.x * 0.5 - 0.32,
			1.95 - float(i) * 0.34,
			0.85 - float(i % 3) * 0.6
		)

		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.72, 0.05, 0.04)
		red.roughness = 0.35
		flag.material_override = red
		add_child(flag)

		var label := Label3D.new()
		label.text = cities[i]
		label.font_size = 34
		label.pixel_size = 0.0016
		label.modulate = Color(0.78, 0.75, 0.68)
		label.rotation.y = -PI * 0.5
		label.position = flag.position + Vector3(-0.06, -0.12, 0.0)
		add_child(label)


## Змея спит. Она заслужила.
func _build_snake() -> void:
	var path := "res://assets/models/snake.glb"
	if not ResourceLoader.exists(path):
		return

	var scene: PackedScene = load(path)
	var snake := scene.instantiate()
	snake.position = Vector3(-2.6, 0.0, 1.8)
	snake.rotation.y = 0.6

	var scales := StandardMaterial3D.new()
	scales.albedo_color = Color(0.16, 0.34, 0.22)
	scales.roughness = 0.45
	_paint(snake, scales)
	add_child(snake)


func _build_lights() -> void:
	# Ровный тёплый свет: единственная комната в игре, где не страшно.
	var main := OmniLight3D.new()
	main.position = Vector3(0.0, 2.35, 0.0)
	main.light_color = Color(1.0, 0.88, 0.72)
	main.light_energy = 1.1
	main.omni_range = 7.0
	main.omni_attenuation = 1.8
	main.light_size = 0.3
	main.shadow_enabled = true
	main.shadow_blur = 2.0
	add_child(main)


func _slab(centre: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = centre
	add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)


func _paint(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_paint(child, material)
