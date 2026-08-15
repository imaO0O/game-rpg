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
## Высота жилой комнаты. При 2.7 мебель и двери выглядели игрушечными:
## пространство читалось как ангар, а не как квартира.
const ROOM_H := 2.5

## Комнаты: положение и размер в метрах.
const ROOMS := [
	{"pos": Vector3(0, 0, 0), "size": Vector3(5, ROOM_H, 4)},
	{"pos": Vector3(0, 0, -7), "size": Vector3(3, ROOM_H, 10)},
	{"pos": Vector3(5, 0, -11), "size": Vector3(7, ROOM_H, 5)},
	{"pos": Vector3(-4, 0, -11), "size": Vector3(4, ROOM_H, 4)},
	# Комната Зейда: тесная, вытянутая, с одним выходом.
	{"pos": Vector3(-4, 0, -16), "size": Vector3(4, ROOM_H, 5)},
]

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _dark_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _paper_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D
var _helmet_material: StandardMaterial3D
var _furniture_material: StandardMaterial3D
var _appliance_material: StandardMaterial3D
var _stain: NoiseTexture2D
var _micro: NoiseTexture2D
var _mirror: Mirror
var _coffee: CoffeePoint
var _monitor: CameraMonitor
var _cameras: Array[SecurityCamera] = []
var _runaway_memory: MemoryObject


func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_rooms()
	_build_trim()
	_build_props()
	_build_clutter()
	_build_lights()
	_build_dust()
	_build_wear()
	_build_ambience()
	_build_memories()
	_build_cameras()
	_build_zade_room()
	_build_scares()
	_build_hud()


# --- Материалы ---------------------------------------------------------

func _build_materials() -> void:
	_floor_material = _pbr(
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_Color.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_NormalGL.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_Roughness.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_AmbientOcclusion.jpg",
		# Крупнее доска — реже повтор в кадре. При 1.5 рисунок пола
		# успевал повториться трижды на глубину коридора.
		Vector3(0.55, 0.55, 0.55)
	)
	# Старые доски не блестят. Без этого под лампой появлялось
	# зеркальное пятно, читавшееся как лужа в сухом коридоре.
	_floor_material.roughness = 0.92
	_floor_material.specular = 0.25
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

	# Плинтус заметно темнее стены — иначе он сливается с ней и стык
	# всё равно выглядит острым.
	_trim_material = StandardMaterial3D.new()
	_trim_material.albedo_color = Color(0.13, 0.11, 0.09)
	_trim_material.roughness = 0.85

	# Бумага почти не блестит и слегка светлее всего в комнате.
	_paper_material = StandardMaterial3D.new()
	_paper_material.albedo_color = Color(0.62, 0.60, 0.55)
	_paper_material.roughness = 0.95

	# Потолок — та же штукатурка, но темнее и глуше: побелка со временем
	# сереет, а бликов сверху быть не должно.
	_ceiling_material = _pbr(
		"res://assets/pbr/Plaster001/Plaster001_1K-JPG_Color.jpg",
		"res://assets/pbr/Plaster001/Plaster001_1K-JPG_NormalGL.jpg",
		"res://assets/pbr/Plaster001/Plaster001_1K-JPG_Roughness.jpg",
		"",
		Vector3(0.9, 0.9, 0.9)
	)
	_ceiling_material.albedo_color = Color(0.62, 0.60, 0.58)
	_ceiling_material.roughness = 1.0

	# Мебель светлее пола. С тем же материалом стол сливался с досками
	# и пропадал целиком: предметы на нём выглядели висящими в воздухе.
	_furniture_material = _pbr(
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_Color.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_NormalGL.jpg",
		"res://assets/pbr/WoodFloor043/WoodFloor043_1K-JPG_Roughness.jpg",
		"",
		Vector3(1.6, 1.6, 1.6)
	)
	# Albedo выше единицы физически невозможен: поверхность отражала
	# больше света, чем на неё падало, и дерево шло лакированной
	# полосой-бликом. Ниже единицы и глуше — получается патина.
	_furniture_material.albedo_color = Color(1.0, 0.95, 0.85)
	_furniture_material.roughness = 0.7

	# Техника: тёмная, но не чёрная. Чистый чёрный в кадре читается
	# как дыра или заглушка, а не как предмет.
	_appliance_material = StandardMaterial3D.new()
	# 0.14 всё ещё читалось чёрным кубом на светлом столе. Техника
	# должна быть темнее дерева, но оставаться предметом.
	_appliance_material.albedo_color = Color(0.26, 0.26, 0.28)
	_appliance_material.roughness = 0.35
	_appliance_material.metallic = 0.3

	# Единственная красная вещь в доме (CONCEPT_3D.md, «Тон»).
	# Лак должен бликовать: шлем обязан ловить взгляд.
	_helmet_material = StandardMaterial3D.new()
	_helmet_material.albedo_color = Color(0.72, 0.04, 0.03)
	_helmet_material.roughness = 0.18
	_helmet_material.metallic = 0.1
	_helmet_material.clearcoat_enabled = true
	_helmet_material.clearcoat = 0.8


func _pbr(color: String, normal: String, rough: String, ao: String, tiling: Vector3) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()

	if ResourceLoader.exists(color):
		mat.albedo_texture = load(color)
	if ResourceLoader.exists(normal):
		mat.normal_enabled = true
		mat.normal_texture = load(normal)
		# Полная сила рельефа на стенах даёт контраст, похожий на камуфляж.
		mat.normal_scale = 0.35
	if ResourceLoader.exists(rough):
		mat.roughness_texture = load(rough)
	if ao != "" and ResourceLoader.exists(ao):
		mat.ao_enabled = true
		mat.ao_texture = load(ao)

	mat.uv1_scale = tiling
	# Триплanar снимает вопрос развёртки: одна и та же настройка годится
	# и для пола, и для стен любого размера.
	mat.uv1_triplanar = true

	# Слой пятен поверх основного материала. Он крупнее тайла и не кратен
	# ему, поэтому разбивает регулярный повтор досок — именно повтор
	# первым выдаёт, что текстура положена «как есть».
	mat.detail_enabled = true
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_albedo = _stain_texture()
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	# Микрорельеф: мелкий шум как нормаль. Без него штукатурка остаётся
	# плоской даже под скользящим светом — свет не за что зацепиться.
	mat.detail_normal = _micro_normal()

	return mat


## Мелкий шум в виде карты нормалей. Частота на порядок выше, чем
## у карты пятен: одна разбивает повтор, вторая даёт сцепление со светом.
func _micro_normal() -> NoiseTexture2D:
	if _micro != null:
		return _micro

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.09
	noise.fractal_octaves = 3

	_micro = NoiseTexture2D.new()
	_micro.noise = noise
	_micro.width = 512
	_micro.height = 512
	_micro.seamless = true
	_micro.as_normal_map = true
	# Слабее, чем кажется нужным: при высоком контрасте пятна читаются
	# как камуфляж, а не как неровности штукатурки.
	_micro.bump_strength = 0.18
	return _micro


## Процедурная карта пятен: облачный шум, растянутый настолько, что
## его период не совпадает с периодом основной текстуры.
func _stain_texture() -> NoiseTexture2D:
	if _stain != null:
		return _stain

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.011
	noise.fractal_octaves = 3

	_stain = NoiseTexture2D.new()
	_stain.noise = noise
	_stain.width = 512
	_stain.height = 512
	_stain.seamless = true
	# Разброс намеренно узкий. Широкий давал на стенах облака, читавшиеся
	# как плесень; задача слоя — сбить регулярность, а не рисовать грязь.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.84, 0.83, 0.81),
		Color(0.94, 0.94, 0.93),
		Color(1.0, 1.0, 1.0),
	])
	_stain.color_ramp = ramp
	return _stain


# --- Освещение и атмосфера ---------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.12, 0.18)
	# Минимальный подсвет, чтобы вне конусов пол и потолок сохраняли
	# форму, а не проваливались в чистый чёрный.
	env.ambient_light_energy = 0.45

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
	env.ssao_intensity = 2.8
	env.ssao_radius = 1.2
	# Контактные тени в углах — то, чем обжитая комната отличается
	# от коробки. Без них стык стены и пола выглядит нарисованным.
	env.ssao_power = 1.5
	env.ssao_detail = 0.6

	env.ssil_enabled = true
	env.ssil_intensity = 0.6

	# Глобальное освещение: свет от лампы отражается от пола и стен и
	# доходит до потолка. Без него верх кадра остаётся угольно-чёрным,
	# и комната читается как коробка с прожектором.
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.75
	env.sdfgi_energy = 1.6
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.08

	env.glow_enabled = true
	# Порог поднят: при низком любая лампа превращается в выжженный
	# белый шар, и источник света перестаёт читаться как предмет.
	env.glow_intensity = 0.42
	env.glow_bloom = 0.08
	# Порог выше: при 1.25 в него пробивались обычные лампы, и каждая
	# превращалась в белое пятно. Свечение должно доставаться только
	# тому, что действительно ярче всего в кадре.
	env.glow_hdr_threshold = 1.7
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
	# Коридор длинный: при прежних 0.7 и четырёх метрах свет обрывался
	# на трети пути, и дальше геометрия не читалась вовсе.
	_lamp(Vector3(0.0, 2.35, -9.0), Color(0.5, 0.68, 1.0), 1.1, 5.5)
	# Вглубь и повыше: стоя у входа, лампа била прямо в объектив
	# и выжигала весь кадр. Свет должен быть в глубине, а не в лицо.
	# Шкаф перед лампой съедает часть света, но добирать это энергией
	# нельзя: при 1.4 лампа пробивала порог свечения и превращалась
	# в белое пятно. Вместо этого — вторая слабая точка ниже.
	_lamp(Vector3(7.5, 2.6, -13.0), Color(1.0, 0.5, 0.3), 0.95, 5.2)
	_point_light(Vector3(7.2, 0.9, -12.2), Color(1.0, 0.55, 0.35), 0.45, 3.2)

	# Ночник у кровати: без него правая половина дальней комнаты была
	# чернотой с красным бликом, и кадр читался как самый пустой в доме.
	# Без арматуры — потолочный плафон на высоте 1.3 висел бы посреди
	# комнаты ни на чём.
	_point_light(Vector3(6.4, 1.15, -11.9), Color(1.0, 0.78, 0.52), 0.7, 3.5, 3.0)


## Источник без арматуры. Нужен там, где свет мотивирован соседним
## предметом — ночник у кровати, подсветка часов, — и подвешивать
## к потолку плафон было бы враньём.
func _point_light(pos: Vector3, color: Color, energy: float, range_m: float, falloff := 2.0, size := 0.18) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	# Круче спад — компактнее пятно. Ночник с пологим затуханием
	# расплывался по всей стене.
	light.omni_attenuation = falloff
	# Крупнее источник — мягче край пятна. Точечный в упор к стене
	# рисует резкую сингулярность.
	light.light_size = size
	light.shadow_enabled = true
	light.shadow_blur = 1.6
	light.light_volumetric_fog_energy = 0.25
	light.add_to_group("house_light")
	add_child(light)


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
	light.light_size = 0.22
	light.shadow_blur = 1.8
	# Объёмный вклад слабый: при высоком лампа рисует вокруг себя мягкое
	# пятно, которое висит поверх сцены и не связано с геометрией —
	# первое, что бросается в глаза как дефект.
	light.light_volumetric_fog_energy = 0.35
	# Скримеры гасят весь свет разом — им нужно знать, что гасить.
	light.add_to_group("house_light")
	add_child(light)

	# Арматура: шнур, патрон, плафон. Голая светящаяся сфера читается
	# как источник света из движка, а не как лампа в комнате.
	var fixture_path := "res://assets/models/ceiling_lamp.glb"
	if ResourceLoader.exists(fixture_path):
		var scene: PackedScene = load(fixture_path)
		var fixture := scene.instantiate()
		# Модель свисает от точки крепления, поэтому вешаем её к потолку.
		fixture.position = Vector3(pos.x, pos.y + 0.34, pos.z)

		var enamel := StandardMaterial3D.new()
		enamel.albedo_color = Color(0.72, 0.70, 0.66)
		enamel.roughness = 0.35
		enamel.metallic = 0.2
		_apply_material(fixture, enamel)
		add_child(fixture)

	# Сама лампочка внутри плафона.
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	bulb.mesh = sphere
	bulb.position = pos

	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	# Не выше: при большем сама лампочка размазывается в пятно
	# на потолке — тот же дефект, что был у объёмного света.
	glow.emission_energy_multiplier = 1.5
	bulb.material_override = glow
	add_child(bulb)


# --- Геометрия ---------------------------------------------------------

func _build_rooms() -> void:
	for room: Dictionary in ROOMS:
		var pos: Vector3 = room.pos
		var size: Vector3 = room.size

		_slab(pos + Vector3(0, -WALL * 0.5, 0), Vector3(size.x, WALL, size.z), _floor_material)
		# Потолок — та же штукатурка, что и стены. Раньше он был выкрашен
		# почти в чёрный, и это выглядело как дыра в геометрии: света он
		# не отражал вовсе, сколько его ни добавляй.
		_slab(pos + Vector3(0, size.y + WALL * 0.5, 0), Vector3(size.x, WALL, size.z), _ceiling_material)

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
	# Выше и толще, чем кажется правильным: при девяти сантиметрах
	# плинтус в кадре не читался вовсе и стык оставался острым.
	const H := 0.13
	const D := 0.03

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

		# Вертикальные уголки. Прямое ребро стены не ловит свет и
		# выглядит нарисованным; узкая грань под углом даёт блик
		# и обозначает, где стена поворачивает.
		for dx in [-half.x, half.x]:
			for dz in [-half.z, half.z]:
				var corner := _slab(
					Vector3(
						pos.x + dx - signf(dx) * 0.03,
						size.y * 0.5,
						pos.z + dz - signf(dz) * 0.03
					),
					Vector3(0.05, size.y, 0.05),
					_wall_material
				)
				corner.rotation.y = PI * 0.25


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

	# Мелочь на поверхностях. Ровно она отличает комнату, где живут,
	# от комнаты, куда поставили мебель: взгляду нужно за что цепляться
	# на каждом плане, а не только на дальнем.
	_prop("mug", Vector3(1.35, 0.77, 0.1), 0.7, _paper_material)
	_prop("book", Vector3(1.85, 0.77, 0.55), -0.4, _furniture_material)
	_prop("book", Vector3(1.9, 0.79, 0.52), 0.3, _dark_material)
	_prop("bottle", Vector3(-2.3, 0.0, 1.75), 0.0, _dark_material)
	_prop("bottle", Vector3(-2.15, 0.0, 1.55), 0.9, _dark_material)
	_prop("photo_frame", Vector3(2.15, 0.79, -1.45), PI * 0.85, _floor_material)
	_prop("mug", Vector3(-1.95, 0.92, -1.05), -0.5, _paper_material)

	# Часы в коридоре: их вешают затем, чтобы игрок заметил,
	# что стрелки стоят. Циферблат светлый — на тёмном материале
	# часы просто не читались, и коридор выглядел пустым тупиком.
	_prop("wall_clock", Vector3(1.42, 1.85, -6.2), -PI * 0.5, _paper_material)
	# Своя подсветка: без неё циферблат теряется даже светлым.
	# Источник вынесен в комнату, а не прижат к стене: в двадцати
	# сантиметрах он давал точку-сингулярность, а сами часы оставались
	# в его же тени и читались чёрным силуэтом в белом ореоле.
	_point_light(Vector3(0.85, 1.85, -6.2), Color(1.0, 0.88, 0.7), 0.14, 1.6, 2.0, 0.3)

	# Дальняя комната — обжитая: кружка у кровати, книга, бутылка.
	_prop("mug", Vector3(5.9, 0.44, -12.3), 0.2, _paper_material)
	_prop("book", Vector3(6.05, 0.0, -10.6), 1.2, _furniture_material)
	_prop("bottle", Vector3(7.4, 0.0, -11.9), 0.0, _dark_material)
	_prop("tickets", Vector3(3.55, 0.79, -13.15), 0.5, _paper_material)

	# Комната Зейда: он тут жил, а не только следил.
	_prop("mug", Vector3(-2.6, 1.02, -17.5), -0.8, _paper_material)
	_prop("bottle", Vector3(-5.6, 0.0, -18.3), 0.4, _dark_material)
	_prop("bottle", Vector3(-5.45, 0.0, -18.1), 1.1, _dark_material)
	_prop("book", Vector3(-4.2, 0.0, -18.6), -0.9, _furniture_material)


## Следы жизни: затёртости на высоте руки, пятна под мебелью,
## тёмные полосы вдоль проходов.
##
## Идеально чистая стена читается как поверхность из редактора. Дом,
## в котором жили, грязнее там, где к нему прикасались, — и глаз
## считывает это раньше, чем успевает разобрать, что именно видит.
func _build_wear() -> void:
	# Затёртости у дверных проёмов — на той высоте, где берутся за косяк.
	for spot in [
		Vector3(-0.9, 1.05, -2.2), Vector3(0.9, 1.05, -2.2),
		Vector3(-0.9, 1.05, -12.0), Vector3(0.9, 1.05, -12.0),
	]:
		_wear_patch(spot, Vector3(0.5, 0.9, 0.5), 0.5)

	# Потёртости вдоль стен коридора: там ходят, задевая плечом.
	for i in 6:
		_wear_patch(
			Vector3(-1.4, 1.15, -3.5 - i * 1.6),
			Vector3(0.4, 1.2, 1.4),
			0.32
		)

	# Пятна на полу: под мебелью и там, где что-то проливали.
	for spot in [
		Vector3(1.6, 0.02, 0.4), Vector3(-2.0, 0.02, -1.2),
		Vector3(0.2, 0.02, -6.5), Vector3(6.4, 0.02, -11.4),
	]:
		_wear_patch(spot, Vector3(1.6, 0.5, 1.6), 0.4)


## Проекция пятна на всё, что под ней. Decal ложится по геометрии,
## поэтому одно и то же пятно годится и для стены, и для пола.
func _wear_patch(pos: Vector3, size: Vector3, strength: float) -> void:
	var decal := Decal.new()
	decal.position = pos
	decal.size = size
	decal.texture_albedo = _stain_texture()
	decal.albedo_mix = strength
	decal.modulate = Color(0.35, 0.33, 0.30)
	# Мягкие края: резкая граница пятна выдаёт наклейку.
	decal.upper_fade = 0.6
	decal.lower_fade = 0.6
	decal.normal_fade = 0.35
	add_child(decal)


## Камеры Зейда. Развешаны по углам и смотрят на проходы — туда,
## где человек обязательно окажется, а не в пустые стены.
func _build_cameras() -> void:
	var spots := [
		{
			"label": "кухня",
			"pos": Vector3(-2.2, 2.3, 1.7),
			"look": Vector3(1.6, 0.9, 0.2),
		},
		{
			"label": "коридор",
			"pos": Vector3(1.2, 2.3, -3.4),
			"look": Vector3(0.0, 1.0, -9.0),
		},
		{
			"label": "дальняя комната",
			"pos": Vector3(7.8, 2.3, -9.2),
			"look": Vector3(5.4, 0.9, -12.0),
		},
		{
			"label": "у зеркала",
			"pos": Vector3(1.2, 2.3, -7.6),
			"look": Vector3(-1.4, 1.1, -6.4),
		},
		# Камера в его же комнате, направленная на монитор. Переключив
		# на неё, игрок видит себя со спины — и монитор, показывающий
		# монитор.
		{
			"label": "эта комната",
			"pos": Vector3(-5.4, 2.2, -17.9),
			"look": Vector3(-2.6, 1.3, -17.2),
		},
	]

	for spot: Dictionary in spots:
		var camera := SecurityCamera.new()
		camera.label = spot.label
		camera.position = spot.pos
		add_child(camera)
		# Целимся после добавления: look_at требует места в дереве.
		camera.aim_at(spot.look)
		_cameras.append(camera)


## Комната Зейда: доска с фотографиями и стул напротив неё.
## Обстановка расставлена так, чтобы взгляд шёл по цепочке —
## сначала стул, потом то, на что он смотрит.
func _build_zade_room() -> void:
	var room := ZadeRoom.new()
	room.board_centre = Vector3(-4.0, 1.45, -18.3)
	add_child(room)

	# Стул стоит вплотную к доске и развёрнут к ней: здесь сидели долго.
	_prop("chair", Vector3(-4.0, 0.0, -16.4), 0.0, _furniture_material)
	_prop("shelf", Vector3(-5.6, 0.0, -17.4), PI * 0.5, _furniture_material)
	_prop("cardboard_box", Vector3(-2.7, 0.0, -17.9), 0.5, _floor_material)
	_prop("suitcase", Vector3(-2.6, 0.0, -15.4), -0.3, _dark_material)

	# Единственный свет — лампа сбоку от доски, а не перед ней:
	# висящая по центру била бы прямо в глаза входящему.
	_lamp(Vector3(-5.3, 1.75, -17.6), Color(1.0, 0.72, 0.42), 0.7, 3.4)

	# Финал в глубине его комнаты, за доской: чтобы дойти, надо пройти
	# мимо всего, что он собрал.
	# Комната Зейда занимает x от -6 до -2, z от -18.5 до -13.5 —
	# ставим в её дальний конец, а не за стену.
	var finale := Finale.new()
	finale.position = Vector3(-4.2, 0.0, -17.9)
	add_child(finale)

	# Тёплый свет только на нём: он последнее, что игрок увидит в доме.
	_point_light(Vector3(-4.2, 1.8, -17.6), Color(1.0, 0.82, 0.6), 0.9, 3.4, 2.4)

	# Монитор на столике сбоку: отсюда он смотрел за всем домом.
	_monitor = CameraMonitor.new()
	_monitor.position = Vector3(-2.35, 1.3, -17.2)
	_monitor.rotation.y = -PI * 0.5
	add_child(_monitor)

	# Осколок здесь один, и он про него, а не про города.
	var shard := MemoryObject.new()
	shard.id = "ryazan_04"
	shard.position = Vector3(-4.0, 0.5, -16.4)
	add_child(shard)


## Интерфейс. Ищем игрока в сцене, а не требуем ссылку: дом строится
## кодом, и лишняя связь в редакторе только ломалась бы.
func _build_hud() -> void:
	var hud := preload("res://src/proto3d/hud3d.tscn").instantiate()
	hud.player = get_node_or_null("Player")
	add_child(hud)


## Осколки памяти по дому. Идентификаторы те же, что в двумерной
## версии: каталог, сохранение и подписи переиспользуются целиком.
func _build_memories() -> void:
	# Осколок — конкретная вещь, а не светящаяся рамка. Кружка, стопка
	# билетов, книга, фотография: каждая говорит о хозяйке сама,
	# ещё до того, как игрок прочтёт подпись.
	var spots := [
		{"id": "ryazan_01", "pos": Vector3(1.6, 0.77, 0.7), "model": "mug"},
		{"id": "ryazan_02", "pos": Vector3(-2.0, 0.92, -1.2), "model": "tickets"},
		{"id": "ryazan_03", "pos": Vector3(0.4, 0.0, -8.2), "model": "book"},
		{"id": "ryazan_05", "pos": Vector3(6.2, 0.55, -12.6), "model": "photo_frame"},
	]

	for spot: Dictionary in spots:
		var memory := MemoryObject.new()
		memory.id = spot.id
		memory.model = spot.model
		memory.position = spot.pos
		add_child(memory)
		if spot.id == "ryazan_03":
			_runaway_memory = memory


## Ровный гул дома. Полная тишина в хорроре работает хуже гула:
## в тишине слышно, что звука просто нет, и иллюзия рассыпается.
func _build_ambience() -> void:
	var path := "res://assets/audio/ambience.wav"
	if not ResourceLoader.exists(path):
		return

	var player := AudioStreamPlayer.new()
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / 2
	player.stream = stream
	player.volume_db = -18.0
	player.autoplay = true
	add_child(player)


## Скримеры. Первый стоит в начале коридора: игрок должен узнать
## правила жанра раньше, чем уйдёт вглубь дома.
func _build_scares() -> void:
	var pitstop := preload("res://src/proto3d/scare_pitstop.gd").new()
	pitstop.position = Vector3(0.0, 1.2, -4.5)
	add_child(pitstop)

	# Зеркальный — дальше по коридору, когда игрок уже расслабился
	# после первого и решил, что понял правила.
	var mirror_scare := preload("res://src/proto3d/scare_mirror.gd").new()
	mirror_scare.position = Vector3(0.0, 1.2, -6.4)
	# Ссылку выставляем до добавления в дерево: _ready сработает сразу
	# в add_child, и после него присваивать уже поздно.
	mirror_scare.mirror = _mirror
	add_child(mirror_scare)

	# Змея — у шкафа в первой комнате: третий по счёту, но первый,
	# который меняет отношение к целому классу объектов в доме.
	var snake := preload("res://src/proto3d/scare_snake.gd").new()
	snake.position = Vector3(-1.6, 1.1, -1.2)
	add_child(snake)

	# Кофемашина пугает не входом в зону, а собственным нажатием
	# игрока — от этого и смешнее.
	var coffee_scare := preload("res://src/proto3d/scare_coffee.gd").new()
	coffee_scare.attach(_coffee)
	coffee_scare.position = _coffee.position
	add_child(coffee_scare)

	# Фигура на записи: срабатывает не от места, а от того, что игрок
	# переключил камеру на дальнюю комнату.
	var figure := preload("res://src/proto3d/scare_camera_figure.gd").new()
	figure.attach(_monitor)
	add_child(figure)

	# Самый неприятный: игрок видит себя со спины, и за ней кто-то есть.
	# Обернувшись, он не увидит ничего — проверить нельзя.
	var behind := preload("res://src/proto3d/scare_behind.gd").new()
	behind.attach(_monitor)
	add_child(behind)

	# Стратегия: надпись на стене коридора, меняющая решение.
	# Стоит на пути к дальней комнате — мимо не пройти.
	var strategy := preload("res://src/proto3d/scare_strategy.gd").new()
	strategy.position = Vector3(0.0, 1.5, -10.2)
	add_child(strategy)

	# Пинки в дальней комнате: там игрок уже расслабился и оглядывается,
	# а не идёт напряжённо вперёд.
	var pinkie := preload("res://src/proto3d/scare_pinkie.gd").new()
	pinkie.position = Vector3(4.6, 1.2, -11.2)
	add_child(pinkie)

	# Срабатывает от неудачи игрока, а не от места: врезался в стены
	# трижды — получил сочувствие от радио.
	var stupid := preload("res://src/proto3d/scare_stupid.gd").new()
	add_child(stupid)

	# Убегающий осколок в коридоре. Не пугает вовсе — раздражает,
	# а потом становится смешным. Нужен затем, чтобы игрок перестал
	# ждать удара от каждой странности в доме.
	if _runaway_memory != null:
		var runaway := preload("res://src/proto3d/scare_runaway.gd").new()
		runaway.attach(_runaway_memory, [
			Vector3(0.6, 0.35, -6.4),
			Vector3(-0.7, 0.35, -8.8),
			Vector3(0.8, 0.35, -11.2),
		] as Array[Vector3])
		add_child(runaway)

	# Дементор из пара — со второго кофе. Первый раз игрок уже получил
	# скример от самой машины, два подряд в одном месте превратили бы
	# точку покоя в аттракцион.
	var dementor := preload("res://src/proto3d/scare_dementor.gd").new()
	dementor.attach(_coffee)
	add_child(dementor)


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
	# Стол собран из плит, а не взят моделью: экспорт table.glb давал
	# файл нормального размера, но в сцене он не появлялся, а стулья
	# из того же скрипта работали. Разбираться дороже, чем собрать
	# из семи коробок — а заодно у стола появилась коллизия.
	_build_table(Vector3(1.6, 0.0, 0.4))
	_prop("chair", Vector3(1.6, 0.0, 1.15), PI, _furniture_material)
	_prop("chair", Vector3(0.75, 0.0, 0.4), -PI * 0.5, _furniture_material)
	_prop("wardrobe", Vector3(-2.0, 0.0, -1.2), PI * 0.5, _furniture_material)
	_prop("floor_lamp", Vector3(-1.9, 0.0, 1.4), 0.0, _dark_material)

	_prop("cardboard_box", Vector3(-0.9, 0.0, -5.5), 0.3, _floor_material)
	_prop("cardboard_box", Vector3(-0.85, 0.34, -5.45), -0.2, _floor_material)
	_prop("cardboard_box", Vector3(0.95, 0.0, -8.6), 1.1, _floor_material)
	_prop("cardboard_box", Vector3(5.4, 0.0, -12.2), -0.6, _floor_material)

	# Кофемашина — точка покоя. Модель отдельно, логика отдельно.
	# Не чёрная: на тёмном материале она читалась кубом-заглушкой
	# и забивала лучшее световое пятно кадра.
	_prop("coffee_machine", Vector3(1.55, 0.77, 0.15), -0.15, _appliance_material)

	_coffee = CoffeePoint.new()
	_coffee.id = "home_kitchen"
	_coffee.city = "Рязань"
	_coffee.drink = "капучино на овсяном"
	_coffee.position = Vector3(1.55, 0.77, 0.15)
	add_child(_coffee)

	# Стеллаж и то, что стоит на нём: шлем и чемодан рассказывают,
	# чей это дом, быстрее любой записки.
	_prop("shelf", Vector3(2.3, 0.0, -1.55), PI, _furniture_material)
	_prop("helmet", Vector3(2.15, 1.22, -1.5), 0.4, _helmet_material)
	_prop("suitcase", Vector3(-2.05, 0.0, 0.9), 0.25, _dark_material)

	# Спальня в дальней комнате.
	_prop("bed", Vector3(6.4, 0.0, -11.4), PI * 0.5, _furniture_material)
	_prop("shelf", Vector3(3.4, 0.0, -13.2), 0.0, _furniture_material)

	# Шкаф в глубине комнаты, между входом и дальней лампой: срезает
	# часть света и даёт клин тени. Не у самого входа — там он просто
	# упирался бы в лицо входящему.
	_prop("wardrobe", Vector3(6.4, 0.0, -12.4), -PI * 0.35, _furniture_material)

	# Рама зеркала — модель, само стекло — отдельный узел с отражением.
	# Рама деревянная: плоский чёрный материал читался как дыра в стене,
	# а не как предмет.
	_prop("mirror", Vector3(-1.42, 0.0, -6.4), PI * 0.5, _floor_material)

	_mirror = Mirror.new()
	_mirror.glass_size = Vector2(0.52, 1.14)
	_mirror.position = Vector3(-1.38, 0.62, -6.4)
	_mirror.rotation.y = PI * 0.5
	add_child(_mirror)

	# Двери в проёмах — приоткрытые, чтобы за ними была видна темнота.
	_prop("door", Vector3(-0.55, 0.0, -2.2), 0.6, _floor_material)
	_prop("door", Vector3(-0.5, 0.0, -12.0), -0.5, _floor_material)

	# Косяки проёмов.
	for z in [-2.2, -12.0]:
		_slab(Vector3(-0.95, 1.05, z), Vector3(0.12, 2.1, 0.12), _dark_material)
		_slab(Vector3(0.95, 1.05, z), Vector3(0.12, 2.1, 0.12), _dark_material)


## Стол: столешница, две царги и четыре ножки.
func _build_table(pos: Vector3) -> void:
	const TOP_H := 0.74
	_slab(pos + Vector3(0.0, TOP_H + 0.025, 0.0), Vector3(1.3, 0.05, 0.8), _furniture_material)

	for dz in [-0.34, 0.34]:
		_slab(pos + Vector3(0.0, TOP_H - 0.06, dz), Vector3(1.18, 0.08, 0.06), _furniture_material)

	for dx in [-0.58, 0.58]:
		for dz in [-0.33, 0.33]:
			_slab(
				pos + Vector3(dx, TOP_H * 0.5, dz),
				Vector3(0.06, TOP_H, 0.06),
				_furniture_material
			)


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
