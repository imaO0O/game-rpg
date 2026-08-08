## Прототип дома Зейда в 3D от первого лица.
##
## Цель — не игра, а честный ответ на вопрос «как это может выглядеть».
## Поэтому здесь всё, от чего зависит впечатление: настоящие PBR-материалы,
## объёмный туман, глобальное освещение, тени от каждого источника
## и постобработка. Геометрия — простые объёмы: в тесном тёмном интерьере
## работает свет, а не сложность форм.
##
## Материалы: ambientCG, лицензия CC0.
extends Node3D

const WALL := 0.15
const ROOM_H := 2.7

## Комнаты: положение и размер в метрах.
const ROOMS := [
	{"pos": Vector3(0, 0, 0), "size": Vector3(5, ROOM_H, 4)},
	{"pos": Vector3(0, 0, -7), "size": Vector3(3, ROOM_H, 10)},
	{"pos": Vector3(5, 0, -11), "size": Vector3(7, ROOM_H, 5)},
	{"pos": Vector3(-4, 0, -11), "size": Vector3(4, ROOM_H, 4)},
]

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _dark_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_rooms()
	_build_props()
	_build_lights()


# --- Материалы ---------------------------------------------------------

func _build_materials() -> void:
	_floor_material = _pbr(
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_Color.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_NormalGL.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_Roughness.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_AmbientOcclusion.jpg",
		Vector3(1.5, 1.5, 1.5)
	)
	_wall_material = _pbr(
		"res://assets/pbr/Plaster001/Plaster001_1K-JPG_Color.jpg",
		"res://assets/pbr/Plaster001/Plaster001_1K-JPG_NormalGL.jpg",
		"res://assets/pbr/Plaster001/Plaster001_1K-JPG_Roughness.jpg",
		"",
		Vector3(0.8, 0.8, 0.8)
	)

	_dark_material = StandardMaterial3D.new()
	_dark_material.albedo_color = Color(0.05, 0.05, 0.06)
	_dark_material.roughness = 0.9


func _pbr(color: String, normal: String, rough: String, ao: String, tiling: Vector3) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()

	if ResourceLoader.exists(color):
		mat.albedo_texture = load(color)
	if ResourceLoader.exists(normal):
		mat.normal_enabled = true
		mat.normal_texture = load(normal)
		mat.normal_scale = 1.0
	if ResourceLoader.exists(rough):
		mat.roughness_texture = load(rough)
	if ao != "" and ResourceLoader.exists(ao):
		mat.ao_enabled = true
		mat.ao_texture = load(ao)

	mat.uv1_scale = tiling
	# Триплanar снимает вопрос развёртки: одна и та же настройка годится
	# и для пола, и для стен любого размера.
	mat.uv1_triplanar = true
	return mat


# --- Освещение и атмосфера ---------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.12, 0.18)
	env.ambient_light_energy = 0.35

	# Объёмный туман — главный источник ощущения глубины и сырости.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.55, 0.58, 0.68)
	env.volumetric_fog_emission = Color(0.02, 0.03, 0.05)
	env.volumetric_fog_length = 48.0

	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.10)
	env.fog_density = 0.02

	# Затенение в углах: без него интерьер выглядит нарисованным.
	env.ssao_enabled = true
	env.ssao_intensity = 3.0
	env.ssao_radius = 1.4

	env.ssil_enabled = true
	env.ssil_intensity = 0.6

	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.85

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.92

	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _build_lights() -> void:
	# Лампа в первой комнате — единственный «нормальный» свет в доме.
	_lamp(Vector3(0.0, 2.3, 0.0), Color(1.0, 0.82, 0.55), 3.5, 7.0)
	# Дальше — только аварийные отсветы, чтобы было куда идти.
	_lamp(Vector3(0.0, 2.3, -9.0), Color(0.55, 0.72, 1.0), 1.6, 6.0)
	_lamp(Vector3(6.0, 2.3, -11.0), Color(1.0, 0.55, 0.35), 2.2, 6.5)


func _lamp(pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 1.6
	add_child(light)

	# Сам плафон: источник должен быть виден, иначе свет «ниоткуда».
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	bulb.mesh = sphere
	bulb.position = pos

	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 6.0
	bulb.material_override = glow
	add_child(bulb)


# --- Геометрия ---------------------------------------------------------

func _build_rooms() -> void:
	for room: Dictionary in ROOMS:
		var pos: Vector3 = room.pos
		var size: Vector3 = room.size

		_slab(pos + Vector3(0, -WALL * 0.5, 0), Vector3(size.x, WALL, size.z), _floor_material)
		_slab(pos + Vector3(0, size.y + WALL * 0.5, 0), Vector3(size.x, WALL, size.z), _dark_material)

		var half := size * 0.5
		_slab(pos + Vector3(-half.x, half.y, 0), Vector3(WALL, size.y, size.z), _wall_material)
		_slab(pos + Vector3(half.x, half.y, 0), Vector3(WALL, size.y, size.z), _wall_material)
		_slab(pos + Vector3(0, half.y, -half.z), Vector3(size.x, size.y, WALL), _wall_material)
		_slab(pos + Vector3(0, half.y, half.z), Vector3(size.x, size.y, WALL), _wall_material)


## Плита с коллизией. Всё в доме сделано из них.
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


## Мебель и хлам. Пустой интерьер читается как тестовая сцена,
## сколько на него ни вешай света.
func _build_props() -> void:
	# Стол и стулья в первой комнате.
	_slab(Vector3(1.6, 0.72, 0.4), Vector3(1.2, 0.06, 0.8), _floor_material)
	for x in [1.1, 2.1]:
		for z in [0.05, 0.75]:
			_slab(Vector3(x, 0.36, z), Vector3(0.07, 0.72, 0.07), _dark_material)

	# Шкаф у стены.
	_slab(Vector3(-2.0, 1.0, -1.2), Vector3(0.55, 2.0, 1.1), _floor_material)

	# Ящики в коридоре.
	_slab(Vector3(-0.9, 0.3, -5.5), Vector3(0.6, 0.6, 0.6), _floor_material)
	_slab(Vector3(-0.9, 0.9, -5.5), Vector3(0.5, 0.5, 0.5), _floor_material)
	_slab(Vector3(0.9, 0.25, -8.6), Vector3(0.5, 0.5, 0.7), _floor_material)

	# Дверные проёмы обозначены косяками.
	for z in [-2.2, -12.0]:
		_slab(Vector3(-0.95, 1.05, z), Vector3(0.12, 2.1, 0.12), _dark_material)
		_slab(Vector3(0.95, 1.05, z), Vector3(0.12, 2.1, 0.12), _dark_material)
