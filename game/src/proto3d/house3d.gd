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
var _trim_material: StandardMaterial3D
var _paper_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_rooms()
	_build_trim()
	_build_props()
	_build_clutter()
	_build_lights()
	_build_dust()


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

	# Плинтус светлее пола и темнее стены — так стык читается как деталь.
	_trim_material = StandardMaterial3D.new()
	_trim_material.albedo_color = Color(0.20, 0.17, 0.14)
	_trim_material.roughness = 0.55

	# Бумага почти не блестит и слегка светлее всего в комнате.
	_paper_material = StandardMaterial3D.new()
	_paper_material.albedo_color = Color(0.62, 0.60, 0.55)
	_paper_material.roughness = 0.95


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

	# Глобальное освещение: свет от лампы отражается от пола и стен и
	# доходит до потолка. Без него верх кадра остаётся угольно-чёрным,
	# и комната читается как коробка с прожектором.
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_energy = 1.4
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.08

	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	# Приглушённый цвет — общее место жанра: хоррор почти обесцвечен,
	# и на этом фоне работают редкие тёплые акценты.
	env.adjustment_saturation = 0.78

	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _build_lights() -> void:
	# Света в доме мало и он тёплый только в первой комнате. Дальше —
	# холодные отсветы, обозначающие направление, но не освещающие путь.
	_lamp(Vector3(0.0, 2.35, 0.6), Color(1.0, 0.78, 0.48), 1.4, 4.5)
	_lamp(Vector3(0.0, 2.35, -9.0), Color(0.5, 0.68, 1.0), 0.7, 4.0)
	_lamp(Vector3(6.0, 2.35, -11.0), Color(1.0, 0.5, 0.3), 0.9, 4.5)


func _lamp(pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	# Затухание круче единицы убирает видимый круглый обрез на стене:
	# свет гаснет плавно, а не заканчивается окружностью.
	light.omni_attenuation = 2.2
	light.shadow_enabled = true
	# Ненулевой размер источника даёт полутень. Резкая тень от точки —
	# первое, что выдаёт движок вместо комнаты.
	light.light_size = 0.35
	light.shadow_blur = 1.8
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
func _slab(centre: Vector3, size: Vector3, material: Material) -> StaticBody3D:
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

	return body


## Плинтус по всем стыкам пола и стен.
##
## Голый прямой угол между полом и стеной — самый заметный признак
## блокаута: в жилом помещении такого стыка не бывает. Плинтус ловит
## блик и затенение, и комната сразу читается как построенная.
func _build_trim() -> void:
	const H := 0.09
	const D := 0.022

	for room: Dictionary in ROOMS:
		var pos: Vector3 = room.pos
		var size: Vector3 = room.size
		var half := Vector3(size.x * 0.5, 0.0, size.z * 0.5)

		# Вдоль длинных стен.
		for dz in [-half.z, half.z]:
			_slab(
				Vector3(pos.x, H * 0.5, pos.z + dz - signf(dz) * D * 0.5),
				Vector3(size.x, H, D),
				_trim_material
			)
		# Вдоль торцов.
		for dx in [-half.x, half.x]:
			_slab(
				Vector3(pos.x + dx - signf(dx) * D * 0.5, H * 0.5, pos.z),
				Vector3(D, H, size.z),
				_trim_material
			)


## Мелочь, которой живут комнаты: бумага на полу, бутылки, забытые вещи.
## Пустая комната с одним предметом читается как кукольный домик,
## сколько на неё ни вешай света.
func _build_clutter() -> void:
	# Бумаги — плоские листы, разбросанные без порядка.
	var papers := [
		Vector3(0.9, 0.002, -0.6), Vector3(1.2, 0.002, -0.9),
		Vector3(-1.4, 0.002, 0.9), Vector3(0.2, 0.002, -4.2),
		Vector3(-0.6, 0.002, -6.1), Vector3(0.5, 0.002, -9.8),
		Vector3(4.6, 0.002, -10.2), Vector3(5.8, 0.002, -12.4),
	]
	for i in papers.size():
		var sheet := _slab(papers[i], Vector3(0.21, 0.001, 0.29), _paper_material)
		sheet.rotation.y = float(i) * 1.37

	# Бутылки и банки вдоль стен.
	var bottles := [
		Vector3(-2.2, 0.0, 1.6), Vector3(-2.35, 0.0, 1.35),
		Vector3(1.3, 0.0, -3.9), Vector3(-1.2, 0.0, -8.2),
		Vector3(6.8, 0.0, -9.6), Vector3(6.6, 0.0, -12.8),
	]
	for pos: Vector3 in bottles:
		var bottle := _cylinder(pos + Vector3(0, 0.13, 0), 0.035, 0.26, _dark_material)
		bottle.rotation.y = randf() * TAU

	# Провод вдоль плинтуса — тянется из комнаты в коридор.
	for i in 14:
		_slab(
			Vector3(-1.42, 0.05, 1.4 - i * 0.55),
			Vector3(0.012, 0.012, 0.5),
			_dark_material
		)


## Пыль в воздухе. Видна только в луче света — именно поэтому и работает:
## показывает, что воздух в комнате есть.
func _build_dust() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 420
	particles.lifetime = 14.0
	particles.preprocess = 8.0
	particles.visibility_aabb = AABB(Vector3(-12, 0, -18), Vector3(24, 4, 24))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(10.0, 1.4, 12.0)
	mat.gravity = Vector3(0.0, -0.012, 0.0)
	mat.initial_velocity_min = 0.01
	mat.initial_velocity_max = 0.05
	mat.scale_min = 0.35
	mat.scale_max = 1.0
	particles.process_material = mat

	# Пылинка должна быть на пределе различимости: заметная точка читается
	# как белый квадрат и портит кадр сильнее, чем отсутствие пыли вообще.
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.006, 0.006)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.albedo_color = Color(1.0, 0.96, 0.9, 0.12)
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Пыль не должна писать глубину — иначе она вырезает силуэты за собой.
	dust_mat.no_depth_test = false
	dust_mat.disable_receive_shadows = true
	mesh.material = dust_mat
	particles.draw_pass_1 = mesh

	particles.position = Vector3(0.0, 1.4, -6.0)
	add_child(particles)


func _cylinder(pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	add_child(node)
	return node


## Мебель — модели из Blender (tools/blender/furniture.py).
## Пустой интерьер читается как тестовая сцена, сколько на него
## ни вешай света, а коробки вместо мебели — как заглушка.
func _build_props() -> void:
	_prop("table", Vector3(1.6, 0.0, 0.4), 0.0, _floor_material)
	_prop("chair", Vector3(1.6, 0.0, 1.15), PI, _floor_material)
	_prop("chair", Vector3(0.75, 0.0, 0.4), -PI * 0.5, _floor_material)
	_prop("wardrobe", Vector3(-2.0, 0.0, -1.2), PI * 0.5, _floor_material)
	_prop("floor_lamp", Vector3(-1.9, 0.0, 1.4), 0.0, _dark_material)

	_prop("cardboard_box", Vector3(-0.9, 0.0, -5.5), 0.3, _floor_material)
	_prop("cardboard_box", Vector3(-0.85, 0.34, -5.45), -0.2, _floor_material)
	_prop("cardboard_box", Vector3(0.95, 0.0, -8.6), 1.1, _floor_material)
	_prop("cardboard_box", Vector3(5.4, 0.0, -12.2), -0.6, _floor_material)

	# Двери в проёмах — приоткрытые, чтобы за ними была видна темнота.
	_prop("door", Vector3(-0.55, 0.0, -2.2), 0.6, _floor_material)
	_prop("door", Vector3(-0.5, 0.0, -12.0), -0.5, _floor_material)

	# Косяки проёмов.
	for z in [-2.2, -12.0]:
		_slab(Vector3(-0.95, 1.05, z), Vector3(0.12, 2.1, 0.12), _dark_material)
		_slab(Vector3(0.95, 1.05, z), Vector3(0.12, 2.1, 0.12), _dark_material)


## Ставит модель и вешает на неё материал: из Blender геометрия приходит
## без материалов намеренно — так один и тот же стул может быть и дубовым,
## и крашеным.
func _prop(name: String, pos: Vector3, yaw: float, material: Material) -> void:
	var path := "res://assets/models/%s.glb" % name
	if not ResourceLoader.exists(path):
		push_warning("Нет модели %s" % path)
		return

	var scene: PackedScene = load(path)
	var node := scene.instantiate()
	node.position = pos
	node.rotation.y = yaw
	add_child(node)

	_apply_material(node, material)


func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_override = material
		# Мебель должна отбрасывать тень: без этого она «висит» над полом.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_apply_material(child, material)
